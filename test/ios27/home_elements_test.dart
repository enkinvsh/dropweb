// Тесты элементов главной iOS (T4-A1): фон, кнопка питания, кнопки дока и круглая кнопка.
//
// Golden — полный кадр 822×1828 с элементами в рамках из `layout.json`; карточка в кадр не
// входит (её рисует другой исполнитель), на её месте пусто. Сверка с доской — глазами и
// `.omo/ios/t4/a1/diffstat.py`, зелёный golden сам по себе совпадения не доказывает.

import 'dart:ui' show Tristate;

import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_backdrop.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_circle_button.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_dock_button.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_power_button.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_activity_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/board_providers.dart';
import 'support/golden.dart';
import 'support/layout.dart';

/// Сцена полного кадра: что рисует фон и в каком состоянии кнопка питания.
class _Scene {
  const _Scene(this.name, this.backdrop, this.power,
      {this.routeInactive = false});

  /// Имя сцены доски (`home-off`, `connecting`, ...).
  final String name;
  final Ios27BackdropState backdrop;
  final Ios27PowerState power;

  /// Сцены с блокировкой: кнопка маршрута погашена (`glass--inactive`, app.js:550).
  final bool routeInactive;
}

const _scenes = <_Scene>[
  _Scene('home-off', Ios27BackdropState.off, Ios27PowerState.off),
  _Scene('home-on', Ios27BackdropState.on, Ios27PowerState.on),
  _Scene(
      'connecting', Ios27BackdropState.connecting, Ios27PowerState.connecting),
  _Scene('error', Ios27BackdropState.off, Ios27PowerState.error),
  _Scene('offline', Ios27BackdropState.off, Ios27PowerState.offline),
  _Scene(
    'expired',
    Ios27BackdropState.off,
    Ios27PowerState.disabled,
    routeInactive: true,
  ),
];

Ios27ProviderTheme _theme(int provider) =>
    Ios27ProviderTheme.fromHeader(kBoardProviders[provider].theme);

Ios27Colors _colors(int provider, Brightness b) => Ios27Colors.from(
      theme: _theme(provider),
      brightness: b,
      child: const SizedBox.shrink(),
    );

/// Заранее считает фон: `Isolate.run` из FakeAsync-зоны теста не возвращается, поэтому
/// картинка кладётся в кэш вне неё.
Future<void> _prewarm(
  WidgetTester tester,
  Ios27Colors colors,
  Ios27BackdropState state, {
  double t = kIos27BackdropT0,
}) =>
    tester.runAsync(
      () => Ios27BackdropRenderer.debugPrewarm(
        Ios27BackdropSpec.fromColors(colors, on: state.target, t: t),
      ),
    );

/// Даёт `.then(setState)` фона дойти до кадра.
Future<void> _settleBackdrop(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
}

Rect _r(Ios27RefLayout l, String name) => l.element(name)!;

/// Кадр главной без карточки: фон + элементы в рамках доски.
Widget _frame(Ios27RefLayout layout, _Scene scene) => Stack(
      children: [
        Positioned.fill(child: Ios27Backdrop(state: scene.backdrop)),
        Positioned.fromRect(
          rect: _r(layout, 'settings'),
          child: const Ios27CircleButton.icon(
            icon: Ios27IconName.settings,
            semanticLabel: 'Настройки',
          ),
        ),
        Positioned.fromRect(
          rect: _r(layout, 'dock-sub'),
          child: const Ios27DockButton.subscriptions(semanticLabel: 'Подписка'),
        ),
        Positioned.fromRect(
          rect: _r(layout, 'power'),
          child: Ios27PowerButton(
            state: scene.power,
            semanticLabel: 'Подключить VPN',
            onPressed: () {},
          ),
        ),
        Positioned.fromRect(
          rect: _r(layout, 'dock-route'),
          child: Ios27DockButton.route(
            semanticLabel: 'Маршрут: Авто. Открыть список',
            inactive: scene.routeInactive,
            onPressed: () {},
          ),
        ),
      ],
    );

