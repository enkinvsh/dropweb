import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/symbols.g.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/theme/tokens.g.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_round_button.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_symbol.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

const _navKey = ValueKey<String>('m3e.navBtn');
const _subsKey = ValueKey<String>('m3e.subsBtn');
const _routeKey = ValueKey<String>('m3e.routeBtn');

/// Три кнопки на местах доски (layout.json): настройки 351,48 44, подписка 20,798 48,
/// маршрут 343,798 48. Подписка и маршрут получают [subsMark] и [routeMuted] снаружи.
Widget _buttons({
  required Widget subsMark,
  bool routeMuted = false,
  VoidCallback? onNav,
  VoidCallback? onSubs,
  VoidCallback? onRoute,
}) =>
    Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return ColoredBox(
          color: M3eColors.of(context).home.bg,
          child: Stack(
            children: [
              Positioned(
                left: 351,
                top: 48,
                child: M3eTonalIconButton(
                  key: _navKey,
                  size: 44,
                  icon: const M3eSymbolIcon(M3eSymbol.settings),
                  semanticLabel: l10n.m3eA11ySettings,
                  onPressed: onNav ?? () {},
                ),
              ),
              Positioned(
                left: 20,
                top: 798,
                child: M3eTonalIconButton(
                  key: _subsKey,
                  size: 48,
                  icon: subsMark,
                  semanticLabel: l10n.m3eA11ySubs,
                  onPressed: onSubs ?? () {},
                ),
              ),
              Positioned(
                left: 343,
                top: 798,
                child: M3eTonalIconButton(
                  key: _routeKey,
                  size: 48,
                  muted: routeMuted,
                  icon: const M3eSymbolIcon(M3eSymbol.public),
                  semanticLabel: l10n.m3eA11yRoute,
                  onPressed: onRoute ?? () {},
                ),
              ),
            ],
          ),
        );
      },
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  int provider = 0,
  Brightness brightness = Brightness.light,
  bool shadows = false,
}) async {
  debugDisableShadows = !shadows;
  final h = parseDropwebTheme(kBoardProviders[provider].theme);
  await pumpM3eBoard(
    tester,
    m3eBoardApp(
      seed: h.accent,
      filter: h.filter,
      brightness: brightness,
      child: child,
    ),
  );
}

/// Прямоугольник элемента сцены из layout.json (dp от корня 411x914).
Rect _ref(String scene, String key) {
  final all = jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
      as Map<String, dynamic>;
  final elements =
      (all[scene] as Map<String, dynamic>)['elements'] as Map<String, dynamic>;
  var e = elements[key];
  if (e is List) e = e.first;
  final m = e as Map<String, dynamic>;
  return Rect.fromLTWH(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['w'] as num).toDouble(),
    (m['h'] as num).toDouble(),
  );
}

void _expectRectNear(Rect actual, Rect expected, String what,
    {double tol = 4}) {
  expect((actual.left - expected.left).abs(), lessThanOrEqualTo(tol),
      reason: '$what left $actual vs $expected');
  expect((actual.top - expected.top).abs(), lessThanOrEqualTo(tol),
      reason: '$what top $actual vs $expected');
  expect((actual.width - expected.width).abs(), lessThanOrEqualTo(tol),
      reason: '$what width $actual vs $expected');
  expect((actual.height - expected.height).abs(), lessThanOrEqualTo(tol),
      reason: '$what height $actual vs $expected');
}

