import 'package:dropweb/controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('controller.shouldRunAutoUpdateCheck', () {
    // Android/Play-facing builds must never hit the GitHub releases API on
    // startup, even if a persisted setting (possibly applied from a
    // subscription `dropweb-settings: autoupdate` header) is still true.
    test('Android skips auto check when setting is true', () {
      expect(
        shouldRunAutoUpdateCheck(isAndroid: true, autoCheckUpdate: true),
        isFalse,
      );
    });

    test('Android skips auto check when setting is false', () {
      expect(
        shouldRunAutoUpdateCheck(isAndroid: true, autoCheckUpdate: false),
        isFalse,
      );
    });

    // Non-Android (desktop) keeps using the persisted preference: this is
    // the existing behaviour, only Android changes for the Play release.
    test('non-Android runs auto check when setting is true', () {
      expect(
        shouldRunAutoUpdateCheck(isAndroid: false, autoCheckUpdate: true),
        isTrue,
      );
    });

    test('non-Android skips auto check when setting is false', () {
      expect(
        shouldRunAutoUpdateCheck(isAndroid: false, autoCheckUpdate: false),
        isFalse,
      );
    });
  });
}
