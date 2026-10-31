// Тема iOS-редизайна: цвета колонки iOS доски для поддерева, плюс Theme, текст и значки по умолчанию.
//
// Устройство то же, что у M3E (`M3eThemeScope`, `m3eColorsFor`), данные другие: палитра из `tokens.g.dart`,
// акцент и орбы из `accent.dart`. Яркость и «Повышенная контрастность» берутся из системы:
// iOS-интерфейс следует системной теме, `ThemeProps.themeMode` не читается.

import 'package:dropweb/ui/ios27/glass/ios27_glass.dart'
    show Ios27GlassColors, Ios27GlassPalette;
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text_scale.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_data.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_source.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Цвета iOS-колонки доски для поддерева.
///
/// [vars] совпадает с вычисленными свойствами корня `[data-col="ios"] .app` на доске (28 имён,
/// `test/ios27/ref/colors.json`): так экраны могут сверяться с эталоном по именам свойств CSS.
class Ios27Colors extends InheritedWidget {
  const Ios27Colors({
    required this.palette,
    required this.accent,
    required this.theme,
    required this.brightness,
    required this.highContrast,
    required super.child,
    super.key,
  });

  /// Палитра по теме и «Повышенной контрастности»: набор берётся из токенов, не считается здесь.
  factory Ios27Colors.from({
    required Ios27ProviderTheme theme,
    required Brightness brightness,
    required Widget child,
    bool highContrast = false,
    Key? key,
  }) =>
      Ios27Colors(
        key: key,
        palette: Ios27Tokens.palette(
          dark: brightness == Brightness.dark,
          increasedContrast: highContrast,
        ),
        accent: theme.apply(),
        theme: theme,
        brightness: brightness,
        highContrast: highContrast,
        child: child,
      );

  /// Токены темы: `--label`, `--fill-*`, `--bg` и остальные.
  final Ios27Palette palette;

  /// Результат `applyAccent` доски: подогнанный акцент, текст на нём, мягкий тон и орбы.
  final Ios27AppliedAccent accent;

  /// Три цвета, из которых получен [accent]: нужны экранам «Оформление» и фону.
  final Ios27ProviderTheme theme;

  /// Яркость системы (или заданная явно, в golden-тестах).
  final Brightness brightness;

  /// Включена ли «Повышенная контрастность»: тогда действует набор `IncreasedContrast`.
  final bool highContrast;

  /// Те же данные с другим [child]: так скоуп собирает цепочку виджетов, не считая цвета дважды.
  Ios27Colors withChild(Widget child) => Ios27Colors(
        key: key,
        palette: palette,
        accent: accent,
        theme: theme,
        brightness: brightness,
        highContrast: highContrast,
        child: child,
      );

  /// Тёмная ли тема.
  bool get dark => brightness == Brightness.dark;

  /// `--accent`.
  Color get accentColor => accent.vars.accent(dark: dark);

  /// `--on-accent`: белый или чёрный по контрасту к акценту.
  Color get onAccent => accent.vars.onAccent(dark: dark);

  /// `--accent-soft`.
  Color get accentSoft => accent.vars.soft(dark: dark);

  /// `--orb1`: цвет верхнего орба фона.
  Color get orb1 => accent.orb1;

  /// `--orb2`: цвет нижнего орба фона.
  Color get orb2 => accent.orb2;

  /// Палитра стекла под текущую яркость (см. [ios27GlassPaletteFor]).
  Ios27GlassPalette get glassPalette => ios27GlassPaletteFor(dark: dark);

  /// Все свойства корня iOS-колонки доски по именам CSS.
  Map<String, Color> get vars => {
        for (final e in {
          ...palette.toVars(),
          ...accent.toVars(dark: dark),
        }.entries)
          e.key: Color(e.value),
      };

  /// Цвета из ближайшего [Ios27ThemeScope]; нет скоупа, нет и цветов.
  ///
  /// Для кода над скоупом (диалоги и листы, открытые с корневого `navigatorKey.currentContext`)
  /// есть [ios27ColorsFor].
  static Ios27Colors of(BuildContext context) {
    final colors = maybeOf(context);
    assert(
      colors != null,
      'Ios27Colors не найден: оберните экран в Ios27ThemeScope, а в коде над скоупом '
      '(корневой Navigator) берите ios27ColorsFor(context).',
    );
    return colors!;
  }

  /// То же, что [of], но без ошибки при отсутствии скоупа.
  static Ios27Colors? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Ios27Colors>();

  // Сравнение по значению: акцент и орбы хранятся вычисленными, а не только в [theme], поэтому
  // сверяем и их. Палитра приходит константой из токенов, достаточно тождества.
  @override
  bool updateShouldNotify(Ios27Colors oldWidget) =>
      theme != oldWidget.theme ||
      brightness != oldWidget.brightness ||
      highContrast != oldWidget.highContrast ||
      !identical(palette, oldWidget.palette) ||
      accent.vars.light != oldWidget.accent.vars.light ||
      accent.vars.dark != oldWidget.accent.vars.dark ||
      accent.orb1 != oldWidget.accent.orb1 ||
      accent.orb2 != oldWidget.accent.orb2;
}

