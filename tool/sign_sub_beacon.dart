// Подписант маяка зеркал подписки (docs/subscription-headers.md, раздел 10).
//
//   fvm dart tool/sign_sub_beacon.dart keygen
//   fvm dart tool/sign_sub_beacon.dart sign --key beacon.key --seq 2 \
//       --mirror 'https://front.example/sub/{id}' > beacon.json
//
// Запускать именно `dart <файл>`, а не `dart run`: `dart run` пишет в stdout
// служебное «Running build hooks...», и оно попадёт в документ.
//
// Проверка шаблонов — та же функция, что в приложении: документ, который
// приложение отвергнет, подписант не выпустит.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:dropweb/common/subscription_beacon.dart';

const _help = '''
Подписант маяка зеркал подписки.

Использование:
  dart tool/sign_sub_beacon.dart keygen
      Создаёт пару ключей Ed25519 и печатает:
        private: <base64 seed, 32 байта> — хранить в секрете, НЕ публиковать;
        public:  <base64 открытый ключ>  — значение заголовка
                 dropweb-sub-beacon-key.

  dart tool/sign_sub_beacon.dart sign --key <файл> --seq <n>
      [--expires-days <d>] --mirror <шаблон> [--mirror <шаблон> ...]
      Печатает в stdout документ маяка (JSON) — его кладут на любой
      статический https-хостинг по адресу из заголовка dropweb-sub-beacon.
        --key           файл с base64 private seed из keygen;
        --seq           номер версии списка, целое ≥ 1; каждый новый документ —
                        с бо́льшим номером (приложение не примет откат);
        --expires-days  через сколько дней документ перестанет приниматься
                        (по умолчанию — бессрочно);
        --mirror        шаблон адреса подписки с {id} (подставится sub-id
                        пользователя), только https; до 8 шаблонов.

  dart tool/sign_sub_beacon.dart --help
''';

/// Открытый ключ (base64) для приватного seed.
Future<String> beaconPublicKeyForSeed(List<int> seed) async {
  final keyPair = await Ed25519().newKeyPairFromSeed(seed);
  return base64.encode((await keyPair.extractPublicKey()).bytes);
}

/// Документ маяка. Подписываются сырые байты payload — приложению не нужна
/// канонизация JSON, чтобы проверить подпись.
Future<String> signBeaconDocument({
  required List<int> seed,
  required int seq,
  required List<String> mirrors,
  int? expires,
}) async {
  if (seed.length != 32) {
    throw ArgumentError('seed должен быть 32 байта');
  }
  if (seq < 1) throw ArgumentError('seq должен быть ≥ 1');
  if (mirrors.isEmpty) throw ArgumentError('нужен хотя бы один --mirror');
  if (mirrors.length > kMaxBeaconTemplates) {
    throw ArgumentError('не больше $kMaxBeaconTemplates шаблонов');
  }
  for (final template in mirrors) {
    // loopback-http приложение допускает для отладки, но в публикуемый
    // документ ему попадать незачем.
    if (!isValidBeaconTemplate(template) ||
        !template.trim().startsWith('https://')) {
      throw ArgumentError(
        'шаблон должен быть https и содержать {id}: $template',
      );
    }
  }
  final payload = utf8.encode(json.encode({
    'v': 1,
    'seq': seq,
    if (expires != null) 'expires': expires,
    'mirrors': mirrors,
  }));
  final keyPair = await Ed25519().newKeyPairFromSeed(seed);
  final signature = await Ed25519().sign(payload, keyPair: keyPair);
  return json.encode({
    'payload': base64.encode(payload),
    'sig': base64.encode(signature.bytes),
  });
}

Future<int> runSignSubBeacon(
  List<String> args,
  StringSink out,
  StringSink err,
) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    out.write(_help);
    return args.isEmpty ? 64 : 0;
  }
  switch (args.first) {
    case 'keygen':
      final random = Random.secure();
      final seed = List<int>.generate(32, (_) => random.nextInt(256));
      out
        ..writeln('private: ${base64.encode(seed)}')
        ..writeln('public: ${await beaconPublicKeyForSeed(seed)}');
      return 0;
    case 'sign':
      return _sign(args.skip(1).toList(), out, err);
    default:
      err.writeln('Неизвестная команда: ${args.first}. См. --help');
      return 64;
  }
}

Future<int> _sign(List<String> args, StringSink out, StringSink err) async {
  String? keyPath;
  int? seq;
  int? expiresDays;
  final mirrors = <String>[];
  for (var i = 0; i < args.length; i++) {
    final name = args[i];
    if (i + 1 >= args.length) {
      err.writeln('У $name нет значения. См. --help');
      return 64;
    }
    final value = args[++i];
    switch (name) {
      case '--key':
        keyPath = value;
      case '--seq':
        seq = int.tryParse(value);
      case '--expires-days':
        expiresDays = int.tryParse(value);
        if (expiresDays == null || expiresDays < 1) {
          err.writeln('--expires-days должен быть целым ≥ 1');
          return 64;
        }
      case '--mirror':
        mirrors.add(value);
      default:
        err.writeln('Неизвестный параметр: $name. См. --help');
        return 64;
    }
  }
  if (keyPath == null || seq == null) {
    err.writeln('Нужны --key и --seq. См. --help');
    return 64;
  }

  final List<int> seed;
  try {
    seed = base64.decode(File(keyPath).readAsStringSync().trim());
  } catch (e) {
    err.writeln('Не удалось прочитать ключ из $keyPath: ${e.runtimeType}');
    return 66;
  }

  final expires = expiresDays == null
      ? null
      : DateTime.now()
              .add(Duration(days: expiresDays))
              .millisecondsSinceEpoch ~/
          1000;
  try {
    out.writeln(await signBeaconDocument(
      seed: seed,
      seq: seq,
      mirrors: mirrors,
      expires: expires,
    ));
    return 0;
  } on ArgumentError catch (e) {
    err.writeln('Ошибка: ${e.message}');
    return 65;
  }
}

Future<void> main(List<String> args) async {
  exitCode = await runSignSubBeacon(args, stdout, stderr);
}
