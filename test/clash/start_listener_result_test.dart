import 'dart:convert';

import 'package:dropweb/clash/start_listener_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String wire({required bool ok, String? tunError}) =>
      jsonEncode({'ok': ok, 'tunError': tunError});

  group('parseStartListenerResult', () {
    test('proxy-only / effective success parses into an ok outcome', () {
      final outcome = parseStartListenerResult(wire(ok: true));

      expect(outcome, isA<StartListenerOk>());
    });

    test('real tun failure preserves the exact core cause verbatim', () {
      final outcome = parseStartListenerResult(
        wire(ok: false, tunError: 'wintun: adapter is already in use'),
      );

      expect(outcome, isA<StartListenerTunError>());
      expect(
        (outcome as StartListenerTunError).cause,
        'wintun: adapter is already in use',
      );
    });

    test('not-ok payload with a null cause is a protocol failure, not ok', () {
      expect(
        () => parseStartListenerResult(wire(ok: false, tunError: null)),
        throwsA(isA<StartListenerProtocolException>()),
      );
    });

    test('not-ok payload with an empty cause is a protocol failure', () {
      expect(
        () => parseStartListenerResult(wire(ok: false, tunError: '')),
        throwsA(isA<StartListenerProtocolException>()),
      );
    });

    test('malformed (non-JSON) payload fails closed, never a false default',
        () {
      expect(
        () => parseStartListenerResult('not-json'),
        throwsA(isA<StartListenerProtocolException>()),
      );
    });

    test('missing ok key fails closed', () {
      expect(
        () => parseStartListenerResult(jsonEncode({'tunError': null})),
        throwsA(isA<StartListenerProtocolException>()),
      );
    });

    test('non-object payload (bare bool string) fails closed', () {
      expect(
        () => parseStartListenerResult('true'),
        throwsA(isA<StartListenerProtocolException>()),
      );
    });

    test('ok=true with a non-null cause fails closed (contradiction)', () {
      expect(
        () => parseStartListenerResult(
          wire(ok: true, tunError: 'unexpected cause'),
        ),
        throwsA(isA<StartListenerProtocolException>()),
      );
    });

    test('wrong-typed ok value fails closed', () {
      expect(
        () => parseStartListenerResult(jsonEncode({'ok': 'yes'})),
        throwsA(isA<StartListenerProtocolException>()),
      );
    });
  });
}
