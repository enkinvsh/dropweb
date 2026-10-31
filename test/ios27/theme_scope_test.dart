// Тема iOS-редизайна на уровне скоупа: цвета против эталона доски (G2 на уровне Ios27Colors), яркость,
// «Повышенная контрастность», провайдер темы, цвета для кода над скоупом, текст под «Жирный текст».

import 'dart:convert';
import 'dart:io';

import 'package:dropweb/common/constant.dart';
import 'package:dropweb/models/config.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_source.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/board_providers.dart';

/// ThemeSetting без обращения к globalState: build отдаёт заданные свойства (приём из test/m3e/theme_test.dart).
class _FakeThemeSetting extends ThemeSetting {
  _FakeThemeSetting(this._props);

  final ThemeProps _props;

  @override
  ThemeProps build() => _props;

  // Смена состояния иначе пишет срез в globalState.configRepository, которого в тесте нет.
  @override
  void onUpdate(ThemeProps value) {}
}

Override _themeOverride(ThemeProps props) =>
    themeSettingProvider.overrideWith(() => _FakeThemeSetting(props));

final RegExp _hexRe = RegExp(r'^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$');

/// `#RRGGBB` / `#RRGGBBAA` доски в ARGB: разбор тот же, что в `gate2_colors_test.dart` (альфа последняя).
int _parse(String hex) {
  final m = _hexRe.firstMatch(hex);
  if (m == null) {
    fail('значение "$hex" не похоже на #RRGGBB или #RRGGBBAA');
  }
  final rgb = int.parse(m.group(1)!, radix: 16);
  final a = m.group(2) == null ? 0xFF : int.parse(m.group(2)!, radix: 16);
  return (a << 24) | rgb;
}

String _fmt(int argb) {
  final a = argb >>> 24;
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return a == 0xFF
      ? '#$rgb'.toUpperCase()
      : '#$rgb${a.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
}

