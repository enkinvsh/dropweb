import 'dart:convert';
import 'dart:math';

import 'package:dropweb/views/profiles/receive_profile_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateHandoffNonce', () {
    test('is 32 lowercase hex chars (16 bytes)', () {
      final nonce = generateHandoffNonce();

      expect(nonce.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(nonce), isTrue);
    });

    test('produces different values across calls (secure source)', () {
      final values = List.generate(50, (_) => generateHandoffNonce()).toSet();

      // 50 random 128-bit values must be unique.
      expect(values.length, 50);
    });

    test('accepts an injected Random for deterministic generation', () {
      // Same seed → same nonce; proves the byte→hex encoding is stable.
      final a = generateHandoffNonce(Random(1234));
      final b = generateHandoffNonce(Random(1234));

      expect(a, b);
      expect(a.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(a), isTrue);
    });
  });

  group('validateHandoffBody', () {
    const nonce = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6';

    String body(Map<String, dynamic> m) => jsonEncode(m);

    test('garbage body → 400', () {
      expect(validateHandoffBody('not json {{{', nonce).statusCode, 400);
      expect(validateHandoffBody('', nonce).statusCode, 400);
    });

    test('non-object JSON (array/number/string) → 400', () {
      expect(validateHandoffBody('[1,2,3]', nonce).statusCode, 400);
      expect(validateHandoffBody('42', nonce).statusCode, 400);
      expect(validateHandoffBody('"hello"', nonce).statusCode, 400);
    });

    test('missing nonce → 403', () {
      final r = validateHandoffBody(body({'url': 'https://x/sub'}), nonce);

      expect(r.statusCode, 403);
      expect(r.url, isNull);
    });

    test('wrong nonce → 403', () {
      final r = validateHandoffBody(
        body({'url': 'https://x/sub', 'nonce': 'deadbeef'}),
        nonce,
      );

      expect(r.statusCode, 403);
      expect(r.url, isNull);
    });

    test('non-string nonce → 403', () {
      final r = validateHandoffBody(
        body({'url': 'https://x/sub', 'nonce': 12345}),
        nonce,
      );

      expect(r.statusCode, 403);
    });

    test('wrong nonce takes precedence over missing url (no info leak)', () {
      // An unauthenticated caller must not learn anything about url validity.
      final r = validateHandoffBody(body({'nonce': 'wrong'}), nonce);

      expect(r.statusCode, 403);
    });

    test('correct nonce but missing/empty url → 400', () {
      expect(validateHandoffBody(body({'nonce': nonce}), nonce).statusCode, 400);
      expect(
        validateHandoffBody(body({'nonce': nonce, 'url': ''}), nonce).statusCode,
        400,
      );
      expect(
        validateHandoffBody(body({'nonce': nonce, 'url': 7}), nonce).statusCode,
        400,
      );
    });

    test('correct nonce + valid url → 200 with url', () {
      const url = 'https://panel.example/api/sub/TOKEN';
      final r = validateHandoffBody(body({'nonce': nonce, 'url': url}), nonce);

      expect(r.statusCode, 200);
      expect(r.url, url);
    });
  });
}
