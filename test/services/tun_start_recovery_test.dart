import 'package:dropweb/clash/start_listener_result.dart';
import 'package:dropweb/services/tun_start_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

/// A scripted logical start whose outcomes the recovery driver consumes in
/// order. Each call pops the next scripted result; a StartListenerTimeout
/// entry throws the timeout exception, a TunError entry throws TunStart
/// exception, a success entry returns normally.
class _ScriptedStart {
  _ScriptedStart(this._script);

  final List<Object> _script;
  int calls = 0;

  Future<void> call() async {
    final step = _script[calls];
    calls++;
    if (step is StartListenerTimeoutException) throw step;
    if (step is TunStartException) throw step;
    // success: return normally
  }
}

void main() {
  final timeout = StartListenerTimeoutException(const Duration(seconds: 30));

  group('runTunStartRecovery', () {
    test('first hang then a single restart then success => connected',
        () async {
      final start = _ScriptedStart([timeout, 'ok']);
      var recoveries = 0;

      final outcome = await runTunStartRecovery(
        start: start.call,
        recover: () async => recoveries++,
      );

      expect(outcome, TunStartRecovery.connected);
      expect(start.calls, 2);
      expect(recoveries, 1);
    });

    test('two hangs => exactly one restart then honest timeout', () async {
      final start = _ScriptedStart([timeout, timeout]);
      var recoveries = 0;

      final outcome = await runTunStartRecovery(
        start: start.call,
        recover: () async => recoveries++,
      );

      expect(outcome, TunStartRecovery.timedOut);
      expect(start.calls, 2);
      expect(recoveries, 1);
    });

    test('typed tun error => zero restarts, exact cause propagated', () async {
      final start = _ScriptedStart([
        const TunStartException('wintun: adapter is already in use'),
      ]);
      var recoveries = 0;

      TunStartException? thrown;
      try {
        await runTunStartRecovery(
          start: start.call,
          recover: () async => recoveries++,
        );
      } on TunStartException catch (error) {
        thrown = error;
      }

      expect(thrown, isNotNull);
      expect(thrown!.cause, 'wintun: adapter is already in use');
      expect(start.calls, 1);
      expect(recoveries, 0);
    });

    test('immediate success => zero restarts', () async {
      final start = _ScriptedStart(['ok']);
      var recoveries = 0;

      final outcome = await runTunStartRecovery(
        start: start.call,
        recover: () async => recoveries++,
      );

      expect(outcome, TunStartRecovery.connected);
      expect(start.calls, 1);
      expect(recoveries, 0);
    });

    test('recover failure after first timeout propagates fail-closed',
        () async {
      final start = _ScriptedStart([timeout, 'unused']);
      final failure = StateError('helper identity missing');

      await expectLater(
        runTunStartRecovery(
          start: start.call,
          recover: () async => throw failure,
        ),
        throwsA(same(failure)),
      );

      expect(start.calls, 1);
    });
  });
}
