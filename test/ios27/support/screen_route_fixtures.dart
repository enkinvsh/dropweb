// Данные и подмены провайдеров для тестов листа «Маршрут» iOS: набор доски (NORMAL/WORST) в виде
// моделей M3E, которые лист читает из провайдеров. Форма данных та же, что у
// `test/m3e/route_sheet_test.dart`, чтобы лист iOS и лист Android проверялись на одном входе.

import 'package:dropweb/models/models.dart';
import 'package:dropweb/ui/ios27/screens/route/ios27_route_sheet.dart';
import 'package:dropweb/ui/m3e/route/m3e_route_providers.dart';
import 'package:dropweb/ui/m3e/screens/m3e_servers_groups.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/board_fixtures.dart';
import '../support/golden.dart';
import '../support/layer_harness.dart';

/// Адрес замера в данных тестов: ячейки задержки адресуются парой «имя, адрес».
const String kRouteTestUrl = 'https://t.test';

/// Данные главного уровня из набора доски: «Авто» с лучшей страной, страны с пингом. Страна без
/// ответа (`ms == null`) становится отрицательным пингом (`ms()` доски: «нет ответа»).
M3eRouteData routeDataFor(
  Ios27BoardData b, {
  String selected = 'auto',
  List<Proxy> probe = const [],
  bool tunnelAvailable = true,
  bool tunnel = true,
}) {
  final best = b.countries.firstWhere((c) => c.id == b.best);
  return M3eRouteData(
    rows: [
      M3eRouteRow(
        id: 'auto',
        label: 'Авто',
        sup: best.name,
        isAggregate: true,
        pingMs: best.ms ?? -1,
        selected: selected == 'auto',
      ),
      for (final c in b.countries)
        M3eRouteRow(
          id: c.id,
          label: c.name,
          flag: c.flag,
          pingMs: c.ms ?? -1,
          selected: selected == c.id,
        ),
    ],
    routerName: 'VPN',
    fullTunnelAvailable: tunnelAvailable,
    fullTunnel: tunnel,
    groupsCount: b.groups.length,
    probe: probe,
    testUrl: probe.isEmpty ? null : kRouteTestUrl,
  );
}

/// Группы доски в моделях M3E; выбран первый узел группы (`selNode` доски по умолчанию 0).
List<M3eServerGroup> serverGroupsFor(Ios27BoardData b) => [
      for (final g in b.groups)
        M3eServerGroup(
          name: g.name,
          testUrl: kRouteTestUrl,
          nodes: [
            for (final n in g.nodes)
              M3eServerNode(name: n.name, type: n.protocol),
          ],
          selectedName: g.nodes.first.name,
          selectedLabel: g.nodes.first.name,
        ),
    ];

/// Задержки узлов доски по имени; `null` на доске — «нет ответа», то есть отрицательное число.
Map<String, int> delaysFor(Ios27BoardData b) => {
      for (final g in b.groups)
        for (final n in g.nodes) n.name: n.ms ?? -1,
    };

/// Журнал вызовов подменённых действий.
class RouteCalls {
  final List<String> log = [];

  M3eRouteActions get route => M3eRouteActions(
        pick: (row) async => log.add('pick:${row.id}'),
        setFullTunnel: ({required enabled}) async => log.add('tunnel:$enabled'),
        probe: (proxies, url) async =>
            log.add('probe:${proxies.map((p) => p.name).join(',')}@$url'),
      );

  /// Дополнительная реакция на выбор узла (тест переносит галочку через живой провайдер групп).
  void Function(String group, String node)? onSelect;

  M3eServersActions get servers => M3eServersActions(
        selectNode: (group, node) {
          log.add('select:$group>$node');
          onSelect?.call(group, node);
        },
        probe: (nodes, url) async =>
            log.add('probeNodes:${nodes.map((n) => n.name).join(',')}@$url'),
      );
}

/// Подмены провайдеров листа «Маршрут» поверх `layerOverrides()`.
List<Override> routeOverrides(
  Ios27BoardData b,
  RouteCalls calls, {
  M3eRouteData? data,
  List<M3eServerGroup>? groups,
  bool applying = false,
  StateProvider<List<M3eServerGroup>>? liveGroups,
}) {
  final delays = delaysFor(b);
  return [
    ...layerOverrides(),
    m3eRouteDataProvider.overrideWithValue(data ?? routeDataFor(b)),
    m3eRouteActionsProvider.overrideWithValue(calls.route),
    if (applying) m3eRouteApplyingProvider.overrideWith((ref) => true),
    if (liveGroups != null)
      m3eServerGroupsProvider.overrideWith((ref) => ref.watch(liveGroups))
    else
      m3eServerGroupsProvider.overrideWithValue(groups ?? serverGroupsFor(b)),
    m3eNodeDelayProvider.overrideWith((ref, key) => delays[key.name]),
    m3eServersActionsProvider.overrideWithValue(calls.servers),
  ];
}

/// Контекст корневого навигатора: выше любой области темы.
BuildContext rootContext(WidgetTester tester) =>
    tester.element(find.byType(Navigator).first);

/// Открывает лист «Маршрут» с корневого навигатора и ждёт, пока он сядет.
Future<void> openRouteSheet(WidgetTester tester) async {
  // ignore: unawaited_futures
  showIos27RouteSheet(rootContext(tester));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

/// Ждёт окончания перехода страницы листа (пружина `smooth`, 735 мс).
Future<void> settleSheetPage(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

/// Стандартные искатели рамок `layout.json` для листа (ключи `sheet.*` ставят Ios27List/Row).
Map<String, Finder> sheetElements() => {
      'sheet': find.byKey(const ValueKey('ios27.sheet.frame')),
      'sheet.title': find.byKey(const ValueKey('ios27.sheet.title')),
      'sheet.back': find.byKey(const ValueKey('ios27.sheet.back')),
      'sheet.close': find.byKey(const ValueKey('ios27.sheet.close')),
      'sheet.group': find.byKey(const ValueKey('sheet.group')),
      'sheet.row': find.byKey(const ValueKey('sheet.row')),
      'sheet.rowTitle': find.byKey(const ValueKey('sheet.rowTitle')),
      'sheet.rowDetail': find.byKey(const ValueKey('sheet.rowDetail')),
      'sheet.rowIcon': find.byKey(const ValueKey('sheet.rowIcon')),
      'sheet.rowFlag': find.byKey(const ValueKey('sheet.rowFlag')),
      'sheet.rowCheck': find.byKey(const ValueKey('sheet.rowCheck')),
      'sheet.switch': find.byKey(const ValueKey('sheet.switch')),
    };

/// Кадр доски с подменами; окно пустое, лист открывают отдельно.
Widget routeApp({
  required Ios27BoardData data,
  required RouteCalls calls,
  required Brightness brightness,
  M3eRouteData? routeData,
  List<M3eServerGroup>? groups,
  bool applying = false,
  double textScale = 1.0,
  bool disableAnimations = false,
  StateProvider<List<M3eServerGroup>>? liveGroups,
}) =>
    ios27BoardApp(
      brightness: brightness,
      textScale: textScale,
      disableAnimations: disableAnimations,
      overrides: routeOverrides(
        data,
        calls,
        data: routeData,
        groups: groups,
        applying: applying,
        liveGroups: liveGroups,
      ),
      child: const SizedBox.expand(),
    );
