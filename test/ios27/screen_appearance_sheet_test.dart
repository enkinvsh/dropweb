// Лист выбора цвета iOS-редизайна: рамки доски ±4 dp (сцена `colors`), golden colors_* и
// color-sheet_*, выбор из сетки и из сохранённых цветов, живая перекраска главной за страницей,
// запоминание при повторном открытии, движение (G8), крайние размеры.

import 'dart:ui' show Tristate;

import 'package:dropweb/providers/config.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_own_colors.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_source.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';

import 'screen_appearance_harness.dart';
import 'support/golden.dart';
import 'support/layout.dart';
import 'support/surface.dart';

// Без группы «Темы»: её нет на доске, см. `OutsideThemesFinder`.
Finder _k(String key) => pageKey(key);

Map<String, Finder> _sceneElements() => {
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
      'page.well': _k('page.well'),
      'page.glassPreview': _k('page.glassPreview'),
      'page.glassBtn': _k('page.glassBtn'),
      'page.sliderRow': _k('page.sliderRow'),
      'page.slider': _k('page.slider'),
      'page.sliderCaps': _k('page.sliderCaps'),
      'sheet': _k('ios27.sheet.frame'),
      'sheet.title': _k('ios27.sheet.title'),
      'sheet.close': _k('ios27.sheet.close'),
      'cp.grid': _k('cp.grid'),
      'cp.current': _k('cp.current'),
      'cp.dots': _k('cp.dots'),
      'cp.dot': _k('cp.dot'),
    };

Rect _rect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero) & box.size;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  // Ниже края экрана строку подводит прокрутка страницы (на малых экранах «Стекло» её сдвигает).
  await revealIfHidden(tester, find.text(text));
  await tester.tap(find.text(text));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Страница → «Свои» → колодец [slot]: открывает лист цвета и ждёт его посадки.
Future<void> _openSheet(
  WidgetTester tester, {
  String slot = 'Кнопки',
}) async {
  await openAppearance(tester);
  await _tapText(tester, 'Свои');
  await revealIfHidden(tester, find.text(slot));
  await tester.tap(find.text(slot));
  await settle(tester);
}

