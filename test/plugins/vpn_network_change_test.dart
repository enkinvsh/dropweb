import 'dart:async';

import 'package:dropweb/plugins/vpn.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_path_provider.dart';

class _RecordingVpnListener with VpnListener {
  _RecordingVpnListener(this.onDns);

  final void Function(String dns) onDns;

  @override
  void onDnsChanged(String dns) => onDns(dns);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useFakePathProvider();

  group('handleUnderlyingNetworkChanged', () {
    test('network change resets resolver before closing connections',
        () async {
      final calls = <String>[];

      await handleUnderlyingNetworkChanged(
        resetConnections: () {
          calls.add('reset');
          return true;
        },
        closeConnections: () {
          calls.add('close');
          return true;
        },
        invalidateDelayData: () => calls.add('invalidate'),
      );

      expect(calls, ['reset', 'close', 'invalidate']);
    });

    test('network change awaits asynchronous resolver reset', () async {
      final calls = <String>[];
      final reset = Completer<bool>();

      final done = handleUnderlyingNetworkChanged(
        resetConnections: () {
          calls.add('reset');
          return reset.future;
        },
        closeConnections: () {
          calls.add('close');
          return true;
        },
        invalidateDelayData: () => calls.add('invalidate'),
      );

      await Future<void>.delayed(Duration.zero);
      expect(calls, ['reset'],
          reason: 'close must not run while the resolver reset is pending');

      reset.complete(true);
      await done;
      expect(calls, ['reset', 'close', 'invalidate']);
    });

    test('network change awaits asynchronous connection close', () async {
      final calls = <String>[];
      final close = Completer<bool>();

      final done = handleUnderlyingNetworkChanged(
        resetConnections: () {
          calls.add('reset');
          return true;
        },
        closeConnections: () {
          calls.add('close');
          return close.future;
        },
        invalidateDelayData: () => calls.add('invalidate'),
      );

      await Future<void>.delayed(Duration.zero);
      expect(calls, ['reset', 'close'],
          reason: 'invalidate must not run while the close is pending');

      close.complete(true);
      await done;
      expect(calls, ['reset', 'close', 'invalidate']);
    });

    // V2: `networkChanged` is delivered to the VPN SERVICE isolate, which has
    // no AppController at all (`globalState._appController` is only ever set
    // from lib/application.dart, i.e. by the UI isolate). Resolving the
    // invalidator eagerly threw `Null check operator used on a null value`
    // and aborted the whole reset — the core kept the previous bearer's DNS
    // pools and flows. The reset MUST still complete without it.
    test('network change without an AppController still resets the core',
        () async {
      final calls = <String>[];

      await handleUnderlyingNetworkChanged(
        resetConnections: () {
          calls.add('reset');
          return true;
        },
        closeConnections: () {
          calls.add('close');
          return true;
        },
        invalidateDelayData: null,
      );

      expect(calls, ['reset', 'close'],
          reason: 'a missing delay invalidator must not abort the core reset');
    });

    test('skipped delay invalidation is reported, never silent', () async {
      final logs = <String>[];
      // Snapshot debugPrint INSIDE the body: the test binding swaps it after
      // top-level main() runs, and restoring a stale snapshot trips
      // debugAssertAllFoundationVarsUnset.
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      addTearDown(() => debugPrint = previousDebugPrint);

      await handleUnderlyingNetworkChanged(
        resetConnections: () => true,
        closeConnections: () => true,
        invalidateDelayData: null,
      );

      expect(
        logs.where((line) => line.contains('delay data not invalidated')),
        isNotEmpty,
        reason: 'the degraded path must be visible in the log, not silent',
      );
    });
  });

  group('normalizeSystemDnsPayload', () {
    test('empty DNS payload remains empty', () {
      expect(normalizeSystemDnsPayload(''), '');
    });

    test('DNS normalization removes empty entries and duplicates', () {
      expect(
        normalizeSystemDnsPayload('1.1.1.1:53, ,1.1.1.1:53,[::1]:53'),
        '1.1.1.1:53,[::1]:53',
      );
    });
  });

  group('dnsChanged dispatch', () {
    test('malformed non-string MethodChannel DNS payload is ignored', () {
      final received = <String>[];
      final listener = _RecordingVpnListener(received.add);
      final vpnInstance = Vpn();
      vpnInstance.addListener(listener);
      addTearDown(() => vpnInstance.removeListener(listener));

      expect(() => vpnInstance.handleDnsChangedPayload(42), returnsNormally);
      expect(received, isEmpty,
          reason: 'a non-string payload must never reach listeners');

      // A valid payload still reaches listeners, normalized.
      vpnInstance.handleDnsChangedPayload('1.1.1.1:53,1.1.1.1:53');
      expect(received, ['1.1.1.1:53']);

      // Empty stays a meaningful clear command.
      vpnInstance.handleDnsChangedPayload('');
      expect(received, ['1.1.1.1:53', '']);
    });
  });
}