/// flutter_test рисует тени жёсткой чёрной обводкой, а доска снята с настоящей мягкой.
/// Для golden включаем реальные тени; флаг обязан вернуться до проверки инвариантов теста,
/// а они идут раньше addTearDown, поэтому возврат делает [_golden].
Future<void> _golden(WidgetTester tester, String name) async {
  try {
    await expectM3eGolden(tester, name);
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  group('golden: кнопки', () {
    for (final (name, brightness) in [
      ('light', Brightness.light),
      ('dark', Brightness.dark),
    ]) {
      for (final p in [0, 5]) {
        for (final muted in [false, true]) {
          final kind = muted ? 'muted' : 'normal';
          testWidgets('buttons_${kind}_${name}_p$p', (tester) async {
            await _pump(
              tester,
              _buttons(
                subsMark: const M3eSubMark(),
                routeMuted: muted,
              ),
              provider: p,
              brightness: brightness,
              shadows: true,
            );
            await _golden(tester, 'buttons_${kind}_${name}_p$p');
          });
        }
      }
    }
  });

  group('golden: знак подписки', () {
    testWidgets('submark_stacks_light_p0', (tester) async {
      await _pump(tester, _buttons(subsMark: const M3eSubMark()),
          shadows: true);
      await _golden(tester, 'submark_stacks_light_p0');
    });
  });

  group('поведение', () {
    testWidgets('размер 44 и 48, ключи приходят снаружи', (tester) async {
      await _pump(tester, _buttons(subsMark: const M3eSubMark()));
      expect(tester.getSize(find.byKey(_navKey)), const Size(44, 44));
      expect(tester.getSize(find.byKey(_subsKey)), const Size(48, 48));
      expect(tester.getSize(find.byKey(_routeKey)), const Size(48, 48));
    });

    testWidgets('нажатие зовёт onPressed; приглушённая тоже нажимается',
        (tester) async {
      var nav = 0, route = 0;
      await _pump(
        tester,
        _buttons(
          subsMark: const M3eSubMark(),
          routeMuted: true,
          onNav: () => nav++,
          onRoute: () => route++,
        ),
      );
      await tester.tap(find.byKey(_navKey));
      await tester.tap(find.byKey(_routeKey));
      await tester.pump(const Duration(milliseconds: 400));
      expect(nav, 1);
      // На доске маршрут при закрытой подписке тускнеет, но data-act остаётся.
      expect(route, 1);
    });

    testWidgets('onPressed == null отключает кнопку', (tester) async {
      await _pump(
        tester,
        const Center(
          child: M3eTonalIconButton(
            key: _navKey,
            size: 44,
            icon: M3eSymbolIcon(M3eSymbol.settings),
            semanticLabel: 'x',
          ),
        ),
      );
      final semantics = tester.ensureSemantics();
      final node = tester.getSemantics(find.byKey(_navKey));
      expect(node.label, 'x');
      expect(
        node.getSemanticsData().flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      semantics.dispose();
    });

    testWidgets('подпись для диктора и роль кнопки', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _buttons(subsMark: const M3eSubMark()));
      final node = tester.getSemantics(find.byKey(_routeKey));
      expect(node.label, 'Выбрать маршрут');
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
    });

    testWidgets('нажатие морфит круг в угол 8 пружиной и возвращает',
        (tester) async {
      await _pump(tester, _buttons(subsMark: const M3eSubMark()));
      double radiusOf() {
        final material = tester.widget<Material>(
          find.descendant(
              of: find.byKey(_subsKey), matching: find.byType(Material)),
        );
        final shape = material.shape! as RoundedRectangleBorder;
        return (shape.borderRadius as BorderRadius).topLeft.x;
      }

      expect(radiusOf(), 24);
      final g =
          await tester.startGesture(tester.getCenter(find.byKey(_subsKey)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(radiusOf(), closeTo(8, 0.3));
      await g.up();
      // Первый кадр после старта пружины только запускает тикер, время идёт со второго.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(radiusOf(), closeTo(24, 0.3));
      // Пружина дозатухла и волна ушла, тикеров не осталось.
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('отключённые анимации: нажатие меняет угол сразу',
        (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: _buttons(subsMark: const M3eSubMark()),
          ),
        ),
      );
      final g =
          await tester.startGesture(tester.getCenter(find.byKey(_subsKey)));
      await tester.pump();
      final material = tester.widget<Material>(
        find.descendant(
            of: find.byKey(_subsKey), matching: find.byType(Material)),
      );
      final r = ((material.shape! as RoundedRectangleBorder).borderRadius
              as BorderRadius)
          .topLeft
          .x;
      expect(r, 8);
      await g.up();
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('цвета: карточка и чернила главной, приглушённая — onSurface',
        (tester) async {
      await _pump(
          tester, _buttons(subsMark: const M3eSubMark(), routeMuted: true));
      final colors = M3eColors.of(tester.element(find.byKey(_navKey)));
      Material materialOf(Key k) => tester.widget<Material>(
            find.descendant(of: find.byKey(k), matching: find.byType(Material)),
          );
      expect(materialOf(_navKey).color, colors.home.card);
      expect(materialOf(_navKey).elevation, M3eElevation.level1);
      final muted = materialOf(_routeKey);
      expect(muted.color, colors.scheme.onSurface.withValues(alpha: 0.08));
      expect(muted.elevation, 0);
    });

    testWidgets('знак подписки: символ stacks', (tester) async {
      await _pump(tester, const Center(child: M3eSubMark()));
      expect(find.byType(M3eSymbolIcon), findsOneWidget);
    });
  });

  group('паритет с layout.json (±4 dp)', () {
    for (final scene in [
      'support-light-p0',
      'home-off-light-p0',
      'expired-light-p0',
    ]) {
      testWidgets(scene, (tester) async {
        await _pump(
          tester,
          _buttons(
            subsMark: const M3eSubMark(),
            routeMuted: scene == 'expired-light-p0',
          ),
        );
        _expectRectNear(tester.getRect(find.byKey(_navKey)),
            _ref(scene, 'navBtn'), 'navBtn');
        _expectRectNear(tester.getRect(find.byKey(_subsKey)),
            _ref(scene, 'subsBtn'), 'subsBtn');
        _expectRectNear(tester.getRect(find.byKey(_routeKey)),
            _ref(scene, 'routeBtn'), 'routeBtn');
      });
    }
  });
}
