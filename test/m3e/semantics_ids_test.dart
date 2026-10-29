// Идентификаторы для автотестов через adb (`docs/adb-remote.md`, раздел uiautomator):
// `Semantics(identifier:)` попадает в `resource-id` дампа uiautomator, поэтому их потеря
// ломает внешние сценарии. Проверяется главная и лист «Маршрут».
// Прогон: `fvm flutter test test/m3e/semantics_ids_test.dart`.

import 'package:dropweb/ui/m3e/route/m3e_route_providers.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:dropweb/ui/m3e/screens/m3e_route_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gate_support.dart';

M3eRouteData _data({bool tunnel = true}) => M3eRouteData(
      rows: const [
        M3eRouteRow(
          id: 'auto',
          label: 'Авто',
          isAggregate: true,
          pingMs: 43,
          selected: true,
        ),
        M3eRouteRow(id: 'nl', label: 'Нидерланды', flag: '🇳🇱', pingMs: 48),
        M3eRouteRow(id: 'fi', label: 'Финляндия', flag: '🇫🇮', pingMs: 61),
      ],
      routerName: 'VPN',
      fullTunnelAvailable: tunnel,
      fullTunnel: false,
      groupsCount: 3,
    );

void main() {
  tearDown(() => debugDisableShadows = true);

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      gateHomeApp(
        'home-off',
        extra: [m3eRouteDataProvider.overrideWithValue(_data())],
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('главная: dw_connect и dw_exit', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHome(tester);
    expect(find.bySemanticsIdentifier('dw_connect'), findsOneWidget);
    expect(find.bySemanticsIdentifier('dw_exit'), findsOneWidget);
    // Идентификатор не должен отнимать у кнопки метку и нажимаемость.
    final exit = tester.getSemantics(find.bySemanticsIdentifier('dw_exit'));
    expect(exit.label, isNotEmpty);
    expect(exit.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    // Узел кнопки, а не объемлющий ряд: у ряда другая метка и вся его ширина.
    expect(exit.rect.width, lessThan(100));
    handle.dispose();
  });

  testWidgets('лист «Маршрут»: dw_mode_standard, dw_mode_country, dw_tunnel',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHome(tester);
    await tester.tap(find.byKey(kM3eRouteBtnKey));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.bySemanticsIdentifier('dw_mode_standard'), findsOneWidget);
    // Две страны: идентификатор общий для всех строк-стран.
    expect(find.bySemanticsIdentifier('dw_mode_country'), findsNWidgets(2));
    expect(find.bySemanticsIdentifier('dw_tunnel'), findsOneWidget);
    // Узел с идентификатором занимает ровно строку: uiautomator отдаёт его границы,
    // по ним автотест и нажимает.
    final pairs = {
      'dw_mode_standard': kM3eRouteAutoKey,
      'dw_tunnel': kM3eRouteTunnelKey,
    };
    for (final MapEntry(key: id, value: rowKey) in pairs.entries) {
      final node = tester.getSemantics(find.bySemanticsIdentifier(id));
      final row = tester.getRect(find.byKey(rowKey));
      expect(node.rect.width, closeTo(row.width, 1), reason: id);
      expect(node.rect.height, closeTo(row.height, 1), reason: id);
    }
    handle.dispose();
  });
}
