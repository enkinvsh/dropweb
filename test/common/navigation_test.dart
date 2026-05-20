import 'package:dropweb/common/navigation.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Navigation.getItems', () {
    test('keeps only dashboard and tools in the base navigation list', () {
      final labels = navigation.getItems().map((item) => item.label).toList();

      expect(labels, isNot(contains(PageLabel.cabinet)));
      expect(labels.take(2), [PageLabel.dashboard, PageLabel.tools]);
    });

    test(
        'tools is desktop-only so mobile cannot swipe into the settings page',
        () {
      final tools = navigation
          .getItems()
          .firstWhere((item) => item.label == PageLabel.tools);

      expect(tools.modes, [NavigationItemMode.desktop]);
      expect(tools.modes, isNot(contains(NavigationItemMode.mobile)));
    });

    test('dashboard remains reachable on mobile', () {
      final dashboard = navigation
          .getItems()
          .firstWhere((item) => item.label == PageLabel.dashboard);

      expect(dashboard.modes, contains(NavigationItemMode.mobile));
    });
  });
}