/// Палитра стекла для [Ios27GlassColors] под яркость [dark].
///
/// Заливку (`fill`) берём из токенов (`Ios27Tokens.glass(...).base.opaque`): это плотная заливка
/// стекла при «Уменьшении прозрачности», и она уже выгружена с доски. Остальные два цвета остаются
/// константами T3a (`Ios27GlassPalette.light/dark`): токены их не несут. Заливку `glass--tint:disabled`
/// (glass.css:261) и кольцо Increase Contrast (`--g-shadow-out`, glass.css:283-288) генератор
/// не выгружает. Тест `theme_scope_test.dart` следит, чтобы `fill` из токенов не разошёлся с константой.
Ios27GlassPalette ios27GlassPaletteFor({required bool dark}) {
  final base = dark ? Ios27GlassPalette.dark : Ios27GlassPalette.light;
  return Ios27GlassPalette(
    fill: Ios27Tokens.glass(dark: dark).base.opaque ?? base.fill,
    disabledTintFill: base.disabledTintFill,
    contrastRing: base.contrastRing,
  );
}

/// Тема iOS-редизайна для поддерева.
///
/// Кладёт: [Ios27Colors], палитру стекла, [Theme], текст по умолчанию (роль body, `--label`),
/// цвет значков `--label` и масштаб текста [Ios27TextScaleScope].
///
/// Масштаб текста внутри скоупа всегда системный Dynamic Type, зажатый в 0.8–2.0 (решение Q2):
/// настройка «Размер текста» приложения на iOS-интерфейс не действует, а `ThemeManager` и без
/// того переписывает `MediaQuery.textScaler` у корня. Места, где текст не должен расти (тосты),
/// сами ставят `MediaQuery.withNoTextScaling`: он лежит ниже скоупа и сохраняет силу.
///
/// Основной конструктор берёт цвета из [ios27ThemeProvider] и перерисовывается при их смене;
/// [Ios27ThemeScope.explicit] нужен golden-тестам и образцам в настройках.
class Ios27ThemeScope extends StatelessWidget {
  const Ios27ThemeScope({required this.child, super.key})
      : _theme = null,
        brightness = null,
        highContrast = null,
        glassLevel = null;

  /// Тема задана явно, провайдер не читается; [brightness] и [highContrast] по умолчанию берутся
  /// из системы (`MediaQuery`).
  const Ios27ThemeScope.explicit({
    required Ios27ProviderTheme theme,
    required this.child,
    this.brightness,
    this.highContrast,
    this.glassLevel,
    super.key,
  }) : _theme = theme;

  final Ios27ProviderTheme? _theme;

  /// Яркость вместо системной.
  final Brightness? brightness;

  /// «Повышенная контрастность» вместо системной.
  final bool? highContrast;

  /// Ползунок «Стекло» (0..100) только для [Ios27ThemeScope.explicit]; `null` — как в системе.
  /// Основной конструктор берёт его из [ios27GlassLevelProvider] и на смену ползунка перерисовывается.
  final int? glassLevel;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final explicit = _theme;
    if (explicit != null) {
      return _Scope(
        theme: explicit,
        brightness: brightness,
        highContrast: highContrast,
        glassLevel: glassLevel,
        child: child,
      );
    }
    return Consumer(
      builder: (context, ref, _) => _Scope(
        theme: ref.watch(ios27ThemeProvider),
        brightness: brightness,
        highContrast: highContrast,
        glassLevel: ref.watch(ios27GlassLevelProvider),
        child: child,
      ),
    );
  }
}

class _Scope extends StatelessWidget {
  const _Scope({
    required this.theme,
    required this.brightness,
    required this.highContrast,
    required this.glassLevel,
    required this.child,
  });

  final Ios27ProviderTheme theme;
  final Brightness? brightness;
  final bool? highContrast;
  final int? glassLevel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Тема следует системе, а не `ThemeProps.themeMode`: так на доске (`color-scheme: light dark`).
    final resolvedBrightness =
        brightness ?? MediaQuery.platformBrightnessOf(context);
    final resolvedHighContrast =
        highContrast ?? MediaQuery.highContrastOf(context);
    // Данные считаем один раз без детей, чтобы построить по ним Theme и затем вложить поддерево.
    final colors = Ios27Colors.from(
      theme: theme,
      brightness: resolvedBrightness,
      highContrast: resolvedHighContrast,
      child: const SizedBox.shrink(),
    );
    final label = colors.palette.label;

    return colors.withChild(
      Ios27GlassColors(
        light: ios27GlassPaletteFor(dark: false),
        dark: ios27GlassPaletteFor(dark: true),
        brightness: resolvedBrightness,
        level: glassLevel,
        child: Theme(
          data: ios27ThemeData(colors),
          child: DefaultTextStyle(
            style: ios27RoleStyle(
              Ios27Text.body,
              color: label,
              bold: MediaQuery.boldTextOf(context),
            ),
            child: IconTheme(
              data: IconThemeData(color: label),
              // Самым внутренним: всё, что скоуп кладёт выше, масштаб текста не читает.
              child: Ios27TextScaleScope(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Цвета iOS-редизайна для кода, которому скоуп может быть недоступен.
///
/// Диалоги, листы и тосты открываются с корневого `navigatorKey.currentContext`: он выше любого
/// [Ios27ThemeScope], и [Ios27Colors.of] там падает (на Android так был пойман блокер 6c3a3234).
/// Поэтому: есть скоуп, берём его; нет, строим цвета из провайдера и системных настроек.
/// Цвета при этом читаются один раз и на смену темы не подписаны.
Ios27Colors ios27ColorsFor(BuildContext context) {
  final inherited = Ios27Colors.maybeOf(context);
  if (inherited != null) {
    return inherited;
  }
  return Ios27Colors.from(
    theme: ProviderScope.containerOf(context).read(ios27ThemeProvider),
    brightness: MediaQuery.platformBrightnessOf(context),
    highContrast: MediaQuery.highContrastOf(context),
    child: const SizedBox.shrink(),
  );
}
