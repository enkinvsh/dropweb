import 'dart:convert';
import 'dart:io';

import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/screens/m3e_appearance.dart';
import 'package:dropweb/ui/m3e/screens/m3e_color_sheet.dart';
import 'package:dropweb/ui/m3e/theme/m3e_own_color.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

/// Подмена `ThemeSetting`: оригинальный `build` читает `globalState`, которого в тесте нет,
/// а `onUpdate` пишет в репозиторий конфига.
class _Theme extends ThemeSetting {
  _Theme(this.props);

  final ThemeProps props;

  @override
  ThemeProps build() => props;

  @override
  void onUpdate(ThemeProps value) {}
}

class _App extends AppSetting {
  @override
  AppSettingProps build() => const AppSettingProps();

  @override
  void onUpdate(AppSettingProps value) {}
}

/// Подписка провайдера [p] в `ThemeProps`, как её пишет разбор `dropweb-theme`.
ThemeProps _props(int p, {bool own = false, int? ownColor}) {
  final h = parseDropwebTheme(kBoardProviders[p].theme);
  return ThemeProps(
    primaryColor: argbFromHexOrNull(h.accent),
    m3eOwnColorEnabled: own,
    m3eOwnColor: ownColor,
  );
}

List<Override> _overrides(ThemeProps props, {int? board}) => [
      themeSettingProvider.overrideWith(() => _Theme(props)),
      // Цвет провайдера задаём прямо: DROPWEB присылает `#29FF76`, а `m3eSeedFor`
      // принимает его за «акцент не задан» и подставляет голубой цвет по умолчанию.
      if (board != null)
        m3eProviderSourceProvider.overrideWithValue(
          M3eThemeSource(
            seed: parseDropwebTheme(kBoardProviders[board].theme).accent,
            filter: parseDropwebTheme(kBoardProviders[board].theme).filter,
          ),
        ),
      appSettingProvider.overrideWith(_App.new),
    ];

