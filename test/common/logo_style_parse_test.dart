import 'package:dropweb/views/dashboard/widgets/corner_badge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSubscriptionLogoStyle', () {
    test('null headers -> watermark', () {
      expect(
        parseSubscriptionLogoStyle(null),
        SubscriptionLogoStyle.watermark,
      );
    });

    test('no dropweb-theme key -> watermark', () {
      expect(
        parseSubscriptionLogoStyle({'dropweb-logo': 'https://x/l.png'}),
        SubscriptionLogoStyle.watermark,
      );
    });

    test('five-field header (no logoStyle) -> watermark', () {
      expect(
        parseSubscriptionLogoStyle(
          {'dropweb-theme': 'fidelity,#15803D,#009938,#009938,2'},
        ),
        SubscriptionLogoStyle.watermark,
      );
    });

    test('sixth field "inline" -> inline', () {
      expect(
        parseSubscriptionLogoStyle(
          {'dropweb-theme': 'fidelity,#15803D,#009938,#009938,2,inline'},
        ),
        SubscriptionLogoStyle.inline,
      );
    });

    test('sixth field " INLINE " (spaces + case) -> inline', () {
      expect(
        parseSubscriptionLogoStyle(
          {'dropweb-theme': 'fidelity,#15803D,#009938,#009938,2, INLINE '},
        ),
        SubscriptionLogoStyle.inline,
      );
    });

    test('sixth field "banana" (unknown) -> watermark', () {
      expect(
        parseSubscriptionLogoStyle(
          {'dropweb-theme': 'fidelity,#15803D,#009938,#009938,2,banana'},
        ),
        SubscriptionLogoStyle.watermark,
      );
    });

    test('empty sixth field -> watermark', () {
      expect(
        parseSubscriptionLogoStyle(
          {'dropweb-theme': 'fidelity,#15803D,#009938,#009938,2,'},
        ),
        SubscriptionLogoStyle.watermark,
      );
    });

    test('header of only commas ",,,,,inline" -> inline', () {
      expect(
        parseSubscriptionLogoStyle({'dropweb-theme': ',,,,,inline'}),
        SubscriptionLogoStyle.inline,
      );
    });

    test('empty dropweb-theme value -> watermark', () {
      expect(
        parseSubscriptionLogoStyle({'dropweb-theme': ''}),
        SubscriptionLogoStyle.watermark,
      );
    });
  });
}
