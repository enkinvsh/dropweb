import 'dart:async';
import 'dart:io';

import 'package:dropweb/plugins/vpn.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingVpnListener with VpnListener {
  _RecordingVpnListener(this.onDns);

  final void Function(String dns) onDns;

  @override
  void onDnsChanged(String dns) => onDns(dns);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // `handleDnsChangedPayload` logs when it rejects a malformed payload, and
  // that log reaches `FileLogger`, which asks `path_provider` for a directory
  // over a MethodChannel. With no platform behind the channel the call fails
  // asynchronously — after the test that triggered it has already finished —
  // so the run reported "failed after test completion" for a test whose own
  // assertions had passed. It surfaced as an intermittent local failure and a
  // hard red on CI, on a test that has nothing to do with logging.
  //
  // Pointing the channel at a temp directory lets that write complete instead
  // of throwing into a dead zone. Same treatment `show_error_message_test`
  // already gives it.
  late Directory supportDirectory;
  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'dropweb_vpn_network_change_test',
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => supportDirectory.path,
    );
  });

  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (supportDirectory.existsSync()) {
      await supportDirectory.delete(recursive: true);
    }
  });

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
