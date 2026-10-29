import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show CheckedState, Tristate;

import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/ui/m3e/color/theme_header.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_model.dart';
import 'package:dropweb/ui/m3e/route/m3e_route_providers.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:dropweb/ui/m3e/screens/m3e_route_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_scenes.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';

const _homeKey = ValueKey<String>('route.test.home');
const _sheetKey = ValueKey<String>('m3e.sheet');
const _scrimKey = ValueKey<String>('m3e.scrim');
const _titleKey = ValueKey<String>('m3e.sheet.title');
const _backKey = ValueKey<String>('m3e.sheet.back');
const _serversBodyKey = ValueKey<String>('route.test.servers');

/// Данные листа из набора доски: «Авто» с лучшей страной, страны с пингом, выбрана «Авто»
/// (`st.route == 'auto'`, `routeMain()` android.js:530). Страна без ответа (`ms == null`)
/// становится отрицательным пингом.
M3eRouteData _dataFor(
  BoardData b, {
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
    testUrl: probe.isEmpty ? null : 'https://t.test',
  );
}

/// Действия-заглушки с журналом вызовов.
class _Calls {
  final List<String> log = [];

  M3eRouteActions get actions => M3eRouteActions(
        pick: (row) async => log.add('pick:${row.id}'),
        setFullTunnel: ({required enabled}) async => log.add('tunnel:$enabled'),
        probe: (proxies, url) async =>
            log.add('probe:${proxies.map((p) => p.name).join(',')}@$url'),
      );
}