Map<String, dynamic> _colorsRef() {
  final path =
      Platform.environment['IOS27_COLORS_JSON'] ?? 'test/ios27/ref/colors.json';
  final file = File(path);
  if (!file.existsSync()) {
    fail(
        'Нет $path: эталон цветов снимает T1 (tool/canon/shoot_board_ios.mjs).');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Показывает дерево `MaterialApp > home` и отдаёт цвета, увиденные из контекста внутри [scope].
Future<Ios27Colors> _colorsIn(
  WidgetTester tester,
  Widget Function(Widget probe) scope, {
  List<Override> overrides = const [],
}) async {
  late Ios27Colors seen;
  final probe = Builder(
    builder: (context) {
      seen = Ios27Colors.of(context);
      return const SizedBox.shrink();
    },
  );
  await tester.pumpWidget(
    ProviderScope(
      // Новый ключ на каждый показ: ProviderScope с тем же ключом не принимает другие overrides,
      // а тесты показывают скоуп несколько раз подряд.
      key: UniqueKey(),
      overrides: overrides,
      child: MaterialApp(home: scope(probe)),
    ),
  );
  return seen;
}

void main() {
  group('цвета скоупа против colors.json доски (допуск 0)', () {
    final ref = _colorsRef();

    for (final scene in ['home-off', 'home-on']) {
      for (final dark in [false, true]) {
        final mode = dark ? 'dark' : 'light';
        final brightness = dark ? Brightness.dark : Brightness.light;

        for (var n = 0; n < kBoardProviders.length; n++) {
          testWidgets('$scene-$mode-p$n (${kBoardProviders[n].name})',
              (tester) async {
            final theme =
                Ios27ProviderTheme.fromHeader(kBoardProviders[n].theme);
            final colors = await _colorsIn(
              tester,
              (probe) => Ios27ThemeScope.explicit(
                theme: theme,
                brightness: brightness,
                highContrast: false,
                child: probe,
              ),
            );
            _expectVarsEqual(
                colors, ref['$scene-$mode-p$n'], '$scene-$mode-p$n');
          });
        }

        // Свой цвет: на доске `PRESETS[k].light` у провайдера 0, орбы остаются провайдерскими.
        for (var k = 0; k < kIos27AccentPresets.length; k++) {
          testWidgets('$scene-$mode-a$k (${kIos27AccentPresets[k].id})',
              (tester) async {
            final theme =
                Ios27ProviderTheme.fromHeader(kBoardProviders.first.theme)
                    .withOwn(accent: kIos27AccentPresets[k].light);
            final colors = await _colorsIn(
              tester,
              (probe) => Ios27ThemeScope.explicit(
                theme: theme,
                brightness: brightness,
                highContrast: false,
                child: probe,
              ),
            );
            _expectVarsEqual(
                colors, ref['$scene-$mode-a$k'], '$scene-$mode-a$k');
          });
        }
      }
    }

    test('в эталоне есть все ключи, которые проверяются выше', () {
      for (final scene in ['home-off', 'home-on']) {
        for (final mode in ['light', 'dark']) {
          for (var n = 0; n < kBoardProviders.length; n++) {
            expect(ref.containsKey('$scene-$mode-p$n'), isTrue,
                reason: '$scene-$mode-p$n');
          }
          for (var k = 0; k < kIos27AccentPresets.length; k++) {
            expect(ref.containsKey('$scene-$mode-a$k'), isTrue,
                reason: '$scene-$mode-a$k');
          }
        }
      }
    });
  });

  group('яркость и контраст', () {
    testWidgets('яркость следует за системой, themeMode не читается',
        (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      const light = ThemeProps(
        primaryColor: defaultPrimaryColor,
        themeMode: ThemeMode.light,
      );
      // Система тёмная, themeMode светлый: идёт система.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      var colors = await _colorsIn(
        tester,
        (probe) => Ios27ThemeScope(child: probe),
        overrides: [_themeOverride(light)],
      );
      expect(colors.brightness, Brightness.dark);
      expect(colors.dark, isTrue);
      expect(identical(colors.palette, Ios27Tokens.dark), isTrue);

      // Система светлая, themeMode тёмный: снова система.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      colors = await _colorsIn(
        tester,
        (probe) => Ios27ThemeScope(child: probe),
        overrides: [
          _themeOverride(
            const ThemeProps(
                primaryColor: defaultPrimaryColor, themeMode: ThemeMode.dark),
          ),
        ],
      );
      expect(colors.brightness, Brightness.light);
      expect(identical(colors.palette, Ios27Tokens.light), isTrue);
    });

    testWidgets('явная яркость перекрывает системную', (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      final colors = await _colorsIn(
        tester,
        (probe) => Ios27ThemeScope.explicit(
          theme: Ios27ProviderTheme.defaults,
          brightness: Brightness.dark,
          child: probe,
        ),
      );
      expect(colors.brightness, Brightness.dark);
    });

    testWidgets('«Повышенная контрастность» берёт набор IncreasedContrast',
        (tester) async {
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      for (final dark in [false, true]) {
        tester.platformDispatcher.platformBrightnessTestValue =
            dark ? Brightness.dark : Brightness.light;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(highContrast: true);
        final colors = await _colorsIn(
          tester,
          (probe) => Ios27ThemeScope.explicit(
            theme: Ios27ProviderTheme.defaults,
            child: probe,
          ),
        );
        expect(colors.highContrast, isTrue);
        expect(
          identical(
            colors.palette,
            dark
                ? Ios27Tokens.darkIncreasedContrast
                : Ios27Tokens.lightIncreasedContrast,
          ),
          isTrue,
        );
        // Контрастный набор отличается от обычного хотя бы красным.
        expect(
          colors.palette.red,
          isNot(Ios27Tokens.palette(dark: dark).red),
        );
      }
    });

    testWidgets('highContrast можно задать явно', (tester) async {
      final colors = await _colorsIn(
        tester,
        (probe) => Ios27ThemeScope.explicit(
          theme: Ios27ProviderTheme.defaults,
          brightness: Brightness.light,
          highContrast: true,
          child: probe,
        ),
      );
      expect(colors.highContrast, isTrue);
      expect(identical(colors.palette, Ios27Tokens.lightIncreasedContrast),
          isTrue);
    });
  });

  group('источник темы из themeSettingProvider', () {
    Ios27ProviderTheme provider(ThemeProps props) {
      final container = ProviderContainer(overrides: [_themeOverride(props)]);
      addTearDown(container.dispose);
      return container.read(ios27ProviderThemeProvider);
    }

    Ios27ProviderTheme result(ThemeProps props) {
      final container = ProviderContainer(overrides: [_themeOverride(props)]);
      addTearDown(container.dispose);
      return container.read(ios27ThemeProvider);
    }

    test('по умолчанию: акцент #29FF76 без подмены, орбы и размытие из свойств',
        () {
      final t = provider(defaultThemeProps);
      expect(t.accent, '#29FF76');
      expect(t.orb1, '#009938');
      expect(t.orb2, '#2BFF7A');
      expect(t.blur, 4);
    });

    test(
        'цвет провайдера не подменяется: #38BDF8 остаётся #38BDF8, #29FF76 тоже',
        () {
      expect(
          provider(defaultThemeProps.copyWith(primaryColor: 0xFF38BDF8)).accent,
          '#38BDF8');
      expect(
          provider(defaultThemeProps.copyWith(primaryColor: 0xFF29FF76)).accent,
          '#29FF76');
    });

    test('пустой акцент берёт defaultPrimaryColor', () {
      expect(provider(defaultThemeProps.copyWith(primaryColor: null)).accent,
          '#29FF76');
    });

    test('пустые орбы следуют за акцентом', () {
      final t = provider(
        defaultThemeProps.copyWith(
          primaryColor: 0xFFA78BFA,
          orbColorPrimary: null,
          orbColorSecondary: null,
        ),
      );
      expect([t.accent, t.orb1, t.orb2], ['#A78BFA', '#A78BFA', '#A78BFA']);
    });

    test('размытие зажато в 1..5, ноль даёт 3 как Number(b) || 3 на доске', () {
      expect(provider(defaultThemeProps.copyWith(orbBlur: 9)).blur, 5);
      expect(provider(defaultThemeProps.copyWith(orbBlur: 0.2)).blur, 1);
      expect(provider(defaultThemeProps.copyWith(orbBlur: 0)).blur, 3);
      expect(provider(defaultThemeProps.copyWith(orbBlur: 2)).blur, 2);
    });

    // Цвета провайдера для тестов слотов фона: акцент, верхний и нижний орб различимы.
    final base = defaultThemeProps.copyWith(
      primaryColor: 0xFFA78BFA,
      orbColorPrimary: 0xFFEC4899,
      orbColorSecondary: 0xFF6366F1,
      orbBlur: 4,
    );

    test('свой акцент без своих орбов: орбы остаются провайдерскими', () {
      final props = base.copyWith(
        m3eOwnColorEnabled: true,
        m3eOwnColor: 0xFFFF2D55,
      );
      final t = result(props);
      expect([t.accent, t.orb1, t.orb2, t.blur],
          ['#FF2D55', '#EC4899', '#6366F1', 4.0]);
      // Провайдерская тема при этом остаётся цветом подписки.
      expect(provider(props).accent, '#A78BFA');
    });

    test('свой цвет выключен или пуст: действует провайдер', () {
      final off = defaultThemeProps.copyWith(
          m3eOwnColorEnabled: false, m3eOwnColor: 0xFFFF2D55);
      final empty = defaultThemeProps.copyWith(
          m3eOwnColorEnabled: true, m3eOwnColor: null);
      expect(result(off).accent, '#29FF76');
      expect(result(empty).accent, '#29FF76');
    });

    test('три слота «Своих»: акцент, фон сверху и фон снизу заменяются вместе',
        () {
      final t = result(base.copyWith(
        m3eOwnColorEnabled: true,
        m3eOwnColor: 0xFFFF2D55,
        ios27OwnOrb1: 0xFF0088FF,
        ios27OwnOrb2: 0xFF34C759,
      ));
      expect([t.accent, t.orb1, t.orb2, t.blur],
          ['#FF2D55', '#0088FF', '#34C759', 4.0]);
    });

    test('задан один орб: второй остаётся орбом провайдера', () {
      final top = result(base.copyWith(
        m3eOwnColorEnabled: true,
        ios27OwnOrb1: 0xFF0088FF,
      ));
      expect(
          [top.accent, top.orb1, top.orb2], ['#A78BFA', '#0088FF', '#6366F1']);
      final bottom = result(base.copyWith(
        m3eOwnColorEnabled: true,
        ios27OwnOrb2: 0xFF34C759,
      ));
      expect([bottom.accent, bottom.orb1, bottom.orb2],
          ['#A78BFA', '#EC4899', '#34C759']);
    });

    test('орбы заданы, но «Свои» выключены: действует провайдер целиком', () {
      final t = result(base.copyWith(
        m3eOwnColorEnabled: false,
        m3eOwnColor: 0xFFFF2D55,
        ios27OwnOrb1: 0xFF0088FF,
        ios27OwnOrb2: 0xFF34C759,
      ));
      expect([t.accent, t.orb1, t.orb2], ['#A78BFA', '#EC4899', '#6366F1']);
    });

    test('«Свои» включены, но ни один слот не задан: ничего не перекрашивается',
        () {
      final t = result(base.copyWith(m3eOwnColorEnabled: true));
      expect([t.accent, t.orb1, t.orb2, t.blur],
          ['#A78BFA', '#EC4899', '#6366F1', 4.0]);
    });

    test('образец «Цвет провайдера» не видит своих орбов', () {
      final props = base.copyWith(
        m3eOwnColorEnabled: true,
        ios27OwnOrb1: 0xFF0088FF,
        ios27OwnOrb2: 0xFF34C759,
      );
      final p = provider(props);
      expect([p.orb1, p.orb2], ['#EC4899', '#6366F1']);
    });

    test('альфа своего цвета отбрасывается: в hex остаются RGB', () {
      final t = result(base.copyWith(
        m3eOwnColorEnabled: true,
        ios27OwnOrb1: 0x800088FF,
      ));
      expect(t.orb1, '#0088FF');
    });

    testWidgets(
        'скоуп на провайдере: акцент из primaryColor, орбы из orbColor*, свой цвет — только акцент',
        (tester) async {
      final props = defaultThemeProps.copyWith(
        primaryColor: 0xFF38BDF8,
        orbColorPrimary: 0xFF6366F1,
        orbColorSecondary: 0xFF22D3EE,
        orbBlur: 3,
      );
      var colors = await _colorsIn(
        tester,
        (probe) => Ios27ThemeScope(child: probe),
        overrides: [_themeOverride(props)],
      );
      expect([colors.theme.accent, colors.theme.orb1, colors.theme.orb2],
          ['#38BDF8', '#6366F1', '#22D3EE']);
      expect(colors.orb1, const Color(0xFF6366F1));
      expect(colors.orb2, const Color(0xFF22D3EE));

      colors = await _colorsIn(
        tester,
        (probe) => Ios27ThemeScope(child: probe),
        overrides: [
          _themeOverride(
            props.copyWith(m3eOwnColorEnabled: true, m3eOwnColor: 0xFFFF2D55),
          ),
        ],
      );
      expect(colors.theme.accent, '#FF2D55');
      expect(colors.orb1, const Color(0xFF6366F1));
      expect(colors.orb2, const Color(0xFF22D3EE));

      // Свои орбы доходят до цветов скоупа, которые читает фон.
      colors = await _colorsIn(
        tester,
        (probe) => Ios27ThemeScope(child: probe),
        overrides: [
          _themeOverride(
            props.copyWith(
              m3eOwnColorEnabled: true,
              m3eOwnColor: 0xFFFF2D55,
              ios27OwnOrb1: 0xFF0088FF,
              ios27OwnOrb2: 0xFF34C759,
            ),
          ),
        ],
      );
      expect(colors.theme.accent, '#FF2D55');
      expect(colors.orb1, const Color(0xFF0088FF));
      expect(colors.orb2, const Color(0xFF34C759));
    });

    testWidgets(
        'смена свойств перерисовывает потомков, зависящих от Ios27Colors',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          _themeOverride(defaultThemeProps.copyWith(primaryColor: 0xFF38BDF8))
        ],
      );
      addTearDown(container.dispose);
      final accents = <String>[];
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Ios27ThemeScope(
              child: Builder(
                builder: (context) {
                  accents.add(Ios27Colors.of(context).theme.accent);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(accents.last, '#38BDF8');
      // Свой цвет включается через тот же провайдер, что и в настройках.
      container.read(themeSettingProvider.notifier).updateState(
            (state) => state.copyWith(
              m3eOwnColorEnabled: true,
              m3eOwnColor: 0xFFFF2D55,
            ),
          );
      await tester.pump();
      expect(accents.last, '#FF2D55');
    });
  });

  group('ThemeProps: поля «Своих» цветов фона iOS', () {
    test('сохранённый раньше JSON без полей читается, поля null', () {
      // Так лежит тема у пользователя, обновившегося с версии до iOS-редизайна.
      // Через jsonEncode: вложенный TextScale иначе остаётся объектом, а не картой.
      final stored = Map<String, Object?>.from(
        jsonDecode(jsonEncode(defaultThemeProps.toJson())) as Map,
      )
        ..remove('ios27OwnOrb1')
        ..remove('ios27OwnOrb2')
        ..['m3eOwnColorEnabled'] = true
        ..['m3eOwnColor'] = 0xFFFF2D55;
      expect(stored.containsKey('ios27OwnOrb1'), isFalse);
      final props = ThemeProps.safeFromJson(stored);
      expect(props.ios27OwnOrb1, isNull);
      expect(props.ios27OwnOrb2, isNull);
      // Остальное не пострадало и не откатилось к умолчанию.
      expect(props.m3eOwnColorEnabled, isTrue);
      expect(props.m3eOwnColor, 0xFFFF2D55);
    });

    test('пустой JSON и null дают умолчания, а не падение', () {
      expect(ThemeProps.safeFromJson(<String, Object?>{}).ios27OwnOrb1, isNull);
      expect(ThemeProps.safeFromJson(null), defaultThemeProps);
    });

    test('значения переживают круг toJson, jsonEncode, fromJson', () {
      final src = defaultThemeProps.copyWith(
        m3eOwnColorEnabled: true,
        ios27OwnOrb1: 0xFF0088FF,
        ios27OwnOrb2: 0xFF34C759,
      );
      final json = jsonDecode(jsonEncode(src.toJson())) as Map<String, Object?>;
      final back = ThemeProps.safeFromJson(json);
      expect(back.ios27OwnOrb1, 0xFF0088FF);
      expect(back.ios27OwnOrb2, 0xFF34C759);
      expect(back, src);
    });

    test('по умолчанию поля пусты, значение не попадает в умолчания', () {
      expect(defaultThemeProps.ios27OwnOrb1, isNull);
      expect(defaultThemeProps.ios27OwnOrb2, isNull);
    });
  });

  group('Ios27Colors и содержимое скоупа', () {
    testWidgets(
        'в скоупе есть Theme, текст по умолчанию, значки и палитра стекла',
        (tester) async {
      late BuildContext inner;
      await tester.pumpWidget(
        MaterialApp(
          home: Ios27ThemeScope.explicit(
            theme: Ios27ProviderTheme.fromHeader(kBoardProviders[1].theme),
            brightness: Brightness.dark,
            highContrast: false,
            child: Builder(
              builder: (context) {
                inner = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      final colors = Ios27Colors.of(inner);
      final theme = Theme.of(inner);
      expect(theme.platform, TargetPlatform.iOS);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, colors.accentColor);
      expect(theme.colorScheme.onPrimary, colors.onAccent);
      expect(theme.colorScheme.surface, colors.palette.bg);
      expect(theme.colorScheme.onSurface, colors.palette.label);
      expect(theme.colorScheme.outline, colors.palette.separator);
      expect(theme.colorScheme.error, colors.palette.red);
      expect(theme.scaffoldBackgroundColor, colors.palette.bg);
      expect(theme.splashFactory, NoSplash.splashFactory);
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Onest');
      expect(theme.textTheme.bodyMedium?.fontFamilyFallback, ['Twemoji']);

      final text = DefaultTextStyle.of(inner).style;
      expect(text.color, colors.palette.label);
      expect(text.fontSize, Ios27Text.body.size);
      expect(text.fontWeight, FontWeight.w400);
      expect(IconTheme.of(inner).color, colors.palette.label);

      final glass = Ios27GlassColors.maybeOf(inner);
      expect(glass, isNotNull);
      expect(glass!.brightness, Brightness.dark);
      expect(glass.dark, colors.glassPalette);
    });

    testWidgets('textScaler предка скоуп игнорирует: берёт системный',
        (tester) async {
      late TextScaler seen;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.7)),
            child: child!,
          ),
          home: Ios27ThemeScope.explicit(
            theme: Ios27ProviderTheme.defaults,
            child: Builder(
              builder: (context) {
                seen = MediaQuery.textScalerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      // Предок (как ThemeManager с настройкой TextScale) просит 1.7, но внутри
      // скоупа действует системный масштаб; в тесте платформа отдаёт 1.0.
      // Подробности и граничные случаи: text_scale_test.dart.
      expect(seen.scale(10), closeTo(10, 1e-9));
    });

    test('vars: 28 имён, палитра ∪ акцент', () {
      final colors = Ios27Colors.from(
        theme: Ios27ProviderTheme.defaults,
        brightness: Brightness.light,
        child: const SizedBox.shrink(),
      );
      expect(colors.vars, hasLength(28));
      expect(
        colors.vars.keys.toSet(),
        {
          ...colors.palette.toVars().keys,
          '--accent',
          '--on-accent',
          '--accent-soft',
          '--orb1',
          '--orb2',
        },
      );
      expect(colors.vars['--accent'], const Color(0xFF1AA34C));
      expect(colors.vars['--on-accent'], const Color(0xFFFFFFFF));
      expect(colors.vars['--accent-soft'], const Color(0x1F1AA34C));
    });

    test('updateShouldNotify сравнивает по значению', () {
      Ios27Colors make(String accent,
              {Brightness b = Brightness.light, bool hc = false}) =>
          Ios27Colors.from(
            theme: Ios27ProviderTheme.defaults.withOwn(accent: accent),
            brightness: b,
            highContrast: hc,
            child: const SizedBox.shrink(),
          );
      final base = make('#29FF76');
      expect(base.updateShouldNotify(make('#29FF76')), isFalse);
      expect(base.updateShouldNotify(make('#FF2D55')), isTrue);
      expect(
          base.updateShouldNotify(make('#29FF76', b: Brightness.dark)), isTrue);
      expect(base.updateShouldNotify(make('#29FF76', hc: true)), isTrue);
    });

    test('палитра стекла: заливка из токенов равна константе T3a', () {
      // Если токены поменяются, а константа T3a нет, стекло-заглушка разойдётся с доской.
      expect(ios27GlassPaletteFor(dark: false), Ios27GlassPalette.light);
      expect(ios27GlassPaletteFor(dark: true), Ios27GlassPalette.dark);
      expect(Ios27Tokens.glass(dark: false).base.opaque,
          Ios27GlassPalette.light.fill);
      expect(Ios27Tokens.glass(dark: true).base.opaque,
          Ios27GlassPalette.dark.fill);
    });

    testWidgets('Ios27Colors.of без скоупа падает с пояснением',
        (tester) async {
      late BuildContext outside;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              outside = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(Ios27Colors.maybeOf(outside), isNull);
      expect(
        () => Ios27Colors.of(outside),
        throwsA(
          isA<AssertionError>()
              .having((e) => e.message, 'message', contains('ios27ColorsFor')),
        ),
      );
    });
  });

  group('ios27ColorsFor', () {
    testWidgets(
        'над скоупом (корневой Navigator) строит цвета из провайдера и системы',
        (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _themeOverride(
                defaultThemeProps.copyWith(primaryColor: 0xFF38BDF8)),
          ],
          child: const MaterialApp(home: SizedBox.shrink()),
        ),
      );
      // Контекст Navigator выше любого Ios27ThemeScope: так открываются диалоги и тосты.
      final root = tester.element(find.byType(Navigator).first);
      expect(Ios27Colors.maybeOf(root), isNull);

      final colors = ios27ColorsFor(root);
      expect(colors.theme.accent, '#38BDF8');
      expect(colors.brightness, Brightness.dark);
      expect(colors.palette.label, Ios27Tokens.dark.label);
    });

    testWidgets('внутри скоупа возвращает его же цвета', (tester) async {
      late Ios27Colors viaOf;
      late Ios27Colors viaFor;
      await tester.pumpWidget(
        MaterialApp(
          home: Ios27ThemeScope.explicit(
            theme: Ios27ProviderTheme.defaults,
            brightness: Brightness.light,
            child: Builder(
              builder: (context) {
                viaOf = Ios27Colors.of(context);
                viaFor = ios27ColorsFor(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(identical(viaOf, viaFor), isTrue);
    });
  });

  group('ios27Text и «Жирный текст»', () {
    test('ios27BoldWeight: на 200 тяжелее, не выше w700', () {
      expect(ios27BoldWeight(FontWeight.w300), FontWeight.w500);
      expect(ios27BoldWeight(FontWeight.w400), FontWeight.w600);
      expect(ios27BoldWeight(FontWeight.w500), FontWeight.w700);
      expect(ios27BoldWeight(FontWeight.w600), FontWeight.w700);
      expect(ios27BoldWeight(FontWeight.w700), FontWeight.w700);
    });

    Future<TextStyle> styleIn(
      WidgetTester tester,
      Ios27TextRole role, {
      required bool bold,
      Color? color,
    }) async {
      late TextStyle style;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(boldText: bold),
            child: child!,
          ),
          home: Ios27ThemeScope.explicit(
            theme: Ios27ProviderTheme.defaults,
            brightness: Brightness.light,
            child: Builder(
              builder: (context) {
                style = ios27Text(context, role, color: color);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return style;
    }

    testWidgets('без Bold Text вес роли и цвет --label', (tester) async {
      final body = await styleIn(tester, Ios27Text.body, bold: false);
      expect(body.fontWeight, FontWeight.w400);
      expect(body.color, Ios27Tokens.light.label);
      expect(body.fontSize, 17);
      expect(body.fontFamily, 'Onest');
      expect(body.fontFamilyFallback, ['Twemoji']);
    });

    testWidgets('Bold Text поднимает вес на 200 с потолком w700',
        (tester) async {
      expect((await styleIn(tester, Ios27Text.body, bold: true)).fontWeight,
          FontWeight.w600);
      expect((await styleIn(tester, Ios27Text.headline, bold: true)).fontWeight,
          FontWeight.w700);
      expect((await styleIn(tester, Ios27Text.title1, bold: true)).fontWeight,
          FontWeight.w700);
    });

    testWidgets('явный цвет перекрывает --label', (tester) async {
      const red = Color(0xFFAA0000);
      final s =
          await styleIn(tester, Ios27Text.callout, bold: false, color: red);
      expect(s.color, red);
    });
  });
}

void _expectVarsEqual(Ios27Colors colors, Object? refEntry, String key) {
  expect(refEntry, isNotNull, reason: 'в colors.json нет записи $key');
  final ref = {
    for (final e in (refEntry! as Map<String, dynamic>).entries)
      e.key: _parse(e.value as String),
  };
  final ours = {
    for (final e in colors.vars.entries) e.key: e.value.toARGB32(),
  };
  expect(ours.keys.toSet(), ref.keys.toSet(),
      reason: '$key: наборы имён свойств');
  final bad = <String>[
    for (final name in ref.keys)
      if (ours[name] != ref[name])
        '$name: доска ${_fmt(ref[name]!)}, Dart ${_fmt(ours[name]!)}',
  ];
  expect(bad, isEmpty, reason: key);
}