Future<void> _tapDot(WidgetTester tester, int index) async {
  await tester.tap(_k('cp.dot').at(index));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Нажимает клетку сетки [index] (0..119) по её центру.
Future<void> _tapCell(WidgetTester tester, int index) async {
  final grid = _rect(tester, _k('cp.grid'));
  final cw = grid.width / kIos27ColorGridColumns;
  final ch = grid.height / (kIos27ColorGrid.length ~/ kIos27ColorGridColumns);
  final col = index % kIos27ColorGridColumns;
  final row = index ~/ kIos27ColorGridColumns;
  await tester.tapAt(
    Offset(grid.left + (col + 0.5) * cw, grid.top + (row + 0.5) * ch),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Узел семантики клетки сетки с подписью [hex] (или `null`).
SemanticsNode? _gridCell(WidgetTester tester, String hex) {
  SemanticsNode? found;
  void visit(SemanticsNode node) {
    if (node.label == hex) {
      found = node;
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(_k('cp.grid')));
  return found;
}

/// Цвет образца «текущий» листа.
Color _current(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: _k('cp.current'), matching: find.byType(DecoratedBox)),
  );
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  for (final brightness in Brightness.values) {
    final mode = brightness.name;

    group('сверка с доской, $mode', () {
      testWidgets('colors p0: рамки ±4 dp и golden', (tester) async {
        await pumpIos27Board(tester, appearanceApp(brightness: brightness));
        await _openSheet(tester);
        expect(tester.takeException(), isNull);
        final refKey = 'colors-$mode-rt-p0';
        final rows = appearanceParity(refKey, _sceneElements());
        expectIos27Parity(rows);
        await expectIos27Golden(tester, 'colors_${mode}_p0');
      });

      testWidgets('colors p5 (серый провайдер): golden', (tester) async {
        await pumpIos27Board(
          tester,
          appearanceApp(brightness: brightness, provider: 5),
        );
        await _openSheet(tester);
        expect(tester.takeException(), isNull);
        await expectIos27Golden(tester, 'colors_${mode}_p5');
      });

      // На доске color-sheet и colors побайтно равны (выбора нет); здесь сцена с выбранным
      // сохранённым цветом, чтобы кольцо выбора попало в golden.
      testWidgets('color-sheet p0: выбран «Синий», golden', (tester) async {
        await pumpIos27Board(tester, appearanceApp(brightness: brightness));
        await _openSheet(tester);
        await _tapDot(tester, 0);
        expect(tester.takeException(), isNull);
        await expectIos27Golden(tester, 'color-sheet_${mode}_p0');
      });

      testWidgets('color-sheet p5: выбран «Графитовый», golden',
          (tester) async {
        await pumpIos27Board(
          tester,
          appearanceApp(brightness: brightness, provider: 5),
        );
        await _openSheet(tester);
        await _tapDot(tester, 7);
        expect(tester.takeException(), isNull);
        await expectIos27Golden(tester, 'color-sheet_${mode}_p5');
      });

      testWidgets('color-sheet p0: выбрана клетка сетки, golden',
          (tester) async {
        await pumpIos27Board(tester, appearanceApp(brightness: brightness));
        await _openSheet(tester);
        // Ряд 5, колонка 3 («#982ABC»): середина палитры, рамка выбора на цветной клетке.
        await _tapCell(tester, 5 * kIos27ColorGridColumns + 3);
        expect(tester.takeException(), isNull);
        await expectIos27Golden(tester, 'color-sheet_${mode}_p0_cell');
      });
    });
  }

  group('выбор цвета', () {
    testWidgets(
        'лист открывается колодцем «Кнопки»: заголовок и метка Semantics',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await _openSheet(tester);
      expect(tester.widget<Text>(_k('ios27.sheet.title')).data, 'Кнопки');
      expect(find.bySemanticsLabel('Цвет: Кнопки'), findsOneWidget);
      expect(_k('cp.dot'), findsNWidgets(kIos27AccentPresets.length));
      handle.dispose();
    });

    testWidgets(
        'первоначально ничего не выбрано: цвет провайдера не из палитры',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await _openSheet(tester);
      expect(_current(tester), Ios27Rgb.fromHex('#29FF76').color);
      for (final preset in kIos27AccentPresets) {
        final label =
            find.bySemanticsLabel(RegExp('^${RegExp.escape(_name(preset))}\$'));
        expect(label, findsOneWidget, reason: preset.id);
        final flags =
            tester.getSemantics(label).getSemanticsData().flagsCollection;
        expect(flags.isSelected, isNot(Tristate.isTrue), reason: preset.id);
      }
      handle.dispose();
    });

    testWidgets(
        'сохранённый цвет: применяется сразу, лист остаётся, цвет отмечен',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await _openSheet(tester);
      await _tapDot(tester, 0);

      final container = containerOf(tester);
      expect(container.read(ios27ThemeProvider).accent, '#0088FF');
      expect(_k('ios27.sheet.frame'), findsOneWidget);
      expect(_current(tester), Ios27Rgb.fromHex('#0088FF').color);
      final blue = tester
          .getSemantics(find.bySemanticsLabel('Синий'))
          .getSemanticsData()
          .flagsCollection;
      expect(blue.isSelected, Tristate.isTrue);
      final purple = tester
          .getSemantics(find.bySemanticsLabel('Фиолетовый'))
          .getSemanticsData()
          .flagsCollection;
      expect(purple.isSelected, isNot(Tristate.isTrue));
      // Колодец за листом перекрасился.
      expect(
        tester.widget<Ios27RowWell>(_k('page.well').first).color,
        Ios27Rgb.fromHex('#0088FF').color,
      );
      expect(container.read(themeSettingProvider).m3eOwnColor, 0xFF0088FF);
      handle.dispose();
    });

    for (var i = 0; i < kIos27AccentPresets.length; i++) {
      final preset = kIos27AccentPresets[i];
      testWidgets('кружок ${preset.id} выбирает ${preset.light}',
          (tester) async {
        await pumpIos27Board(
          tester,
          appearanceApp(brightness: Brightness.light),
        );
        await _openSheet(tester);
        await _tapDot(tester, i);
        expect(
          containerOf(tester).read(ios27ThemeProvider).accent,
          preset.light,
        );
      });
    }

    testWidgets('клетка сетки: выбирается цвет из таблицы', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await _openSheet(tester);
      const index = 5 * kIos27ColorGridColumns + 3;
      await _tapCell(tester, index);
      final hex = kIos27ColorGrid[index];
      expect(containerOf(tester).read(ios27ThemeProvider).accent, hex);
      expect(_current(tester), Ios27Rgb.fromHex(hex).color);
      // Клетки — виртуальные узлы `CustomPainter`: элементов у них нет, ищем в дереве семантики.
      final cell = _gridCell(tester, hex);
      expect(cell, isNotNull, reason: hex);
      expect(
        cell!.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      final other = _gridCell(tester, kIos27ColorGrid[index + 1]);
      expect(
        other!.getSemanticsData().flagsCollection.isSelected,
        isNot(Tristate.isTrue),
      );
      // Сто двадцать клеток озвучиваются каждая своей подписью.
      for (final label in kIos27ColorGrid) {
        expect(_gridCell(tester, label), isNotNull, reason: label);
      }
      handle.dispose();
    });

    testWidgets('все 120 клеток нажимаются по центру и дают свой цвет',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await _openSheet(tester);
      for (var i = 0; i < kIos27ColorGrid.length; i++) {
        await _tapCell(tester, i);
        expect(
          containerOf(tester).read(ios27ThemeProvider).accent,
          kIos27ColorGrid[i],
          reason: 'клетка $i',
        );
      }
    });

    testWidgets('«Фон сверху» и «Фон снизу» красят только свой слот',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await _openSheet(tester, slot: 'Фон сверху');
      final provider = containerOf(tester).read(ios27ProviderThemeProvider);
      await _tapDot(tester, 2);
      var theme = containerOf(tester).read(ios27ThemeProvider);
      expect(theme.orb1, kIos27AccentPresets[2].light);
      expect(theme.accent, provider.accent);
      expect(theme.orb2, provider.orb2);
      expect(
        containerOf(tester).read(themeSettingProvider).ios27OwnOrb1,
        0xFF000000 | ios27ArgbOfHex(kIos27AccentPresets[2].light),
      );

      await tester.tap(_k('ios27.sheet.close'));
      await settle(tester);
      await tester.tap(find.text('Фон снизу'));
      await settle(tester);
      await _tapDot(tester, 5);
      theme = containerOf(tester).read(ios27ThemeProvider);
      expect(theme.orb2, kIos27AccentPresets[5].light);
      expect(theme.orb1, kIos27AccentPresets[2].light);
      expect(theme.accent, provider.accent);
    });
  });

  group('запоминание и живая перекраска', () {
    testWidgets(
        'главная за страницей перекрашивается вживую и выбор переживает повторное открытие',
        (tester) async {
      final handle = tester.ensureSemantics();
      final log = AccentLog();
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light, log: log),
      );
      final before = log.accent;
      expect(before, ios27AccentVars('#29FF76').accent(dark: false));

      await _openSheet(tester);
      await _tapDot(tester, 0);
      final blue = ios27AccentVars('#0088FF').accent(dark: false);
      expect(log.accent, blue);
      expect(log.accent, isNot(before));
      // Фоновые цвета выбором кнопок не тронуты.
      expect(log.orb1, Ios27Rgb.fromHex('#000000').color);

      // Закрыли лист, открыли снова: выбранное на месте.
      await tester.tap(_k('ios27.sheet.close'));
      await settle(tester);
      expect(_k('ios27.sheet.frame'), findsNothing);
      await tester.tap(find.text('Кнопки'));
      await settle(tester);
      expect(_current(tester), Ios27Rgb.fromHex('#0088FF').color);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Синий'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(log.accent, blue);

      // «Провайдер» возвращает цвет провайдера, «Свои» снова отдаёт сохранённый.
      await tester.tap(_k('ios27.sheet.close'));
      await settle(tester);
      await _tapText(tester, 'Провайдер');
      expect(log.accent, before);
      await _tapText(tester, 'Свои');
      expect(log.accent, blue);
      handle.dispose();
    });

    testWidgets('тёмная тема: акцент подгоняется под контраст, как на доске',
        (tester) async {
      final log = AccentLog();
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.dark, log: log),
      );
      await _openSheet(tester);
      await _tapDot(tester, 5); // жёлтый #FFCC00
      expect(log.accent, ios27AccentVars('#FFCC00').accent(dark: true));
    });
  });

  group('G8: движение', () {
    testWidgets('после посадки листа и выбора нет кадров-хвостов',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await _openSheet(tester);
      await _tapDot(tester, 3);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('«Уменьшить движение»: лист садится без кадров-хвостов',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light, disableAnimations: true),
      );
      await openAppearance(tester);
      await _tapText(tester, 'Свои');
      await tester.tap(find.text('Кнопки'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(_k('ios27.sheet.frame'), findsOneWidget);
      await _tapDot(tester, 1);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('закрытие листа: чисто, без исключений', (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await _openSheet(tester);
      await tester.tap(_k('ios27.sheet.close'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(_k('ios27.sheet.frame'), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('крайние размеры', () {
    for (final device in kIos27Iphones) {
      for (final scale in [0.8, 1.0, 1.4, 2.0]) {
        testWidgets('${device.name} × текст $scale: лист без переполнения',
            (tester) async {
          await pumpIos27Board(
            tester,
            appearanceApp(
              brightness: Brightness.dark,
              textScale: scale,
              device: device,
            ),
            device: device,
          );
          await _openSheet(tester);
          expect(tester.takeException(), isNull);
          // Лист не шире экрана; тело прокручивается, если не помещается.
          final frame = _rect(tester, _k('ios27.sheet.frame'));
          expect(frame.left, greaterThanOrEqualTo(0));
          expect(frame.right, lessThanOrEqualTo(device.size.width + 0.01));
          expect(frame.bottom, lessThanOrEqualTo(device.size.height + 0.01));
          // Нижний ряд достижим: прокрутка до кружка и нажатие выбирают цвет.
          await tester.ensureVisible(_k('cp.dot').last);
          await tester.pump();
          await tester.tap(_k('cp.dot').last);
          await tester.pump();
          expect(
            containerOf(tester).read(ios27ThemeProvider).accent,
            kIos27AccentPresets.last.light,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}

/// Название сохранённого цвета в русской локали (ключи `ios27Preset*`).
String _name(Ios27AccentPreset preset) => const {
      'blue': 'Синий',
      'purple': 'Фиолетовый',
      'pink': 'Розовый',
      'red': 'Красный',
      'orange': 'Оранжевый',
      'yellow': 'Жёлтый',
      'green': 'Зелёный',
      'graphite': 'Графитовый',
    }[preset.id]!;
