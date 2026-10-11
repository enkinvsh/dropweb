/// Маяк зеркал: подписанный провайдером список шаблонов адресов подписки,
/// лежащий на сторонних статических хостингах. Нужен, когда умерли все
/// адреса, которые приложение уже знает, и новый фронт можно сообщить только
/// через канал, который трудно заблокировать и нельзя подделать.
/// Контракт — docs/subscription-headers.md, раздел 10.
///
/// Файл без Flutter-зависимостей: его же использует tool/sign_sub_beacon.dart.
library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'subscription_resilience.dart';

/// Ключ провайдера, а не пользователя: токена в этих заголовках нет, но и в
/// plaintext `providerHeaders` им делать нечего — читаются они только из
/// защищённого хранилища.
const subscriptionBeaconHeaders = {
  'dropweb-sub-beacon',
  'dropweb-sub-beacon-key',
};

/// Несколько хостингов на случай блокировки одного; больше — лишние запросы
/// на каждом аварийном обновлении.
const kMaxBeaconUrls = 4;

/// Текущий ключ + ротация (новый и старый одновременно) + запас.
const kMaxBeaconKeys = 3;

/// Столько же, сколько зеркал в `dropweb-sub-mirrors`.
const kMaxBeaconTemplates = kMaxSubscriptionMirrors;

/// Документ — пара строк base64; 64 KiB с большим запасом, а мусор или
/// подменённая страница хостинга дальше не разбираются.
const kMaxBeaconDocumentBytes = 64 * 1024;

/// Потолок попыток по адресам из маяка за одно обновление: каждая — до
/// десятков секунд таймаутов.
const kMaxBeaconAttempts = 4;

const _kEd25519KeyBytes = 32;
const _kEd25519SignatureBytes = 64;
const _kIdPlaceholder = '{id}';

/// Документ маяка отвергнут. [reason] — короткий код без адресов и ключей:
/// он может попасть в лог.
class BeaconRejected implements Exception {
  const BeaconRejected(this.reason);

  final String reason;

  @override
  String toString() => 'BeaconRejected: $reason';
}

/// Проверенное содержимое маяка.
class BeaconPayload {
  const BeaconPayload({
    required this.seq,
    required this.mirrors,
    this.expires,
  });

  final int seq;
  final int? expires;

  /// Шаблоны адресов с `{id}`.
  final List<String> mirrors;
}

/// Что храним о маяке на профиль: максимальный принятый seq (защита от
/// отката на старый, возможно скомпрометированный список) и сам последний
/// проверенный документ — запасной вариант, если ни один хостинг не отвечает.
class BeaconState {
  const BeaconState({required this.seq, required this.document});

  final int seq;
  final String document;

  String encode() => json.encode({'seq': seq, 'doc': document});

  static BeaconState? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return null;
      final seq = decoded['seq'];
      final doc = decoded['doc'];
      if (seq is! int || doc is! String) return null;
      return BeaconState(seq: seq, document: doc);
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is BeaconState && other.seq == seq && other.document == document;

  @override
  int get hashCode => Object.hash(seq, document);
}

/// Результат поиска маяка. [fromCache] — ни один хостинг не дал валидного
/// документа, взят сохранённый.
class BeaconResolution {
  const BeaconResolution({
    required this.payload,
    required this.state,
    required this.fromCache,
  });

  final BeaconPayload payload;
  final BeaconState state;
  final bool fromCache;
}

/// Разбирает `dropweb-sub-beacon`: те же правила, что у зеркал подписки.
List<String> parseSubscriptionBeaconUrls(String? raw) =>
    parseSubscriptionMirrors(raw).take(kMaxBeaconUrls).toList();

List<int>? _decodeBase64(String value) {
  try {
    return base64.decode(base64.normalize(value));
  } catch (_) {
    return null;
  }
}

/// Разбирает `dropweb-sub-beacon-key`: base64 открытых ключей Ed25519.
/// Ключи приводятся к стандартному base64, чтобы дедуп работал и для
/// url-safe записи.
List<String> parseSubscriptionBeaconKeys(String? raw) {
  if (raw == null) return const [];
  final result = <String>[];
  for (final token in raw.split(RegExp(r'[,;\s]+'))) {
    if (token.isEmpty) continue;
    final bytes = _decodeBase64(token);
    if (bytes == null || bytes.length != _kEd25519KeyBytes) continue;
    final canonical = base64.encode(bytes);
    if (result.contains(canonical)) continue;
    result.add(canonical);
    if (result.length >= kMaxBeaconKeys) break;
  }
  return result;
}

/// Шаблон допустим, только если после подстановки любого id получается
/// адрес с разрешённым транспортом.
bool isValidBeaconTemplate(String template) =>
    template.contains(_kIdPlaceholder) &&
    isAllowedSubscriptionUri(
      Uri.tryParse(template.trim().replaceAll(_kIdPlaceholder, 'id')),
    );

