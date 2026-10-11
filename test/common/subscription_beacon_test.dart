// Маяк зеркал: разбор заголовков, проверка подписанного документа, сборка
// персональных адресов. Всё без сети.
import 'dart:convert';

import 'package:dropweb/common/subscription_beacon.dart';
import 'package:dropweb/common/subscription_resilience.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/beacon_signing.dart';

const _tpl = 'https://front.example/sub/{id}';

Map<String, Object?> _payload({
  int v = 1,
  int seq = 1,
  int? expires,
  List<String> mirrors = const [_tpl],
}) =>
    {
      'v': v,
      'seq': seq,
      if (expires != null) 'expires': expires,
      'mirrors': mirrors,
    };

void main() {
  final key = TestBeaconKey(7);
  final otherKey = TestBeaconKey(9);
  late String pub;
  late String otherPub;

  setUpAll(() async {
    pub = await key.publicKeyBase64();
    otherPub = await otherKey.publicKeyBase64();
  });

  Future<Object?> rejection(
    String doc, {
    List<String>? keys,
    int minSeq = 0,
    DateTime? now,
  }) async {
    try {
      await verifyBeaconDocument(
        utf8.encode(doc),
        keys: keys ?? [pub],
        minSeq: minSeq,
        now: now,
      );
      return null;
    } catch (e) {
      return e;
    }
  }

  group('parseSubscriptionBeaconUrls', () {
    test('https, разделители, дедуп', () {
      expect(
        parseSubscriptionBeaconUrls(
          'https://beacon.example/a.json, https://beacon.example/a.json;'
          ' https://b.beacon.example/x.json',
        ),
        [
          'https://beacon.example/a.json',
          'https://b.beacon.example/x.json',
        ],
      );
    });

    test('http только для loopback, мусор выбрасывается', () {
      expect(
        parseSubscriptionBeaconUrls(
          'http://beacon.example/a ftp://x/y http://127.0.0.1:8080/b nope',
        ),
        ['http://127.0.0.1:8080/b'],
      );
    });

    test('не больше 4', () {
      final raw =
          List.generate(6, (i) => 'https://b$i.beacon.example/d').join(',');
      expect(parseSubscriptionBeaconUrls(raw), hasLength(4));
    });

    test('null → пусто', () {
      expect(parseSubscriptionBeaconUrls(null), isEmpty);
    });
  });

  group('parseSubscriptionBeaconKeys', () {
    test('валидные 32 байта, невалидные выбрасываются, дедуп', () {
      final short = base64.encode(List.filled(16, 1));
      expect(
        parseSubscriptionBeaconKeys('$pub, $short;not-base64!! $pub $otherPub'),
        [pub, otherPub],
      );
    });

    test('не больше 3', () {
      final keys = List.generate(5, (i) => base64.encode(List.filled(32, i)));
      expect(parseSubscriptionBeaconKeys(keys.join(' ')), hasLength(3));
    });

    test('null → пусто', () {
      expect(parseSubscriptionBeaconKeys(null), isEmpty);
    });
  });

  group('verifyBeaconDocument', () {
    test('валидный документ', () async {
      final doc = await key.sign(_payload(seq: 3));
      final payload = await verifyBeaconDocument(utf8.encode(doc), keys: [pub]);
      expect(payload.seq, 3);
      expect(payload.mirrors, [_tpl]);
    });

    test('подпись над другим payload → отказ', () async {
      final doc = json.decode(await key.sign(_payload())) as Map;
      final forged = json.encode({
        'payload': base64.encode(
          utf8.encode(
              json.encode(_payload(mirrors: ['https://evil.example/{id}']))),
        ),
        'sig': doc['sig'],
      });
      expect(await rejection(forged), isA<BeaconRejected>());
    });

    test('чужой ключ → отказ', () async {
      final doc = await otherKey.sign(_payload());
      expect(await rejection(doc), isA<BeaconRejected>());
    });

    test('ротация: подходит второй ключ', () async {
      final doc = await otherKey.sign(_payload());
      expect(await rejection(doc, keys: [pub, otherPub]), isNull);
    });

    test('v ≠ 1 → отказ', () async {
      expect(await rejection(await key.sign(_payload(v: 2))),
          isA<BeaconRejected>());
    });

    test('seq ниже принятого → отказ (откат)', () async {
      expect(await rejection(await key.sign(_payload(seq: 4)), minSeq: 5),
          isA<BeaconRejected>());
    });

    test('seq равный принятому → ок', () async {
      expect(
          await rejection(await key.sign(_payload(seq: 5)), minSeq: 5), isNull);
    });

    test('seq < 1 → отказ', () async {
      expect(await rejection(await key.sign(_payload(seq: 0))),
          isA<BeaconRejected>());
    });

    test('expires в прошлом → отказ, в будущем → ок', () async {
      final now = DateTime.utc(2026, 10, 11);
      final nowSec = now.millisecondsSinceEpoch ~/ 1000;
      expect(
        await rejection(await key.sign(_payload(expires: nowSec - 1)),
            now: now),
        isA<BeaconRejected>(),
      );
      expect(
        await rejection(await key.sign(_payload(expires: nowSec + 60)),
            now: now),
        isNull,
      );
    });

    test('шаблон без {id} → отказ', () async {
      expect(
        await rejection(
            await key.sign(_payload(mirrors: ['https://front.example/s']))),
        isA<BeaconRejected>(),
      );
    });

    test('http-шаблон → отказ, loopback http → ок', () async {
      expect(
        await rejection(
            await key.sign(_payload(mirrors: ['http://front.example/{id}']))),
        isA<BeaconRejected>(),
      );
      expect(
        await rejection(
            await key.sign(_payload(mirrors: ['http://127.0.0.1:1/{id}']))),
        isNull,
      );
    });

    test('больше 8 шаблонов → отказ', () async {
      final many = List.generate(9, (i) => 'https://f$i.front.example/{id}');
      expect(await rejection(await key.sign(_payload(mirrors: many))),
          isA<BeaconRejected>());
    });

    test('пустой список шаблонов → отказ', () async {
      expect(await rejection(await key.sign(_payload(mirrors: []))),
          isA<BeaconRejected>());
    });

    test('документ больше 64 KiB → отказ', () async {
      final doc = await key.sign(_payload());
      final padded = doc.replaceFirst('{', '{"pad":"${'x' * 70000}",');
      expect(await rejection(padded), isA<BeaconRejected>());
    });

    test('не JSON / нет полей → отказ', () async {
      expect(await rejection('<html>'), isA<BeaconRejected>());
      expect(await rejection('{"payload":1}'), isA<BeaconRejected>());
    });

    test('причина отказа не содержит шаблонов', () async {
      final e = await rejection(
          await key.sign(_payload(mirrors: ['http://secret.example/{id}'])));
      expect(e.toString(), isNot(contains('secret.example')));
    });
  });

  group('beaconSubscriptionUrls', () {
    test('{id} подставляется с кодированием и нормализуется', () {
      expect(
        beaconSubscriptionUrls(
          ['https://front.example/s/{id}', 'https://b.front.example/{id}/raw'],
          'a b/c',
        ),
        [
          'https://front.example/s/a%20b%2Fc',
          'https://b.front.example/a%20b%2Fc/raw',
        ],
      );
    });

    test('дубли после подстановки схлопываются', () {
      expect(
        beaconSubscriptionUrls(
          ['https://front.example/{id}', 'https://front.example/{id}'],
          'X',
        ),
        ['https://front.example/X'],
      );
    });
  });

  group('resolveBeacon', () {
    Future<BeaconResolution?> resolve({
      required Map<String, Object> docs,
      BeaconState? cached,
      List<String>? urls,
      List<Object>? failures,
    }) =>
        resolveBeacon(
          beaconUrls: urls ?? docs.keys.toList(),
          keys: [pub],
          cached: cached,
          fetch: (url) async {
            final doc = docs[url];
            if (doc is String) return utf8.encode(doc);
            if (doc is Exception) throw doc;
            throw StateError('unreachable');
          },
          onFailure: (i, n, e) => failures?.add(e),
        );

    test('из нескольких валидных берётся максимальный seq', () async {
      final r = await resolve(docs: {
        'https://a.beacon.example/d': await key.sign(_payload(seq: 2)),
        'https://b.beacon.example/d': await key.sign(
            _payload(seq: 5, mirrors: ['https://new.front.example/{id}'])),
        'https://c.beacon.example/d': await key.sign(_payload(seq: 3)),
      });
      expect(r!.payload.seq, 5);
      expect(r.fromCache, isFalse);
      expect(r.state.seq, 5);
      expect(r.payload.mirrors, ['https://new.front.example/{id}']);
    });

    test('маяки недоступны → кэш', () async {
      final cachedDoc = await key.sign(_payload(seq: 4));
      final failures = <Object>[];
      final r = await resolve(
        docs: {'https://a.beacon.example/d': Exception('down')},
        cached: BeaconState(seq: 4, document: cachedDoc),
        failures: failures,
      );
      expect(r!.fromCache, isTrue);
      expect(r.payload.seq, 4);
      expect(failures, hasLength(1));
    });

    test('откат seq с маяка отвергается, используется кэш', () async {
      final cachedDoc = await key.sign(_payload(seq: 6));
      final r = await resolve(
        docs: {'https://a.beacon.example/d': await key.sign(_payload(seq: 2))},
        cached: BeaconState(seq: 6, document: cachedDoc),
      );
      expect(r!.fromCache, isTrue);
      expect(r.payload.seq, 6);
    });

    test('ничего валидного и нет кэша → null', () async {
      final r = await resolve(
        docs: {'https://a.beacon.example/d': await otherKey.sign(_payload())},
      );
      expect(r, isNull);
    });

    test('BeaconState: encode/decode', () {
      const s = BeaconState(seq: 3, document: '{"payload":"x","sig":"y"}');
      expect(BeaconState.decode(s.encode()), s);
      expect(BeaconState.decode('garbage'), isNull);
      expect(BeaconState.decode(null), isNull);
    });
  });

  test('заголовки маяка', () {
    expect(subscriptionBeaconHeaders, {
      'dropweb-sub-beacon',
      'dropweb-sub-beacon-key',
    });
  });

  test('withoutSecretHeaders убирает и заголовки маяка', () {
    expect(
      withoutSecretHeaders({
        'dropweb-sub-beacon': 'https://beacon.example/d',
        'dropweb-sub-beacon-key': 'k',
        'dropweb-theme': 'x',
      }),
      {'dropweb-theme': 'x'},
    );
  });
}
