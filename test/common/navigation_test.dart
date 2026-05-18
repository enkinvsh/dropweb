import 'package:dropweb/common/navigation.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Navigation.getItems', () {
    test('keeps only dashboard and tools in bottom navigation', () {
      final labels = navigation.getItems().map((item) => item.label).toList();

      expect(labels, isNot(contains(PageLabel.cabinet)));
      expect(labels.take(2), [PageLabel.dashboard, PageLabel.tools]);
    });
  });
}
