import 'package:dropweb/common/navigation.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Navigation.getItems', () {
    test('adds cabinet before dashboard when cabinetUri is provided', () {
      final cabinetUri = Uri.parse('https://cab.dropweb.org');
      final items = navigation.getItems(cabinetUri: cabinetUri);
      final labels = items.map((item) => item.label).toList();

      expect(labels.take(3), [
        PageLabel.cabinet,
        PageLabel.dashboard,
        PageLabel.tools,
      ]);

      final cabinetItem =
          items.firstWhere((item) => item.label == PageLabel.cabinet);
      expect(cabinetItem.path, cabinetUri.toString());
    });

    test('keeps the ordinary dashboard and settings tabs without cabinetUri',
        () {
      final labels = navigation.getItems().map((item) => item.label).toList();

      expect(labels, isNot(contains(PageLabel.cabinet)));
      expect(labels.take(2), [PageLabel.dashboard, PageLabel.tools]);
    });
  });
}
