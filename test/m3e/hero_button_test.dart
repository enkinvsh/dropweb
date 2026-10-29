import 'dart:ui' as ui;

import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/theme/tokens.g.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_hero_button.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

/// Положение кнопки на доске: `hero` в ref/layout.json (x 161.5, y 778, 88x88).
const Offset _heroAt = Offset(161.5, 778);

/// Сколько прокрутить вращение перед снимком `on`: 8 с = 120° — кратно периоду
/// Cookie9 (40°), поэтому форма стоит так же, как на эталоне (там вращение не идёт).
const Duration _spinPump = Duration(seconds: 8);

Widget _scene({
  required M3eHeroState state,
  bool disabled = false,
  bool reduced = false,
  bool tickers = true,
  VoidCallback? onPressed,
}) =>
    Builder(
      builder: (context) {
        final home = M3eColors.of(context).home;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: TickerMode(
            enabled: tickers,
            child: ColoredBox(
              color: home.bg,
              child: SizedBox.expand(
                child: Stack(
                  children: [
                    Positioned(
                      left: _heroAt.dx,
                      top: _heroAt.dy,
                      width: kM3eHeroSize,
                      height: kM3eHeroSize,
                      child: M3eHeroButton(
                        state: state,
                        disabled: disabled,
                        onPressed: onPressed,
                        semanticLabel: 'Подключить VPN',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

Widget _app(
  Widget child, {
  int provider = 0,
  Brightness brightness = Brightness.light,
}) {
  final h = parseDropwebTheme(kBoardProviders[provider].theme);
  return m3eBoardApp(
    seed: h.accent,
    filter: h.filter,
    brightness: brightness,
    child: child,
  );
}

Future<ui.Image> _shot(WidgetTester tester) async {
  final box = tester.element(find.byKey(kM3eBoardRootKey)).renderObject!
      as RenderRepaintBoundary;
  return (await tester.runAsync(box.toImage))!;
}

Future<List<int>> _bytes(WidgetTester tester) async {
  final image = await _shot(tester);
  final data = await tester.runAsync(image.toByteData);
  return data!.buffer.asUint8List();
}

void main() {
  group('golden: кнопка подключения', () {
    for (final provider in [0, 5]) {
      for (final brightness in Brightness.values) {
        final theme = brightness == Brightness.dark ? 'dark' : 'light';
        for (final (name, state, disabled, reduced) in const [
          ('off', M3eHeroState.off, false, false),
          // Эталон снят с «меньше движения»: индикатор — статичный SoftBurst.
          ('connecting', M3eHeroState.connecting, false, true),
          ('on', M3eHeroState.on, false, false),
          ('error', M3eHeroState.error, false, false),
          ('disabled', M3eHeroState.off, true, false),
        ]) {
          testWidgets('hero_${name}_${theme}_p$provider', (tester) async {
            await pumpM3eBoard(
              tester,
              _app(
                _scene(state: state, disabled: disabled, reduced: reduced),
                provider: provider,
                brightness: brightness,
              ),
            );
            await tester.pump(
              state == M3eHeroState.on ? _spinPump : const Duration(seconds: 1),
            );
            await expectM3eGolden(tester, 'hero_${name}_${theme}_p$provider');
          });
        }
      }
    }
  });

  group('поведение', () {
    testWidgets('под disableAnimations тикеров нет ни в одном состоянии',
        (tester) async {
      for (final state in M3eHeroState.values) {
        await pumpM3eBoard(
          tester,
          _app(_scene(state: state, reduced: true)),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(
          tester.binding.transientCallbackCount,
          0,
          reason: '$state при reduced motion',
        );
      }
    });

    testWidgets('смена состояния при reduced motion мгновенна и без тикеров',
        (tester) async {
      for (final state in [M3eHeroState.on, M3eHeroState.off]) {
        await pumpM3eBoard(
          tester,
          _app(_scene(state: state, reduced: true)),
        );
      }
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('в on вращение идёт: кадры различаются', (tester) async {
      await pumpM3eBoard(tester, _app(_scene(state: M3eHeroState.on)));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pump(const Duration(seconds: 1));
      final first = await _bytes(tester);
      await tester.pump(const Duration(seconds: 3));
      final second = await _bytes(tester);
      expect(first, isNot(second));
    });

    testWidgets('вне on вращения нет', (tester) async {
      await pumpM3eBoard(tester, _app(_scene(state: M3eHeroState.off)));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('при TickerMode(enabled: false) тикер не тикает',
        (tester) async {
      await pumpM3eBoard(
        tester,
        _app(_scene(state: M3eHeroState.on, tickers: false)),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('смена off → on → off посреди морфа не падает', (tester) async {
      await pumpM3eBoard(tester, _app(_scene(state: M3eHeroState.off)));
      for (final state in [
        M3eHeroState.on,
        M3eHeroState.off,
        M3eHeroState.connecting,
        M3eHeroState.error,
        M3eHeroState.on,
        M3eHeroState.off,
      ]) {
        await tester.pumpWidget(_app(_scene(state: state)));
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('выход из connecting гасит индикатор', (tester) async {
      await pumpM3eBoard(tester, _app(_scene(state: M3eHeroState.connecting)));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(_app(_scene(state: M3eHeroState.off)));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('Semantics: кнопка dw_connect, toggled в on', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpM3eBoard(
        tester,
        _app(_scene(state: M3eHeroState.on, onPressed: () {})),
      );
      final finder = find.bySemanticsIdentifier('dw_connect');
      expect(finder, findsOneWidget);
      expect(
        tester.getSemantics(finder),
        isSemantics(
          label: 'Подключить VPN',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('размеры и ключи: корень 88x88, форма на всю кнопку',
        (tester) async {
      await pumpM3eBoard(tester, _app(_scene(state: M3eHeroState.off)));
      expect(tester.getSize(find.byKey(kM3eHeroKey)), const Size(88, 88));
      expect(tester.getSize(find.byKey(kM3eHeroShapeKey)), const Size(88, 88));
      expect(
        tester.getTopLeft(find.byKey(kM3eHeroKey)),
        const Offset(161.5, 778),
      );
    });

    testWidgets('нажатие вызывает onPressed, при disabled — нет',
        (tester) async {
      var taps = 0;
      await pumpM3eBoard(
        tester,
        _app(_scene(state: M3eHeroState.off, onPressed: () => taps++)),
      );
      await tester.tap(find.byKey(kM3eHeroKey));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);

      await tester.pumpWidget(
        _app(
          _scene(
            state: M3eHeroState.off,
            disabled: true,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byKey(kM3eHeroKey));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);
    });
  });

  group('помощник форм', () {
    test('m3ePlace центрирует контур в (0.5, 0.5) и сохраняет размер', () {
      final cubics = m3ePlacedShape(MaterialShapes.cookie9Sided);
      final b = m3eCubicsBounds(cubics);
      expect((b.left + b.right) / 2, closeTo(0.5, 1e-9));
      expect((b.top + b.bottom) / 2, closeTo(0.5, 1e-9));
      // Библиотека нормализует по границам опорных точек, кривая чуть внутри.
      expect(b.longestSide, inInclusiveRange(0.95, 1.0));
    });

    test('поворот на 360 градусов возвращает контур', () {
      final base = m3ePlacedShape(MaterialShapes.softBurst);
      final turned = m3ePlace(base, degrees: 360);
      for (var i = 0; i < base.length; i++) {
        for (var j = 0; j < 8; j++) {
          expect(turned[i][j], closeTo(base[i][j], 1e-6));
        }
      }
    });

    test('пружина: 0 в начале, около 1 за 0,7 с, перелёт у default spatial',
        () {
      expect(m3eSpringValue(M3eSpring.defaultSpatial, 0), closeTo(0, 1e-9));
      expect(m3eSpringValue(M3eSpring.defaultSpatial, 0.7), closeTo(1, 0.01));
      final peak = [
        for (var i = 1; i < 70; i++)
          m3eSpringValue(M3eSpring.defaultSpatial, i / 100),
      ].reduce((a, b) => a > b ? a : b);
      expect(peak, greaterThan(1));
      expect(m3eSpringValue(M3eSpring.defaultEffects, 1), closeTo(1, 1e-6));
    });

    test('resample доводит число кубиков до n и сохраняет начало и конец', () {
      final c = m3ePlacedShape(MaterialShapes.circle);
      final r = m3eResample(c, 96);
      expect(r.length, 96);
      expect(r.first.sublist(0, 2), c.first.sublist(0, 2));
      expect(r.last.sublist(6), c.last.sublist(6));
    });
  });
}
