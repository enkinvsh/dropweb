import 'dart:convert';
import 'dart:io';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/symbols.g.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/theme/tokens.g.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_round_button.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_symbol.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

const _toastKey = ValueKey<String>('m3e.toast');
const _textKey = ValueKey<String>('m3e.toast.text');
const _fadeKey = ValueKey<String>('m3e.toast.fade');
const _motionKey = ValueKey<String>('m3e.toast.motion');
const _navKey = ValueKey<String>('m3e.navBtn');

const _portText = 'Порт уже занят другим приложением. Перезапустите VPN.';
final String _hugeText =
    List.filled(6, 'Сервер провайдера не отвечает, проверьте подключение.')
        .join(' ');

/// Слот на экране шириной [width] с кнопкой настроек на месте доски (справа 16, top 48)
/// и textScaler [scale]; опционально карточка под слотом (top = safe.top + 64).
Widget _slotScene({
  required String text,
  M3eToastKind? kind,
  double width = 411,
  double scale = 1,
  bool card = false,
}) =>
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: Size(width, 914),
          textScaler: TextScaler.linear(scale),
        ),
        child: ColoredBox(
          color: M3eColors.of(context).home.bg,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 914,
              child: Stack(
                children: [
                  if (card)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 108,
                      height: 189,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: M3eColors.of(context).home.card,
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 16,
                    top: 48,
                    child: M3eTonalIconButton(
                      key: _navKey,
                      size: 44,
                      icon: const M3eSymbolIcon(M3eSymbol.settings),
                      semanticLabel: 'Открыть настройки',
                      onPressed: () {},
                    ),
                  ),
                  Positioned.fill(
                    child: M3eToastPresenter(
                      message: M3eToastMessage(kind: kind, text: text),
                      hold: null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

const _longText =
    'Не удалось обновить подписку: сервер провайдера не отвечает, проверьте '
    'подключение к сети и повторите попытку чуть позже';

/// Фон кадра `home.bg` и презентер на весь экран. Сообщение строится из l10n внутри дерева.
Widget _scene({
  required M3eToastMessage? Function(AppLocalizations l10n) message,
  Duration? hold,
  ValueChanged<M3eToastMessage>? onDismissed,
  bool reduceMotion = false,
}) =>
    Builder(
      builder: (context) {
        Widget child = Stack(
          children: [
            Positioned.fill(
              child: M3eToastPresenter(
                message: message(AppLocalizations.of(context)),
                hold: hold,
                onDismissed: onDismissed,
              ),
            ),
          ],
        );
        if (reduceMotion) {
          child = MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child,
          );
        }
        return ColoredBox(color: M3eColors.of(context).home.bg, child: child);
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

/// Первый кадр после запуска анимации только заводит тикер, время идёт со второго.
Future<void> _settle(WidgetTester tester, [int ms = 700]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

double _opacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.byKey(_fadeKey)).opacity;

Rect _ref(String scene, String key) {
  final all = jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
      as Map<String, dynamic>;
  final elements =
      (all[scene] as Map<String, dynamic>)['elements'] as Map<String, dynamic>;
  final m = elements[key] as Map<String, dynamic>;
  return Rect.fromLTWH(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['w'] as num).toDouble(),
    (m['h'] as num).toDouble(),
  );
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
  group('golden', () {
    for (final (name, brightness) in [
      ('light', Brightness.light),
      ('dark', Brightness.dark),
    ]) {
      for (final p in [0, 5]) {
        testWidgets('toast_support_${name}_p$p', (tester) async {
          await _pump(
            tester,
            _scene(
              message: (l10n) => M3eToastMessage(
                // На доске support = ['out', ...].
                kind: M3eToastKind.out,
                text: l10n.m3eToastSupport,
              ),
            ),
            provider: p,
            brightness: brightness,
            shadows: true,
          );
          await _settle(tester);
          await _golden(tester, 'toast_support_${name}_p$p');
        });
      }
    }

    // Без значка: сообщения без типа, пока владелец не выбрал значки.
    for (final (name, brightness, p) in [
      ('light_p0', Brightness.light, 0),
      ('dark_p5', Brightness.dark, 5),
    ]) {
      testWidgets('toast_plain_$name', (tester) async {
        await _pump(
          tester,
          _scene(
            message: (_) => const M3eToastMessage(text: 'Подписка обновлена'),
          ),
          provider: p,
          brightness: brightness,
          shadows: true,
        );
        await _settle(tester);
        await _golden(tester, 'toast_plain_$name');
      });
    }

    testWidgets('toast_long_light_p0', (tester) async {
      await _pump(
        tester,
        _scene(
          message: (_) => const M3eToastMessage(
            kind: M3eToastKind.alert,
            text: _longText,
          ),
        ),
        shadows: true,
      );
      await _settle(tester);
      await _golden(tester, 'toast_long_light_p0');
    });

    // Замечание владельца с Pixel 10: textScaler 1.15, порт занят. Пузырь обязан лечь
    // в полосу над карточкой и не задеть кнопку настроек.
    testWidgets('toast_slot_long_light_p0', (tester) async {
      await _pump(
        tester,
        _slotScene(
            text: _portText, kind: M3eToastKind.alert, scale: 1.15, card: true),
        shadows: true,
      );
      await _settle(tester);
      await _golden(tester, 'toast_slot_long_light_p0');
    });

    testWidgets('toast_slot_huge_dark_p0', (tester) async {
      await _pump(
        tester,
        _slotScene(text: _hugeText, kind: M3eToastKind.alert, card: true),
        brightness: Brightness.dark,
        shadows: true,
      );
      await _settle(tester);
      await _golden(tester, 'toast_slot_huge_dark_p0');
    });
  });

  group('слот', () {
    // Полоса под строкой состояния: safe.top 44, карточка начинается на safe.top + 64.
    const safeTop = 44.0;
    for (final width in [320.0, 411.0, 600.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final (label, text) in [
          ('короткий', 'Готово'),
          ('порт', _portText),
          ('огромный', _hugeText),
        ]) {
          testWidgets('$label, ширина ${width.toInt()}, textScaler $scale',
              (tester) async {
            await _pump(
              tester,
              _slotScene(
                text: text,
                kind: M3eToastKind.alert,
                width: width,
                scale: scale,
              ),
            );
            // Окно доски 411 dp; другие ширины задаём размером окна (сброс в tearDown
            // делает setM3eBoardSurface).
            tester.view.physicalSize = Size(width * 2, 914 * 2);
            await _settle(tester);
            final plate = tester.getRect(find.byKey(_toastKey));
            final nav = tester.getRect(find.byKey(_navKey));
            expect(plate.top, closeTo(safeTop + kM3eToastTopGap, 0.01));
            // Решение владельца 2026-10-29: центр плашки на линии кнопки настроек.
            expect(plate.center.dy, closeTo(nav.center.dy, 0.01));
            expect(plate.height, closeTo(48, 0.01));
            expect(plate.bottom, lessThanOrEqualTo(safeTop + 64 + 0.01));
            expect(plate.width, lessThanOrEqualTo(360.01));
            // Слева «Назад» 40 dp с полем 16 и зазором 8.
            expect(plate.left, greaterThanOrEqualTo(16 + 40 + 8 - 0.01));
            expect(plate.overlaps(nav), isFalse, reason: '$plate vs $nav');
            expect(plate.center.dx, closeTo(width / 2, 0.01));
            // Текст внутри капсулы, а не за её краем.
            final textRect = tester.getRect(find.byKey(_textKey));
            expect(textRect.left, greaterThanOrEqualTo(plate.left));
            expect(textRect.right, lessThanOrEqualTo(plate.right));
            expect(textRect.top, greaterThanOrEqualTo(plate.top));
            expect(textRect.bottom, lessThanOrEqualTo(plate.bottom));
          });
        }
      }
    }

    testWidgets('больше двух строк — многоточие, полный текст в Semantics',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _slotScene(text: _hugeText));
      await _settle(tester);
      final text = tester.widget<Text>(find.byKey(_textKey));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.getSemantics(find.byKey(_textKey)).label, _hugeText);
      semantics.dispose();
    });

    testWidgets('textScaler не масштабирует текст и значок плашки',
        (tester) async {
      await _pump(tester, _slotScene(text: 'Готово', kind: M3eToastKind.check));
      await _settle(tester);
      final normal = tester.getSize(find.byKey(_textKey));
      await _pump(
        tester,
        _slotScene(text: 'Готово', kind: M3eToastKind.check, scale: 2),
      );
      await _settle(tester);
      expect(tester.getSize(find.byKey(_textKey)), normal);
      expect(
        tester.getSize(find.byType(M3eSymbolIcon).last),
        const Size(20, 20),
      );
    });

    testWidgets('max-width слота: min(360, ширина − 136)', (tester) async {
      expect(m3eToastMaxWidthFor(320), 184);
      expect(m3eToastMaxWidthFor(411), 275);
      expect(m3eToastMaxWidthFor(600), 360);
      expect(m3eToastMaxWidthFor(100), 0);
    });
  });

  group('жизненный цикл', () {
    testWidgets(
        'снятие презентера, который ни разу не показывал плашку, не падает',
        (tester) async {
      await _pump(
        tester,
        const Stack(
          children: [Positioned.fill(child: M3eToastPresenter(message: null))],
        ),
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });

  group('плашка', () {
    testWidgets('все четыре значка, ширина до 360, высота ровно 48',
        (tester) async {
      await _pump(
        tester,
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final kind in M3eToastKind.values)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: M3eToast(kind: kind, text: kind.name),
                ),
              const M3eToast(kind: M3eToastKind.out, text: _longText),
            ],
          ),
        ),
      );
      final plates = tester.widgetList(find.byKey(_toastKey)).length;
      expect(plates, 5);
      final long = tester.getSize(find.byKey(_toastKey).last);
      expect(long.width, 360);
      // Слот фиксированной высоты: длинный текст не растит плашку, а обрезается.
      expect(long.height, 48);
      final short = tester.getSize(find.byKey(_toastKey).first);
      expect(short.height, 48);
      expect(short.width, lessThan(360));
    });

    testWidgets('без значка: нет значка, отступы по 20 с обеих сторон',
        (tester) async {
      await _pump(
        tester,
        const Center(child: M3eToast(text: 'Подписка обновлена')),
      );
      expect(find.byType(M3eSymbolIcon), findsNothing);
      final plate = tester.getRect(find.byKey(_toastKey));
      final text = tester.getRect(find.byKey(_textKey));
      expect(text.left - plate.left, closeTo(20, 0.01));
      expect(plate.right - text.right, closeTo(20, 0.01));
      expect(plate.height, 48);
    });

    testWidgets('слово длиннее строки переносится, не вылезая за 360',
        (tester) async {
      await _pump(
        tester,
        Center(
          child: M3eToast(
            kind: M3eToastKind.out,
            text: 'https://${'очень-длинная-ссылка' * 8}',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
          tester.getSize(find.byKey(_toastKey)).width, lessThanOrEqualTo(360));
    });

    testWidgets('цвета: surfaceContainerHigh, значок по виду, elevation level3',
        (tester) async {
      await _pump(
        tester,
        const Center(
          child: M3eToast(kind: M3eToastKind.check, text: 'ok'),
        ),
      );
      final colors = M3eColors.of(tester.element(find.byKey(_toastKey)));
      final material = tester.widget<Material>(find.byKey(_toastKey));
      expect(material.color, colors.scheme.surfaceContainerHigh);
      expect(material.elevation, M3eElevation.level3);
      expect(material.shape, isA<StadiumBorder>());
    });

    testWidgets('семантика: живая область с текстом, значок не читается',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const Center(
          child: M3eToast(kind: M3eToastKind.check, text: 'Подписка обновлена'),
        ),
      );
      final node = tester.getSemantics(find.byKey(_textKey));
      expect(node.label, 'Подписка обновлена');
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      semantics.dispose();
    });
  });

  group('презентер', () {
    testWidgets(
        'вход пружиной: через ~400 мс плашка на месте и видна полностью',
        (tester) async {
      await _pump(
        tester,
        _scene(
          message: (_) =>
              const M3eToastMessage(kind: M3eToastKind.out, text: 'a'),
        ),
      );
      // Сразу после монтирования плашки ещё нет на экране.
      expect(_opacity(tester), 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final mid = _opacity(tester);
      expect(mid, inExclusiveRange(0, 1));
      // Начало пути: смещена вверх и уменьшена относительно итогового положения.
      expect(tester.getRect(find.byKey(_toastKey)).top,
          lessThan(44 + kM3eToastTopGap));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_opacity(tester), 1);
      expect(tester.getRect(find.byKey(_toastKey)).top,
          closeTo(44 + kM3eToastTopGap, 0.5));
      expect(find.byKey(_motionKey), findsOneWidget);
    });

    testWidgets('выход 200 мс: message == null убирает плашку и все тикеры',
        (tester) async {
      final message = ValueNotifier<M3eToastMessage?>(
        const M3eToastMessage(kind: M3eToastKind.out, text: 'a'),
      );
      await _pump(
        tester,
        ValueListenableBuilder<M3eToastMessage?>(
          valueListenable: message,
          builder: (_, m, __) => _scene(message: (_) => m),
        ),
      );
      await _settle(tester);
      expect(_opacity(tester), 1);

      message.value = null;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // На середине выхода плашка уже прозрачнее, но ещё есть.
      expect(find.byKey(_toastKey), findsOneWidget);
      expect(_opacity(tester), lessThan(1));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byKey(_toastKey), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('держится 2200 мс, затем зовёт onDismissed и уходит',
        (tester) async {
      final dismissed = <String>[];
      await _pump(
        tester,
        _scene(
          message: (_) =>
              const M3eToastMessage(kind: M3eToastKind.check, text: 'ok'),
          hold: kM3eToastHold,
          onDismissed: (m) => dismissed.add(m.text),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2100));
      expect(dismissed, isEmpty);
      expect(find.byKey(_toastKey), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));
      expect(dismissed, ['ok']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(_toastKey), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('top = строка состояния + 2 (линия кнопки настроек), по центру',
        (tester) async {
      await _pump(
        tester,
        _scene(
          message: (_) =>
              const M3eToastMessage(kind: M3eToastKind.out, text: 'abc'),
        ),
      );
      await _settle(tester);
      final rect = tester.getRect(find.byKey(_toastKey));
      expect(rect.top, closeTo(44 + 4 + (44 - 48) / 2, 0.01));
      expect(rect.center.dx, closeTo(411 / 2, 0.01));
    });

    testWidgets('новое сообщение заменяет текст и играет вход заново',
        (tester) async {
      final message = ValueNotifier<M3eToastMessage>(
        const M3eToastMessage(kind: M3eToastKind.out, text: 'первое'),
      );
      await _pump(
        tester,
        ValueListenableBuilder<M3eToastMessage>(
          valueListenable: message,
          builder: (_, m, __) => _scene(message: (_) => m),
        ),
      );
      await _settle(tester);
      expect(find.text('первое'), findsOneWidget);
      message.value =
          const M3eToastMessage(kind: M3eToastKind.alert, text: 'второе');
      await tester.pump();
      expect(find.text('первое'), findsNothing);
      expect(find.text('второе'), findsOneWidget);
      expect(_opacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_opacity(tester), 1);
    });

    testWidgets('плашка не перехватывает касания', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 44,
              height: 80,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
              ),
            ),
            const Positioned.fill(
              child: M3eToastPresenter(
                message: M3eToastMessage(kind: M3eToastKind.out, text: 'x'),
                hold: null,
              ),
            ),
          ],
        ),
      );
      await _settle(tester);
      await tester.tapAt(const Offset(205, 76));
      expect(taps, 1);
    });

    group('при отключённых анимациях', () {
      testWidgets('вход: только прозрачность за 150 мс, без сдвига и масштаба',
          (tester) async {
        await _pump(
          tester,
          _scene(
            reduceMotion: true,
            message: (_) =>
                const M3eToastMessage(kind: M3eToastKind.out, text: 'a'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 75));
        expect(_opacity(tester), closeTo(0.5, 0.01));
        // Положение финальное с первого кадра, трансформации нет совсем.
        expect(
          tester.getRect(find.byKey(_toastKey)).top,
          closeTo(44 + kM3eToastTopGap, 0.01),
        );
        expect(find.byKey(_motionKey), findsNothing);
        await tester.pump(const Duration(milliseconds: 80));
        expect(_opacity(tester), 1);
        expect(tester.binding.transientCallbackCount, 0);
      });

      testWidgets('выход: затухание 150 мс', (tester) async {
        final message = ValueNotifier<M3eToastMessage?>(
          const M3eToastMessage(kind: M3eToastKind.out, text: 'a'),
        );
        await _pump(
          tester,
          ValueListenableBuilder<M3eToastMessage?>(
            valueListenable: message,
            builder: (_, m, __) =>
                _scene(reduceMotion: true, message: (_) => m),
          ),
        );
        await _settle(tester, 300);
        message.value = null;
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 75));
        expect(_opacity(tester), closeTo(0.5, 0.01));
        expect(find.byKey(_motionKey), findsNothing);
        await tester.pump(const Duration(milliseconds: 80));
        expect(find.byKey(_toastKey), findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
      });
    });
  });

  group('паритет с layout.json (±4 dp)', () {
    for (final scene in ['support-light-p0', 'support-dark-p5']) {
      testWidgets(scene, (tester) async {
        await _pump(
          tester,
          _scene(
            message: (l10n) => M3eToastMessage(
              kind: M3eToastKind.out,
              text: l10n.m3eToastSupport,
            ),
          ),
          provider: scene.endsWith('p5') ? 5 : 0,
          brightness:
              scene.contains('dark') ? Brightness.dark : Brightness.light,
        );
        await _settle(tester);
        void near(Rect a, Rect e, String what) {
          expect((a.left - e.left).abs(), lessThanOrEqualTo(4),
              reason: '$what $a vs $e');
          expect((a.top - e.top).abs(), lessThanOrEqualTo(4),
              reason: '$what $a vs $e');
          expect((a.width - e.width).abs(), lessThanOrEqualTo(4),
              reason: '$what $a vs $e');
          expect((a.height - e.height).abs(), lessThanOrEqualTo(4),
              reason: '$what $a vs $e');
        }

        // Решение владельца 2026-10-29: центр тоста на уровне кнопки настроек, доска
        // ставит его ниже на 6 dp (y 52 против 46). Допуск ±4 остаётся прежним, сдвиг
        // вычитается явно, а не поглощается допуском.
        const ownerShift = 52 - (44 + kM3eToastTopGap);
        near(tester.getRect(find.byKey(_toastKey)),
            _ref(scene, 'toast').shift(const Offset(0, -ownerShift)), 'toast');
        near(
            tester.getRect(find.byKey(_textKey)),
            _ref(scene, 'toast.text').shift(const Offset(0, -ownerShift)),
            'toast.text');
      });
    }
  });
}
