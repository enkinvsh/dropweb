import 'dart:io';

import 'package:dropweb/views/about.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('about.shouldShowCheckForUpdate', () {
    // Store builds (Google Play, iOS) MUST NOT expose an in-app update
    // check — store policy requires updates through the store.
    test('store build hides the manual update entry', () {
      expect(shouldShowCheckForUpdate(isStoreBuild: true), isFalse);
    });

    // Sideloaded Android (our primary RU channel) and desktop show it and
    // update from our own server.
    test('sideload and desktop builds keep the manual update entry', () {
      expect(shouldShowCheckForUpdate(isStoreBuild: false), isTrue);
    });
  });

  group('about.privacyPolicyUrl', () {
    // The store build is a neutral client and links the app's own policy.
    test('store build links the app privacy policy', () {
      expect(
        privacyPolicyUrl(isStoreBuild: true),
        'https://dropweb.org/app/privacy/',
      );
    });

    // The sideload build keeps the dropweb service policy.
    test('sideload build keeps the service privacy policy', () {
      expect(
        privacyPolicyUrl(isStoreBuild: false),
        'https://dropweb.org/privacy',
      );
    });
  });

  group('support project link', () {
    // The donation entry was surfaced out of About → "More" into Settings
    // (lib/views/tools.dart, _SupportItem) so it sits one tap deep instead of
    // three. Verify it lives there with our donation page — it is no longer
    // in About.
    test('lives in Settings (tools.dart) with the dropweb donation page', () {
      final source = File('lib/views/tools.dart').readAsStringSync();
      expect(source, contains('supportProject'));
      expect(
        source,
        contains('globalState.openUrl("https://dropweb.org/donate")'),
      );
    });
  });
}