Future<void> _pumpFrame(
  WidgetTester tester,
  _Scene scene, {
  required bool dark,
  required int provider,
}) async {
  final b = dark ? Brightness.dark : Brightness.light;
  final mode = dark ? 'dark' : 'light';
  final layout = Ios27RefLayout.load('${scene.name}-$mode-rt-p$provider');
  await _prewarm(tester, _colors(provider, b), scene.backdrop);
  await pumpIos27Board(
    tester,
    ios27BoardApp(
      brightness: b,
      theme: _theme(provider),
      disableAnimations: true,
      child: _frame(layout, scene),
    ),
  );
  await _settleBackdrop(tester);
}

/// Обёртка одиночных виджетов: скоуп темы, центр, без фона.
Widget _solo(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool reduceTransparency = true,
  bool disableAnimations = false,
  bool highContrast = false,
  double textScale = 1,
}) =>
    ios27BoardApp(
      brightness: brightness,
      theme: _theme(0),
      reduceTransparency: reduceTransparency,
      disableAnimations: disableAnimations,
      highContrast: highContrast,
      textScale: textScale,
      child: Center(child: child),
    );

/// Ширина с учётом `Transform` (`getSize` берёт размер до трансформации).
double _width(WidgetTester tester, Finder f) =>
    tester.getBottomRight(f).dx - tester.getTopLeft(f).dx;

Ios27Icon _icon(WidgetTester tester, Finder within) => tester.widget<Ios27Icon>(
      find.descendant(of: within, matching: find.byType(Ios27Icon)),
    );

