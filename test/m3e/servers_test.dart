// Экран «Серверы и группы» (сцена `servers` доски): список групп и шаг узлов внутри листа.
// Лист и стек шагов собирает тестовая обёртка: на устройстве их держит экран маршрута.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show CheckedState;

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:dropweb/ui/m3e/screens/m3e_servers_groups.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gate_support.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';

const _sheetKey = ValueKey<String>('m3e.sheet');
const _titleKey = ValueKey<String>('m3e.sheet.title');
const _backKey = ValueKey<String>('m3e.sheet.back');
const _testUrl = 'https://test.local/204';

/// Группы доски в виде модели экрана: выбран первый узел, как `sel[i] ?? 0` на доске.
List<M3eServerGroup> _groups(BoardData d, {int extraNodes = 0}) => [
      for (final g in d.groups)
        M3eServerGroup(
          name: g.name,
          testUrl: _testUrl,
          nodes: [
            for (final n in g.nodes)
              M3eServerNode(name: n.name, type: n.protocol),
            for (var i = 0; i < extraNodes && g == d.groups.first; i++)
              M3eServerNode(
                  name: 'Узел №${i + 1}, дополнительный', type: 'VLESS'),
          ],
          selectedName: g.nodes.first.name,
          selectedLabel: g.nodes.first.name,
        ),
    ];

/// Задержки по имени узла: `null` в данных доски значит «нет ответа» (отрицательное число).
Map<String, int> _delays(BoardData d) => {
      for (final g in d.groups)
        for (final n in g.nodes) n.name: n.ms ?? -1,
    };

class _Calls {
  final List<(String, String)> selected = [];
  final List<(List<String>, String?)> probes = [];
}

Override _actions(_Calls calls) => m3eServersActionsProvider.overrideWithValue(
      M3eServersActions(
        selectNode: (g, n) => calls.selected.add((g, n)),
        probe: (nodes, url) async =>
            calls.probes.add(([for (final n in nodes) n.name], url)),
      ),
    );

List<Override> _overrides(
  List<M3eServerGroup> groups,
  Map<String, int> delays,
  _Calls calls,
) =>
    [
      m3eServerGroupsProvider.overrideWithValue(groups),
      m3eNodeDelayProvider.overrideWith((ref, key) => delays[key.name]),
      _actions(calls),
    ];

/// Подталкивает второй шаг сразу после первого кадра: на доске лист открыт на
/// «Серверах и группах» с шагом «назад», то есть стек [Маршрут, Серверы и группы].
class _AutoPush extends StatefulWidget {
  const _AutoPush();

  @override
  State<_AutoPush> createState() => _AutoPushState();
}

