// Страница «Оформление» iOS-редизайна: рамки доски ±4 dp, golden appearance_*, выбор режима,
// колодцы цвета, движение (G8), крайние размеры шрифта на всех экранах iPhone.

import 'dart:ui' show Tristate;

import 'package:dropweb/providers/config.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_own_colors.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_source.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_appearance_harness.dart';
import 'support/golden.dart';
import 'support/layout.dart';
import 'support/surface.dart';

// Без группы «Темы»: её нет на доске, см. `OutsideThemesFinder`.
Finder _k(String key) => pageKey(key);

Map<String, Finder> _pageElements() => {
      'page': _k('page'),
      'page.nav': _k('page.nav'),
      'page.back': _k('page.back'),
      'page.title': _k('page.title'),
      'page.groupHead': _k('page.groupHead'),
      'page.group': _k('page.group'),
      'page.row': colorRows(),
      'page.rowTitle': colorRowTitles(),
      'page.rowCheck': _k('page.rowCheck'),
      'page.rowSwatch': _k('page.rowSwatch'),
      'page.glassPreview': _k('page.glassPreview'),
      'page.glassBtn': _k('page.glassBtn'),
      'page.sliderRow': _k('page.sliderRow'),
      'page.slider': _k('page.slider'),
      'page.sliderCaps': _k('page.sliderCaps'),
    };

Rect _rect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero) & box.size;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  // На малых экранах строка может оказаться ниже края: страница прокручивается.
  await revealIfHidden(tester, find.text(text));
  await tester.tap(find.text(text));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Color _wellColor(WidgetTester tester, int index) =>
    tester.widget<Ios27RowWell>(_k('page.well').at(index)).color;

