// Лист «Маршрут» iOS, второй и третий уровни: «Серверы и группы» (сцена `servers` доски,
// app.js:692-698) и узлы группы (`group:i`, app.js:700-706).

import 'package:dropweb/ui/ios27/screens/route/ios27_route_sheet.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:dropweb/ui/m3e/screens/m3e_servers_groups.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';
import 'support/layout.dart';
import 'support/screen_route_fixtures.dart';
import 'support/surface.dart';

const _frame = ValueKey('ios27.sheet.frame');
const _title = ValueKey('ios27.sheet.title');
const _back = ValueKey('ios27.sheet.back');

/// Открывает лист и переходит на второй уровень нажатием «Серверы и группы».
Future<void> openServers(WidgetTester tester) async {
  await openRouteSheet(tester);
  // При крупном шрифте строка может уйти ниже края листа: доводим её прокруткой.
  await tester.ensureVisible(find.byKey(kIos27RouteServersKey));
  await tester.pump();
  await tester.tap(find.byKey(kIos27RouteServersKey));
  await settleSheetPage(tester);
}

/// Заголовок листа на верхней странице: на нижней, пока она под верхней, тоже есть заголовок.
String _topTitle(WidgetTester tester) =>
    tester.widgetList<Text>(find.byKey(_title)).last.data!;

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final brightness = dark ? Brightness.dark : Brightness.light;

    testWidgets(
        '«Серверы и группы» $mode: рамки ±4 dp по servers-$mode-rt-p0 и golden',
        (tester) async {
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: RouteCalls(),
          brightness: brightness,
        ),
      );
      await openServers(tester);
      // Нижняя страница («Маршрут») лежит в дереве под верхней: берём только то, что видно
      // (hitTestable) или последний экземпляр шапки.
      final rows = ios27Parity(tester, 'servers-$mode-rt-p0', {
        'sheet': find.byKey(_frame),
        'sheet.title': find.byKey(_title).last,
        'sheet.back': find.byKey(_back).last,
        'sheet.close': find.byKey(const ValueKey('ios27.sheet.close')).last,
        'sheet.group': find.byKey(const ValueKey('sheet.group')).hitTestable(),
        'sheet.row': find.byKey(const ValueKey('sheet.row')).hitTestable(),
        'sheet.rowTitle':
            find.byKey(const ValueKey('sheet.rowTitle')).hitTestable(),
        'sheet.rowDetail':
            find.byKey(const ValueKey('sheet.rowDetail')).hitTestable(),
        'sheet.rowIcon':
            find.byKey(const ValueKey('sheet.rowIcon')).hitTestable(),
        'sheet.rowFlag':
            find.byKey(const ValueKey('sheet.rowFlag')).hitTestable(),
      });
      expectIos27Parity(rows);
      await expectIos27Golden(tester, 'servers_${mode}_p0');
    });

    testWidgets('узлы группы $mode: golden, строки без плитки', (tester) async {
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: RouteCalls(),
          brightness: brightness,
        ),
      );
      await openServers(tester);
      // «🇩🇪 Германия ✨» — четвёртая сверху (индекс 4): два узла.
      await tester.tap(find.byKey(kIos27RouteGroupKey(4)));
      await settleSheetPage(tester);
      expect(_topTitle(tester), 'Германия ✨');
      final rows = tester
          .widgetList<Ios27ListRow>(find.byType(Ios27ListRow).hitTestable())
          .toList();
      expect(rows.map((r) => r.title),
          ['Германия, Франкфурт', 'Германия, Берлин']);
      expect(rows.first.accessory, Ios27RowAccessory.check);
      expect(rows.last.accessory, Ios27RowAccessory.none);
      // Узлы без флага и эмодзи идут без плитки (`lead()` доски), строка 52 (min-height).
      final h = tester.getSize(find.byKey(kIos27RouteNodeKey(0))).height;
      expect(h, closeTo(52, 1));
      await expectIos27Golden(tester, 'nodes_${mode}_p0');
    });
  }

  group('второй уровень', () {
    testWidgets(
        'кнопка «Назад» и заголовок; «Назад» возвращает на главный уровень',
        (tester) async {
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: RouteCalls(),
          brightness: Brightness.light,
        ),
      );
      await openServers(tester);
      expect(_topTitle(tester), 'Серверы и группы');
      expect(find.byKey(_back), findsOneWidget);
      await tester.tap(find.byKey(_back));
      await settleSheetPage(tester);
      expect(_topTitle(tester), 'Маршрут');
      expect(find.byKey(_back), findsNothing);
      expect(find.byKey(_frame), findsOneWidget);
    });

    testWidgets('шесть групп: эмодзи и флаги плитками, пинг выбранного узла',
        (tester) async {
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: RouteCalls(),
          brightness: Brightness.light,
        ),
      );
      await openServers(tester);
      final rows = tester
          .widgetList<Ios27ListRow>(find.byType(Ios27ListRow).hitTestable())
          .toList();
      expect(rows.map((r) => r.title), [
        'VPN',
        'Fastest',
        'First Available',
        'США ✨',
        'Германия ✨',
        'Нидерланды ✨',
      ]);
      expect(rows.every((r) => r.leading != null), isTrue);
      expect(
          rows.every((r) => r.accessory == Ios27RowAccessory.chevron), isTrue);
      expect(
        rows.map((r) => r.detail?.replaceAll('\u00A0', ' ')),
        ['41 мс', '41 мс', '88 мс', '156 мс', '88 мс', '41 мс'],
      );
    });

    testWidgets(
        'группа без узлов в выбранном — без пинга; пустой профиль — подсказка',
        (tester) async {
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: RouteCalls(),
          brightness: Brightness.light,
          groups: const [],
        ),
      );
      await openServers(tester);
      expect(find.byType(Ios27ListRow).hitTestable(), findsNothing);
      expect(find.textContaining('профил'), findsWidgets);
    });

    testWidgets('замер выбранных узлов: один раз по адресу', (tester) async {
      final calls = RouteCalls();
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: calls,
          brightness: Brightness.light,
        ),
      );
      await openServers(tester);
      final probes =
          calls.log.where((e) => e.startsWith('probeNodes:')).toList();
      expect(probes, hasLength(1));
      expect(probes.single, endsWith('@$kRouteTestUrl'));
      expect(probes.single, contains('Нидерланды, Амстердам'));
    });
  });

  group('третий уровень', () {
    testWidgets(
        'выбор узла: selectNode, лист остаётся на узлах, галочка переезжает',
        (tester) async {
      final calls = RouteCalls();
      final live = StateProvider<List<M3eServerGroup>>(
        (ref) => serverGroupsFor(kIos27BoardNormal),
      );
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: calls,
          brightness: Brightness.light,
          liveGroups: live,
        ),
      );
      final container = ProviderScope.containerOf(rootContext(tester));
      // Как ядро: после выбора группа отдаёт новое имя выбранного узла.
      calls.onSelect = (group, node) {
        container.read(live.notifier).state = [
          for (final g in container.read(live))
            if (g.name == group)
              M3eServerGroup(
                name: g.name,
                testUrl: g.testUrl,
                nodes: g.nodes,
                selectedName: node,
                selectedLabel: node,
              )
            else
              g,
        ];
      };
      await openServers(tester);
      await tester.tap(find.byKey(kIos27RouteGroupKey(4)));
      await settleSheetPage(tester);
      expect(
        calls.log.where((e) => e.startsWith('probeNodes:')).last,
        'probeNodes:Германия, Франкфурт,Германия, Берлин@$kRouteTestUrl',
      );
      Ios27RowAccessory accessoryOf(String title) => tester
          .widgetList<Ios27ListRow>(find.byType(Ios27ListRow).hitTestable())
          .singleWhere((r) => r.title == title)
          .accessory;
      expect(accessoryOf('Германия, Франкфурт'), Ios27RowAccessory.check);
      expect(accessoryOf('Германия, Берлин'), Ios27RowAccessory.none);

      await tester.tap(find.text('Германия, Берлин'));
      await settleSheetPage(tester);
      expect(calls.log, contains('select:🇩🇪 Германия ✨>Германия, Берлин'));
      // Лист остался на уровне узлов, кнопка «Назад» на месте.
      expect(_topTitle(tester), 'Германия ✨');
      expect(find.byKey(_back), findsOneWidget);
      expect(find.byKey(_frame), findsOneWidget);
      expect(accessoryOf('Германия, Франкфурт'), Ios27RowAccessory.none);
      expect(accessoryOf('Германия, Берлин'), Ios27RowAccessory.check);
    });

    testWidgets('«Назад» с узлов возвращает на группы, не закрывая лист',
        (tester) async {
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: RouteCalls(),
          brightness: Brightness.light,
        ),
      );
      await openServers(tester);
      await tester.tap(find.byKey(kIos27RouteGroupKey(0)));
      await settleSheetPage(tester);
      await tester.tap(find.byKey(_back).last);
      await settleSheetPage(tester);
      expect(_topTitle(tester), 'Серверы и группы');
      expect(find.byKey(_frame), findsOneWidget);
    });

    testWidgets('узлы без ответа показывают «нет ответа»', (tester) async {
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardWorst,
          calls: RouteCalls(),
          brightness: Brightness.light,
        ),
      );
      await openServers(tester);
      // Первая группа WORST — «🛰 Резервный канал…» с узлом без ответа.
      await tester.tap(find.byKey(kIos27RouteGroupKey(0)));
      await settleSheetPage(tester);
      final dead = tester
          .widgetList<Ios27ListRow>(find.byType(Ios27ListRow).hitTestable())
          .where((r) => r.detailTone == Ios27RowDetailTone.dead);
      expect(dead, hasLength(1));
      expect(dead.single.detail, 'нет ответа');
    });

    testWidgets('группа исчезла при открытом листе — страница пустая',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          overrides: routeOverrides(kIos27BoardNormal, RouteCalls()),
          child: const Ios27ServerNodesView(groupName: 'нет такой'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Ios27ListRow), findsNothing);
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
            await openServers(tester);
            expect(tester.takeException(), isNull,
                reason: 'группы ${device.name} x$scale ${brightness.name}');
            await tester.tap(find.byKey(kIos27RouteGroupKey(0)));
            await settleSheetPage(tester);
            expect(tester.takeException(), isNull,
                reason: 'узлы ${device.name} x$scale ${brightness.name}');
            await tester.pumpWidget(const SizedBox());
          }
        }
      });
    }
  });

  group('G8: движение', () {
    testWidgets('переходы между уровнями: 0 кадров-хвостов после посадки',
        (tester) async {
      await pumpIos27Board(
        tester,
        routeApp(
          data: kIos27BoardNormal,
          calls: RouteCalls(),
          brightness: Brightness.light,
        ),
      );
      await openServers(tester);
      await tester.tap(find.byKey(kIos27RouteGroupKey(1)));
      await settleSheetPage(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('«Уменьшить движение»: уровни меняются без кадров-хвостов',
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
      await tester.tap(find.byKey(kIos27RouteServersKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(_topTitle(tester), 'Серверы и группы');
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
