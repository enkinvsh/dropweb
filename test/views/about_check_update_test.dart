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

    // The sideloaded Android build (our primary RU channel, no Play updates)
    // shows it and self-updates from our own server.
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

  group('about support project link', () {
    test('is placed after project and before privacy policy', () {
      final source = File('lib/views/about.dart').readAsStringSync();

      expect(source, contains('appLocalizations.supportProject'));
      expect(source,
          contains('globalState.openUrl("https://web.tribute.tg/d/Huc")'));

      final projectIndex = source.indexOf('appLocalizations.project');
      final supportProjectIndex =
          source.indexOf('appLocalizations.supportProject');
      final privacyPolicyIndex =
          source.indexOf('appLocalizations.privacyPolicy');

      expect(projectIndex, isNot(-1));
      expect(supportProjectIndex, isNot(-1));
      expect(privacyPolicyIndex, isNot(-1));
      expect(projectIndex, lessThan(supportProjectIndex));
      expect(supportProjectIndex, lessThan(privacyPolicyIndex));
    });
  });
}
