// Кнопка-капсула iOS 27 (Ios27Button): сверка с экраном «Нет подписки» доски, нажатие, отключённое состояние,
// семантика, Reduce Motion / Reduce Transparency, масштаб шрифта, голдены prim_button_*.

import 'dart:ui' show Tristate;

import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/board_providers.dart';
import 'support/golden.dart';
import 'support/layout.dart';
import 'support/surface.dart';

Ios27ProviderTheme _theme(int i) =>
    Ios27ProviderTheme.fromHeader(kBoardProviders[i].theme);

/// Окно доски со светлой темой по умолчанию.
Widget _app({
  required Widget child,
  Brightness brightness = Brightness.light,
  Ios27ProviderTheme theme = Ios27ProviderTheme.defaults,
  bool reduceTransparency = true,
  bool highContrast = false,
  double textScale = 1.0,
  bool disableAnimations = false,
}) =>
    ios27BoardApp(
      child: child,
      brightness: brightness,
      theme: theme,
      reduceTransparency: reduceTransparency,
      highContrast: highContrast,
      textScale: textScale,
      disableAnimations: disableAnimations,
    );

/// Размер виджета с учётом `Transform` (обычный `getRect` его игнорирует).
Size _size(WidgetTester tester, Finder f) {
  final d = tester.getBottomRight(f) - tester.getTopLeft(f);
  return Size(d.dx, d.dy);
}

void _noop() {}

/// Две кнопки экрана «Нет подписки» (app.js:449-452): цветное стекло и обычное, ширина — вся.
Widget _emptyButtons({VoidCallback? paste = _noop, VoidCallback? qr = _noop}) =>
    Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 750, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Ios27Button(
              label: 'Вставить ссылку',
              icon: Ios27IconName.clipboard,
              style: Ios27ButtonStyle.prominent,
              block: true,
              nested: false,
              onPressed: paste,
            ),
            Ios27Button(
              label: 'Сканировать QR-код',
              icon: Ios27IconName.qr,
              block: true,
              nested: false,
              onPressed: qr,
            ),
          ],
        ),
      ),
    );