void main() {
  group('полные кадры', () {
    // Кадры снимаются при Reduce Transparency (заглушка стекла) и сверяются с `-rt-` эталонами.
    for (final scene in _scenes) {
      for (final dark in [false, true]) {
        for (final p in [0, 5]) {
          // Второй провайдер (p5) нужен только на ключевых сценах: остальное — те же пиксели.
          final key = scene.name;
          if (p == 5 &&
              key != 'home-off' &&
              key != 'home-on' &&
              key != 'connecting') {
            continue;
          }
          final mode = dark ? 'dark' : 'light';
          testWidgets('golden ${scene.name} $mode p$p', (tester) async {
            await _pumpFrame(tester, scene, dark: dark, provider: p);
            await expectIos27Golden(
              tester,
              'elements_${scene.name}_${mode}_p$p',
            );
          });
        }
      }
    }
  });

  group('кнопка питания', () {
    testWidgets('каждое состояние рисуется', (tester) async {
      for (final state in Ios27PowerState.values) {
        await pumpIos27Board(
          tester,
          _solo(
            Ios27PowerButton(
                state: state, semanticLabel: 'x', onPressed: () {}),
          ),
        );
        final connecting = state == Ios27PowerState.connecting;
        expect(
          find.byType(Ios27ActivityIndicator),
          connecting ? findsOneWidget : findsNothing,
          reason: '$state',
        );
        expect(
          find.byType(Ios27Icon),
          connecting ? findsNothing : findsOneWidget,
          reason: '$state',
        );
        expect(
            tester.getSize(find.byType(Ios27PowerButton)), const Size(80, 80));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('dw_connect: подпись, кнопка, переключатель, enabled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpIos27Board(
        tester,
        _solo(
          Ios27PowerButton(
            state: Ios27PowerState.on,
            semanticLabel: 'Отключить VPN',
            onPressed: () {},
          ),
        ),
      );
      final finder = find.bySemanticsIdentifier(kIos27PowerSemanticsId);
      expect(finder, findsOneWidget);
      expect(kIos27PowerSemanticsId, 'dw_connect');
      final data = tester.getSemantics(finder).getSemanticsData();
      expect(data.label, 'Отключить VPN');
      expect(data.identifier, 'dw_connect');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, Tristate.isTrue);
      expect(data.flagsCollection.isToggled, Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('отключённая кнопка не нажимается и не enabled',
        (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpIos27Board(
        tester,
        _solo(
          Ios27PowerButton(
            state: Ios27PowerState.disabled,
            semanticLabel: 'Подключить VPN',
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(Ios27PowerButton));
      await tester.pump(const Duration(milliseconds: 50));
      expect(taps, 0);
      final data = tester
          .getSemantics(find.bySemanticsIdentifier('dw_connect'))
          .getSemanticsData();
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      // Значок питания погашен до --label-3.
      final colors = Ios27Colors.of(
        tester.element(find.byType(Ios27PowerButton)),
      );
      expect(_icon(tester, find.byType(Ios27PowerButton)).color,
          colors.palette.label3);
      handle.dispose();
    });

    testWidgets('нажатие вызывает onPressed во всех живых состояниях', (
      tester,
    ) async {
      for (final state in [
        Ios27PowerState.off,
        Ios27PowerState.connecting,
        Ios27PowerState.on,
        Ios27PowerState.error,
        Ios27PowerState.offline,
      ]) {
        var taps = 0;
        await pumpIos27Board(
          tester,
          _solo(
            Ios27PowerButton(
              state: state,
              semanticLabel: 'x',
              onPressed: () => taps++,
            ),
          ),
        );
        await tester.tap(find.byType(Ios27PowerButton));
        await tester.pump(const Duration(milliseconds: 50));
        expect(taps, 1, reason: '$state');
      }
    });

    testWidgets('error и offline выглядят как off', (tester) async {
      Future<Color?> iconColor(Ios27PowerState s) async {
        await pumpIos27Board(
          tester,
          _solo(
              Ios27PowerButton(state: s, semanticLabel: 'x', onPressed: () {})),
        );
        expect(find.byType(Ios27Icon), findsOneWidget);
        final glass = tester.widget<Ios27Glass>(find.byType(Ios27Glass));
        expect(glass.tint, isNull, reason: '$s');
        expect(glass.interactive, isTrue, reason: '$s');
        return _icon(tester, find.byType(Ios27PowerButton)).color;
      }

      final off = await iconColor(Ios27PowerState.off);
      expect(await iconColor(Ios27PowerState.error), off);
      expect(await iconColor(Ios27PowerState.offline), off);
    });

    for (final dark in [false, true]) {
      testWidgets('цвета значка (${dark ? 'тёмная' : 'светлая'} тема)', (
        tester,
      ) async {
        final b = dark ? Brightness.dark : Brightness.light;
        Future<Ios27Colors> pumpState(Ios27PowerState s,
            {bool rt = true}) async {
          await pumpIos27Board(
            tester,
            _solo(
              Ios27PowerButton(state: s, semanticLabel: 'x', onPressed: () {}),
              brightness: b,
              reduceTransparency: rt,
            ),
          );
          // Тон просачивается пружиной smooth (735 мс): ждём конца перехода.
          await tester.pump(const Duration(seconds: 1));
          return Ios27Colors.of(tester.element(find.byType(Ios27PowerButton)));
        }

        var c = await pumpState(Ios27PowerState.off);
        expect(_icon(tester, find.byType(Ios27PowerButton)).color,
            c.palette.glassLabel);
        c = await pumpState(Ios27PowerState.on);
        // Reduce Transparency: тон — акцент, значок на --on-accent (glass.css:298).
        expect(tester.widget<Ios27Glass>(find.byType(Ios27Glass)).tint,
            c.accentColor);
        expect(
          _icon(tester, find.byType(Ios27PowerButton)).color?.toARGB32(),
          c.onAccent.toARGB32(),
        );
        c = await pumpState(Ios27PowerState.on, rt: false);
        // Без Reduce Transparency значок белый (стекло с тоном светлое).
        expect(
          _icon(tester, find.byType(Ios27PowerButton)).color?.toARGB32(),
          Colors.white.toARGB32(),
        );
        expect(Ios27A11y.reduceTransparency, isFalse);
      });
    }

    testWidgets('Increase Contrast: подпись полностью чёрная/белая', (
      tester,
    ) async {
      await pumpIos27Board(
        tester,
        _solo(
          Ios27PowerButton(
            state: Ios27PowerState.off,
            semanticLabel: 'x',
            onPressed: () {},
          ),
          highContrast: true,
        ),
      );
      expect(_icon(tester, find.byType(Ios27PowerButton)).color, Colors.black);
    });

    testWidgets('смена вида: значок появляется пружиной, потом покой', (
      tester,
    ) async {
      var state = Ios27PowerState.off;
      late StateSetter set;
      await pumpIos27Board(
        tester,
        _solo(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return Ios27PowerButton(
                state: state,
                semanticLabel: 'x',
                onPressed: () {},
              );
            },
          ),
        ),
      );
      set(() => state = Ios27PowerState.connecting);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Посреди появления значок прозрачен частично и уменьшен.
      final opacity = tester.widgetList<Opacity>(find.byType(Opacity)).first;
      expect(opacity.opacity, lessThan(1));
      expect(opacity.opacity, greaterThan(0));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ImageFiltered), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reduce Motion: после 200 мс нет бегущих тикеров', (
      tester,
    ) async {
      var state = Ios27PowerState.off;
      late StateSetter set;
      await pumpIos27Board(
        tester,
        _solo(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return Ios27PowerButton(
                state: state,
                semanticLabel: 'x',
                onPressed: () {},
              );
            },
          ),
          disableAnimations: true,
        ),
      );
      set(() => state = Ios27PowerState.on);
      await tester.pump();
      // Только прозрачность: ни масштаба, ни размытия.
      await tester.pump(const Duration(milliseconds: 90));
      expect(find.byType(ImageFiltered), findsNothing);
      expect(
          tester
              .widgetList<Transform>(find.descendant(
                of: find.byType(Ios27PowerButton),
                matching: find.byType(Transform),
              ))
              .every((t) => t.transform.getMaxScaleOnAxis() == 1),
          isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('нажатие под Reduce Motion: без подъёма, свечение есть', (
      tester,
    ) async {
      await pumpIos27Board(
        tester,
        _solo(
          Ios27PowerButton(
            state: Ios27PowerState.off,
            semanticLabel: 'x',
            onPressed: () {},
          ),
          disableAnimations: true,
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Ios27PowerButton)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(_width(tester, find.byType(Ios27Glass)), closeTo(80, 0.01));
      final glass = find.descendant(
        of: find.byType(Ios27PowerButton),
        matching: find.byType(CustomPaint),
      );
      expect(glass, findsWidgets);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('спиннер крутится и замирает под TickerMode(false)', (
      tester,
    ) async {
      await pumpIos27Board(
        tester,
        _solo(
          const Ios27PowerButton(
            state: Ios27PowerState.connecting,
            semanticLabel: 'x',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(await _framesOver(tester, 1000), greaterThan(0));

      await pumpIos27Board(
        tester,
        _solo(
          const TickerMode(
            enabled: false,
            child: Ios27PowerButton(
              state: Ios27PowerState.connecting,
              semanticLabel: 'x',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(await _framesOver(tester, 1000), 0);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('спиннер под Reduce Motion всё равно крутится (2 с)', (
      tester,
    ) async {
      await pumpIos27Board(
        tester,
        _solo(
          const Ios27PowerButton(
            state: Ios27PowerState.connecting,
            semanticLabel: 'x',
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      // Ступень 250 мс: за секунду ровно четыре смены (а не восемь, как без Reduce Motion).
      expect(await _framesOver(tester, 1000), inInclusiveRange(3, 5));
    });

    // Спиннер живёт одну фазу connecting: оболочка появления не должна пересоздавать его
    // ни в начале, ни в конце `appear()` (раньше State создавался заново).
    for (final reduce in [false, true]) {
      testWidgets(
          'спиннер создаётся один раз за фазу connecting'
          '${reduce ? ' (Reduce Motion)' : ''}', (tester) async {
        var state = Ios27PowerState.off;
        late StateSetter set;
        try {
          await pumpIos27Board(
            tester,
            _solo(
              StatefulBuilder(
                builder: (context, setState) {
                  set = setState;
                  return Ios27PowerButton(
                    state: state,
                    semanticLabel: 'x',
                    onPressed: () {},
                  );
                },
              ),
              disableAnimations: reduce,
            ),
          );
          expect(find.byType(Ios27ActivityIndicator), findsNothing);

          set(() => state = Ios27PowerState.connecting);
          await tester.pump();
          final first = tester.state(find.byType(Ios27ActivityIndicator));
          // Начало, середина и конец появления (пружина bouncy ~1 с): тот же State.
          for (final ms in [30, 120, 400, 1500]) {
            await tester.pump(Duration(milliseconds: ms));
            expect(
              identical(
                  tester.state(find.byType(Ios27ActivityIndicator)), first),
              isTrue,
              reason: 'после $ms мс',
            );
          }

          // Новая фаза connecting после выхода — новый State, а не залипший старый.
          set(() => state = Ios27PowerState.on);
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.byType(Ios27ActivityIndicator), findsNothing);
          set(() => state = Ios27PowerState.connecting);
          await tester.pump();
          expect(
            identical(tester.state(find.byType(Ios27ActivityIndicator)), first),
            isFalse,
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }

    testWidgets('dispose посреди анимаций не бросает', (tester) async {
      var state = Ios27PowerState.off;
      late StateSetter set;
      await pumpIos27Board(
        tester,
        _solo(
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return Ios27PowerButton(
                state: state,
                semanticLabel: 'x',
                onPressed: () {},
              );
            },
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Ios27PowerButton)),
      );
      set(() => state = Ios27PowerState.on);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(const SizedBox.shrink());
      await gesture.cancel();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('textScale 2.0: размер и отсутствие переполнения', (
      tester,
    ) async {
      await pumpIos27Board(
        tester,
        _solo(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Ios27PowerButton(state: Ios27PowerState.on, semanticLabel: 'x'),
              Ios27DockButton.subscriptions(semanticLabel: 'x'),
              Ios27CircleButton.icon(
                key: ValueKey('solo-circle'),
                icon: Ios27IconName.settings,
              ),
            ],
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Ios27PowerButton)), const Size(80, 80));
      expect(tester.getSize(find.byType(Ios27DockButton)), const Size(48, 48));
      expect(
        tester.getSize(find.byKey(const ValueKey('solo-circle'))),
        const Size(44, 44),
      );
    });
  });

  group('кнопки дока', () {
    testWidgets('подписки: значок stack, идентификатора нет', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIos27Board(
        tester,
        _solo(
          const Ios27DockButton.subscriptions(semanticLabel: 'Подписка'),
        ),
      );
      expect(_icon(tester, find.byType(Ios27DockButton)).name,
          Ios27IconName.stack);
      expect(find.bySemanticsIdentifier('dw_exit'), findsNothing);
      expect(tester.getSize(find.byType(Ios27DockButton)), const Size(48, 48));
      expect(find.bySemanticsLabel('Подписка'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('маршрут: значок globe и dw_exit', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpIos27Board(
        tester,
        _solo(
          Ios27DockButton.route(
            semanticLabel: 'Маршрут: Авто. Открыть список',
            onPressed: () => taps++,
          ),
        ),
      );
      expect(kIos27RouteSemanticsId, 'dw_exit');
      final finder = find.bySemanticsIdentifier('dw_exit');
      expect(finder, findsOneWidget);
      final data = tester.getSemantics(finder).getSemanticsData();
      expect(data.label, 'Маршрут: Авто. Открыть список');
      expect(data.flagsCollection.isButton, isTrue);
      expect(_icon(tester, find.byType(Ios27DockButton)).name,
          Ios27IconName.globe);
      await tester.tap(find.byType(Ios27DockButton));
      await tester.pump(const Duration(milliseconds: 50));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('погасшая кнопка маршрута: inactive, label-3, но нажимается', (
      tester,
    ) async {
      var taps = 0;
      await pumpIos27Board(
        tester,
        _solo(
          Ios27DockButton.route(
            semanticLabel: 'x',
            inactive: true,
            onPressed: () => taps++,
          ),
        ),
      );
      final glass = tester.widget<Ios27Glass>(find.byType(Ios27Glass));
      expect(glass.variant, Ios27GlassVariant.inactive);
      expect(glass.interactive, isFalse);
      final c = Ios27Colors.of(tester.element(find.byType(Ios27DockButton)));
      expect(
          _icon(tester, find.byType(Ios27DockButton)).color, c.palette.label3);

      // Нажатие работает, но кнопка не приподнимается (нет glass--interactive).
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Ios27DockButton)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getSize(find.byType(Ios27Glass)), const Size(48, 48));
      expect(_width(tester, find.byType(Ios27Glass)), closeTo(48, 0.01));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(taps, 1);
    });
  });

  group('круглая кнопка', () {
    testWidgets('подъём 6 % пружиной под пальцем и возврат', (tester) async {
      await pumpIos27Board(
        tester,
        _solo(
          Ios27CircleButton.icon(
            icon: Ios27IconName.settings,
            onPressed: () {},
            semanticLabel: 'Настройки',
          ),
        ),
      );
      final glass = find.byType(Ios27Glass);
      expect(_width(tester, glass), closeTo(44, 0.01));
      final gesture = await tester.startGesture(tester.getCenter(glass));
      // Первый кадр поднимает onTapDown по таймеру 100 мс, пружина идёт со следующего.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_width(tester, glass), closeTo(44 * kIos27PressScale, 0.5));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(_width(tester, glass), closeTo(44, 0.01));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('отмена касания возвращает кнопку в покой', (tester) async {
      await pumpIos27Board(
        tester,
        _solo(
          Ios27CircleButton.icon(
            icon: Ios27IconName.settings,
            onPressed: () {},
          ),
        ),
      );
      final glass = find.byType(Ios27Glass);
      final gesture = await tester.startGesture(tester.getCenter(glass));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveBy(const Offset(200, 0));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(_width(tester, glass), closeTo(44, 0.01));
    });

    testWidgets('без onPressed: не нажимается, без реакции, enabled=false', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpIos27Board(
        tester,
        _solo(
          const Ios27CircleButton.icon(
            icon: Ios27IconName.settings,
            semanticLabel: 'Настройки',
          ),
        ),
      );
      final glass = find.byType(Ios27Glass);
      final gesture = await tester.startGesture(tester.getCenter(glass));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_width(tester, glass), closeTo(44, 0.01));
      await gesture.up();
      handle.dispose();
    });

    testWidgets('значок и тон: светлая/тёмная тема', (tester) async {
      for (final b in Brightness.values) {
        await pumpIos27Board(
          tester,
          _solo(
            const Ios27CircleButton.icon(
              icon: Ios27IconName.settings,
              semanticLabel: 'x',
            ),
            brightness: b,
          ),
        );
        final c =
            Ios27Colors.of(tester.element(find.byType(Ios27CircleButton)));
        final icon = _icon(tester, find.byType(Ios27CircleButton));
        expect(icon.color, c.palette.glassLabel);
        expect(icon.size, 22);
      }
    });

    testWidgets('произвольный child', (tester) async {
      await pumpIos27Board(
        tester,
        _solo(
          const Ios27CircleButton(
            diameter: 60,
            child: Text('A'),
          ),
        ),
      );
      expect(find.text('A'), findsOneWidget);
      expect(
          tester.getSize(find.byType(Ios27CircleButton)), const Size(60, 60));
    });
  });

  group('фон', () {
    testWidgets('рисуется на весь родитель и не заводит анимаций в покое', (
      tester,
    ) async {
      final colors = _colors(0, Brightness.dark);
      await _prewarm(tester, colors, Ios27BackdropState.off);
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.dark,
          theme: _theme(0),
          child: const Ios27Backdrop(state: Ios27BackdropState.off),
        ),
      );
      await _settleBackdrop(tester);
      expect(tester.getSize(find.byType(Ios27Backdrop)), const Size(411, 914));
      // На доске цикла в покое нет (bg.js): никаких бесконечных анимаций.
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets(
        'запасной путь: переход off→on — один кадр без смешения и без тикеров',
        (tester) async {
      final colors = _colors(0, Brightness.light);
      await _prewarm(tester, colors, Ios27BackdropState.off);
      final adv = ios27BackdropAdvance(t: kIos27BackdropT0, from: 0, to: 1);
      await _prewarm(tester, colors, Ios27BackdropState.on, t: adv.t);
      var state = Ios27BackdropState.off;
      late StateSetter set;
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          theme: _theme(0),
          child: StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return Ios27Backdrop(state: state);
            },
          ),
        ),
      );
      await _settleBackdrop(tester);
      set(() => state = Ios27BackdropState.on);
      await tester.pump();
      await _settleBackdrop(tester);
      // CPU-порт не умеет двигаться: нового кадра ждёт одна картинка, тикеров нет
      // (смешение двух кадров давало «призраки» листов, G6).
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 0);
      expect(adv.seconds, inInclusiveRange(0.5, 2.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reduce Motion: смена мгновенна, тикеров нет', (tester) async {
      final colors = _colors(0, Brightness.light);
      await _prewarm(tester, colors, Ios27BackdropState.off);
      await _prewarm(tester, colors, Ios27BackdropState.on);
      var state = Ios27BackdropState.off;
      late StateSetter set;
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          theme: _theme(0),
          disableAnimations: true,
          child: StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return Ios27Backdrop(state: state);
            },
          ),
        ),
      );
      await _settleBackdrop(tester);
      set(() => state = Ios27BackdropState.on);
      await tester.pump();
      await _settleBackdrop(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, 0);
    });

    // Быстрая смена состояния: картинки кэша не должны освобождаться дважды
    // (было: «ассерт на уже закрытой картинке», проба G9 на 200 мс, когда ещё был кроссфейд).
    for (final gapMs in [200, 500, 800, 1500]) {
      testWidgets('off→connecting→on с паузой $gapMs мс: без ассертов',
          (tester) async {
        final colors = _colors(0, Brightness.light);
        final a = ios27BackdropAdvance(t: kIos27BackdropT0, from: 0, to: .5);
        final b = ios27BackdropAdvance(t: a.t, from: .5, to: 1);
        await _prewarm(tester, colors, Ios27BackdropState.off);
        await _prewarm(tester, colors, Ios27BackdropState.connecting, t: a.t);
        await _prewarm(tester, colors, Ios27BackdropState.on, t: b.t);
        var state = Ios27BackdropState.off;
        late StateSetter set;
        try {
          await pumpIos27Board(
            tester,
            ios27BoardApp(
              brightness: Brightness.light,
              theme: _theme(0),
              child: StatefulBuilder(
                builder: (context, setState) {
                  set = setState;
                  return Ios27Backdrop(state: state);
                },
              ),
            ),
          );
          await _settleBackdrop(tester);

          set(() => state = Ios27BackdropState.connecting);
          await tester.pump();
          await _settleBackdrop(tester);
          await tester.pump(Duration(milliseconds: gapMs));
          set(() => state = Ios27BackdropState.on);
          await tester.pump();
          await _settleBackdrop(tester);
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);

          // Запасной путь не заводит кадров вовсе.
          await tester.pump(const Duration(seconds: 4));
          expect(tester.takeException(), isNull);
          expect(tester.binding.transientCallbackCount, 0);

          // Снятие после перехода не освобождает ничего второй раз.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }

    testWidgets('dispose посреди перехода не бросает', (tester) async {
      final colors = _colors(0, Brightness.light);
      await _prewarm(tester, colors, Ios27BackdropState.off);
      final adv = ios27BackdropAdvance(t: kIos27BackdropT0, from: 0, to: 1);
      await _prewarm(tester, colors, Ios27BackdropState.on, t: adv.t);
      var state = Ios27BackdropState.off;
      late StateSetter set;
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          theme: _theme(0),
          child: StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return Ios27Backdrop(state: state);
            },
          ),
        ),
      );
      await _settleBackdrop(tester);
      set(() => state = Ios27BackdropState.on);
      await tester.pump();
      await _settleBackdrop(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });

    test('время шейдера идёт быстрее при переходе (bg.js:139-150)', () {
      final adv = ios27BackdropAdvance(t: 58, from: 0, to: 1);
      expect(adv.t, greaterThan(58));
      final still = ios27BackdropAdvance(t: 58, from: 1, to: 1);
      expect(still.t, 58);
      expect(still.seconds, 0);
    });

    test('CPU-кадр фона: размер и непрозрачность', () {
      final colors = _colors(0, Brightness.dark);
      final px = renderIos27BackdropPixels(
        Ios27BackdropSpec.fromColors(colors, on: 1),
      );
      expect(px.length, kIos27BackdropWidth * kIos27BackdropHeight * 4);
      expect(px[3], 255);
    });
  });
}

/// Счётчик кадров, которые просит приложение. Спиннер и пульс `busy` теперь шагают `Timer`-ом
/// (`Ios27SteppedClock`), поэтому `transientCallbackCount` у них всегда 0 и «живость» видна только
/// по запрошенным кадрам. Persistent-колбэк снять нельзя: он один на процесс и включается флагом.
class _FrameMeter {
  bool on = false;
  int frames = 0;
}

final _FrameMeter _meter = _FrameMeter();
bool _meterHooked = false;

/// Сколько кадров просили за [ms] модельных миллисекунд (шаг 16 мс).
Future<int> _framesOver(WidgetTester tester, int ms) async {
  if (!_meterHooked) {
    _meterHooked = true;
    tester.binding.addPersistentFrameCallback((_) {
      if (_meter.on) {
        _meter.frames++;
      }
    });
  }
  _meter
    ..frames = 0
    ..on = true;
  try {
    for (var i = 0; i < ms ~/ 16; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  } finally {
    _meter.on = false;
  }
  return _meter.frames;
}
