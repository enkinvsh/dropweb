// Группа «Темы» на странице «Оформление»: шесть готовых троек из `themePresets` одним нажатием.
//
// На доске такой группы нет (добавка по просьбе владельца 30.10, «нет пресетов тем»), поэтому здесь
// нет сверки с `layout.json`: группа стоит последней и рамки доски выше не сдвигает, а в сверке
// страницы она исключена (`OutsideThemesFinder`). Здесь проверяются порядок и названия, применение
// всех трёх слотов разом, галочка, возврат к провайдеру, повторное открытие, семантика, крайние
// размеры, движение (G8) и golden `appearance_themes_*`.

import 'dart:ui' show Tristate;

import 'package:dropweb/common/constant.dart' show ThemePreset, themePresets;
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_own_colors.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_theme_presets.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_appearance_harness.dart';
import 'support/golden.dart';
import 'support/layout.dart';
import 'support/surface.dart';

/// Названия в порядке `themePresets` (русские значения ключей `presetEmerald` … `presetStealth`).
const List<String> _names = [
  'Падение',
  'Иней',
  'Аметист',
  'Багрянец',
  'Янтарь',
  'Стелс',
];

Finder _k(String key) => find.byKey(ValueKey<String>(key));

/// Строки и проверки только внутри группы «Темы».
Finder _inThemes(Finder inner) =>
    find.descendant(of: _k('page.themes'), matching: inner);

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder);

