import 'dart:convert';
import 'dart:io';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/m3e/color/theme_header.dart';
import 'package:dropweb/ui/m3e/home/m3e_actions.dart';
import 'package:dropweb/ui/m3e/home/m3e_elapsed_clock.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_model.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_providers.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:dropweb/ui/m3e/symbols.g.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_hero_button.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sub_card.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_symbol.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_scenes.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';

/// Счётчик вызовов действий главной.
class _Calls {
  final List<String> log = [];

  M3eHomeActions get actions => M3eHomeActions(
        toggleVpn: (_, __) async => log.add('toggle'),
        openSettings: (_, __) => log.add('settings'),
        openSubscriptions: (_, __) => log.add('subs'),
        openRoute: (_, __) => log.add('route'),
        refresh: (_, __) async => log.add('refresh'),
        openLink: (u) => log.add('link:$u'),
      );
}

/// Главная на стенде доски. Эталоны сняты с reducedMotion, поэтому по умолчанию
/// `disableAnimations: true`: connecting — статичный SoftBurst, on — Cookie9 в нулевом
/// угле.
Widget _app(
  String scene,
  int provider,
  Brightness brightness, {
  bool worst = false,
  bool reduced = true,
  bool tickers = true,
  _Calls? calls,
  M3eHomeInput? input,
}) {
  final header = parseDropwebTheme(kBoardProviders[provider].theme);
  return m3eBoardApp(
    seed: header.accent,
    filter: header.filter,
    brightness: brightness,
    overrides: [
      m3eHomeInputProvider
          .overrideWithValue(input ?? homeInputFor(scene, worst: worst)),
      m3eHomeClockProvider.overrideWithValue(() => kHomeNow),
      // Секунды таймера заморожены: golden home-on всегда 12:49.
      m3eTickClockProvider.overrideWithValue(() => kHomeNow),
      // Сигнал и запуск проверки адреса читают globalState; в golden они не нужны.
      m3eIpCheckSignalProvider.overrideWithValue((0, false)),
      m3eIpRefreshProvider.overrideWithValue(
        M3eIpRefresh(read: () => null, reset: () {}, checkQuiet: () async {}),
      ),
      m3eIpLogProvider.overrideWithValue((_) {}),
      // Цель замера пинга читает runTime из globalState; в golden замеров нет.
      m3eRouteNodeProvider.overrideWithValue(null),
      if (calls != null)
        m3eHomeActionsProvider.overrideWithValue(calls.actions),
    ],
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: TickerMode(enabled: tickers, child: const M3eHome()),
      ),
    ),
  );
}

/// Тени нужны golden: кнопки подняты на level1, а без `debugDisableShadows = false`
/// flutter_test рисует их жёсткой обводкой. Флаг возвращается в `finally`, до проверок
/// инвариантов теста.
Future<void> _golden(WidgetTester tester, String name) async {
  try {
    await expectM3eGolden(tester, name);
  } finally {
    debugDisableShadows = true;
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget app, {
  bool shadows = false,
}) async {
  debugDisableShadows = !shadows;
  await pumpM3eBoard(tester, app);
  await tester.pump(const Duration(seconds: 1));
}

/// Разбор `layout.json`: ключ сцены → элементы.
Map<String, dynamic> _elements(
  Map<String, dynamic> layout,
  String scene,
  Brightness brightness,
  int p,
) =>
    (layout['$scene-${brightness.name}-p$p']
        as Map<String, dynamic>)['elements'] as Map<String, dynamic>;

Rect _rectOf(Object? raw) {
  final m = (raw is List ? raw.first : raw) as Map<String, dynamic>;
  return Rect.fromLTWH(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['w'] as num).toDouble(),
    (m['h'] as num).toDouble(),
  );
}

