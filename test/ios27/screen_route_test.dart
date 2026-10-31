// Лист «Маршрут» iOS, главный уровень (сцена `route` доски, app.js:672-691): паритет рамок,
// golden, нажатия, семантические id для автотестов, худшие данные, движение.

import 'package:dropweb/models/models.dart' show Proxy;
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/screens/route/ios27_route_sheet.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_avatar.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/board_providers.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';
import 'support/layout.dart';
import 'support/screen_route_fixtures.dart';
import 'support/surface.dart';

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final brightness = dark ? Brightness.dark : Brightness.light;

    testWidgets('«Маршрут» $mode: рамки ±4 dp по route-$mode-rt-p0 и golden',
        (tester) async {
      final calls = RouteCalls();
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: calls,
          brightness: brightness,
        ),
      );
      await openRouteSheet(tester);
      expectIos27Parity(
        ios27Parity(tester, 'route-$mode-rt-p0', sheetElements()),
      );
      await expectIos27Golden(tester, 'route_${mode}_p0');
    });
  }

  // Цвет провайдера меняет галочку и включённый переключатель; лист ставит свой скоуп из
  // провайдера, поэтому p5 снимается телом прямо в окне (приём list_test).
  testWidgets('провайдер p5: тело «Маршрут» golden', (tester) async {
    final calls = RouteCalls();
    await pumpIos27Board(
      tester,
      ios27BoardApp(
        brightness: Brightness.light,
        theme: Ios27ProviderTheme.fromHeader(kBoardProviders[5].theme),
        child: Ios27SheetScope(
          detent: Ios27SheetDetent.medium,
          dismissible: true,
          dragUpdate: (_) {},
          dragEnd: (_) {},
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 60),
            child: Ios27RouteBody(
              data: routeDataFor(kIos27BoardNormal),
              onPick: (_) => calls.log.add('pick'),
              onToggleTunnel: () {},
              onServers: () {},
            ),
          ),
        ),
      ),
    );
    await expectIos27Golden(tester, 'route_light_p5');
  });

  group('содержимое', () {
    testWidgets('«Авто» первой строкой со значком молнии и подписью страны',
        (tester) async {
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: RouteCalls(),
          brightness: Brightness.light,
        ),
      );
      await openRouteSheet(tester);
      expect(find.text('Авто'), findsOneWidget);
      // Без ⚡ в заголовке: молния только значком аватара.
      expect(find.textContaining('⚡'), findsNothing);
      final auto = find.byKey(kIos27RouteAutoKey);
      expect(
        find.descendant(of: auto, matching: find.text('Нидерланды')),
        findsOneWidget,
        reason: 'подпись «Авто» — лучшая страна',
      );
      expect(
        find.descendant(of: auto, matching: find.byType(Ios27Avatar)),
        findsOneWidget,
      );
      final avatar = tester.widget<Ios27Avatar>(
          find.descendant(of: auto, matching: find.byType(Ios27Avatar)));
      expect(avatar.icon, Ios27IconName.zap);
      // Выбрана «Авто»: одна галочка.
      expect(find.byKey(const ValueKey('sheet.rowCheck')), findsOneWidget);
      final details = tester
          .widgetList<Ios27ListRow>(find.byType(Ios27ListRow))
          // В l10n между числом и «мс» неразрывный пробел.
          .map((r) => r.detail?.replaceAll('\u00A0', ' '))
          .toList();
      expect(
        details,
        ['41 мс', '41 мс', '64 мс', '88 мс', '156 мс', null, '6'],
      );
    });

    testWidgets('переключатель только при fullTunnelAvailable', (tester) async {
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: RouteCalls(),
          brightness: Brightness.light,
          routeData: routeDataFor(kIos27BoardNormal, tunnelAvailable: false),
        ),
      );
      await openRouteSheet(tester);
      expect(find.text('Весь трафик через VPN'), findsNothing);
      expect(find.byType(Ios27Toggle), findsNothing);
      expect(find.text('Серверы и группы'), findsOneWidget);
    });

    testWidgets('«Серверы и группы»: число групп и шеврон', (tester) async {
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: RouteCalls(),
          brightness: Brightness.light,
        ),
      );
      await openRouteSheet(tester);
      final row = find.byKey(kIos27RouteServersKey);
      expect(
          find.descendant(of: row, matching: find.text('6')), findsOneWidget);
      expect(
        tester.widget<Ios27ListRow>(row).accessory,
        Ios27RowAccessory.chevron,
      );
    });

    testWidgets('страна без ответа — «нет ответа», медленная — оранжевый тон',
        (tester) async {
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardWorst,
          calls: RouteCalls(),
          brightness: Brightness.light,
        ),
      );
      await openRouteSheet(tester);
      final dead = tester
          .widgetList<Ios27ListRow>(find.byType(Ios27ListRow))
          .where((r) => r.detailTone == Ios27RowDetailTone.dead);
      expect(dead.map((r) => r.title), ['Объединённые Арабские Эмираты']);
      final slow = tester
          .widgetList<Ios27ListRow>(find.byType(Ios27ListRow))
          .where((r) => r.detailTone == Ios27RowDetailTone.slow);
      // 640 и 1840 мс.
      expect(slow.map((r) => r.title),
          ['Нидерланды', 'Соединённые Штаты Америки']);
      expect(find.text('нет ответа'), findsOneWidget);
    });
  });

  group('нажатия', () {
    testWidgets('страна: pick, лист остаётся открытым', (tester) async {
      final calls = RouteCalls();
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: calls,
          brightness: Brightness.light,
        ),
      );
      await openRouteSheet(tester);
      await tester.tap(find.text('Германия'));
      await tester.pump();
      expect(calls.log, contains('pick:de'));
      expect(find.byKey(const ValueKey('ios27.sheet.frame')), findsOneWidget);
    });

    testWidgets('«Авто»: pick агрегатора', (tester) async {
      final calls = RouteCalls();
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: calls,
          brightness: Brightness.light,
        ),
      );
      await openRouteSheet(tester);
      await tester.tap(find.byKey(kIos27RouteAutoKey));
      await tester.pump();
      expect(calls.log, contains('pick:auto'));
    });

    testWidgets('переключатель и строка вокруг него: setFullTunnel(!текущее)',
        (tester) async {
      final calls = RouteCalls();
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: calls,
          brightness: Brightness.light,
        ),
      );
      await openRouteSheet(tester);
      await tester.tap(find.text('Весь трафик через VPN'));
      await tester.pump();
      await tester.tap(find.byType(Ios27Toggle));
      await tester.pump();
      expect(
        calls.log.where((e) => e.startsWith('tunnel:')),
        ['tunnel:false', 'tunnel:false'],
      );
    });

    testWidgets('идёт применение: нажатия не принимаются', (tester) async {
      final calls = RouteCalls();
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: calls,
          brightness: Brightness.light,
          applying: true,
        ),
      );
      await openRouteSheet(tester);
      await tester.tap(find.text('Германия'), warnIfMissed: false);
      await tester.tap(find.byType(Ios27Toggle), warnIfMissed: false);
      await tester.pump();
      expect(
          calls.log
              .where((e) => e.startsWith('pick') || e.startsWith('tunnel')),
          isEmpty);
    });

    testWidgets('замер пинга при открытии: один раз по членам роутера',
        (tester) async {
      final calls = RouteCalls();
      final proxies = [const Proxy(name: 'a', type: 'vless')];
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: calls,
          brightness: Brightness.light,
          routeData: routeDataFor(kIos27BoardNormal, probe: proxies),
        ),
      );
      await openRouteSheet(tester);
      await tester.pump();
      expect(
        calls.log.where((e) => e.startsWith('probe:')),
        ['probe:a@$kRouteTestUrl'],
      );
    });
  });

  group('семантические id (adb-автотесты)', () {
    testWidgets('dw_mode_standard, dw_mode_country, dw_tunnel на строках',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: RouteCalls(),
          brightness: Brightness.light,
        ),
      );
      await openRouteSheet(tester);
      expect(find.bySemanticsIdentifier('dw_mode_standard'), findsOneWidget);
      expect(find.bySemanticsIdentifier('dw_mode_country'), findsNWidgets(4));
      expect(find.bySemanticsIdentifier('dw_tunnel'), findsOneWidget);
      // Узел с идентификатором занимает строку: по его границам автотест и нажимает.
      final pairs = {
        'dw_mode_standard': kIos27RouteAutoKey,
        'dw_tunnel': kIos27RouteTunnelKey,
      };
      for (final MapEntry(key: id, value: rowKey) in pairs.entries) {
        final node = tester.getSemantics(find.bySemanticsIdentifier(id));
        final row = tester.getRect(find.byKey(rowKey));
        expect(node.rect.width, closeTo(row.width, 1), reason: id);
        expect(node.rect.height, closeTo(row.height, 1), reason: id);
      }
      // Метка и нажимаемость строки не потеряны из-за идентификатора.
      final auto =
          tester.getSemantics(find.bySemanticsIdentifier('dw_mode_standard'));
      expect(auto.getSemanticsData().label, contains('Авто'));
      handle.dispose();
    });

    testWidgets('без переключателя нет dw_tunnel', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: RouteCalls(),
          brightness: Brightness.light,
          routeData: routeDataFor(kIos27BoardNormal, tunnelAvailable: false),
        ),
      );
      await openRouteSheet(tester);
      expect(find.bySemanticsIdentifier('dw_tunnel'), findsNothing);
      handle.dispose();
    });
  });

  group('G3: худшие данные', () {
    for (final device in kIos27Iphones) {
      testWidgets('WORST на ${device.name} × масштаб 0.8/1.0/1.4/2.0',
          (tester) async {
        for (final scale in [0.8, 1.0, 1.4, 2.0]) {
          for (final brightness in Brightness.values) {
            await pumpIos27Board(
              tester,
              routeApp(
                data: kIos27BoardWorst,
                calls: RouteCalls(),
                brightness: brightness,
                textScale: scale,
              ),
              device: device,
            );
            await openRouteSheet(tester);
            expect(
              tester.takeException(),
              isNull,
              reason: '${device.name} x$scale ${brightness.name}',
            );
            // Лист не выходит за экран.
            final frame =
                tester.getRect(find.byKey(const ValueKey('ios27.sheet.frame')));
            expect(frame.left, greaterThanOrEqualTo(0));
            expect(frame.right, lessThanOrEqualTo(device.size.width));
            expect(frame.bottom, lessThanOrEqualTo(device.size.height));
            await tester.pumpWidget(const SizedBox());
          }
        }
      });
    }
  });

  group('G8: движение', () {
    testWidgets('после посадки листа нет кадров-хвостов', (tester) async {
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: RouteCalls(),
          brightness: Brightness.light,
        ),
      );
      await openRouteSheet(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('«Уменьшить движение»: лист садится без кадров-хвостов',
        (tester) async {
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: RouteCalls(),
          brightness: Brightness.light,
          disableAnimations: true,
        ),
      );
      // ignore: unawaited_futures
      showIos27RouteSheet(rootContext(tester));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(const ValueKey('ios27.sheet.frame')), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('закрытие листа: 0 тикеров', (tester) async {
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: RouteCalls(),
          brightness: Brightness.light,
        ),
      );
      await openRouteSheet(tester);
      await tester.tap(find.byKey(const ValueKey('ios27.sheet.close')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('ios27.sheet.frame')), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
