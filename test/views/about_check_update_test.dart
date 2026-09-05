import 'dart:io';

import 'package:dropweb/views/about.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('about.shouldShowCheckForUpdate', () {
    // Play builds (--dart-define=PLAY_BUILD=true) MUST NOT expose an in-app
    // update check — Google Play policy requires updates through the store.
    test('Android Play build hides the manual update entry', () {
      expect(
        shouldShowCheckForUpdate(isAndroid: true, isPlayBuild: true),
        isFalse,
      );
    });

    // The sideloaded Android build (our primary RU channel) shows it and
    // self-updates from our own server.
    test('Android sideload build keeps the manual update entry', () {
      expect(
        shouldShowCheckForUpdate(isAndroid: true, isPlayBuild: false),
        isTrue,
      );
    });

    // Desktop always shows the manual check, regardless of build flavour.
    test('non-Android keeps the manual update entry', () {
      expect(shouldShowCheckForUpdate(isAndroid: false, isPlayBuild: true),
          isTrue);
      expect(shouldShowCheckForUpdate(isAndroid: false, isPlayBuild: false),
          isTrue);
    });
  });

  group('support project link', () {
    // The donation entry was surfaced out of About → "More" into Settings
    // (lib/views/tools.dart, _SupportItem) so it sits one tap deep instead of
    // three. Verify it lives there with the correct tribute URL — it is no
    // longer in About.
    test('lives in Settings (tools.dart) with the tribute URL', () {
      final source = File('lib/views/tools.dart').readAsStringSync();
      expect(source, contains('supportProject'));
      expect(
        source,
        contains('globalState.openUrl("https://web.tribute.tg/d/Huc")'),
      );
    });
  });
}
