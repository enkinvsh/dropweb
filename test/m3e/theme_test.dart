import 'package:dropweb/common/constant.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/config.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/theme/m3e_flex.dart';
import 'package:dropweb/ui/m3e/theme/m3e_text.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_source.dart';
import 'package:dropweb/ui/m3e/theme/tokens.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/fonts.dart';
import 'support/golden.dart';
import 'support/surface.dart';

String _hex(Color c) {
  String two(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${two(c.r)}${two(c.g)}${two(c.b)}';
}

/// Роли ColorScheme под теми же именами, что в [m3eRoleNames].
Map<String, Color> _byRole(ColorScheme c) => {
      'primary': c.primary,
      'onPrimary': c.onPrimary,
      'primaryContainer': c.primaryContainer,
      'onPrimaryContainer': c.onPrimaryContainer,
      'inversePrimary': c.inversePrimary,
      'secondary': c.secondary,
      'onSecondary': c.onSecondary,
      'secondaryContainer': c.secondaryContainer,
      'onSecondaryContainer': c.onSecondaryContainer,
      'tertiary': c.tertiary,
      'onTertiary': c.onTertiary,
      'tertiaryContainer': c.tertiaryContainer,
      'onTertiaryContainer': c.onTertiaryContainer,
      'error': c.error,
      'onError': c.onError,
      'errorContainer': c.errorContainer,
      'onErrorContainer': c.onErrorContainer,
      // ignore: deprecated_member_use
      'background': c.background,
      // ignore: deprecated_member_use
      'onBackground': c.onBackground,
      'surface': c.surface,
      'onSurface': c.onSurface,
      // ignore: deprecated_member_use
      'surfaceVariant': c.surfaceVariant,
      'onSurfaceVariant': c.onSurfaceVariant,
      'surfaceDim': c.surfaceDim,
      'surfaceBright': c.surfaceBright,
      'surfaceContainerLowest': c.surfaceContainerLowest,
      'surfaceContainerLow': c.surfaceContainerLow,
      'surfaceContainer': c.surfaceContainer,
      'surfaceContainerHigh': c.surfaceContainerHigh,
      'surfaceContainerHighest': c.surfaceContainerHighest,
      'inverseSurface': c.inverseSurface,
      'inverseOnSurface': c.onInverseSurface,
      'outline': c.outline,
      'outlineVariant': c.outlineVariant,
      'scrim': c.scrim,
      'shadow': c.shadow,
      'surfaceTint': c.surfaceTint,
    };

/// ThemeSetting без обращения к globalState: build отдаёт заданные свойства.
class _FakeThemeSetting extends ThemeSetting {
  _FakeThemeSetting(this._props);

  final ThemeProps _props;

  @override
  ThemeProps build() => _props;
}

String _seedOf(BoardProvider p) => parseDropwebTheme(p.theme).accent;

void main() {
  setUpAll(loadM3eFonts);

  group('ColorScheme из схемы доски', () {
    for (final p in kBoardProviders) {
      for (final dark in [false, true]) {
        test('${p.name} ${dark ? 'dark' : 'light'}: все роли hex-в-hex', () {
          final header = parseDropwebTheme(p.theme);
          final s = scheme(header.accent, header.filter, dark: dark);
          final theme = m3eThemeData(
            s,
            brightness: dark ? Brightness.dark : Brightness.light,
          );
          final roles = _byRole(theme.colorScheme);
          expect(roles.keys.toSet(), m3eRoleNames.toSet());
          expect(roles.length, 37);
          for (final name in m3eRoleNames) {
            expect(_hex(roles[name]!), s.hex(name), reason: name);
          }
          expect(theme.colorScheme.brightness,
              dark ? Brightness.dark : Brightness.light);
          expect(theme.useMaterial3, isTrue);
        });
      }
    }
  });

  group('фильтр схемы из DynamicSchemeVariant', () {
    const expected = {
      DynamicSchemeVariant.tonalSpot: 'tonal_spot',
      DynamicSchemeVariant.vibrant: 'vibrant',
      DynamicSchemeVariant.expressive: 'expressive',
      DynamicSchemeVariant.neutral: 'neutral',
      DynamicSchemeVariant.fidelity: 'fidelity',
      DynamicSchemeVariant.content: 'fidelity',
      DynamicSchemeVariant.rainbow: 'fidelity',
      DynamicSchemeVariant.fruitSalad: 'fidelity',
      DynamicSchemeVariant.monochrome: 'fidelity',
    };

    test('покрыты все значения enum', () {
      expect(expected.keys.toSet(), DynamicSchemeVariant.values.toSet());
    });

    for (final e in expected.entries) {
      test('${e.key.name} -> ${e.value}', () {
        expect(m3eFilterFor(e.key), e.value);
      });
    }

    test('seed из primaryColor', () {
      // Дефолт приложения (null и 0xFF29FF76) — «Голубой» доски, решение владельца 2026-10-29.
      expect(m3eSeedFor(null), '#38BDF8');
      expect(m3eSeedFor(defaultPrimaryColor), '#38BDF8');
      expect(m3eSeedFor(0xFF29FF76), '#38BDF8');
      expect(m3eSeedFor(0xFFEF4444), '#EF4444');
      expect(m3eSeedFor(0xFF0000FF), '#0000FF');
      expect(m3eSeedFor(0x80123456), '#123456');
    });

    test('дефолт совпадает с провайдером «Голубой» доски', () {
      final header = parseDropwebTheme(kBoardProviders[1].theme);
      expect(header.accent, m3eDefaultSeed);
      expect(header.filter, 'fidelity');
      expect(m3eFilterFor(const ThemeProps().schemeVariant), header.filter);
    });
  });

  group('m3eThemeSourceProvider', () {
    M3eThemeSource read(ThemeProps props) {
      final c = ProviderContainer(overrides: [
        themeSettingProvider.overrideWith(() => _FakeThemeSetting(props)),
      ]);
      addTearDown(c.dispose);
      return c.read(m3eThemeSourceProvider);
    }

    test('конфиг по умолчанию -> «Голубой» fidelity', () {
      expect(
        read(defaultThemeProps),
        const M3eThemeSource(seed: '#38BDF8', filter: 'fidelity'),
      );
    });

    test('акцент провайдера подписки сохраняется', () {
      expect(
        read(defaultThemeProps.copyWith(
          primaryColor: 0xFFEF4444,
          schemeVariant: DynamicSchemeVariant.vibrant,
        )),
        const M3eThemeSource(seed: '#EF4444', filter: 'vibrant'),
      );
    });
  });

  group('M3eThemeScope', () {
    testWidgets('яркость из платформы, схема доски в M3eColors', (t) async {
      final p = kBoardProviders[5];
      for (final dark in [false, true]) {
        t.platformDispatcher.platformBrightnessTestValue =
            dark ? Brightness.dark : Brightness.light;
        late M3eColors colors;
        late ThemeData theme;
        await t.pumpWidget(
          MaterialApp(
            home: M3eThemeScope.explicit(
              seed: _seedOf(p),
              filter: 'fidelity',
              child: Builder(
                builder: (context) {
                  colors = M3eColors.of(context);
                  theme = Theme.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        final s = scheme(_seedOf(p), 'fidelity', dark: dark);
        expect(colors.brightness, dark ? Brightness.dark : Brightness.light);
        expect(identical(colors.scheme, s), isTrue);
        expect(_hex(theme.colorScheme.primary), s.hex('primary'));
        expect(colors.home.hex('bg'),
            homeVars(_seedOf(p), 'fidelity', dark: dark).hex('bg'));
      }
      t.platformDispatcher.clearPlatformBrightnessTestValue();
    });
  });

  group('шрифты Roboto Flex', () {
    test('opsz равен кеглю, wght и wdth по android.css', () {
      double axis(TextStyle s, String name) =>
          s.fontVariations!.firstWhere((v) => v.axis == name).value;
      final timer = M3eFlex.cardTimer();
      expect(timer.fontSize, 17);
      expect(timer.height, closeTo(22 / 17, 1e-9));
      expect(axis(timer, 'wght'), 520);
      expect(axis(timer, 'wdth'), 118);
      expect(axis(timer, 'opsz'), 17);
      expect(timer.fontFeatures, contains(const FontFeature.tabularFigures()));
      final v = M3eFlex.statValue();
      expect(axis(v, 'wght'), 680);
      expect(axis(v, 'wdth'), 108);
      final long = M3eFlex.statValueLong(fontSize: 12.5);
      expect(axis(long, 'wdth'), 84);
      expect(axis(long, 'opsz'), 12.5);
      expect(long.letterSpacing, -0.1);
      expect(long.height, closeTo(22 / 12.5, 1e-9));
      expect(M3eFlex.cardName().fontFamily, 'RobotoFlex');
      expect(M3eFlex.cardLine().fontFeatures, isNull);
    });

    test('brand-роли в Onest, остальные в Roboto', () {
      expect(m3eTextStyle(M3eType.headlineMedium).fontFamily, 'Onest');
      expect(m3eTextStyle(M3eType.titleLarge).fontFamily, 'Onest');
      expect(m3eTextStyle(M3eType.titleMedium).fontFamily, 'Roboto');
      expect(m3eTextStyle(M3eType.bodyMedium).fontFamily, 'Roboto');
      expect(m3eTextStyle(M3eType.bodyMedium).fontFamilyFallback,
          contains('Twemoji'));
    });
  });

  group('golden: типошкала и стили Roboto Flex', () {
    for (final dark in [false, true]) {
      testWidgets('theme_type_${dark ? 'dark' : 'light'}_p0', (t) async {
        final header = parseDropwebTheme(kBoardProviders[0].theme);
        await pumpM3eBoard(
          t,
          m3eBoardApp(
            seed: header.accent,
            filter: header.filter,
            brightness: dark ? Brightness.dark : Brightness.light,
            child: const _TypeSheet(),
          ),
        );
        await expectM3eGolden(t, 'theme_type_${dark ? 'dark' : 'light'}_p0');
      });
    }
  });
}

class _TypeSheet extends StatelessWidget {
  const _TypeSheet();

  @override
  Widget build(BuildContext context) {
    final s = M3eColors.of(context).scheme;
    final t = Theme.of(context).textTheme;
    final ink = s.onSurface;
    final ink2 = s.onSurfaceVariant;
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 2),
          child: Text(text, style: t.labelSmall!.copyWith(color: s.primary)),
        );
    return ColoredBox(
      color: s.surface,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(16, kM3eStatusBar + 8, 16, kM3eNavBar),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label('Onest: headlineMedium 28/36'),
            Text('Подключено', style: t.headlineMedium!.copyWith(color: ink)),
            label('Onest: titleLarge 22/28'),
            Text('Мои подписки', style: t.titleLarge!.copyWith(color: ink)),
            label('Roboto: titleMedium 500 / bodyLarge 400 / bodyMedium'),
            Text('Маршрут и серверы',
                style: t.titleMedium!.copyWith(color: ink)),
            Text('IP-адрес 203.0.113.7',
                style: t.bodyLarge!.copyWith(color: ink)),
            Text('Трафик 0,28 ГБ, пинг 44 мс',
                style: t.bodyMedium!.copyWith(color: ink2)),
            Text('Emphasized label 700',
                style: m3eTextStyle(M3eType.labelLargeEmphasized, color: ink)),
            label('Roboto Flex: cardName 17/22 w620'),
            Text('DROPWEB', style: M3eFlex.cardName(color: ink)),
            label('Roboto Flex: cardLine 15/20 w450'),
            Text('Безлимит, без срока', style: M3eFlex.cardLine(color: ink2)),
            label('Roboto Flex: cardTimer wdth118, tabular'),
            Text('12:48 11:11', style: M3eFlex.cardTimer(color: ink2)),
            label('Roboto Flex: statKey 13/18 w500'),
            Text('Трафик', style: M3eFlex.statKey(color: ink2)),
            label('Roboto Flex: statValue w680 wdth108'),
            Text('0,28 ГБ  44 мс  11111', style: M3eFlex.statValue(color: ink)),
            label('Roboto Flex: statValueLong wdth84'),
            Text('2001:db8:85a3::8a2e:370:7334',
                style: M3eFlex.statValueLong(fontSize: 14, color: ink)),
            label('Twemoji'),
            Text('🇷🇺 🇳🇱 🇩🇪 Россия', style: M3eFlex.cardName(color: ink)),
            label('l10n (ru) через AppLocalizations.of'),
            Text(
              '${AppLocalizations.of(context).settings} / ${AppLocalizations.of(context).about}',
              style: t.bodyLarge!.copyWith(color: ink),
            ),
          ],
        ),
      ),
    );
  }
}
