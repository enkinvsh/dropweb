import 'dart:async';

import 'package:dropweb/clash/interface.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// A handler whose [sendMessage] never produces a reply, so every [invoke]
/// resolves through its timeout path. Used to exercise the REAL [invoke]
/// timeout machinery in [ClashHandlerInterface].
class _NeverReplyHandler extends ClashHandlerInterface {
  @override
  void sendMessage(String message) {
    // Intentionally drop the message: the core never answers, forcing a timeout.
  }

  @override
  void reStart() {}

  @override
  FutureOr<bool> destroy() => true;

  @override
  Future<bool> preload() async => true;
}

/// A handler that records the [onTimeout]/[timeout]/[method] each call site
/// passes into [invoke] and then simulates the timeout path faithfully
/// (mirroring the real default-value resolution in [invoke]). This lets the
/// wiring of [setupConfig]/[updateConfig] be asserted without waiting on their
/// real multi-minute timeouts.
class _CapturingHandler extends ClashHandlerInterface {
  ActionMethod? capturedMethod;
  Duration? capturedTimeout;
  Object? capturedOnTimeout;
  bool capturedOnTimeoutWasNull = true;

  @override
  void sendMessage(String message) {}

  @override
  void reStart() {}

  @override
  FutureOr<bool> destroy() => true;

  @override
  Future<bool> preload() async => true;

  @override
  Future<T> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
    FutureOr<T> Function()? onTimeout,
    T? defaultValue,
  }) async {
    capturedMethod = method;
    capturedTimeout = timeout;
    capturedOnTimeout = onTimeout;
    capturedOnTimeoutWasNull = onTimeout == null;
    // Simulate a timeout: faithfully reproduce invoke's resolution order.
    if (onTimeout != null) {
      return await onTimeout();
    }
    // Mirror invoke's default-value behavior (String -> "").
    if (defaultValue != null) return defaultValue;
    if (T == String) return "" as T;
    if (T == bool) return false as T;
    throw StateError("no default for $T");
  }
}

UpdateParams _minimalUpdateParams() => const UpdateParams(
      tun: Tun(),
      mixedPort: 7890,
      allowLan: false,
      findProcessMode: FindProcessMode.off,
      mode: Mode.rule,
      logLevel: LogLevel.info,
      ipv6: false,
      tcpConcurrent: false,
      externalController: ExternalControllerStatus.close,
      unifiedDelay: false,
    );

SetupParams _minimalSetupParams() => const SetupParams(
      config: {},
      selectedMap: {},
      testUrl: "",
    );

void main() {
  group('invoke timeout contract', () {
    test('String invoke WITHOUT onTimeout returns empty default on timeout '
        '(getters rely on this — must not regress)', () async {
      final handler = _NeverReplyHandler();
      final result = await handler.invoke<String>(
        method: ActionMethod.getTraffic,
        timeout: const Duration(milliseconds: 100),
      );
      expect(result, isEmpty);
    });

    test('String invoke WITH onTimeout returns the sentinel on timeout',
        () async {
      final handler = _NeverReplyHandler();
      final result = await handler.invoke<String>(
        method: ActionMethod.setupConfig,
        timeout: const Duration(milliseconds: 100),
        onTimeout: () => "error: core call timed out (test)",
      );
      expect(result, isNotEmpty);
      expect(result, startsWith("error:"));
    });
  });

  group('mutating calls fail-closed on timeout (the bug fix)', () {
    test('setupConfig passes a non-null onTimeout returning an error sentinel',
        () async {
      final handler = _CapturingHandler();
      final result = await handler.setupConfig(_minimalSetupParams());
      expect(result, isNotEmpty,
          reason: 'a timed-out setupConfig must NOT look like success ("")');
      expect(result, startsWith("error:"));
      expect(handler.capturedMethod, ActionMethod.setupConfig);
      expect(handler.capturedOnTimeoutWasNull, isFalse,
          reason: 'setupConfig must wire an explicit onTimeout sentinel');
    });

    test('updateConfig passes a non-null onTimeout returning an error sentinel',
        () async {
      final handler = _CapturingHandler();
      final result = await handler.updateConfig(_minimalUpdateParams());
      expect(result, isNotEmpty,
          reason: 'a timed-out updateConfig must NOT look like success ("")');
      expect(result, startsWith("error:"));
      expect(handler.capturedMethod, ActionMethod.updateConfig);
      expect(handler.capturedOnTimeoutWasNull, isFalse,
          reason: 'updateConfig must wire an explicit onTimeout sentinel');
    });
  });
}
