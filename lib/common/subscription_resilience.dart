/// Устойчивость подписки к падению одного фронта: провайдер называет зеркала
/// той же подписки (`dropweb-sub-mirrors`) и её стабильный идентификатор
/// (`dropweb-sub-id`). Контракт — docs/subscription-headers.md.
library;

import 'subscription_beacon.dart';

/// Заголовки, значения которых несут токен подписки. В `providerHeaders`
/// (plaintext Config) они не попадают — только в защищённое хранилище.
const subscriptionSecretHeaders = {
  'dropweb-sub-mirrors',
  'dropweb-sub-id',
  'fallback-url',
};

/// Заголовки, которым не место в plaintext Config: секреты подписки и
/// параметры маяка (последние живут только в защищённом хранилище).
bool isStoredOutsideConfigHeader(String name) =>
    subscriptionSecretHeaders.contains(name) ||
    subscriptionBeaconHeaders.contains(name);

Map<String, String> withoutSecretHeaders(Map<String, String> headers) {
  if (!headers.keys.any(isStoredOutsideConfigHeader)) return headers;
  return {
    for (final entry in headers.entries)
      if (!isStoredOutsideConfigHeader(entry.key)) entry.key: entry.value,
  };
}

/// Больше зеркал панели незачем: каждый кандидат — до 45 с таймаутов.
const kMaxSubscriptionMirrors = 8;

/// Потолок попыток за одно обновление, чтобы мёртвые фронты не растягивали
/// обновление на минуты.
const kMaxSubscriptionCandidates = 6;

const _kMaxSubIdLength = 128;

/// Та же нормализация, что делает `addProfileFormURL`, чтобы сравнение по URL
/// совпадало с тем, что реально сохранено в профиле.
String normalizeProfileUrl(String url) {
  final trimmed = url.trim();
  return Uri.tryParse(trimmed)?.toString() ?? trimmed;
}

// Те же правила, что у `parseAccountApiBases`: plain http допустим только для
// loopback при локальной разработке.
bool _isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1' ||
      normalized == '[::1]';
}

/// Общее правило транспорта для адресов подписки и маяка: https, а plain http
/// только для loopback.
bool isAllowedSubscriptionUri(Uri? parsed) {
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) return false;
  return parsed.scheme == 'https' ||
      (parsed.scheme == 'http' && _isLoopbackHost(parsed.host));
}

/// Разбирает `dropweb-sub-mirrors`. Невалидные записи молча выбрасываются,
/// чтобы опечатка в одном зеркале не отключала остальные.
List<String> parseSubscriptionMirrors(String? raw) {
  if (raw == null) return const [];
  final result = <String>[];
  final seen = <String>{};
  for (final token in raw.split(RegExp(r'[,;\s]+'))) {
    if (token.isEmpty) continue;
    final parsed = Uri.tryParse(token);
    if (!isAllowedSubscriptionUri(parsed)) continue;
    final normalized = parsed!.toString();
    if (!seen.add(normalized)) continue;
    result.add(normalized);
    if (result.length >= kMaxSubscriptionMirrors) break;
  }
  return result;
}

/// Разбирает `dropweb-sub-id`. Обычно это токен из пути подписки, поэтому
/// значение — секрет, а не метка для показа.
String? parseSubscriptionSubId(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed.length > _kMaxSubIdLength) {
    return null;
  }
  return trimmed;
}

/// Порядок перебора адресов при обновлении. [preferred] — последний сработавший
/// не основной адрес; он идёт первым, только если всё ещё входит в набор
/// (иначе панель его уже убрала, и стучаться туда незачем).
List<String> subscriptionCandidates({
  String? preferred,
  required String primary,
  List<String> mirrors = const [],
  String? fallback,
}) {
  final known = <String>[
    primary,
    ...mirrors,
    if (fallback != null && fallback.trim().isNotEmpty) fallback,
  ];
  final knownNormalized = known.map(normalizeProfileUrl).toSet();
  final ordered = <String>[
    if (preferred != null &&
        preferred.trim().isNotEmpty &&
        knownNormalized.contains(normalizeProfileUrl(preferred)))
      preferred,
    ...known,
  ];
  final result = <String>[];
  final seen = <String>{};
  for (final candidate in ordered) {
    final normalized = normalizeProfileUrl(candidate);
    if (normalized.isEmpty || !seen.add(normalized)) continue;
    result.add(normalized);
    if (result.length >= kMaxSubscriptionCandidates) break;
  }
  return result;
}
