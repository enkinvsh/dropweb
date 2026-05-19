import 'package:dropweb/views/about.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('about.shouldShowCheckForUpdate', () {
    // dropweb ships APK via GitHub releases, not Google Play, so the
    // "no in-app update checks" Play Store policy does not apply.
    // The manual "Check for updates" entry must be visible on every
    // platform, including Android.
    test('returns true so Android shows the manual update entry', () {
      expect(shouldShowCheckForUpdate(), isTrue);
    });
  });
}