void main() {
  for (final brightness in Brightness.values) {
    final mode = brightness.name;

    group('сверка с доской, $mode', () {
      testWidgets('appearance p0: рамки ±4 dp и golden', (tester) async {
        await pumpIos27Board(tester, appearanceApp(brightness: brightness));
        await openAppearance(tester);
        expect(tester.takeException(), isNull);
        final rows =
            appearanceParity('appearance-$mode-rt-p0', _pageElements());
        expectIos27Parity(rows);
        await expectIos27Golden(tester, 'appearance_${mode}_p0');
      });

      testWidgets('appearance p5 (серый провайдер): golden', (tester) async {
        await pumpIos27Board(
          tester,
          appearanceApp(brightness: brightness, provider: 5),
        );
        await openAppearance(tester);
        expect(tester.takeException(), isNull);
        await expectIos27Golden(tester, 'appearance_${mode}_p5');
      });

      testWidgets('«Свои» включены: колодцы и golden (на доске эталона нет)',
          (tester) async {
        await pumpIos27Board(tester, appearanceApp(brightness: brightness));
        await openAppearance(tester);
        await _tapText(tester, 'Свои');
        expect(tester.takeException(), isNull);
        // Группа колодцев стоит под «Цветами» через зазор 24, как на сцене `colors` доски (с
        // поправкой на строку «Как в системе»).
        final ref = shiftedForSystemRow(
          Ios27RefLayout.load('colors-$mode-rt-p0'),
        )['page.group']!;
        expect(_k('page.group'), findsNWidgets(3));
        final own = _rect(tester, _k('page.group').at(2));
        expect(own.top, closeTo(ref[2].top, 4));
        expect(own.height, closeTo(ref[2].height, 4));
        expect(_k('page.well'), findsNWidgets(3));
        await expectIos27Golden(tester, 'appearance_own_${mode}_p0');
      });
    });
  }

  group('выбор режима', () {
    testWidgets(
        'по умолчанию «Провайдер»: галочка на первой строке, колодцев нет',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);
      expect(_k('page.rowCheck'), findsOneWidget);
      final firstRow = _rect(tester, colorRows().at(0));
      final check = _rect(tester, _k('page.rowCheck'));
      expect(check.center.dy, closeTo(firstRow.center.dy, 1));
      expect(_k('page.well'), findsNothing);
      expect(
        containerOf(tester).read(themeSettingProvider).m3eOwnColorEnabled,
        isFalse,
      );
    });

    testWidgets('«Свои»: галочка переезжает, три колодца с подписями слотов',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);
      final accentBefore = containerOf(tester).read(ios27ThemeProvider).accent;
      await _tapText(tester, 'Свои');

      final secondRow = _rect(tester, colorRows().at(1));
      expect(_k('page.rowCheck'), findsOneWidget);
      expect(
        _rect(tester, _k('page.rowCheck')).center.dy,
        closeTo(secondRow.center.dy, 1),
      );
      expect(_k('page.well'), findsNWidgets(3));
      for (final label in ['Кнопки', 'Фон сверху', 'Фон снизу']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        containerOf(tester).read(themeSettingProvider).m3eOwnColorEnabled,
        isTrue,
      );
      // Включение «Своих» цвета не меняет: слоты пока повторяют провайдера (как снимок доски).
      expect(containerOf(tester).read(ios27ThemeProvider).accent, accentBefore);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'колодцы показывают текущий цвет слота: провайдера, пока не выбран свой',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light, provider: 2),
      );
      await openAppearance(tester);
      await _tapText(tester, 'Свои');
      final theme = boardTheme(2);
      expect(_wellColor(tester, 0), Ios27Rgb.fromHex(theme.accent).color);
      expect(_wellColor(tester, 1), Ios27Rgb.fromHex(theme.orb1).color);
      expect(_wellColor(tester, 2), Ios27Rgb.fromHex(theme.orb2).color);
      final own = containerOf(tester).read(ios27OwnThemeProvider);
      expect(own.accent, theme.accent);
      expect(own.orb1, theme.orb1);
      expect(own.orb2, theme.orb2);
    });

    testWidgets('выбор перекрашивает колодец вживую, остальные не трогает',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);
      await _tapText(tester, 'Свои');
      final orb2Before = _wellColor(tester, 2);
      containerOf(tester)
          .read(ios27OwnColorActionsProvider)
          .pick(Ios27ColorSlot.accent, '#FF2D55');
      await tester.pump();
      expect(_wellColor(tester, 0), Ios27Rgb.fromHex('#FF2D55').color);
      expect(_wellColor(tester, 2), orb2Before);
    });

    testWidgets('«Провайдер» возвращает цвета провайдера и не стирает свои',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);
      await _tapText(tester, 'Свои');
      final container = containerOf(tester);
      final actions = container.read(ios27OwnColorActionsProvider);
      final provider = container.read(ios27ProviderThemeProvider);

      actions
        ..pick(Ios27ColorSlot.accent, '#0088FF')
        ..pick(Ios27ColorSlot.orb1, '#CB30E0');
      await tester.pump();
      expect(container.read(ios27ThemeProvider).accent, '#0088FF');
      expect(container.read(ios27ThemeProvider).orb1, '#CB30E0');
      // Второй фон не выбирали: остаётся провайдерским.
      expect(container.read(ios27ThemeProvider).orb2, provider.orb2);

      await _tapText(tester, 'Провайдер');
      expect(container.read(ios27ThemeProvider).accent, provider.accent);
      expect(container.read(ios27ThemeProvider).orb1, provider.orb1);
      expect(_k('page.well'), findsNothing);
      // Сохранённое не стёрто: ни в настройках, ни в производной «своей» теме.
      final props = container.read(themeSettingProvider);
      expect(props.m3eOwnColorEnabled, isFalse);
      expect(props.m3eOwnColor, 0xFF0088FF);
      expect(props.ios27OwnOrb1, 0xFFCB30E0);
      expect(container.read(ios27OwnThemeProvider).accent, '#0088FF');

      await _tapText(tester, 'Свои');
      expect(container.read(ios27ThemeProvider).accent, '#0088FF');
      expect(container.read(ios27ThemeProvider).orb1, '#CB30E0');
      expect(tester.takeException(), isNull);
    });
  });

  group('семантика', () {
    testWidgets('идентификаторы строк и колодцев сохраняются', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);
      await _tapText(tester, 'Свои');

      for (final id in [
        'dw_appearance_provider',
        'dw_appearance_own',
        'dw_appearance_well_accent',
        'dw_appearance_well_orb1',
        'dw_appearance_well_orb2',
      ]) {
        final finder = find.bySemanticsIdentifier(id);
        expect(finder, findsOneWidget, reason: id);
        final data = tester.getSemantics(finder).getSemanticsData();
        expect(data.identifier, id);
        expect(data.flagsCollection.isButton, isTrue, reason: id);
        expect(data.flagsCollection.isEnabled, Tristate.isTrue, reason: id);
      }
      handle.dispose();
    });
  });

  group('G8: движение', () {
    testWidgets('после посадки страницы нет кадров-хвостов', (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);
      await _tapText(tester, 'Свои');
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('«Уменьшить движение»: страница садится без кадров-хвостов',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light, disableAnimations: true),
      );
      await openAppearance(tester);
      await _tapText(tester, 'Свои');
      await tester.pump(const Duration(milliseconds: 150));
      expect(_k('page.well'), findsNWidgets(3));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('закрытие страницы: чисто, без исключений', (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);
      await tester.tap(_k('page.back'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(_k('page'), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('крайние размеры', () {
    for (final device in kIos27Iphones) {
      for (final scale in [0.8, 1.0, 1.4, 2.0]) {
        testWidgets('${device.name} × текст $scale: без переполнения',
            (tester) async {
          await pumpIos27Board(
            tester,
            appearanceApp(
              brightness: Brightness.light,
              textScale: scale,
              device: device,
            ),
            device: device,
          );
          await openAppearance(tester);
          await _tapText(tester, 'Свои');
          expect(tester.takeException(), isNull);
          // Строки не вылезают за экран по горизонтали; считаются и строки группы «Темы».
          final allRows = find.byKey(const ValueKey<String>('page.row'));
          final rows = tester.widgetList(allRows).length;
          for (var i = 0; i < rows; i++) {
            final rect = _rect(tester, allRows.at(i));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(device.size.width + 0.01));
          }
          // Секция «Стекло»: ползунок и подписи остаются в экране и не вылезают друг на друга.
          for (final key in [
            'page.slider',
            'page.sliderCaps',
            'page.glassPreview'
          ]) {
            final rect = _rect(tester, _k(key));
            expect(rect.left, greaterThanOrEqualTo(0), reason: key);
            expect(rect.right, lessThanOrEqualTo(device.size.width + 0.01),
                reason: key);
          }
        });
      }
    }
  });
}