/// Нажимает строку по названию: строка группы может лежать ниже края, тогда её подводит прокрутка.
Future<void> _tapTheme(WidgetTester tester, int index) async {
  final target = find.text(_names[index]);
  await revealIfHidden(tester, target);
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await revealIfHidden(tester, find.text(text));
  await tester.tap(find.text(text));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Страница в самый низ: так в кадр попадает вся группа «Темы».
Future<void> _scrollToEnd(WidgetTester tester) async {
  final position =
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pump();
}

/// Три цвета образца строки [index]: акцент и два фона секторами.
(Color, Color, Color) _swatchColors(WidgetTester tester, int index) {
  // Внешний DecoratedBox несёт сектора, внутренний рисует только обводку 0,5.
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: _k('page.themeSwatch').at(index),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  final gradient = (box.decoration as BoxDecoration).gradient! as SweepGradient;
  return (gradient.colors[0], gradient.colors[2], gradient.colors[4]);
}

/// Индексы строк группы, на которых стоит галочка.
List<int> _checkedThemes(WidgetTester tester) {
  final checks = _inThemes(_k('page.rowCheck')).evaluate().toList();
  if (checks.isEmpty) {
    return const [];
  }
  final rows = _inThemes(_k('page.row')).evaluate().map((e) {
    final box = e.renderObject! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }).toList();
  return [
    for (final check in checks)
      rows.indexWhere((row) {
        final box = check.renderObject! as RenderBox;
        return row.contains(
            box.localToGlobal(Offset.zero) + box.size.center(Offset.zero));
      }),
  ];
}

Color _preset(int argb) => Color(argb);

void main() {
  group('состав и раскладка', () {
    testWidgets('шесть строк в порядке themePresets с названиями и образцами',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);

      expect(themePresets, hasLength(6));
      expect(_inThemes(_k('page.row')), findsNWidgets(6));
      expect(_k('page.themeSwatch'), findsNWidgets(6));
      var previousTop = double.negativeInfinity;
      for (var i = 0; i < 6; i++) {
        final title = find.text(_names[i]);
        expect(title, findsOneWidget, reason: _names[i]);
        final top = _rect(tester, _inThemes(_k('page.row')).at(i)).top;
        expect(top, greaterThan(previousTop), reason: 'порядок строк');
        previousTop = top;
        // Название лежит именно в своей строке.
        expect(
          find.descendant(
            of: _inThemes(_k('page.row')).at(i),
            matching: title,
          ),
          findsOneWidget,
          reason: _names[i],
        );
        final p = themePresets[i];
        expect(
          _swatchColors(tester, i),
          (_preset(p.accent), _preset(p.orbPrimary), _preset(p.orbSecondary)),
          reason: 'образец ${_names[i]}',
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('заголовок «Темы» после «Цветов», тот же шаг и тот же отступ',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);
      expect(find.text('Темы'), findsOneWidget);

      final heads = _k('page.groupHead');
      expect(heads, findsNWidgets(3));
      final groups = _k('page.group');
      expect(groups, findsNWidgets(3));
      // «Стекло», «Цвета», «Темы» сверху вниз; зазор между карточкой и следующим заголовком
      // одинаков (Ios27Gap).
      final gap1 =
          _rect(tester, heads.at(1)).top - _rect(tester, groups.at(0)).bottom;
      final gap2 =
          _rect(tester, heads.at(2)).top - _rect(tester, groups.at(1)).bottom;
      expect(gap2, closeTo(gap1, 0.01));

      // Образец и подпись стоят там же, где у «Провайдер» / «Свои»: тот же компонент и отступ.
      final provider = _rect(tester, _k('page.rowSwatch').first);
      final theme = _rect(tester, _k('page.themeSwatch').first);
      expect(theme.size, provider.size);
      expect(theme.left, provider.left);
      final providerTitle = _rect(tester, _k('page.rowTitle').at(1));
      final themeTitle = _rect(tester, _inThemes(_k('page.rowTitle')).first);
      expect(themeTitle.left, providerTitle.left);
      // Карточка той же ширины, строки той же минимальной высоты.
      expect(
          _rect(tester, groups.at(2)).left, _rect(tester, groups.at(1)).left);
      expect(
          _rect(tester, groups.at(2)).width, _rect(tester, groups.at(1)).width);
      for (var i = 0; i < 6; i++) {
        expect(
          _rect(tester, _inThemes(_k('page.row')).at(i)).height,
          greaterThanOrEqualTo(kIos27RowMinHeight),
        );
      }
    });

    testWidgets('рамки доски выше группы не сдвинуты', (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);
      // Группа последняя: верх страницы стоит там же, где на доске (appearance-light-rt-p0,
      // с поправкой на строку «Как в системе»).
      final rows = appearanceParity('appearance-light-rt-p0', {
        'page.groupHead': pageKey('page.groupHead'),
        'page.group': pageKey('page.group'),
        'page.row': colorRows(),
      });
      expectIos27Parity(rows);
    });
  });

  group('применение темы', () {
    for (var i = 0; i < themePresets.length; i++) {
      testWidgets(
          '«${_names[i]}»: три слота разом, «Свои» включены, всё перекрашено',
          (tester) async {
        final log = AccentLog();
        await pumpIos27Board(
          tester,
          appearanceApp(brightness: Brightness.light, log: log),
        );
        await openAppearance(tester);
        final container = containerOf(tester);
        expect(container.read(ios27ActiveThemeProvider), isNull);
        final before = container.read(themeSettingProvider);
        expect(before.m3eOwnColorEnabled, isFalse);
        expect(before.m3eOwnColor, isNull);

        await _tapTheme(tester, i);
        final p = themePresets[i];
        final props = container.read(themeSettingProvider);
        expect(props.m3eOwnColorEnabled, isTrue);
        expect(props.m3eOwnColor, 0xFF000000 | (p.accent & 0xFFFFFF));
        expect(props.ios27OwnOrb1, 0xFF000000 | (p.orbPrimary & 0xFFFFFF));
        expect(props.ios27OwnOrb2, 0xFF000000 | (p.orbSecondary & 0xFFFFFF));
        expect(container.read(ios27ActiveThemeProvider), i);

        // Главная за страницей перекрасилась вживую: акцент после подгонки контраста, фоны как есть.
        final accentHex = Ios27Rgb.fromHex(
          '#${(p.accent & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
        );
        expect(log.accent, ios27AccentVars(accentHex.hex).accent(dark: false));
        expect(log.orb1, _preset(p.orbPrimary));
        expect(log.orb2, _preset(p.orbSecondary));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('в тёмной теме акцент берётся тёмный вариант', (tester) async {
      final log = AccentLog();
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.dark, log: log),
      );
      await openAppearance(tester);
      await _tapTheme(tester, 4);
      final p = themePresets[4];
      expect(
        log.accent,
        ios27AccentVars(
          '#${(p.accent & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
        ).accent(dark: true),
      );
    });

    testWidgets('«Падение» (#29FF76) не подменяется голубым семенем Android',
        (tester) async {
      // `M3eOwnColorActions.enable` записал бы в акцент семя Android, где #29FF76 заменён на
      // #38BDF8. Тема пишет свои значения напрямую.
      final log = AccentLog();
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light, log: log),
      );
      await openAppearance(tester);
      await _tapTheme(tester, 0);
      expect(
        containerOf(tester).read(themeSettingProvider).m3eOwnColor,
        0xFF29FF76,
      );
      expect(log.accent, ios27AccentVars('#29FF76').accent(dark: false));
    });

    testWidgets('одна запись: главная перестраивается один раз',
        (tester) async {
      final log = AccentLog();
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light, log: log),
      );
      await openAppearance(tester);
      final before = log.builds;
      await _tapTheme(tester, 2);
      // Три отдельных `pick` перекрасили бы главную тремя ступенями.
      expect(log.builds - before, lessThanOrEqualTo(2));
    });
  });

  group('галочка', () {
    testWidgets('по умолчанию нет; нажатие ставит, другое нажатие переносит',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);
      expect(_checkedThemes(tester), isEmpty);

      await _tapTheme(tester, 1);
      expect(_checkedThemes(tester), [1]);

      await _tapTheme(tester, 5);
      expect(_checkedThemes(tester), [5]);
      expect(containerOf(tester).read(ios27ActiveThemeProvider), 5);
    });

    testWidgets('«Свои» остаются отмеченными, колодцы показывают цвета темы',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);
      await _tapTheme(tester, 3);

      // Отмечены «Свои» (вторая строка «Цветов») и строка темы.
      final ownRow = _rect(tester, colorRows().at(1));
      final colorChecks = pageKey('page.rowCheck').evaluate().length;
      expect(colorChecks, 1, reason: 'галочка на «Свои»');
      final check = tester.getRect(pageKey('page.rowCheck'));
      expect(check.center.dy, closeTo(ownRow.center.dy, 1));
      expect(_checkedThemes(tester), [3]);

      expect(pageKey('page.well'), findsNWidgets(3));
      final p = themePresets[3];
      final wells = tester
          .widgetList<Ios27RowWell>(pageKey('page.well'))
          .map((w) => w.color)
          .toList();
      expect(wells, [
        _preset(p.accent),
        _preset(p.orbPrimary),
        _preset(p.orbSecondary),
      ]);
    });

    testWidgets('«Провайдер» снимает галочку темы, значения не стирает',
        (tester) async {
      final log = AccentLog();
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light, log: log),
      );
      await openAppearance(tester);
      final container = containerOf(tester);
      final providerAccent = log.accent;
      await _tapTheme(tester, 1);
      expect(log.accent, isNot(providerAccent));
      final saved = container.read(themeSettingProvider);

      await _tapText(tester, 'Провайдер');
      expect(_checkedThemes(tester), isEmpty);
      expect(container.read(ios27ActiveThemeProvider), isNull);
      expect(log.accent, providerAccent, reason: 'цвета провайдера вернулись');
      final props = container.read(themeSettingProvider);
      expect(props.m3eOwnColorEnabled, isFalse);
      expect(props.m3eOwnColor, saved.m3eOwnColor);
      expect(props.ios27OwnOrb1, saved.ios27OwnOrb1);
      expect(props.ios27OwnOrb2, saved.ios27OwnOrb2);

      // Вернули «Свои»: сохранённые слоты снова образуют тему, галочка возвращается.
      await _tapText(tester, 'Свои');
      expect(_checkedThemes(tester), [1]);
      expect(container.read(ios27ActiveThemeProvider), 1);
    });

    testWidgets('правка одного слота снимает галочку темы', (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);
      await _tapTheme(tester, 2);
      expect(_checkedThemes(tester), [2]);

      containerOf(tester)
          .read(ios27OwnColorActionsProvider)
          .pick(Ios27ColorSlot.orb1, '#000000');
      await tester.pump();
      expect(_checkedThemes(tester), isEmpty);
      expect(containerOf(tester).read(ios27ActiveThemeProvider), isNull);
      // «Свои» остались включёнными.
      expect(containerOf(tester).read(themeSettingProvider).m3eOwnColorEnabled,
          isTrue);
    });

    testWidgets('повторное открытие страницы хранит выбранную тему',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);
      await _tapTheme(tester, 4);
      expect(_checkedThemes(tester), [4]);

      await tester.tap(_k('page.back'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_k('page'), findsNothing);

      await openAppearance(tester);
      expect(_checkedThemes(tester), [4]);
      expect(pageKey('page.well'), findsNWidgets(3));
    });
  });

  group('названия', () {
    test(
        'все шесть ключей переведены на русский, неизвестный ключ остаётся как есть',
        () async {
      final l10n = await AppLocalizations.load(const Locale('ru'));
      expect(
        [for (final p in themePresets) ios27ThemeName(l10n, p)],
        _names,
      );
      const unknown = ThemePreset(
        'presetUnknown',
        0xFF000000,
        0xFF000000,
        0xFF000000,
      );
      expect(ios27ThemeName(l10n, unknown), 'presetUnknown');
    });
  });

  group('семантика', () {
    testWidgets('кнопки с названием, идентификатором и выбранным состоянием',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);
      await _tapTheme(tester, 1);

      for (var i = 0; i < 6; i++) {
        final finder = find.bySemanticsIdentifier('dw_appearance_theme_$i');
        expect(finder, findsOneWidget, reason: 'тема $i');
        final node = tester.getSemantics(finder);
        final data = node.getSemanticsData();
        expect(data.identifier, 'dw_appearance_theme_$i');
        expect(data.flagsCollection.isButton, isTrue, reason: 'тема $i');
        expect(data.flagsCollection.isEnabled, Tristate.isTrue,
            reason: 'тема $i');
        expect(data.label, contains(_names[i]), reason: 'тема $i');
        if (i == 1) {
          expect(data.flagsCollection.isSelected, Tristate.isTrue);
        } else {
          expect(data.flagsCollection.isSelected, isNot(Tristate.isTrue),
              reason: 'тема $i');
        }
      }
      handle.dispose();
    });
  });

  group('G8: движение', () {
    testWidgets('после применения темы кадров-хвостов нет', (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light),
      );
      await openAppearance(tester);
      await _tapTheme(tester, 2);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('«Уменьшить движение»: тема применяется без кадров-хвостов',
        (tester) async {
      await pumpIos27Board(
        tester,
        appearanceApp(brightness: Brightness.light, disableAnimations: true),
      );
      await openAppearance(tester);
      await _tapTheme(tester, 3);
      await tester.pump(const Duration(milliseconds: 150));
      expect(_checkedThemes(tester), [3]);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('golden', () {
    for (final brightness in Brightness.values) {
      testWidgets(
          'appearance_themes_${brightness.name}_p0: низ страницы, выбрана «Иней»',
          (tester) async {
        await pumpIos27Board(tester, appearanceApp(brightness: brightness));
        await openAppearance(tester);
        await _tapTheme(tester, 1);
        await _scrollToEnd(tester);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        await expectIos27Golden(
            tester, 'appearance_themes_${brightness.name}_p0');
      });
    }
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
          await _tapTheme(tester, 5);
          expect(tester.takeException(), isNull);
          expect(_checkedThemes(tester), [5]);

          // Строки группы целиком по ширине экрана; название и галочка не наезжают друг на друга.
          for (var i = 0; i < 6; i++) {
            final row = _rect(tester, _inThemes(_k('page.row')).at(i));
            expect(row.left, greaterThanOrEqualTo(0));
            expect(row.right, lessThanOrEqualTo(device.size.width + 0.01));
            final title = _rect(tester, find.text(_names[i]));
            expect(title.left, greaterThanOrEqualTo(row.left));
            expect(title.right, lessThanOrEqualTo(row.right));
          }
          final head = _rect(tester, find.text('Темы'));
          expect(head.right, lessThanOrEqualTo(device.size.width + 0.01));
          // Последняя строка достижима прокруткой.
          await tester.ensureVisible(find.text(_names[5]));
          await tester.pump();
          final last = _rect(tester, find.text(_names[5]));
          expect(last.bottom, lessThanOrEqualTo(device.size.height + 0.01));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
