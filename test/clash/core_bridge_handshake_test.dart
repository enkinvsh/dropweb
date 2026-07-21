import 'dart:async';
import 'dart:convert';

import 'package:dropweb/clash/core_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef';
  const expectation = CoreBridgeExpectation(
    runToken: token,
    corePid: 42,
    coreCreationTime100ns: 1337,
  );
  const current = CoreBootAttempt(generation: 3, attempt: 2);

  String hello({
    String runToken = token,
    int corePid = 42,
    int creationTime = 1337,
  }) =>
      jsonEncode({
        'type': 'dropweb-core-hello',
        'protocol': 1,
        'runToken': runToken,
        'corePid': corePid,
        'coreCreationTime100ns': creationTime,
      });

  test('valid first hello admits only the exact current attempt', () {
    final parsed = admitCoreBridgeHello(
      line: hello(),
      expectation: expectation,
      attempt: current,
      currentAttempt: current,
    );

    expect(parsed.runToken, token);
  });

  test('wrong token never reaches the admission completer', () {
    final admitted = Completer<void>();

    expect(
      () {
        admitCoreBridgeHello(
          line: hello(runToken: 'fedcba9876543210fedcba9876543210'),
          expectation: expectation,
          attempt: current,
          currentAttempt: current,
        );
        admitted.complete();
      },
      throwsA(isA<CoreBridgeHandshakeException>()),
    );
    expect(admitted.isCompleted, isFalse);
  });

  test('non-hello first frame never reaches the admission completer', () {
    final admitted = Completer<void>();

    expect(
      () {
        admitCoreBridgeHello(
          line: jsonEncode({'id': 'late-action', 'code': 0}),
          expectation: expectation,
          attempt: current,
          currentAttempt: current,
        );
        admitted.complete();
      },
      throwsA(isA<CoreBridgeHandshakeException>()),
    );
    expect(admitted.isCompleted, isFalse);
  });

  test('stale generation and helper response mismatch fail closed', () {
    const stale = CoreBootAttempt(generation: 2, attempt: 2);

    expect(
      () => admitCoreBridgeHello(
        line: hello(),
        expectation: expectation,
        attempt: stale,
        currentAttempt: current,
      ),
      throwsA(isA<CoreBridgeHandshakeException>()),
    );
    expect(
      () => admitCoreBridgeHello(
        line: hello(corePid: 43),
        expectation: expectation,
        attempt: current,
        currentAttempt: current,
      ),
      throwsA(isA<CoreBridgeHandshakeException>()),
    );
    expect(
      () => admitCoreBridgeHello(
        line: hello(creationTime: 1338),
        expectation: expectation,
        attempt: current,
        currentAttempt: current,
      ),
      throwsA(isA<CoreBridgeHandshakeException>()),
    );
  });
}
