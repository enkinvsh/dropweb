import 'dart:io';

import 'package:dropweb/views/about.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('about.shouldShowCheckForUpdate', () {
    // Android/Play-facing builds MUST NOT expose an in-app GitHub-driven
    // update check. Google Play policy: updates ship through Play, so the
    // About → "Проверить обновления" entry has to be hidden there.
    test('Android (Play target) hides the manual update entry', () {
      expect(shouldShowCheckForUpdate(isAndroid: true), isFalse);
    });

    // Desktop and other non-Play targets continue to ship signed binaries
    // from GitHub releases, so the manual check stays available.
    test('non-Android keeps the manual update entry', () {
      expect(shouldShowCheckForUpdate(isAndroid: false), isTrue);
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
