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
}
