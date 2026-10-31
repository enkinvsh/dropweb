// Тост iOS-редизайна: геометрия D4, текст, движение, golden против доски.

import 'package:dropweb/ui/ios27/layers/ios27_toast.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden.dart';
import 'support/layer_harness.dart';
import 'support/layout.dart';
import 'support/surface.dart';

const _worst =
    'Очень длинное сообщение об ошибке, которое никак не помещается в две строки '
    'тоста и должно обрезаться многоточием в конце, а не вылезать за плашку '
    'ПодпискаБезПробеловПодпискаБезПробеловПодпискаБезПробелов';

Widget _host(
  M3eToastMessage? message, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  bool disableAnimations = false,
  Ios27Device device = kIos27BoardDevice,
  Duration? hold,
  ValueChanged<M3eToastMessage>? onDismissed,
}) =>
    ios27BoardApp(
      brightness: brightness,
      textScale: textScale,
      disableAnimations: disableAnimations,
      device: device,
      child: Stack(
        children: [
          Positioned.fill(
            child: Builder(
              builder: (context) =>
                  ColoredBox(color: ios27ColorsFor(context).palette.bg),
            ),
          ),
          Positioned.fill(
            child: Ios27ToastPresenter(
              message: message,
              hold: hold,
              onDismissed: onDismissed,
            ),
          ),
        ],
      ),
    );

Rect _rect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero) & box.size;
}

void main() {
  const toastFinder = ValueKey<String>('ios27.toast');
  const textFinder = ValueKey<String>('ios27.toast.text');

  testWidgets('D4: высота 48, центр на линии кнопок панели', (tester) async {
    for (final device in [
      kIos27IphoneSmall,
      kIos27BoardDevice,
      kIos27IphoneLarge,
    ]) {
      await pumpIos27Board(
        tester,
        _host(
          const M3eToastMessage(kind: M3eToastKind.check, text: 'Готово'),
          device: device,
          hold: null,
        ),
        device: device,
      );
      await tester.pump(const Duration(seconds: 2));
      final r = _rect(tester, find.byKey(toastFinder));
      expect(r.height, closeTo(48, 0.01), reason: device.name);
      // Кнопки панели стоят на верхней границе safe area, высота 44.
      final gearCenter = device.padding.top + 22;
      expect(r.center.dy, closeTo(gearCenter, 0.01), reason: device.name);
      expect(r.center.dx, closeTo(device.size.width / 2, 0.01));
    }
  });

  testWidgets('D4: центр совпадает с шестерёнкой из layout.json доски',
      (tester) async {
    await pumpIos27Board(
      tester,
      _host(
        const M3eToastMessage(
            kind: M3eToastKind.alert, text: 'Нет связи с сервером'),
        hold: null,
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    final gear =
        Ios27RefLayout.load('refresh-fail-light-rt-p0').element('settings')!;
    final r = _rect(tester, find.byKey(toastFinder));
    expect(r.center.dy, closeTo(gear.center.dy, 0.01));
  });

  testWidgets('D4: ширина min(360, W−136) на 375/411/440', (tester) async {
    for (final device in [
      kIos27IphoneSmall,
      kIos27BoardDevice,
      kIos27IphoneLarge,
    ]) {
      await pumpIos27Board(
        tester,
        _host(
          const M3eToastMessage(kind: M3eToastKind.alert, text: _worst),
          device: device,
          hold: null,
        ),
        device: device,
      );
      await tester.pump(const Duration(seconds: 2));
      final r = _rect(tester, find.byKey(toastFinder));
      final expected = (device.size.width - 136).clamp(0.0, 360.0);
      expect(r.width, closeTo(expected, 0.01), reason: device.name);
      expect(ios27ToastMaxWidthFor(device.size.width), expected);
    }
  });

  testWidgets(
      'текст: не больше двух строк, многоточие, масштаб 1.0 при textScale 2',
      (tester) async {
    await pumpIos27Board(
      tester,
      _host(
        const M3eToastMessage(kind: M3eToastKind.alert, text: _worst),
        textScale: 2.0,
        hold: null,
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(textFinder),
        matching: find.byType(RichText),
      ),
    );
    expect(paragraph.didExceedMaxLines, isTrue);
    expect(paragraph.textScaler, TextScaler.noScaling);
    expect(paragraph.size.height, lessThanOrEqualTo(36.01));
    expect(_rect(tester, find.byKey(toastFinder)).height, closeTo(48, 0.01));
  });

  testWidgets(
      'вне Material и DefaultTextStyle предка: текст без жёлтого подчёркивания',
      (tester) async {
    // Как в `MessageManager`: слой над Navigator, ниже `MaterialApp.builder`. Стиль текста по
    // умолчанию там — аварийный (жёлтый, двойное подчёркивание), его надо перекрыть самим тостом.
    await tester.pumpWidget(
      ProviderScope(
        overrides: layerOverrides(),
        child: MaterialApp(
          builder: (context, child) => Stack(
            children: [
              child!,
              const Positioned.fill(
                child: Ios27ToastPresenter(
                  message: M3eToastMessage(
                    kind: M3eToastKind.check,
                    text: 'Подписка обновлена',
                  ),
                ),
              ),
            ],
          ),
          home: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey<String>('ios27.toast.text')),
    );
    expect(paragraph.text.style?.decoration, TextDecoration.none);
    expect(
      paragraph.text.style?.decorationStyle,
      isNot(TextDecorationStyle.double),
    );
  });

  testWidgets('тост на месте и уходит сам через hold, затем нет тикеров',
      (tester) async {
    M3eToastMessage? dismissed;
    await pumpIos27Board(
      tester,
      _host(
        const M3eToastMessage(
            kind: M3eToastKind.check, text: 'Подписка обновлена'),
        onDismissed: (m) => dismissed = m,
        hold: kM3eToastHold,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(toastFinder), findsOneWidget);
    expect(dismissed, isNull);
    await tester.pump(const Duration(milliseconds: 1300));
    expect(dismissed, isNotNull);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(toastFinder), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('Reduce Motion: только прозрачность за 100 мс, без сдвига',
      (tester) async {
    await pumpIos27Board(
      tester,
      _host(
        const M3eToastMessage(kind: M3eToastKind.check, text: 'Готово'),
        disableAnimations: true,
        hold: null,
      ),
    );
    expect(
        find.byKey(const ValueKey<String>('ios27.toast.motion')), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    final mid = tester.widget<Opacity>(
      find.byKey(const ValueKey<String>('ios27.toast.fade')),
    );
    expect(mid.opacity, inExclusiveRange(0.0, 1.0));
    await tester.pump(const Duration(milliseconds: 120));
    final end = tester.widget<Opacity>(
      find.byKey(const ValueKey<String>('ios27.toast.fade')),
    );
    expect(end.opacity, 1.0);
    expect(tester.binding.transientCallbackCount, 0);
  });

  group('golden', () {
    Future<void> shoot(
      WidgetTester tester,
      M3eToastMessage message,
      String name,
    ) async {
      await pumpIos27Board(tester, _host(message, hold: null));
      await tester.pump(const Duration(seconds: 2));
      await expectIos27Golden(tester, name);
    }

    testWidgets('support', (tester) async {
      await shoot(
        tester,
        const M3eToastMessage(
            kind: M3eToastKind.out, text: 'Открываем справочную'),
        'layer_toast_support',
      );
    });

    testWidgets('refresh-fail', (tester) async {
      await shoot(
        tester,
        const M3eToastMessage(
            kind: M3eToastKind.alert, text: 'Нет связи с сервером'),
        'layer_toast_refresh_fail',
      );
    });
  });
}
