import 'package:dropweb/common/vpn_consent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('VpnConsent', () {
    setUp(() {
      // Fresh, isolated SharedPreferences for each test — prevents leakage
      // between cases and keeps the suite hermetic.
      SharedPreferences.setMockInitialValues({});
    });

    test('uses a versioned storage key so future copy bumps can re-prompt',
        () {
      expect(VpnConsent.currentVersion, 'v1');
      expect(VpnConsent.storageKey, 'vpn_disclosure_accepted_v1');
    });

    test('isAccepted returns false on a fresh install', () async {
      const consent = VpnConsent();

      expect(await consent.isAccepted(), isFalse);
    });

    test('markAccepted persists the flag so subsequent reads return true',
        () async {
      const consent = VpnConsent();

      final wrote = await consent.markAccepted();

      expect(wrote, isTrue);
      expect(await consent.isAccepted(), isTrue);
    });

    test('reset clears a previously stored consent flag', () async {
      const consent = VpnConsent();
      await consent.markAccepted();
      expect(await consent.isAccepted(), isTrue);

      await consent.reset();

      expect(await consent.isAccepted(), isFalse);
    });

    test(
      'isAccepted ignores unrelated preference values',
      () async {
        SharedPreferences.setMockInitialValues({
          'some_other_flag': true,
          'vpn_disclosure_accepted_v0': true,
        });
        const consent = VpnConsent();

        expect(await consent.isAccepted(), isFalse);
      },
    );

    test('default vpnConsent singleton talks to the same storage key',
        () async {
      await vpnConsent.markAccepted();
      const fresh = VpnConsent();

      expect(await fresh.isAccepted(), isTrue);
    });

    // The central AppController.updateStatus(true) guard refuses to start
    // VPN when `vpnConsent.isAccepted()` resolves to false. Direct
    // controller tests aren't feasible — AppController is tightly coupled
    // to globalState, Riverpod refs, platform plugins, and the running
    // mihomo core — so we lock in the exact predicate semantics here.
    group('central guard predicate (consumed by AppController.updateStatus)',
        () {
      test('predicate is false on fresh install — VPN start must be refused',
          () async {
        const consent = VpnConsent();
        expect(await consent.isAccepted(), isFalse);
      });

      test('predicate is true once consent persisted — VPN start may proceed',
          () async {
        const consent = VpnConsent();
        await consent.markAccepted();
        expect(await consent.isAccepted(), isTrue);
      });
    });
  });
}