/// Проверяет документ маяка. Подпись — над сырыми байтами payload, поэтому
/// канонизация JSON не нужна. [minSeq] — максимальный уже принятый seq:
/// равный принимается (тот же документ с другого хостинга), меньший — нет.
Future<BeaconPayload> verifyBeaconDocument(
  List<int> documentBytes, {
  required List<String> keys,
  int minSeq = 0,
  DateTime? now,
}) async {
  if (documentBytes.length > kMaxBeaconDocumentBytes) {
    throw const BeaconRejected('too-large');
  }
  final Object? document;
  try {
    document = json.decode(utf8.decode(documentBytes));
  } catch (_) {
    throw const BeaconRejected('malformed');
  }
  if (document is! Map) throw const BeaconRejected('malformed');
  final payloadField = document['payload'];
  final sigField = document['sig'];
  if (payloadField is! String || sigField is! String) {
    throw const BeaconRejected('malformed');
  }
  final payloadBytes = _decodeBase64(payloadField);
  final sigBytes = _decodeBase64(sigField);
  if (payloadBytes == null ||
      sigBytes == null ||
      sigBytes.length != _kEd25519SignatureBytes) {
    throw const BeaconRejected('malformed');
  }

  if (!await _verifiedByAnyKey(payloadBytes, sigBytes, keys)) {
    throw const BeaconRejected('bad-signature');
  }

  final Object? payload;
  try {
    payload = json.decode(utf8.decode(payloadBytes));
  } catch (_) {
    throw const BeaconRejected('malformed-payload');
  }
  if (payload is! Map) throw const BeaconRejected('malformed-payload');
  if (payload['v'] != 1) throw const BeaconRejected('version');
  final seq = payload['seq'];
  if (seq is! int || seq < 1) throw const BeaconRejected('seq');
  if (seq < minSeq) throw const BeaconRejected('rollback');
  final expires = payload['expires'];
  if (expires != null) {
    if (expires is! int) throw const BeaconRejected('expires');
    final nowSec = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    if (expires < nowSec) throw const BeaconRejected('expired');
  }
  final mirrors = payload['mirrors'];
  if (mirrors is! List || mirrors.isEmpty) {
    throw const BeaconRejected('no-mirrors');
  }
  if (mirrors.length > kMaxBeaconTemplates) {
    throw const BeaconRejected('too-many-mirrors');
  }
  final templates = <String>[];
  for (final template in mirrors) {
    // Подписанный документ с битым шаблоном — ошибка подписанта; лучше не
    // принять его целиком, чем молча работать с половиной списка.
    if (template is! String || !isValidBeaconTemplate(template)) {
      throw const BeaconRejected('bad-template');
    }
    templates.add(template.trim());
  }
  return BeaconPayload(
    seq: seq,
    expires: expires as int?,
    mirrors: templates,
  );
}

Future<bool> _verifiedByAnyKey(
  List<int> message,
  List<int> signature,
  List<String> keys,
) async {
  final algorithm = Ed25519();
  for (final key in keys) {
    final keyBytes = _decodeBase64(key);
    if (keyBytes == null || keyBytes.length != _kEd25519KeyBytes) continue;
    try {
      final ok = await algorithm.verify(
        message,
        signature: Signature(
          signature,
          publicKey: SimplePublicKey(keyBytes, type: KeyPairType.ed25519),
        ),
      );
      if (ok) return true;
    } catch (_) {
      // Невалидный ключ не должен мешать проверке остальными.
    }
  }
  return false;
}

/// Персональные адреса подписки из шаблонов: `{id}` кодируется целиком,
/// чтобы id со слэшами или пробелами не менял структуру адреса.
List<String> beaconSubscriptionUrls(List<String> templates, String subId) {
  final encoded = Uri.encodeComponent(subId);
  final result = <String>[];
  final seen = <String>{};
  for (final template in templates) {
    final url = normalizeProfileUrl(
      template.replaceAll(_kIdPlaceholder, encoded),
    );
    if (!isAllowedSubscriptionUri(Uri.tryParse(url))) continue;
    if (!seen.add(url)) continue;
    result.add(url);
  }
  return result;
}

/// Скачивает документы со всех [beaconUrls] и берёт валидный с наибольшим
/// seq; если валидных нет — проверенный ранее документ из [cached].
/// [fetch] обязан ходить на хостинг маяка без каких-либо данных профиля.
/// [onFailure] получает только номер и ошибку — адреса в лог не уходят.
Future<BeaconResolution?> resolveBeacon({
  required List<String> beaconUrls,
  required List<String> keys,
  required BeaconState? cached,
  required Future<List<int>> Function(String url) fetch,
  void Function(int index, int total, Object error)? onFailure,
  DateTime? now,
}) async {
  if (keys.isEmpty) return null;
  final minSeq = cached?.seq ?? 0;
  BeaconPayload? best;
  String? bestDocument;
  for (var i = 0; i < beaconUrls.length; i++) {
    try {
      final bytes = await fetch(beaconUrls[i]);
      final payload = await verifyBeaconDocument(
        bytes,
        keys: keys,
        minSeq: minSeq,
        now: now,
      );
      if (best == null || payload.seq > best.seq) {
        best = payload;
        bestDocument = utf8.decode(bytes);
      }
    } catch (e) {
      onFailure?.call(i, beaconUrls.length, e);
    }
  }
  if (best != null && bestDocument != null) {
    return BeaconResolution(
      payload: best,
      state: BeaconState(seq: best.seq, document: bestDocument),
      fromCache: false,
    );
  }
  if (cached == null) return null;
  try {
    // Кэш перепроверяется: ключи могли смениться, срок — истечь.
    final payload = await verifyBeaconDocument(
      utf8.encode(cached.document),
      keys: keys,
      minSeq: cached.seq,
      now: now,
    );
    return BeaconResolution(payload: payload, state: cached, fromCache: true);
  } catch (e) {
    onFailure?.call(beaconUrls.length, beaconUrls.length, e);
    return null;
  }
}