void main() {
  tearDown(Ios27A11y.debugReset);

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('«Нет подписки» $mode: рамки кнопок ±4 dp и golden',
        (tester) async {
      await pumpIos27Board(
        tester,
        _app(
          brightness: dark ? Brightness.dark : Brightness.light,
          child: _emptyButtons(),
        ),
      );
      expectIos27Parity(
        ios27Parity(tester, 'empty-$mode-rt-p0', {
          'empty.btn': find.byType(Ios27Button),
        }),
      );
      await expectIos27Golden(tester, 'prim_button_empty_${mode}_p0');
    });
  }

  testWidgets(
      'размеры: regular 50, compact 48, small 34, подпись не обрезается',
      (tester) async {
    await pumpIos27Board(
      tester,
      _app(
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 12,
          children: [
            Ios27Button(label: 'Обычная', onPressed: _noop, nested: false),
            Ios27Button(
              label: 'Компактная',
              onPressed: _noop,
              size: Ios27ButtonSize.compact,
              nested: false,
            ),
            Ios27Button(
              label: 'Малая',
              onPressed: _noop,
              size: Ios27ButtonSize.small,
              style: Ios27ButtonStyle.plain,
            ),
          ],
        ),
      ),
    );
    final heights = find
        .byType(Ios27Button)
        .evaluate()
        .map((e) => (e.renderObject! as RenderBox).size.height)
        .toList();
    expect(heights, [50, 48, 34]);
  });

  testWidgets('алерт: две compact-кнопки 130×48 в строке', (tester) async {
    await pumpIos27Board(
      tester,
      _app(
        child: const Center(
          child: SizedBox(
            width: 268,
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Ios27Button(
                    label: 'Отмена',
                    onPressed: _noop,
                    size: Ios27ButtonSize.compact,
                    block: true,
                  ),
                ),
                Expanded(
                  child: Ios27Button(
                    label: 'Продолжить',
                    onPressed: _noop,
                    size: Ios27ButtonSize.compact,
                    style: Ios27ButtonStyle.prominent,
                    block: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (final e in find.byType(Ios27Button).evaluate()) {
      final size = (e.renderObject! as RenderBox).size;
      expect(size, const Size(130, 48));
    }
  });

  testWidgets('тап вызывает onPressed; отключённая кнопка молчит',
      (tester) async {
    var taps = 0;
    await pumpIos27Board(
      tester,
      _app(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 12,
          children: [
            Ios27Button(
              label: 'Вкл',
              onPressed: () => taps++,
              nested: false,
            ),
            const Ios27Button(label: 'Выкл', onPressed: null, nested: false),
            Ios27Button(
              label: 'Серая',
              onPressed: () => taps += 10,
              style: Ios27ButtonStyle.plain,
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Вкл'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Выкл'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Серая'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    expect(taps, 11);
  });

  testWidgets('семантика: кнопка, подпись, идентификатор, enabled',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpIos27Board(
        tester,
        _app(
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Ios27Button(
                label: 'Вставить',
                semanticLabel: 'Вставить ссылку из буфера',
                semanticIdentifier: 'dw_paste',
                onPressed: _noop,
                nested: false,
              ),
              Ios27Button(
                label: 'Выкл',
                semanticIdentifier: 'dw_off',
                onPressed: null,
                nested: false,
              ),
            ],
          ),
        ),
      );
      var sem = tester.getSemantics(find.bySemanticsIdentifier('dw_paste'));
      expect(sem.label, 'Вставить ссылку из буфера');
      expect(sem.flagsCollection.isButton, isTrue);
      expect(sem.flagsCollection.isEnabled, Tristate.isTrue);
      sem = tester.getSemantics(find.bySemanticsIdentifier('dw_off'));
      expect(sem.label, 'Выкл');
      expect(sem.flagsCollection.isEnabled, Tristate.isFalse);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('стеклянная кнопка: под пальцем 1,06, потом возвращается',
      (tester) async {
    await pumpIos27Board(
      tester,
      _app(
        child: const Center(
          child: Ios27Button(label: 'Стекло', onPressed: _noop, nested: false),
        ),
      ),
    );
    final base = _size(tester, find.byType(Ios27Glass)).width;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Ios27Button)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_size(tester, find.byType(Ios27Glass)).width,
        closeTo(base * 1.06, 0.6));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_size(tester, find.byType(Ios27Glass)).width, closeTo(base, 0.05));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('быстрый тап не оставляет кнопку раздутой', (tester) async {
    await pumpIos27Board(
      tester,
      _app(
        child: const Center(
          child: Ios27Button(label: 'Стекло', onPressed: _noop, nested: false),
        ),
      ),
    );
    final base = _size(tester, find.byType(Ios27Glass)).width;
    await tester.tap(find.byType(Ios27Button));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_size(tester, find.byType(Ios27Glass)).width, closeTo(base, 0.05));
  });

  testWidgets('Reduce Motion: масштаб не меняется, после нажатия тикеров нет',
      (tester) async {
    await pumpIos27Board(
      tester,
      _app(
        disableAnimations: true,
        child: const Center(
          child: Ios27Button(label: 'Стекло', onPressed: _noop, nested: false),
        ),
      ),
    );
    final base = _size(tester, find.byType(Ios27Glass)).width;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Ios27Button)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_size(tester, find.byType(Ios27Glass)).width, closeTo(base, 0.01));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
      'Reduce Transparency: флаг доходит до кнопки (заглушка и нативное стекло)',
      (tester) async {
    for (final rt in [true, false]) {
      await pumpIos27Board(
        tester,
        _app(
          reduceTransparency: rt,
          child: const Center(
            child:
                Ios27Button(label: 'Стекло', onPressed: _noop, nested: false),
          ),
        ),
      );
      expect(Ios27A11y.reduceTransparency, rt);
      expect(tester.takeException(), isNull);
      expect(find.text('Стекло'), findsOneWidget);
    }
  });

  testWidgets('контроллеры освобождаются при удалении посреди нажатия',
      (tester) async {
    await pumpIos27Board(
      tester,
      _app(
        child: const Center(
          child: Ios27Button(label: 'Стекло', onPressed: _noop, nested: false),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Ios27Button)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox.shrink());
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('кнопка при onPressed -> null во время нажатия отпускается',
      (tester) async {
    final enabled = ValueNotifier<bool>(true);
    addTearDown(enabled.dispose);
    await pumpIos27Board(
      tester,
      _app(
        child: Center(
          child: ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (_, on, __) => Ios27Button(
              label: 'Стекло',
              onPressed: on ? _noop : null,
              nested: false,
            ),
          ),
        ),
      ),
    );
    final base = _size(tester, find.byType(Ios27Button)).width;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Ios27Button)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    enabled.value = false;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_size(tester, find.byType(Ios27Button)).width, closeTo(base, 0.05));
    await gesture.up();
  });

  for (final scale in [0.8, 1.0, 1.4, 2.0]) {
    for (final device in kIos27Iphones) {
      testWidgets(
          'масштаб $scale на ${device.name}: длинная подпись без переполнения',
          (tester) async {
        await pumpIos27Board(
          tester,
          _app(
            textScale: scale,
            child: const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    Ios27Button(
                      label: 'Вставить ссылку на подписку из буфера обмена',
                      icon: Ios27IconName.clipboard,
                      style: Ios27ButtonStyle.prominent,
                      block: true,
                      onPressed: _noop,
                      nested: false,
                    ),
                    Ios27Button(
                      label: 'Сканировать QR-код с другого устройства',
                      icon: Ios27IconName.qr,
                      block: true,
                      onPressed: _noop,
                      nested: false,
                    ),
                    Ios27Button(
                      label: 'Удалить подписку навсегда без возврата',
                      style: Ios27ButtonStyle.danger,
                      size: Ios27ButtonSize.compact,
                      block: true,
                      onPressed: _noop,
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Ios27Button(
                        label: 'Вставить',
                        style: Ios27ButtonStyle.primary,
                        size: Ios27ButtonSize.small,
                        onPressed: _noop,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          device: device,
        );
        expect(tester.takeException(), isNull);
        for (final e in find.byType(Ios27Button).evaluate()) {
          final box = e.renderObject! as RenderBox;
          expect(box.size.height, greaterThanOrEqualTo(34));
        }
      });
    }
  }

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    for (final p in [0, 5]) {
      if (p == 5 && dark) {
        continue;
      }
      testWidgets('golden prim_button_${mode}_p$p: пять видов и отключённые',
          (tester) async {
        await pumpIos27Board(
          tester,
          _app(
            brightness: dark ? Brightness.dark : Brightness.light,
            theme: _theme(p),
            disableAnimations: true,
            child: Container(
              color: dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  for (final style in Ios27ButtonStyle.values)
                    Ios27Button(
                      label: style.name,
                      icon: Ios27IconName.plus,
                      style: style,
                      block: true,
                      nested: false,
                      onPressed: _noop,
                    ),
                  for (final style in [
                    Ios27ButtonStyle.glass,
                    Ios27ButtonStyle.prominent,
                    Ios27ButtonStyle.primary,
                  ])
                    Ios27Button(
                      label: '${style.name} · выкл',
                      style: style,
                      block: true,
                      nested: false,
                      onPressed: null,
                    ),
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Ios27Button(
                      label: 'Вставить',
                      style: Ios27ButtonStyle.plain,
                      size: Ios27ButtonSize.small,
                      onPressed: _noop,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await expectIos27Golden(tester, 'prim_button_${mode}_p$p');
      });
    }
  }
}
