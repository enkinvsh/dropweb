import 'package:dropweb/common/navigation.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Navigation.getItems', () {
    test('adds cabinet before dashboard when cabinet marker is active', () {
      final labels = navigation
          .getItems(hasCabinetMarker: true)
          .map((item) => item.label)
          .toList();

      expect(labels.take(3), [
        PageLabel.cabinet,
        PageLabel.dashboard,
        PageLabel.tools,
      ]);
    });

    test('keeps the ordinary dashboard and settings tabs without marker', () {
      final labels = navigation.getItems().map((item) => item.label).toList();

      expect(labels, isNot(contains(PageLabel.cabinet)));
      expect(labels.take(2), [PageLabel.dashboard, PageLabel.tools]);
    });
  });
}
