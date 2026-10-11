// Подписант маяка: документ, который он выпускает, должен проходить проверку
// приложения, а подделанный — нет.
import 'dart:convert';
import 'dart:io';

import 'package:dropweb/common/subscription_beacon.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/sign_sub_beacon.dart';

void main() {
  final seed = List<int>.generate(32, (i) => i);

  test('подписанный документ проходит проверку приложения', () async {
    final pub = await beaconPublicKeyForSeed(seed);
    final doc = await signBeaconDocument(
      seed: seed,
      seq: 7,
      mirrors: ['https://front.example/s/{id}'],
    );

    final payload = await verifyBeaconDocument(utf8.encode(doc), keys: [pub]);

    expect(payload.seq, 7);
    expect(payload.mirrors, ['https://front.example/s/{id}']);
  });

  test('подменённый payload не проходит', () async {
    final pub = await beaconPublicKeyForSeed(seed);
    final doc = json.decode(await signBeaconDocument(
      seed: seed,
      seq: 1,
      mirrors: ['https://front.example/{id}'],
    )) as Map<String, dynamic>;
    doc['payload'] = base64.encode(utf8.encode(json.encode({
      'v': 1,
      'seq': 1,
      'mirrors': ['https://evil.example/{id}'],
    })));

    expect(
      () => verifyBeaconDocument(utf8.encode(json.encode(doc)), keys: [pub]),
      throwsA(isA<BeaconRejected>()),
    );
  });

  test('шаблон без {id} или не https — отказ', () {
    expect(
      () => signBeaconDocument(
          seed: seed, seq: 1, mirrors: ['https://front.example/s']),
      throwsArgumentError,
    );
    expect(
      () => signBeaconDocument(
          seed: seed, seq: 1, mirrors: ['http://front.example/{id}']),
      throwsArgumentError,
    );
  });

  test('CLI: keygen → sign → документ проверяется', () async {
    final out = StringBuffer();
    expect(await runSignSubBeacon(['keygen'], out, StringBuffer()), 0);
    final lines = out.toString().trim().split('\n');
    final privateLine = lines.firstWhere((l) => l.startsWith('private:'));
    final publicLine = lines.firstWhere((l) => l.startsWith('public:'));
    final privateSeed = privateLine.substring('private:'.length).trim();
    final pub = publicLine.substring('public:'.length).trim();

    final dir = await Directory.systemTemp.createTemp('beacon-key');
    addTearDown(() => dir.delete(recursive: true));
    final keyFile = File('${dir.path}/key')
      ..writeAsStringSync('$privateSeed\n');

    final docOut = StringBuffer();
    final code = await runSignSubBeacon([
      'sign',
      '--key',
      keyFile.path,
      '--seq',
      '3',
      '--expires-days',
      '30',
      '--mirror',
      'https://front.example/a/{id}',
      '--mirror',
      'https://b.front.example/{id}',
    ], docOut, StringBuffer());
    expect(code, 0);

    final payload = await verifyBeaconDocument(
      utf8.encode(docOut.toString().trim()),
      keys: [pub],
    );
    expect(payload.seq, 3);
    expect(payload.expires, isNotNull);
    expect(payload.mirrors, hasLength(2));
  });

  test('CLI: плохой шаблон → ненулевой код, документа нет', () async {
    final dir = await Directory.systemTemp.createTemp('beacon-key');
    addTearDown(() => dir.delete(recursive: true));
    final keyFile = File('${dir.path}/key')
      ..writeAsStringSync(base64.encode(seed));
    final out = StringBuffer();
    final err = StringBuffer();

    final code = await runSignSubBeacon([
      'sign',
      '--key',
      keyFile.path,
      '--seq',
      '1',
      '--mirror',
      'https://front.example/no-id',
    ], out, err);

    expect(code, isNot(0));
    expect(out.toString(), isEmpty);
    expect(err.toString(), isNotEmpty);
  });

  test('CLI: --help по-русски', () async {
    final out = StringBuffer();
    expect(await runSignSubBeacon(['--help'], out, StringBuffer()), 0);
    expect(out.toString(), contains('Использование'));
  });
}