class _AutoPushState extends State<_AutoPush> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      M3eSheetStack.of(context).push(
        (_) => M3eSheetScaffold(
          title: l.m3eServersTitle,
          body: const M3eServersGroupsView(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<void> _settle(WidgetTester tester, [int ms = 700]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(const Duration(milliseconds: 50));
}

/// Главная home-on на NORMAL/WORST и поверх неё лист, открытый на «Серверах и группах».
Future<void> _open(
  WidgetTester tester, {
  int provider = 0,
  Brightness brightness = Brightness.light,
  bool worst = false,
  int extraNodes = 0,
  bool shadows = false,
  _Calls? calls,
  List<M3eServerGroup>? groups,
}) async {
  // Доска снята с мягкой тенью листа, flutter_test без флага рисует жёсткую обводку.
  // Флаг возвращает `_golden`: инвариант теста проверяется раньше addTearDown.
  debugDisableShadows = !shadows;
  final data = worst ? kBoardWorst : kBoardNormal;
  await pumpM3eBoard(
    tester,
    gateHomeApp(
      'home-on',
      provider: provider,
      brightness: brightness,
      worst: worst,
      extra: _overrides(
        groups ?? _groups(data, extraNodes: extraNodes),
        _delays(data),
        calls ?? _Calls(),
      ),
    ),
  );
  final ctx = tester.element(find.byType(M3eHome));
  final l = AppLocalizations.of(ctx);
  unawaited(showM3eSheet<void>(
    ctx,
    builder: (_) => M3eSheetStack(
      root: (_) => M3eSheetScaffold(
        title: l.m3eRouteTitle,
        body: const _AutoPush(),
      ),
    ),
  ));
  await _settle(tester);
}

Future<void> _golden(WidgetTester tester, String name) async {
  try {
    await expectM3eGolden(tester, name);
  } finally {
    debugDisableShadows = true;
  }
}

Finder _item(int i) => find.byKey(m3eServersItemKey(i));

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.load(const Locale('ru'));
  });

  group('golden: сцена servers', () {
    for (final b in Brightness.values) {
      for (final p in const [0, 5]) {
        final name = 'servers_${b.name}_p$p';
        testWidgets(name, (tester) async {
          await _open(tester, provider: p, brightness: b, shadows: true);
          expect(tester.takeException(), isNull);
          await _golden(tester, name);
        });
      }
    }

    testWidgets('servers_group_light_p0: шаг узлов группы «Fastest»', (
      tester,
    ) async {
      await _open(tester, shadows: true);
      await tester.tap(_item(1));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(find.byKey(_titleKey)).data,
        'Fastest',
        reason: 'заголовок шага — имя группы без ведущего эмодзи',
      );
      expect(find.byKey(_backKey), findsOneWidget);
      await _golden(tester, 'servers_group_light_p0');
    });
  });

  group('golden: худшие данные', () {
    testWidgets('servers_worst_light_p0: длинные имена, нет ответа', (
      tester,
    ) async {
      await _open(tester, worst: true, shadows: true);
      expect(tester.takeException(), isNull);
      await _golden(tester, 'servers_worst_light_p0');
    });

    testWidgets(
        'servers_worst_nodes_light_p0: 60 узлов, длинное имя, нет ответа', (
      tester,
    ) async {
      await _open(tester, worst: true, extraNodes: 58, shadows: true);
      await tester.tap(_item(0));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l.m3eMsNoAnswer), findsWidgets,
          reason: 'узел без ответа показывает «нет ответа»');
      await _golden(tester, 'servers_worst_nodes_light_p0');
    });
  });

  group('паритет раскладки с layout.json (±4 dp)', () {
    final layout =
        jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
            as Map<String, dynamic>;
    const tolerance = 4.0;

    void expectRect(Rect actual, Map<String, dynamic> ref, String what) {
      final r = {
        'x': actual.left,
        'y': actual.top,
        'w': actual.width,
        'h': actual.height,
      };
      for (final k in r.keys) {
        expect(
          r[k],
          closeTo((ref[k] as num).toDouble(), tolerance),
          reason: '$what.$k: у нас ${r[k]}, на доске ${ref[k]}',
        );
      }
    }

    testWidgets('servers-light-p0', (tester) async {
      await _open(tester);
      final el = (layout['servers-light-p0']
          as Map<String, dynamic>)['elements'] as Map<String, dynamic>;
      for (final e in {
        'sheet': _sheetKey,
        'sheet.title': _titleKey,
        'sheet.back': _backKey,
        'list': kM3eServersListKey,
      }.entries) {
        expectRect(
          tester.getRect(find.byKey(e.value)),
          (el[e.key] is List ? (el[e.key] as List).first : el[e.key])
              as Map<String, dynamic>,
          e.key,
        );
      }
      final items = el['list.item'] as List<dynamic>;
      expect(items, hasLength(6));
      for (var i = 0; i < items.length; i++) {
        expectRect(
          tester.getRect(_item(i)),
          items[i] as Map<String, dynamic>,
          'list.item.$i',
        );
      }
    });
  });

  group('поведение', () {
    testWidgets('группа: подпись выбранного узла, пинг и «нет ответа»', (
      tester,
    ) async {
      await _open(tester, worst: true);
      // У первой группы WORST выбран узел без ответа, у остальных число.
      expect(
        find.descendant(of: _item(0), matching: find.text(l.m3eMsNoAnswer)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _item(1), matching: find.text('41\u00a0мс')),
        findsOneWidget,
      );
      expect(
          find.text(
              'Резервный канал для обхода блокировок мобильного оператора'),
          findsOneWidget);
    });

    testWidgets('при открытии меряется выбранный узел каждой группы, один раз',
        (
      tester,
    ) async {
      final calls = _Calls();
      await _open(tester, calls: calls);
      expect(calls.probes, hasLength(1),
          reason: 'один адрес замера — один вызов');
      final names = calls.probes.single.$1;
      expect(calls.probes.single.$2, _testUrl);
      // Выбранные узлы 6 групп: ⚡ Авто, Нидерланды…, Германия…, США… — без повторов.
      expect(names.toSet().length, names.length);
      expect(names, contains('⚡ Авто'));
      expect(names, contains('Нидерланды, Амстердам'));
    });

    testWidgets('шаг узлов меряет все узлы группы с её адресом замера', (
      tester,
    ) async {
      final calls = _Calls();
      await _open(tester, calls: calls);
      calls.probes.clear();
      await tester.tap(_item(1));
      await _settle(tester);
      expect(calls.probes, hasLength(1));
      expect(calls.probes.single.$2, _testUrl);
      expect(calls.probes.single.$1, [
        'Нидерланды, Амстердам',
        'Финляндия, Хельсинки',
        'Германия, Франкфурт',
        'США, Нью-Йорк',
      ]);
    });

    testWidgets(
        'выбор узла меняет узел в своей группе и возвращает на шаг назад', (
      tester,
    ) async {
      final calls = _Calls();
      await _open(tester, calls: calls);
      await tester.tap(_item(1));
      await _settle(tester);
      // Тот же ключ `m3e.list.item.N`, что в группах: узлы идут по порядку.
      await tester.tap(_item(2));
      await _settle(tester);
      expect(calls.selected, [('⚡ Fastest', 'Германия, Франкфурт')]);
      expect(tester.widget<Text>(find.byKey(_titleKey)).data, l.m3eServersTitle,
          reason: 'после выбора лист вернулся к списку групп');
    });

    testWidgets('у узлов радио-семантика: выбран ровно один', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester);
      await tester.tap(_item(1));
      await _settle(tester);
      for (var i = 0; i < 4; i++) {
        final node = tester.getSemantics(_item(i));
        expect(node.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
        expect(
          node.flagsCollection.isChecked,
          i == 0 ? CheckedState.isTrue : CheckedState.isFalse,
          reason: 'узел $i',
        );
      }
      expect(
        tester.getSemantics(_item(0)).getSemanticsData().label,
        allOf(contains('Нидерланды'), contains('VLESS')),
      );
      handle.dispose();
    });

    testWidgets('нет групп: показывается nullProfileDesc', (tester) async {
      await _open(tester, groups: const []);
      expect(find.text(l.nullProfileDesc), findsOneWidget);
      expect(find.byKey(kM3eServersListKey), findsNothing);
    });
  });

  group('m3eServerTitle', () {
    test('убирает ведущие эмодзи и флаги', () {
      expect(m3eServerTitle('🌍 VPN'), 'VPN');
      expect(m3eServerTitle('🇺🇸 США ✨'), 'США ✨');
      expect(m3eServerTitle('⚡ Fastest'), 'Fastest');
      // Составные эмодзи (ZWJ, keycap) тоже уходят целиком, а не по кусочку.
      expect(m3eServerTitle('🏳️‍🌈 Прайд'), 'Прайд');
      expect(m3eServerTitle('1️⃣ Первый'), 'Первый');
      expect(m3eServerTitle('⚪ White · резерв'), 'White · резерв');
      expect(m3eServerTitle('Германия, Франкфурт'), 'Германия, Франкфурт');
    });

    test('если после эмодзи пусто, оставляет имя целиком', () {
      expect(m3eServerTitle('🌍'), '🌍');
      expect(m3eServerTitle('🌍 '), '🌍 ');
    });
  });
}
