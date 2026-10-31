// Масштаб текста внутри iOS-поддерева: системный Dynamic Type в пределах 0.8–2.0 (решение Q2).
//
// Настройка «Размер текста» приложения (ThemeManager, у владельца сохранено 1.4) на iOS-интерфейс
// не действует: скоуп читает платформу напрямую, мимо предка.

import 'dart:async';

import 'package:dropweb/ui/ios27/layers/ios27_alert.dart';
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/pages/ios27_page.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text_scale.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden.dart';
import 'support/layer_harness.dart';

/// Системный коэффициент от платформы теста; сбрасывается по завершении теста.
void _platformScale(WidgetTester tester, double factor) {
  tester.platformDispatcher.textScaleFactorTestValue = factor;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Свидетель: пишет масштаб, который видит на своём месте, и считает перестроения.
class _Seen {
  TextScaler scaler = TextScaler.noScaling;
  int builds = 0;

  /// Во сколько раз масштаб увеличивает шрифт в 100 пунктов. Сравнение по значению, а не по
  /// `==` с `TextScaler.linear`: платформенный масштабировщик нелинейный и обёрнут зажимом.
  double get factor => scaler.scale(100) / 100;

  Widget probe() => Builder(
        builder: (context) {
          builds++;
          scaler = MediaQuery.textScalerOf(context);
          return const SizedBox.shrink();
        },
      );
}

/// Приложение с «ThemeManager»: предок задаёт свой масштаб, как делает корень приложения.
Widget _app({
  required Widget Function(BuildContext context) home,
  double? ancestor,
  List<Override> overrides = const [],
}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        builder: ancestor == null
            ? null
            : (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(ancestor)),
                  child: child!,
                ),
        home: Builder(builder: home),
      ),
    );

Widget _explicit(Widget child) => Ios27ThemeScope.explicit(
      theme: Ios27ProviderTheme.defaults,
      child: child,
    );

/// Контекст корневого навигатора: выше любой области темы.
BuildContext _root(WidgetTester tester) =>
    tester.element(find.byType(Navigator).first);