/// Кадр как у эталона `route-*`: главная доски под листом. На доске при открытии
/// маршрута VPN включён (`home-on`), поэтому фон — именно эта сцена.
Widget _app(
  int provider,
  Brightness brightness,
  M3eRouteData data, {
  _Calls? calls,
  bool applying = false,
  bool reduced = true,
}) {
  final header = parseDropwebTheme(kBoardProviders[provider].theme);
  return m3eBoardApp(
    seed: header.accent,
    filter: header.filter,
    brightness: brightness,
    overrides: [
      m3eRouteDataProvider.overrideWithValue(data),
      m3eRouteActionsProvider.overrideWithValue((calls ?? _Calls()).actions),
      if (applying) m3eRouteApplyingProvider.overrideWith((ref) => true),
    ],
    child: Builder(
      builder: (context) {
        final l = AppLocalizations.of(context);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: KeyedSubtree(
            key: _homeKey,
            child: M3eHomeScreen(
              view: buildM3eHomeView(
                l,
                homeInputFor('home-on'),
                now: kHomeNow,
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _servers(BuildContext context) =>
    const SizedBox(key: _serversBodyKey, height: 40, child: Text('серверы'));

Future<void> _pump(
  WidgetTester tester,
  Widget app, {
  bool shadows = false,
  bool open = true,
}) async {
  debugDisableShadows = !shadows;
  await pumpM3eBoard(tester, app);
  await tester.pump(const Duration(seconds: 1));
  if (open) await _open(tester);
}

Future<void> _open(WidgetTester tester) async {
  unawaited(
    showM3eRouteSheet(
      tester.element(find.byKey(_homeKey)),
      serversBuilder: _servers,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Тени нужны golden: без `debugDisableShadows = false` flutter_test рисует их жёсткой
/// обводкой. Флаг возвращается в `finally`, до проверок инвариантов теста.
Future<void> _golden(WidgetTester tester, String name) async {
  try {
    await expectM3eGolden(tester, name);
  } finally {
    debugDisableShadows = true;
  }
}

/// Текст внутри списка стран: главная под листом тоже рисует флаг в карточке.
Finder _inList(String text) => find.descendant(
      of: find.byKey(kM3eRouteCountriesKey),
      matching: find.text(text),
    );

Rect _rectOf(Object? raw) {
  final m = (raw is List ? raw.first : raw) as Map<String, dynamic>;
  return Rect.fromLTWH(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['w'] as num).toDouble(),
    (m['h'] as num).toDouble(),
  );
}

/// Заглушка `Groups`: базовый `onUpdate` пишет в `globalState`, которого в тесте нет.
class _Groups extends Groups {
  _Groups(this.value);
  final List<Group> value;
  @override
  List<Group> build() => value;
  @override
  void onUpdate(List<Group> value) {}
}

Group _group(
  String name, {
  List<String> all = const [],
  String? now,
  String? testUrl,
  bool? hidden,
}) =>
    Group(
      type: GroupType.Selector,
      name: name,
      now: now,
      testUrl: testUrl,
      hidden: hidden,
      all: [for (final n in all) Proxy(name: n, type: 'VLESS')],
    );

void main() {
  final layout = jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
      as Map<String, dynamic>;

  tearDown(() => debugDisableShadows = true);

  group('ворота 3: golden листа «Маршрут»', () {
    for (final brightness in Brightness.values) {
      for (final p in const [0, 5]) {
        final name = 'route_${brightness.name}_p$p';
        testWidgets(name, (tester) async {
          await _pump(
            tester,
            _app(p, brightness, _dataFor(kBoardNormal)),
            shadows: true,
          );
          expect(tester.takeException(), isNull);
          expect(find.byKey(_sheetKey), findsOneWidget);
          await _golden(tester, name);
        });
      }
    }
  });

  group('худшие данные', () {
    for (final brightness in Brightness.values) {
      final name = 'route_worst_${brightness.name}_p0';
      testWidgets(name, (tester) async {
        // WORST: длинные имена стран, 640/1840 мс (медленно), у ОАЭ нет ответа.
        await _pump(
          tester,
          _app(0, brightness, _dataFor(kBoardWorst, selected: 'ae')),
          shadows: true,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('нет ответа'), findsOneWidget);
        expect(find.text('1840\u00a0мс'), findsOneWidget);
        expect(find.text('Объединённые Арабские Эмираты'), findsOneWidget);
        expect(find.text('7 групп'), findsOneWidget);
        // Ни одна строка не вылезла за лист по ширине.
        final sheet = tester.getRect(find.byKey(_sheetKey));
        for (final id in ['de', 'nl', 'us', 'ae', 'kz']) {
          final r = tester.getRect(find.byKey(kM3eRouteRowKey(id)));
          expect(r.left, greaterThanOrEqualTo(sheet.left));
          expect(r.right, lessThanOrEqualTo(sheet.right));
        }
        await _golden(tester, name);
      });
    }
  });

  group('ворота 4: паритет с layout.json (±4 dp)', () {
    const tolerance = 4.0;
    final table = <String>[];

    void check(String tag, String element, Rect ours, Rect board) {
      final delta = [
        (board.left - ours.left).abs(),
        (board.top - ours.top).abs(),
        (board.width - ours.width).abs(),
        (board.height - ours.height).abs(),
      ].reduce((a, b) => a > b ? a : b);
      String r(Rect x) => '${x.left.toStringAsFixed(1)},'
          '${x.top.toStringAsFixed(1)},${x.width.toStringAsFixed(1)}×'
          '${x.height.toStringAsFixed(1)}';
      table.add(
        '| $tag | $element | ${r(board)} | ${r(ours)} | '
        '${delta.toStringAsFixed(2)} | ${delta <= tolerance ? 'ок' : 'НЕТ'} |',
      );
      expect(delta, lessThanOrEqualTo(tolerance), reason: '$tag $element');
    }

    tearDownAll(() {
      final out = File('.omo/m3e-android/b/route_parity.md');
      out.parent.createSync(recursive: true);
      out.writeAsStringSync(
        '# Паритет листа «Маршрут» с доской (допуск ±4 dp)\n\n'
        'Сцена `route`, NORMAL, ключи из `test/m3e/ref/layout.json`. Δmax — наибольшее '
        'расхождение по x, y, w, h.\n\n'
        '| Сцена | Элемент | Доска x,y,w×h | Flutter x,y,w×h | Δmax | Итог |\n'
        '|---|---|---|---|---|---|\n'
        '${table.join('\n')}\n',
      );
    });

    testWidgets('все сцены route', (tester) async {
      for (final brightness in Brightness.values) {
        for (final p in const [0, 5]) {
          await _pump(tester, _app(p, brightness, _dataFor(kBoardNormal)));
          expect(tester.takeException(), isNull);
          final tag = 'route-${brightness.name}-p$p';
          final el = (layout[tag] as Map<String, dynamic>)['elements']
              as Map<String, dynamic>;

          check(tag, 'sheet', tester.getRect(find.byKey(_sheetKey)),
              _rectOf(el['sheet']));
          check(tag, 'scrim', tester.getRect(find.byKey(_scrimKey)),
              _rectOf(el['scrim']));
          check(tag, 'sheet.title', tester.getRect(find.byKey(_titleKey)),
              _rectOf(el['sheet.title']));

          final lists = el['list'] as List<dynamic>;
          check(
              tag,
              'list[0]',
              tester.getRect(find.byKey(kM3eRouteCountriesKey)),
              _rectOf([lists[0]]));
          check(tag, 'list[1]', tester.getRect(find.byKey(kM3eRouteMoreKey)),
              _rectOf([lists[1]]));

          final items = el['list.item'] as List<dynamic>;
          final keys = <Key>[
            kM3eRouteAutoKey,
            for (final c in kBoardNormal.countries) kM3eRouteRowKey(c.id),
            kM3eRouteTunnelKey,
            kM3eRouteServersKey,
          ];
          expect(keys.length, items.length, reason: '$tag: число пунктов');
          for (var i = 0; i < keys.length; i++) {
            check(tag, 'list.item[$i]', tester.getRect(find.byKey(keys[i])),
                _rectOf([items[i]]));
          }

          // Следующий кадр открывается заново: закрываем лист жестом «назад».
          await tester.tapAt(const Offset(200, 100));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
        }
      }
    });
  });

  group('поведение', () {
    testWidgets('«Авто» показывает узел, который выбрала группа',
        (tester) async {
      await _pump(tester, _app(0, Brightness.light, _dataFor(kBoardNormal)));
      expect(
        find.descendant(
          of: find.byKey(kM3eRouteAutoKey),
          matching: find.text('Нидерланды'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(kM3eRouteAutoKey),
          matching: find.text('Авто'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('выбранная строка — радио с галочкой; лист не закрывается',
        (tester) async {
      final handle = tester.ensureSemantics();
      final calls = _Calls();
      await _pump(
        tester,
        _app(
          0,
          Brightness.light,
          _dataFor(kBoardNormal, selected: 'fi'),
          calls: calls,
        ),
      );
      final fi = tester.getSemantics(find.byKey(kM3eRouteRowKey('fi')));
      final nl = tester.getSemantics(find.byKey(kM3eRouteRowKey('nl')));
      expect(fi.flagsCollection.isChecked, CheckedState.isTrue);
      expect(nl.flagsCollection.isChecked, CheckedState.isFalse);

      await tester.tap(find.byKey(kM3eRouteRowKey('de')));
      await tester.pump();
      // Как на доске: выбор страны лист не закрывает.
      expect(calls.log, ['pick:de']);
      expect(find.byKey(_sheetKey), findsOneWidget);
      handle.dispose();
    });

    testWidgets('тап «Авто» передаёт агрегатор', (tester) async {
      final calls = _Calls();
      await _pump(
        tester,
        _app(0, Brightness.light, _dataFor(kBoardNormal, selected: 'nl'),
            calls: calls),
      );
      await tester.tap(find.byKey(kM3eRouteAutoKey));
      await tester.pump();
      expect(calls.log, ['pick:auto']);
    });

    testWidgets('«Весь трафик» переключает и держит dw_tunnel', (tester) async {
      final handle = tester.ensureSemantics();
      final calls = _Calls();
      await _pump(
        tester,
        _app(0, Brightness.light, _dataFor(kBoardNormal), calls: calls),
      );
      expect(find.bySemanticsIdentifier('dw_tunnel'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(kM3eRouteTunnelKey))
            .flagsCollection
            .isToggled,
        Tristate.isTrue,
      );
      await tester.tap(find.byKey(kM3eRouteTunnelKey));
      await tester.pump();
      expect(calls.log, ['tunnel:false']);
      handle.dispose();
    });

    testWidgets('без полного туннеля пункта нет', (tester) async {
      await _pump(
        tester,
        _app(
          0,
          Brightness.light,
          _dataFor(kBoardNormal, tunnelAvailable: false),
        ),
      );
      expect(find.byKey(kM3eRouteTunnelKey), findsNothing);
      expect(find.byKey(kM3eRouteServersKey), findsOneWidget);
    });

    testWidgets('«Серверы и группы» кладёт тело в стек, «Назад» возвращает',
        (tester) async {
      await _pump(tester, _app(0, Brightness.light, _dataFor(kBoardNormal)));
      expect(find.text('6 групп'), findsOneWidget);
      await tester.tap(find.byKey(kM3eRouteServersKey));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(_serversBodyKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(_titleKey)).data,
        'Серверы и группы',
      );
      expect(find.byKey(_backKey), findsOneWidget);
      expect(find.byKey(kM3eRouteAutoKey), findsNothing);

      await tester.tap(find.byKey(_backKey));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(_serversBodyKey), findsNothing);
      expect(find.byKey(kM3eRouteAutoKey), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(_titleKey)).data, 'Маршрут');
    });

    testWidgets('пока применяется маршрут, нажатия не проходят',
        (tester) async {
      final calls = _Calls();
      await _pump(
        tester,
        _app(0, Brightness.light, _dataFor(kBoardNormal),
            calls: calls, applying: true),
      );
      await tester.tap(find.byKey(kM3eRouteRowKey('de')), warnIfMissed: false);
      await tester.tap(find.byKey(kM3eRouteTunnelKey), warnIfMissed: false);
      await tester.pump();
      expect(calls.log, isEmpty);
    });

    testWidgets('замер при открытии один раз', (tester) async {
      final calls = _Calls();
      final probe = [
        const Proxy(name: 'a', type: 'VLESS'),
        const Proxy(name: 'b', type: 'VLESS'),
      ];
      await _pump(
        tester,
        _app(0, Brightness.light, _dataFor(kBoardNormal, probe: probe),
            calls: calls),
      );
      // Повторные перерисовки не повторяют замер.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(calls.log, ['probe:a,b@https://t.test']);
    });

    testWidgets('пустой роутер: только «Серверы и группы»', (tester) async {
      await _pump(
        tester,
        _app(
          0,
          Brightness.light,
          const M3eRouteData(groupsCount: 2),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(kM3eRouteCountriesKey), findsNothing);
      expect(find.byKey(kM3eRouteServersKey), findsOneWidget);
      expect(find.text('2 группы'), findsOneWidget);
    });
  });

  group('адаптер реальных групп', () {
    const profileId = 'p';
    const profile = Profile(
      id: profileId,
      autoUpdateDuration: Duration(hours: 1),
      fullTunnel: true,
    );

    ProviderContainer container({
      required List<Group> groups,
      Map<String, String?> selected = const {},
      Map<String, int?> delays = const {},
      String routerName = 'VPN',
    }) {
      final c = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWithValue(profile),
          currentGroupsStateProvider
              .overrideWithValue(GroupsState(value: groups)),
          groupsProvider.overrideWith(() => _Groups(groups)),
          m3eRouteInfoProvider(profileId).overrideWith(
            (ref) async => (fullTunnelAvailable: true, routerName: routerName),
          ),
          for (final g in groups)
            getProxyNameProvider(g.name).overrideWithValue(selected[g.name]),
          // Одно имя бывает в нескольких группах: переопределение ставится один раз.
          for (final name in {
            for (final g in groups) ...[g.name, for (final p in g.all) p.name],
          })
            getDelayProvider(proxyName: name, testUrl: 'https://t.test')
                .overrideWithValue(delays[name]),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    final groups = [
      _group(
        'VPN',
        all: ['⚡ Авто', '🇳🇱 Нидерланды', '🇩🇪 Германия', 'Узел без флага'],
        now: '🇳🇱 Нидерланды',
        testUrl: 'https://t.test',
      ),
      _group('⚡ Авто',
          all: ['🇳🇱 Нидерланды, Амстердам'],
          now: '🇳🇱 Нидерланды, Амстердам'),
    ];

    test('«Авто» первой, страны со своими флагами и пингом', () async {
      final c = container(
        groups: groups,
        selected: {'VPN': '⚡ Авто', '⚡ Авто': '🇳🇱 Нидерланды, Амстердам'},
        delays: {
          '⚡ Авто': 41,
          '🇳🇱 Нидерланды': 41,
          '🇩🇪 Германия': -1,
          'Узел без флага': null,
        },
      );
      final sub = c.listen(m3eRouteDataProvider, (_, __) {});
      await c.read(m3eRouteInfoProvider(profileId).future);
      final data = c.read(m3eRouteDataProvider);
      sub.close();

      expect(data.routerName, 'VPN');
      expect(data.fullTunnelAvailable, isTrue);
      expect(data.fullTunnel, isTrue);
      expect(data.groupsCount, 2);
      expect(data.testUrl, 'https://t.test');
      expect(data.probe.length, 4);

      final auto = data.rows.first;
      expect(auto.isAggregate, isTrue);
      expect(auto.selected, isTrue);
      // Подпись «Авто» — узел, который агрегатор выбрал сейчас, без флага.
      expect(auto.sup, 'Нидерланды, Амстердам');
      expect(auto.pingMs, 41);

      final nl = data.rows.firstWhere((r) => r.id == '🇳🇱 Нидерланды');
      expect(nl.flag, '🇳🇱');
      expect(nl.label, 'Нидерланды');
      expect(nl.selected, isFalse);
      final de = data.rows.firstWhere((r) => r.id == '🇩🇪 Германия');
      expect(de.pingMs, -1);
      final plain = data.rows.firstWhere((r) => r.id == 'Узел без флага');
      expect(plain.flag, isNull);
      expect(plain.pingMs, isNull);
    });

    test('выбрана страна: отмечена она, а не «Авто»', () async {
      final c = container(
        groups: groups,
        selected: {'VPN': '🇩🇪 Германия'},
      );
      final sub = c.listen(m3eRouteDataProvider, (_, __) {});
      await c.read(m3eRouteInfoProvider(profileId).future);
      final data = c.read(m3eRouteDataProvider);
      sub.close();
      expect(data.rows.where((r) => r.selected).map((r) => r.id),
          ['🇩🇪 Германия']);
      expect(data.rows.first.selected, isFalse);
    });

    test('пока конфиг читается, строк нет, группы считаются', () {
      final c = container(groups: groups);
      final data = c.read(m3eRouteDataProvider);
      expect(data.rows, isEmpty);
      expect(data.routerName, isNull);
      expect(data.groupsCount, 2);
    });

    // Конфиг с телефона владельца (шаблон панели провайдера, 2026-10-29): страны
    // приходят url-test группами с флагом, рядом «Tunnel»-узлы и белые узлы.
    final ownerGroups = [
      _group(
        '🌍 VPN',
        all: [
          '⚡ Авто',
          '📶 First Available',
          '🇩🇪 Германия ✨',
          '🇺🇸 США ✨',
          '🇳🇱 Нидерланды ✨',
          '🇩🇪 Германия · Tunnel',
          '🇳🇱 Нидерланды · Tunnel',
          '🇺🇸 США · Tunnel',
          '⚪ White',
          '⚪ White · резерв',
        ],
        now: '⚡ Авто',
        testUrl: 'https://t.test',
      ),
      // Авто → вложенная `⚡ Fastest` → лист: подпись строки «Авто» — лист цепочки.
      _group('⚡ Авто',
          all: ['⚡ Fastest', '📶 First Available'],
          now: '⚡ Fastest',
          hidden: true),
      _group('⚡ Fastest',
          all: ['🇩🇪 Германия · Tunnel', '🇳🇱 Нидерланды · Tunnel'],
          now: '🇩🇪 Германия · Tunnel'),
      _group('📶 First Available', all: ['⚪ White']),
      _group('🇩🇪 Германия ✨', all: ['🇩🇪 Германия · Tunnel']),
      _group('🇺🇸 США ✨', all: ['🇺🇸 США · Tunnel']),
      _group('🇳🇱 Нидерланды ✨', all: ['🇳🇱 Нидерланды · Tunnel']),
    ];
    const ownerDelays = {
      '⚡ Авто': 44,
      '🇩🇪 Германия ✨': 48,
      '🇺🇸 США ✨': 131,
      '🇳🇱 Нидерланды ✨': 43,
      '🇩🇪 Германия · Tunnel': 52,
      '🇳🇱 Нидерланды · Tunnel': -1,
    };

    Future<M3eRouteData> ownerData() async {
      final c = container(
        groups: ownerGroups,
        routerName: '🌍 VPN',
        selected: {
          '🌍 VPN': '⚡ Авто',
          '⚡ Авто': '⚡ Fastest',
          '⚡ Fastest': '🇩🇪 Германия · Tunnel',
          '🇩🇪 Германия ✨': '🇩🇪 Германия · Tunnel',
        },
        delays: ownerDelays,
      );
      // Подписка держит autoDispose-провайдер живым, пока читается его значение.
      final sub = c.listen(m3eRouteDataProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(m3eRouteInfoProvider(profileId).future);
      return c.read(m3eRouteDataProvider);
    }

    test('конфиг владельца: «Авто», страны с флагом без подписи, остальное',
        () async {
      final data = await ownerData();
      expect(data.rows.map((r) => r.id), [
        '⚡ Авто',
        '🇩🇪 Германия ✨',
        '🇺🇸 США ✨',
        '🇳🇱 Нидерланды ✨',
        '🇩🇪 Германия · Tunnel',
        '🇳🇱 Нидерланды · Tunnel',
        '🇺🇸 США · Tunnel',
        '⚪ White',
        '⚪ White · резерв',
      ]);
      // Агрегаторы без флага, кроме «Авто», не показываются (`📶 First Available`),
      // но замеряются все члены роутера.
      expect(data.rows.length, 9);
      expect(data.probe.length, 10);

      final auto = data.rows.first;
      expect(auto.flag, isNull);
      // Эмодзи из имени группы для аватара; подпись — лист цепочки, не `⚡ Fastest`.
      expect(auto.emoji, '⚡');
      expect(auto.isAggregate, isTrue);
      expect(auto.sup, 'Германия · Tunnel');
      expect(auto.selected, isTrue);

      for (final id in ['🇩🇪 Германия ✨', '🇺🇸 США ✨', '🇳🇱 Нидерланды ✨']) {
        final row = data.rows.firstWhere((r) => r.id == id);
        expect(row.flag, isNotNull, reason: id);
        expect(row.sup, isNull, reason: id);
        // Для логики группа остаётся группой: старый экран «Страна» тоже ставит
        // для неё `standard`.
        expect(row.isAggregate, isTrue, reason: id);
      }
      final de = data.rows.firstWhere((r) => r.id == '🇩🇪 Германия ✨');
      expect(de.label, 'Германия ✨');
      expect(de.pingMs, 48);
      final tunnel =
          data.rows.firstWhere((r) => r.id == '🇳🇱 Нидерланды · Tunnel');
      expect(tunnel.isAggregate, isFalse);
      expect(tunnel.pingMs, -1);

      expect(data.rows.any((r) => r.id == '📶 First Available'), isFalse);
      // Эмодзи узла без флага — в аватаре, из подписи убрано.
      final white = data.rows.firstWhere((r) => r.id == '⚪ White');
      expect(white.emoji, '⚪');
      expect(white.label, 'White');
      final reserve = data.rows.firstWhere((r) => r.id == '⚪ White · резерв');
      expect(reserve.emoji, '⚪');
      expect(reserve.label, 'White · резерв');
      // Нет ни флага, ни эмодзи — эмодзи не придумываем.
      expect(
          data.rows.firstWhere((r) => r.id == '🇩🇪 Германия · Tunnel').emoji,
          isNull);
    });

    test('выбран скрытый агрегатор: ни одна строка не отмечена', () async {
      final c = container(
        groups: ownerGroups,
        routerName: '🌍 VPN',
        selected: {'🌍 VPN': '📶 First Available'},
      );
      final sub = c.listen(m3eRouteDataProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(m3eRouteInfoProvider(profileId).future);
      expect(
          c.read(m3eRouteDataProvider).rows.where((r) => r.selected), isEmpty);
    });

    test('цикл во вложенных группах не подвешивает сборку', () async {
      final loop = [
        _group('VPN',
            all: ['A', '🇩🇪 Германия'], now: 'A', testUrl: 'https://t.test'),
        _group('A', all: ['B'], now: 'B'),
        _group('B', all: ['A'], now: 'A'),
      ];
      final c = container(
        groups: loop,
        selected: {'VPN': 'A', 'A': 'B', 'B': 'A'},
      );
      final sub = c.listen(m3eRouteDataProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(m3eRouteInfoProvider(profileId).future);
      expect(c.read(m3eRouteDataProvider).rows.first.id, 'A');
    });

    testWidgets(
        'конфиг владельца: страны с флагами в листе, выбор и идентификаторы',
        (tester) async {
      final data = await ownerData();
      final handle = tester.ensureSemantics();
      final calls = _Calls();
      await _pump(
        tester,
        _app(0, Brightness.light, data, calls: calls),
        shadows: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsIdentifier('dw_mode_standard'), findsOneWidget);
      // Аватар с флагом у шести строк: три группы-страны и три «Tunnel»-узла.
      expect(_inList('🇩🇪'), findsNWidgets(2));
      expect(_inList('🇺🇸'), findsNWidgets(2));
      expect(_inList('🇳🇱'), findsNWidgets(2));
      // Шесть стран с флагом и два белых узла без агрегатора.
      expect(find.bySemanticsIdentifier('dw_mode_country'), findsNWidgets(8));
      // Подпись узла только у «Авто».
      expect(find.text('Германия · Tunnel'), findsNWidgets(2));
      // Подпись без ⚪, сам ⚪ — аватар-эмодзи (по одному у двух белых узлов).
      expect(_inList('White'), findsOneWidget);
      expect(_inList('White · резерв'), findsOneWidget);
      expect(_inList('⚪'), findsNWidgets(2));
      await _golden(tester, 'route_groups_light_p0');

      await tester.ensureVisible(find.byKey(kM3eRouteRowKey('🇺🇸 США ✨')));
      await tester.tap(find.byKey(kM3eRouteRowKey('🇺🇸 США ✨')));
      await tester.pump();
      // Замер при открытии покрывает всех членов роутера, группы-страны тоже.
      expect(calls.log.where((e) => e.startsWith('probe:')).single,
          contains('🇺🇸 США ✨'));
      expect(
          calls.log.where((e) => e.startsWith('pick:')), ['pick:🇺🇸 США ✨']);
      handle.dispose();
    });
  });
}
