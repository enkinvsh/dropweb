import 'package:dropweb/common/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('utils.delayBadgeLabel', () {
    test('null delay shows nothing', () {
      expect(utils.delayBadgeLabel(null), isNull);
    });

    test('zero delay (loading) shows nothing', () {
      expect(utils.delayBadgeLabel(0), isNull);
    });

    test('negative delay (unavailable) shows n/a', () {
      expect(utils.delayBadgeLabel(-1), 'n/a');
      expect(utils.delayBadgeLabel(-9999), 'n/a');
    });

    test('positive delay shows ms', () {
      expect(utils.delayBadgeLabel(123), '123 ms');
    });
  });
}