void main() {
  tearDown(Ios27SystemTextScale.debugReset);

  group('границы', () {
    test('диапазон 0.8–2.0', () {
      expect(Ios27SystemTextScale.min, 0.8);
      expect(Ios27SystemTextScale.max, 2.0);
    });

    test('clamp зажимает итог, внутри диапазона не трогает', () {
      double at(TextScaler s) => s.scale(10);
      expect(at(Ios27SystemTextScale.clamp(const TextScaler.linear(0.1))),
          closeTo(8, 1e-9));
      expect(at(Ios27SystemTextScale.clamp(const TextScaler.linear(0.8))),
          closeTo(8, 1e-9));
      expect(at(Ios27SystemTextScale.clamp(TextScaler.noScaling)),
          closeTo(10, 1e-9));
      expect(at(Ios27SystemTextScale.clamp(const TextScaler.linear(1.4))),
          closeTo(14, 1e-9));
      expect(at(Ios27SystemTextScale.clamp(const TextScaler.linear(2.0))),
          closeTo(20, 1e-9));
      expect(at(Ios27SystemTextScale.clamp(const TextScaler.linear(5))),
          closeTo(20, 1e-9));
    });
  });

  group('системное значение вместо предка', () {
    testWidgets('предок 1.4 (ThemeManager), система 1.0: внутри скоупа 1.0',
        (tester) async {
      final inside = _Seen();
      late TextScaler outside;
      await tester.pumpWidget(
        _app(
          ancestor: 1.4,
          home: (context) {
            outside = MediaQuery.textScalerOf(context);
            return _explicit(inside.probe());
          },
        ),
      );
      // Контроль: снаружи предок действительно отдаёт 1.4, иначе тест ничего не доказывает.
      expect(outside.scale(100), closeTo(140, 1e-9));
      expect(inside.factor, closeTo(1.0, 1e-9));
    });

    testWidgets('предок 1.0, система 1.3: внутри 1.3 (предок не нужен)',
        (tester) async {
      _platformScale(tester, 1.3);
      final inside = _Seen();
      await tester.pumpWidget(
        _app(ancestor: 1.0, home: (_) => _explicit(inside.probe())),
      );
      expect(inside.factor, closeTo(1.3, 1e-9));
    });

    const cases = <(double, double)>[
      (0.5, 0.8),
      (0.8, 0.8),
      (1.0, 1.0),
      (1.3, 1.3),
      (2.0, 2.0),
      (2.5, 2.0),
      (3.5, 2.0),
    ];
    for (final (system, expected) in cases) {
      testWidgets('система $system → внутри $expected (предок 1.4)',
          (tester) async {
        _platformScale(tester, system);
        final inside = _Seen();
        await tester.pumpWidget(
          _app(ancestor: 1.4, home: (_) => _explicit(inside.probe())),
        );
        expect(inside.factor, closeTo(expected, 1e-9));
      });
    }

    testWidgets('основной конструктор (из провайдера) ведёт себя так же',
        (tester) async {
      _platformScale(tester, 2.5);
      final inside = _Seen();
      await tester.pumpWidget(
        _app(
          ancestor: 1.4,
          overrides: layerOverrides(),
          home: (_) => Ios27ThemeScope(child: inside.probe()),
        ),
      );
      expect(inside.factor, closeTo(2.0, 1e-9));
    });

    testWidgets('реальный Text: ширина по системному, а не по ThemeManager',
        (tester) async {
      const style = TextStyle(fontSize: 10, fontFamily: 'Ahem');
      const key = ValueKey<String>('probe-text');
      await tester.pumpWidget(
        _app(
          ancestor: 1.4,
          home: (_) => _explicit(const Align(
            alignment: Alignment.topLeft,
            child: Text('A', key: key, style: style),
          )),
        ),
      );
      // Ahem: глиф квадратный, ширина равна кеглю. Допуск 1e-2: на Linux раскладка текста
      // даёт 9.99998 вместо 10 (шум float32, 1.5e-5), на macOS ровно 10; масштаб 1.4
      // от этого отличается на 4 пикселя, а не на сотые.
      expect(tester.getSize(find.byKey(key)).width, closeTo(10, 1e-2));

      _platformScale(tester, 2.0);
      await tester.pump();
      // Тот же допуск: 19.99998 на Linux против 20 на macOS.
      expect(tester.getSize(find.byKey(key)).width, closeTo(20, 1e-2));
    });
  });

  group('смена на лету', () {
    testWidgets('системный размер меняется при запущенном приложении',
        (tester) async {
      final inside = _Seen();
      await tester.pumpWidget(
        _app(ancestor: 1.4, home: (_) => _explicit(inside.probe())),
      );
      expect(inside.factor, closeTo(1.0, 1e-9));
      final before = inside.builds;

      _platformScale(tester, 1.6);
      await tester.pump();
      expect(inside.factor, closeTo(1.6, 1e-9));
      expect(inside.builds, greaterThan(before));

      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      await tester.pump();
      expect(inside.factor, closeTo(2.0, 1e-9));

      tester.platformDispatcher.textScaleFactorTestValue = 0.4;
      await tester.pump();
      expect(inside.factor, closeTo(0.8, 1e-9));
    });

    testWidgets('несвязанное изменение MediaQuery свидетеля не будит',
        (tester) async {
      final inside = _Seen();
      final bottom = ValueNotifier<double>(0);
      addTearDown(bottom.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => ValueListenableBuilder<double>(
              valueListenable: bottom,
              builder: (context, inset, _) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(viewInsets: EdgeInsets.only(bottom: inset)),
                child: child!,
              ),
            ),
            home: _explicit(inside.probe()),
          ),
        ),
      );
      final before = inside.builds;
      bottom.value = 300;
      await tester.pump();
      // Свидетель читает только textScaler: клавиатура его не перестраивает.
      expect(inside.builds, before);
    });
  });

  group('что скоуп не отбирает', () {
    testWidgets('MediaQuery.withNoTextScaling ниже скоупа побеждает',
        (tester) async {
      _platformScale(tester, 2.0);
      final inside = _Seen();
      await tester.pumpWidget(
        _app(
          ancestor: 1.4,
          home: (_) => _explicit(
            Builder(
              builder: (context) => MediaQuery.withNoTextScaling(
                child: inside.probe(),
              ),
            ),
          ),
        ),
      );
      expect(inside.scaler, TextScaler.noScaling);
      expect(inside.factor, 1.0);
    });

    testWidgets('вложенные скоупы не умножают масштаб', (tester) async {
      _platformScale(tester, 3.0);
      final inside = _Seen();
      await tester.pumpWidget(
        _app(
          ancestor: 1.4,
          home: (_) => _explicit(_explicit(inside.probe())),
        ),
      );
      expect(inside.factor, closeTo(2.0, 1e-9));
    });

    testWidgets('остальные поля MediaQuery берутся у предка', (tester) async {
      late MediaQueryData seen;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                boldText: true,
                padding: const EdgeInsets.only(top: 48, bottom: 52),
              ),
              child: child!,
            ),
            home: _explicit(
              Builder(
                builder: (context) {
                  seen = MediaQuery.of(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(seen.boldText, isTrue);
      expect(seen.padding, const EdgeInsets.only(top: 48, bottom: 52));
    });
  });

  group('подмена для тестов', () {
    testWidgets('debugOverride задаёт системное значение, reset снимает',
        (tester) async {
      final inside = _Seen();
      Ios27SystemTextScale.debugOverride = 1.7;
      await tester.pumpWidget(
        _app(ancestor: 1.4, home: (_) => _explicit(inside.probe())),
      );
      expect(inside.factor, closeTo(1.7, 1e-9));

      // Подмена заменяет платформу и зажимается тем же диапазоном.
      Ios27SystemTextScale.debugOverride = 5;
      await tester.pump();
      expect(inside.factor, closeTo(2.0, 1e-9));

      Ios27SystemTextScale.debugOverride = 0.5;
      await tester.pump();
      expect(inside.factor, closeTo(0.8, 1e-9));

      Ios27SystemTextScale.debugReset();
      await tester.pump();
      expect(Ios27SystemTextScale.debugOverride, isNull);
      expect(inside.factor, closeTo(1.0, 1e-9));
    });

    testWidgets('подмена посреди кадра не падает', (tester) async {
      final inside = _Seen();
      await tester.pumpWidget(
        _app(
          ancestor: 1.0,
          home: (_) => _explicit(
            Builder(
              builder: (context) {
                // Сборка тела теста меняет подмену во время кадра: setState в скоупе недопустим.
                Ios27SystemTextScale.debugOverride ??= 1.5;
                return inside.probe();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(inside.factor, closeTo(1.5, 1e-9));
    });
  });

  group('harness ios27BoardApp', () {
    for (final scale in [0.8, 1.0, 1.4, 2.0]) {
      testWidgets('textScale $scale управляет масштабом внутри кадра',
          (tester) async {
        final inside = _Seen();
        await pumpIos27Board(
          tester,
          ios27BoardApp(
            brightness: Brightness.light,
            textScale: scale,
            child: inside.probe(),
          ),
        );
        expect(inside.factor, closeTo(scale, 1e-9));
      });
    }

    testWidgets('предыдущий тест подмену не оставил', (tester) async {
      expect(Ios27SystemTextScale.debugOverride, isNull);
    });
  });

  // Лист, алерт и страница открываются маршрутом с корневого навигатора. Их `MediaQuery` копируется
  // НИЖЕ `Ios27ThemeScope`: копия из контекста маршрута вернула бы масштаб предка (ThemeManager, 1.4)
  // поверх системного.
  group('слои из корневого навигатора', () {
    // Предок несёт 1.4 (как ThemeManager), система 1.0: снимаем подмену harness-а.
    Future<_Seen> openSheet(WidgetTester tester) async {
      final inside = _Seen();
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          textScale: 1.4,
          overrides: layerOverrides(),
          child: const SizedBox.expand(),
        ),
      );
      Ios27SystemTextScale.debugOverride = 1.0;
      await tester.pump();
      unawaited(showIos27Sheet<void>(
        _root(tester),
        title: 'Маршрут',
        builder: (_) => inside.probe(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      return inside;
    }

    Future<_Seen> openAlert(WidgetTester tester) async {
      final inside = _Seen();
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          textScale: 1.4,
          overrides: layerOverrides(),
          child: const SizedBox.expand(),
        ),
      );
      Ios27SystemTextScale.debugOverride = 1.0;
      await tester.pump();
      unawaited(showIos27Alert<void>(
        _root(tester),
        builder: (_) => inside.probe(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      return inside;
    }

    Future<_Seen> openPage(WidgetTester tester) async {
      final inside = _Seen();
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          textScale: 1.4,
          overrides: layerOverrides(),
          child: const SizedBox.expand(),
        ),
      );
      Ios27SystemTextScale.debugOverride = 1.0;
      await tester.pump();
      unawaited(pushIos27Page<void>(
        _root(tester),
        title: 'Страница',
        builder: (_) => inside.probe(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      return inside;
    }

    testWidgets('лист: системный масштаб, а не ThemeManager', (tester) async {
      final inside = await openSheet(tester);
      expect(inside.factor, closeTo(1.0, 1e-9));
    });

    testWidgets('алерт: системный масштаб, а не ThemeManager', (tester) async {
      final inside = await openAlert(tester);
      expect(inside.factor, closeTo(1.0, 1e-9));
    });

    testWidgets('страница: системный масштаб, а не ThemeManager',
        (tester) async {
      final inside = await openPage(tester);
      expect(inside.factor, closeTo(1.0, 1e-9));
    });

    testWidgets(
        'форма правки слоёв: копия MediaQuery из контекста внутри скоупа '
        'сохраняет системный масштаб', (tester) async {
      final inside = _Seen();
      late bool reduced;
      await tester.pumpWidget(
        _app(
          ancestor: 1.4,
          home: (_) => _explicit(
            // Так слой должен собирать содержимое: Builder даёт контекст ниже скоупа.
            Builder(
              builder: (scopeContext) => MediaQuery(
                data: MediaQuery.of(scopeContext)
                    .copyWith(disableAnimations: true),
                child: Builder(
                  builder: (context) {
                    reduced = MediaQuery.disableAnimationsOf(context);
                    return inside.probe();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(reduced, isTrue);
      expect(inside.factor, closeTo(1.0, 1e-9));
    });
  });
}
