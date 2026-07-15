import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropweb/common/connectivity_close_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldCloseConnectionsForConnectivity', () {
    test('desktop plus wifi only returns true', () {
      expect(
        shouldCloseConnectionsForConnectivity(
          isDesktop: true,
          results: [ConnectivityResult.wifi],
        ),
        isTrue,
      );
    });

    test('desktop plus ethernet only returns true', () {
      expect(
        shouldCloseConnectionsForConnectivity(
          isDesktop: true,
          results: [ConnectivityResult.ethernet],
        ),
        isTrue,
      );
    });

    test('desktop result containing vpn returns false', () {
      expect(
        shouldCloseConnectionsForConnectivity(
          isDesktop: true,
          results: [ConnectivityResult.wifi, ConnectivityResult.vpn],
        ),
        isFalse,
      );
    });

    test('android/non-desktop plus wifi only returns false', () {
      expect(
        shouldCloseConnectionsForConnectivity(
          isDesktop: false,
          results: [ConnectivityResult.wifi],
        ),
        isFalse,
      );
    });

    test('android/non-desktop empty result returns false', () {
      expect(
        shouldCloseConnectionsForConnectivity(
          isDesktop: false,
          results: const [],
        ),
        isFalse,
      );
    });

    test('non-desktop result without vpn returns false', () {
      expect(
        shouldCloseConnectionsForConnectivity(
          isDesktop: false,
          results: [ConnectivityResult.mobile, ConnectivityResult.ethernet],
        ),
        isFalse,
      );
    });
  });

  group('handleConnectivityChanged coordinator', () {
    test('desktop close branch awaits close and still runs both updates',
        () async {
      final calls = <String>[];
      final close = Completer<bool>();

      final done = handleConnectivityChanged(
        isDesktop: true,
        results: [ConnectivityResult.wifi],
        closeConnections: () {
          calls.add('close');
          return close.future;
        },
        updateLocalIp: () => calls.add('updateLocalIp'),
        addCheckIpNumDebounce: () => calls.add('addCheckIpNumDebounce'),
      );

      await Future<void>.delayed(Duration.zero);
      expect(calls, ['close'],
          reason: 'updates wait for the in-flight close');

      close.complete(true);
      await done;
      expect(calls, ['close', 'updateLocalIp', 'addCheckIpNumDebounce']);
    });

    test('android no-close branch still runs both non-destructive updates',
        () async {
      final calls = <String>[];

      await handleConnectivityChanged(
        isDesktop: false,
        results: [ConnectivityResult.wifi],
        closeConnections: () {
          calls.add('close');
          return true;
        },
        updateLocalIp: () => calls.add('updateLocalIp'),
        addCheckIpNumDebounce: () => calls.add('addCheckIpNumDebounce'),
      );

      expect(calls, ['updateLocalIp', 'addCheckIpNumDebounce'],
          reason: 'Android must never close from connectivity_plus');
    });

    test('desktop vpn-carrying result does not close but updates run',
        () async {
      final calls = <String>[];

      await handleConnectivityChanged(
        isDesktop: true,
        results: [ConnectivityResult.vpn, ConnectivityResult.wifi],
        closeConnections: () {
          calls.add('close');
          return true;
        },
        updateLocalIp: () => calls.add('updateLocalIp'),
        addCheckIpNumDebounce: () => calls.add('addCheckIpNumDebounce'),
      );

      expect(calls, ['updateLocalIp', 'addCheckIpNumDebounce']);
    });
  });
}