void main() {
  late AppLocalizations l;
  final layout = jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
      as Map<String, dynamic>;

  setUpAll(() async {
    l = await AppLocalizations.load(const Locale('ru'));
  });

  tearDown(() => debugDisableShadows = true);

  group('ворота 3: golden 10 сцен × тема × провайдеры', () {
    for (final scene in kHomeSceneIds) {
      for (final brightness in Brightness.values) {
        for (final p in const [0, 5]) {
          final name = 'home_${scene}_${brightness.name}_p$p';
          testWidgets(name, (tester) async {
            await _pump(
              tester,
              _app(scene, p, brightness),
              shadows: true,
            );
            expect(tester.takeException(), isNull);
            await _golden(tester, name);
          });
        }
      }
    }
  });

  group('ворота 3: худшие данные', () {
    for (final scene in const ['home-off', 'home-on']) {
      for (final brightness in Brightness.values) {
        final name = 'home_worst_${scene}_${brightness.name}_p0';
        testWidgets(name, (tester) async {
          await _pump(
            tester,
            _app(scene, 0, brightness, worst: true),
            shadows: true,
          );
          // Переполнение строки сообщается как исключение кадра.
          expect(tester.takeException(), isNull);
          for (var i = 0; i < 2; i++) {
            final text = find.descendant(
              of: find.byKey(M3eCardKeys.statValue(i)),
              matching: find.byType(RichText),
            );
            final paragraph = tester.renderObject<RenderParagraph>(text.last);
            expect(paragraph.didExceedMaxLines, isFalse,
                reason: 'значение $i обрезано');
          }
          // Длинное объявление раздвигает карточку, но не доезжает до нижнего ряда.
          expect(
            tester.getRect(find.byKey(M3eCardKeys.card)).bottom,
            lessThan(tester.getRect(find.byKey(kM3eJoyKey)).top),
          );
          await _golden(tester, name);
        });
      }
    }
  });

  group('ворота 4: паритет раскладки с layout.json (±4 dp)', () {
    const tolerance = 4.0;
    const named = <String, Key>{
      'card': M3eCardKeys.card,
      'card.head': M3eCardKeys.head,
      'card.plan': M3eCardKeys.plan,
      'card.line': M3eCardKeys.line,
      'card.meter': M3eCardKeys.meter,
      'card.stats': M3eCardKeys.stats,
      'card.sub': M3eCardKeys.sub,
      'card.site': M3eCardKeys.site,
      'card.refresh': M3eCardKeys.refresh,
      'card.name': M3eCardKeys.name,
      'card.state': M3eCardKeys.state,
      'card.dot': M3eCardKeys.dot,
      'card.timer': M3eCardKeys.timer,
      'card.why': M3eCardKeys.why,
      'hero': kM3eHeroKey,
      'hero.shape': kM3eHeroShapeKey,
      'joy': kM3eJoyKey,
      'navBtn': kM3eNavBtnKey,
      'subsBtn': kM3eSubsBtnKey,
      'routeBtn': kM3eRouteBtnKey,
    };

    // Сводка для `.omo/m3e-android/parity.md`: сцена | элемент | доска | Flutter | Δ.
    final rows = <String, ({Rect board, Rect ours, double delta})>{};

    void record(String scene, String element, Rect board, Rect ours) {
      final delta = [
        (board.left - ours.left).abs(),
        (board.top - ours.top).abs(),
        (board.width - ours.width).abs(),
        (board.height - ours.height).abs(),
      ].reduce((a, b) => a > b ? a : b);
      final key = '$scene|$element';
      final prev = rows[key];
      if (prev == null) {
        rows[key] = (board: board, ours: ours, delta: delta);
      } else if (delta > prev.delta) {
        rows[key] = (board: prev.board, ours: prev.ours, delta: delta);
      }
    }

    void expectRect(Rect ours, Rect board, String what) {
      expect(ours.left, closeTo(board.left, tolerance), reason: '$what.x');
      expect(ours.top, closeTo(board.top, tolerance), reason: '$what.y');
      expect(ours.width, closeTo(board.width, tolerance), reason: '$what.w');
      expect(ours.height, closeTo(board.height, tolerance), reason: '$what.h');
    }

    for (final scene in kHomeSceneIds) {
      testWidgets(scene, (tester) async {
        for (final brightness in Brightness.values) {
          for (final p in const [0, 5]) {
            await _pump(tester, _app(scene, p, brightness));
            expect(tester.takeException(), isNull);
            final tag = '$scene-${brightness.name}-p$p';
            final elements = _elements(layout, scene, brightness, p);
            for (final e in named.entries) {
              final ref = elements[e.key];
              final finder = find.byKey(e.value);
              if (ref == null) {
                expect(finder, findsNothing,
                    reason: '$tag: ${e.key} не должно быть');
                continue;
              }
              expect(finder, findsOneWidget,
                  reason: '$tag: ${e.key} нет в дереве');
              final ours = tester.getRect(finder);
              final board = _rectOf(ref);
              expectRect(ours, board, '$tag ${e.key}');
              record(scene, e.key, board, ours);
            }
            for (final group in const ['stat', 'statValue']) {
              final refs = elements['card.$group'] as List<dynamic>;
              // Пинг убран с карточки по решению владельца 2026-10-29: колонок две
              // вместо трёх равных, поэтому x и w берём свои, а y и h сверяем с доской.
              for (var i = 0; i < 2; i++) {
                final key = group == 'stat'
                    ? M3eCardKeys.stat(i)
                    : M3eCardKeys.statValue(i);
                final ours = tester.getRect(find.byKey(key));
                final full = _rectOf(refs[i]);
                final board =
                    Rect.fromLTWH(ours.left, full.top, ours.width, full.height);
                expectRect(ours, board, '$tag card.$group.$i');
                record(scene, 'card.$group.$i', board, ours);
              }
            }
          }
        }
      });
    }

    tearDownAll(() {
      // Сводку пишем только по запросу: тест не должен менять файлы репозитория сам.
      final out = Platform.environment['M3E_PARITY_REPORT'];
      if (out == null || out.isEmpty) return;
      String fmt(Rect r) =>
          '${r.left.toStringAsFixed(1)},${r.top.toStringAsFixed(1)} '
          '${r.width.toStringAsFixed(1)}×${r.height.toStringAsFixed(1)}';
      final buffer = StringBuffer()
        ..writeln('# Паритет главной с доской (T5, ворота 4)')
        ..writeln()
        ..writeln(
            'Допуск ±4 dp. Δmax — наибольшее расхождение по x, y, w, h среди '
            'четырёх вариантов (light/dark × провайдеры 0/5); колонки «Доска» и '
            '«Flutter» — вариант с наибольшим Δ.')
        ..writeln()
        ..writeln(
            '| Сцена | Элемент | Доска x,y w×h | Flutter x,y w×h | Δmax | ок |')
        ..writeln('|---|---|---|---|---|---|');
      for (final scene in kHomeSceneIds) {
        final keys = rows.keys.where((k) => k.startsWith('$scene|')).toList();
        for (final k in keys) {
          final r = rows[k]!;
          buffer.writeln(
            '| $scene | ${k.split('|')[1]} | ${fmt(r.board)} | ${fmt(r.ours)} | '
            '${r.delta.toStringAsFixed(2)} | ${r.delta <= tolerance ? 'да' : 'НЕТ'} |',
          );
        }
      }
      File(out).writeAsStringSync(buffer.toString());
    });
  });

  group('ворота 8: движение', () {
    testWidgets('под disableAnimations после паузы тикеров нет',
        (tester) async {
      for (final scene in kHomeSceneIds) {
        await _pump(tester, _app(scene, 0, Brightness.light));
        await tester.pump(const Duration(seconds: 2));
        expect(tester.binding.transientCallbackCount, 0,
            reason: '$scene при reduced motion');
      }
    });

    testWidgets('под TickerMode(enabled: false) ни один контроллер не тикает',
        (tester) async {
      for (final scene in kHomeSceneIds) {
        await _pump(
          tester,
          _app(scene, 0, Brightness.light, reduced: false, tickers: false),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(tester.binding.transientCallbackCount, 0,
            reason: '$scene под выключенными тикерами');
      }
    });
  });

  group('поведение', () {
    testWidgets('кнопка подписок всегда со знаком-стопкой, без логотипа',
        (tester) async {
      // Решение владельца 2026-10-29: логотип провайдера (`dropweb-logo`, SVG или
      // растр) на этой кнопке не показывается; на доске NORMAL у профиля логотип есть.
      for (final worst in [false, true]) {
        await _pump(
            tester, _app('home-off', 0, Brightness.light, worst: worst));
        final button = find.byKey(kM3eSubsBtnKey);
        final symbol = tester.widget<M3eSymbolIcon>(
          find.descendant(of: button, matching: find.byType(M3eSymbolIcon)),
        );
        expect(symbol.symbol, M3eSymbol.stacks, reason: 'worst=$worst');
        // Сам знак — SVG 24×24; логотип был бы коробкой 30×20 или кругом-растром.
        final svg = tester.widget<SvgPicture>(
          find.descendant(of: button, matching: find.byType(SvgPicture)),
        );
        expect(svg.width, 24, reason: 'worst=$worst');
        expect(
          find.descendant(of: button, matching: find.byType(Image)),
          findsNothing,
        );
      }
    });

    testWidgets('нажатие по кнопке включает VPN, диктор слышит dw_connect',
        (tester) async {
      final calls = _Calls();
      final handle = tester.ensureSemantics();
      await _pump(tester, _app('home-off', 0, Brightness.light, calls: calls));
      final node = find.bySemanticsIdentifier('dw_connect');
      expect(node, findsOneWidget);
      expect(
        tester.getSemantics(node),
        isSemantics(
          label: l.m3eA11yConnect,
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasToggledState: true,
        ),
      );
      await tester.tap(find.byKey(kM3eHeroKey));
      await tester.pump();
      expect(calls.log, ['toggle']);
      handle.dispose();
    });

    testWidgets('подписи кнопки по состояниям', (tester) async {
      final handle = tester.ensureSemantics();
      for (final (scene, label) in [
        ('home-on', l.m3eA11yDisconnect),
        ('connecting', l.m3eA11yCancel),
        ('error', l.m3eA11yRetry),
        ('home-off', l.m3eA11yConnect),
      ]) {
        await _pump(tester, _app(scene, 0, Brightness.light));
        expect(
          tester.getSemantics(find.bySemanticsIdentifier('dw_connect')).label,
          label,
          reason: scene,
        );
      }
      handle.dispose();
    });

    testWidgets('при подключении нажатие ничего не делает', (tester) async {
      final calls = _Calls();
      await _pump(
        tester,
        _app('connecting', 0, Brightness.light, calls: calls),
      );
      await tester.tap(find.byKey(kM3eHeroKey));
      await tester.pump();
      expect(calls.log, isEmpty);
    });

    testWidgets('при закрытой подписке кнопка не нажимается, маршрут доступен',
        (tester) async {
      for (final scene in const ['expired', 'traffic-out']) {
        final calls = _Calls();
        await _pump(tester, _app(scene, 0, Brightness.light, calls: calls));
        await tester.tap(find.byKey(kM3eHeroKey));
        await tester.pump();
        expect(calls.log, isEmpty, reason: scene);
        await tester.tap(find.byKey(kM3eRouteBtnKey));
        await tester.pump();
        expect(calls.log, ['route'], reason: scene);
      }
    });

    testWidgets('кнопки открывают настройки, подписки, маршрут',
        (tester) async {
      final calls = _Calls();
      await _pump(tester, _app('home-off', 0, Brightness.light, calls: calls));
      await tester.tap(find.byKey(kM3eNavBtnKey));
      await tester.tap(find.byKey(kM3eSubsBtnKey));
      await tester.tap(find.byKey(kM3eRouteBtnKey));
      await tester.pump();
      expect(calls.log, ['settings', 'subs', 'route']);
    });

    testWidgets('«Обновить» доходит до действия', (tester) async {
      final calls = _Calls();
      await _pump(tester, _app('expired', 0, Brightness.light, calls: calls));
      await tester.tap(find.byKey(M3eCardKeys.refresh));
      await tester.pump();
      expect(calls.log, ['refresh']);
    });

    testWidgets('в магазинной сборке ссылки в объявлении не нажимаются',
        (tester) async {
      final base = homeInputFor('home-off', worst: true);
      final calls = _Calls();
      await _pump(
        tester,
        _app(
          'home-off',
          0,
          Brightness.light,
          calls: calls,
          input: M3eHomeInput(
            subscription: base.subscription,
            providerName: base.providerName,
            announce: base.announce,
            linksTappable: false,
          ),
        ),
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(M3eCardKeys.site),
          matching: find.byType(Text),
        ),
      );
      var taps = 0;
      text.textSpan!.visitChildren((span) {
        if (span is TextSpan && span.recognizer != null) {
          (span.recognizer! as dynamic).onTap?.call();
          taps++;
        }
        return true;
      });
      expect(taps, 1);
      expect(calls.log, isEmpty);
    });
  });
}
