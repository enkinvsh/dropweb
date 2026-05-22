import 'package:dropweb/common/access_control_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowAccessControl', () {
    // Access Control / per-app proxy is an advanced surface on Android: it
    // exposes the installed-package list and the per-app split-tunnel rules.
    // For the Google Play target it must be hidden by default and only
    // appear after the existing developer/advanced mode is unlocked (5
    // rapid taps on the Settings nav), matching how `_ConfigItem` and
    // `_SettingItem` are gated in `lib/views/tools.dart`.
    test('Android with developer mode off hides Access Control', () {
      expect(
        shouldShowAccessControl(isAndroid: true, developerMode: false),
        isFalse,
      );
    });

    test('Android with developer mode on shows Access Control', () {
      expect(
        shouldShowAccessControl(isAndroid: true, developerMode: true),
        isTrue,
      );
    });

    // Access Control settings entry only ever existed on Android. Non-Android
    // platforms (iOS / desktop) must keep returning false regardless of the
    // developer-mode flag so we never accidentally surface it elsewhere.
    test('non-Android hides Access Control with developer mode off', () {
      expect(
        shouldShowAccessControl(isAndroid: false, developerMode: false),
        isFalse,
      );
    });

    test('non-Android hides Access Control even with developer mode on', () {
      expect(
        shouldShowAccessControl(isAndroid: false, developerMode: true),
        isFalse,
      );
    });
  });
}