/// Эталоны сняты с reducedMotion: те же условия.
Widget _page() => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: const M3eAppearancePage(),
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  int p,
  Brightness brightness,
  ThemeProps props, {
  bool board = true,
}) async {
  final h = parseDropwebTheme(kBoardProviders[p].theme);
  await pumpM3eBoard(
    tester,
    m3eBoardApp(
      seed: h.accent,
      filter: h.filter,
      brightness: brightness,
      overrides: _overrides(props, board: board ? p : null),
      child: _page(),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  unawaited_(showM3eColorSheet(tester.element(find.byType(M3eAppearancePage))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void unawaited_(Future<void> f) {}

Map<String, dynamic> _elements(String scene) {
  final all = jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
      as Map<String, dynamic>;
  return (all[scene] as Map<String, dynamic>)['elements']
      as Map<String, dynamic>;
}

Rect _ref(String scene, String key, [int index = 0]) {
  var e = _elements(scene)[key];
  if (e is List) e = e[index];
  final m = e as Map<String, dynamic>;
  return Rect.fromLTWH(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['w'] as num).toDouble(),
    (m['h'] as num).toDouble(),
  );
}

Rect _rect(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(ValueKey<String>(key)));

void _near(Rect actual, Rect expected, String what) {
  const tolerance = 4.0;
  expect(actual.left, closeTo(expected.left, tolerance), reason: '$what: x');
  expect(actual.top, closeTo(expected.top, tolerance), reason: '$what: y');
  expect(actual.width, closeTo(expected.width, tolerance), reason: '$what: w');
  expect(actual.height, closeTo(expected.height, tolerance),
      reason: '$what: h');
}

Brightness _b(String theme) =>
    theme == 'dark' ? Brightness.dark : Brightness.light;

ProviderContainer _container(ThemeProps props) {
  final c = ProviderContainer(overrides: _overrides(props));
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('golden', () {
    for (final p in [0, 5]) {
      for (final theme in ['light', 'dark']) {
        testWidgets('appearance_${theme}_p$p', (tester) async {
          await _pump(tester, p, _b(theme), _props(p));
          await expectM3eGolden(tester, 'appearance_${theme}_p$p');
        });
        testWidgets('colors_${theme}_p$p', (tester) async {
          // Сцена доски `colors`: свой цвет включён и равен акценту провайдера.
          final accent = argbFromHexOrNull(
            parseDropwebTheme(kBoardProviders[p].theme).accent,
          )!;
          await _pump(
            tester,
            p,
            _b(theme),
            _props(p, own: true, ownColor: accent),
          );
          await _openSheet(tester);
          await expectM3eGolden(tester, 'colors_${theme}_p$p');
        });
      }
    }
  });

  group('паритет с layout.json (±4 dp)', () {
    for (final p in [0, 5]) {
      for (final theme in ['light', 'dark']) {
        testWidgets('appearance-$theme-p$p', (tester) async {
          final scene = 'appearance-$theme-p$p';
          await _pump(tester, p, _b(theme), _props(p));
          _near(_rect(tester, 'm3e.bar'), _ref(scene, 'bar'), 'bar');
          _near(_rect(tester, 'm3e.bar.back'), _ref(scene, 'bar.back'),
              'bar.back');
          _near(_rect(tester, 'm3e.page.title'), _ref(scene, 'page.title'),
              'page.title');
          // Под страницей лежат «Настройки»: у `list` две записи, у `list.item`
          // пять; страница «Оформление» — вторая и пункты 3, 4.
          _near(_rect(tester, 'm3e.list'), _ref(scene, 'list', 1), 'list');
          for (var i = 0; i < 2; i++) {
            _near(_rect(tester, 'm3e.list.item.$i'),
                _ref(scene, 'list.item', 3 + i), 'list.item.$i');
          }
          final dot = find.descendant(
            of: find.byKey(const ValueKey('m3e.list.item.0')),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  (w.decoration as BoxDecoration).gradient is SweepGradient,
            ),
          );
          _near(tester.getRect(dot), _ref(scene, 'swatch'), 'swatch');
        });
        testWidgets('colors-$theme-p$p', (tester) async {
          final scene = 'colors-$theme-p$p';
          final accent = argbFromHexOrNull(
            parseDropwebTheme(kBoardProviders[p].theme).accent,
          )!;
          await _pump(
            tester,
            p,
            _b(theme),
            _props(p, own: true, ownColor: accent),
          );
          await _openSheet(tester);
          _near(_rect(tester, 'm3e.scrim'), _ref(scene, 'scrim'), 'scrim');
          _near(_rect(tester, 'm3e.sheet'), _ref(scene, 'sheet'), 'sheet');
          _near(_rect(tester, 'm3e.sheet.title'), _ref(scene, 'sheet.title'),
              'sheet.title');
          _near(_rect(tester, 'm3e.swatches'), _ref(scene, 'swatches'),
              'swatches');
          for (var i = 0; i < 30; i++) {
            _near(_rect(tester, 'm3e.swatch.$i'), _ref(scene, 'swatch', i),
                'swatch.$i');
          }
        });
      }
    }
  });

  group('палитра', () {
    test('30 оттенков и 9 основных, все разные', () {
      expect(m3eColorGrid.length, 30);
      expect(m3eColorGrid.toSet().length, 30);
      expect(m3eSeedColors.length, 9);
      expect(m3eSeedColors.toSet().length, 9);
    });
  });

  group('свой цвет', () {
    test('старый конфиг без полей читается', () {
      final old = Map<String, Object?>.of(
        jsonDecode(jsonEncode(const ThemeProps().toJson()))
            as Map<String, Object?>,
      )
        ..remove('m3eOwnColorEnabled')
        ..remove('m3eOwnColor');
      final props = ThemeProps.fromJson(old);
      expect(props.m3eOwnColorEnabled, isFalse);
      expect(props.m3eOwnColor, isNull);
      final back = ThemeProps.fromJson(
        jsonDecode(
          jsonEncode(
            const ThemeProps(m3eOwnColorEnabled: true, m3eOwnColor: 0xFFAA5533)
                .toJson(),
          ),
        ) as Map<String, Object?>,
      );
      expect(back.m3eOwnColorEnabled, isTrue);
      expect(back.m3eOwnColor, 0xFFAA5533);
    });

    test('свой цвет побеждает провайдера и переживает смену подписки', () {
      final c = _container(_props(1));
      expect(c.read(m3eThemeSourceProvider).seed, '#38BDF8');
      c.read(m3eOwnColorActionsProvider).pick(0xAA5533);
      expect(
        c.read(m3eThemeSourceProvider),
        const M3eThemeSource(seed: '#AA5533', filter: 'fidelity'),
      );
      // Обновление профиля с другим `dropweb-theme` пишет только primaryColor.
      final next = argbFromHexOrNull('#EF4444')!;
      c.read(themeSettingProvider.notifier).updateState(
            (t) => t.copyWith(primaryColor: next),
          );
      expect(c.read(m3eThemeSourceProvider).seed, '#AA5533');
      expect(c.read(m3eOwnColorEnabledProvider), isTrue);
      // Возврат к цвету провайдера: берётся новый акцент, свой цвет остаётся сохранённым.
      c.read(m3eOwnColorActionsProvider).useProvider();
      expect(c.read(m3eThemeSourceProvider).seed, '#EF4444');
      expect(c.read(m3eOwnColorProvider), 0xFFAA5533);
      // Повторное включение берёт сохранённый цвет, а не акцент подписки.
      c.read(m3eOwnColorActionsProvider).enable();
      expect(c.read(m3eThemeSourceProvider).seed, '#AA5533');
    });

    test('первое включение берёт акцент подписки', () {
      final c = _container(_props(2));
      c.read(m3eOwnColorActionsProvider).enable();
      expect(c.read(m3eOwnColorProvider), 0xFFA78BFA);
      expect(c.read(m3eThemeSourceProvider).seed, '#A78BFA');
    });

    test('масштаб текста включён по умолчанию, сохранённое false не трогаем',
        () {
      expect(const TextScale().enable, isTrue);
      expect(const TextScale().scale, 1.0);
      // Новая установка и старый JSON без поля.
      expect(TextScale.fromJson(const {}).enable, isTrue);
      final old = ThemeProps.fromJson(
        jsonDecode(
          jsonEncode(const ThemeProps().toJson()..remove('textScale')),
        ) as Map<String, Object?>,
      );
      expect(old.textScale.enable, isTrue);
      // Явно сохранённое выключение без миграции остаётся выключенным.
      expect(TextScale.fromJson(const {'enable': false}).enable, isFalse);
    });

    testWidgets('страница: пункта лого нет, масштаб включён и со слайдером',
        (tester) async {
      await _pump(tester, 0, Brightness.light, _props(0));
      expect(find.byKey(const ValueKey('m3e.extras.logo')), findsNothing);
      expect(
          find.byKey(const ValueKey('m3e.extras.textScale')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('m3e.extras.textScale.slider')),
        findsOneWidget,
      );
    });

    testWidgets('выбор образца перекрашивает схему', (tester) async {
      await _pump(tester, 0, Brightness.light, _props(0), board: false);
      M3eColors colors() => M3eColors.of(
            tester.element(find.byKey(const ValueKey('m3e.list'))),
          );
      final before = colors().scheme.hex('primaryContainer');
      expect(find.byKey(kM3ePaletteKey), findsNothing);
      await tester.tap(find.byKey(const ValueKey('m3e.list.item.1')));
      await tester.pump();
      expect(find.byKey(kM3ePaletteKey), findsOneWidget);
      await tester.tap(find.byKey(m3ePaletteSwatchKey(6)));
      await tester.pump();
      final seed = _hexUpper(m3eSeedColors[6]);
      expect(
        colors().scheme.hex('primaryContainer'),
        scheme(seed, 'fidelity', dark: false).hex('primaryContainer'),
      );
      expect(colors().scheme.hex('primaryContainer'), isNot(before));
      // Назад к провайдеру: схема возвращается.
      await tester.tap(find.byKey(const ValueKey('m3e.list.item.0')));
      await tester.pump();
      expect(colors().scheme.hex('primaryContainer'), before);
      expect(find.byKey(kM3ePaletteKey), findsNothing);
    });

    testWidgets('выбор в листе записывается и отмечает образец',
        (tester) async {
      await _pump(tester, 0, Brightness.dark, _props(0), board: false);
      await tester.tap(find.byKey(const ValueKey('m3e.list.item.1')));
      await tester.pump();
      // Десятый образец открывает лист «Другой цвет».
      await tester.tap(
        find.byKey(m3ePaletteSwatchKey(m3eSeedColors.length)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('m3e.swatches')), findsOneWidget);
      await tester.tap(find.byKey(m3eColorSwatchKey(3)));
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('m3e.swatches'))),
      );
      expect(
        container.read(m3eOwnColorProvider)! & 0xFFFFFF,
        m3eColorGrid[3],
      );
      expect(container.read(m3eOwnColorEnabledProvider), isTrue);
    });
  });
}

String _hexUpper(int rgb) => m3eHexOf(rgb);
