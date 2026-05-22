import 'package:dropweb/common/send_to_tv_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowSendToTv', () {
    // Android (Google Play target) must not expose the Send to TV / LAN
    // subscription-sharing flow: it posts the subscription URL over plain
    // local HTTP to an arbitrary `add-profile` endpoint and is not essential
    // for the Play v1 release.
    test('Android hides Send to TV', () {
      expect(shouldShowSendToTv(isAndroid: true), isFalse);
    });

    // Non-Android (iOS / desktop direct-distribution) keeps the existing
    // user-explicit local sharing flow intact.
    test('non-Android shows Send to TV', () {
      expect(shouldShowSendToTv(isAndroid: false), isTrue);
    });
  });
}
