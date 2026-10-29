// Динамическая схема M3 из цвета провайдера: перенос `scheme()` из android.js доски (строки 41-90).
//
// Фильтр из заголовка `dropweb-theme` выбирает вариант: четыре фильтра дают свои схемы по
// spec 2025, всё остальное (в том числе `fidelity`) -- CMF spec 2026: только там
// primary-container ровно равен seed, а нейтрали несут оттенок провайдера.

import 'dart:ui' show Color;

import 'package:material_color_utilities/material_color_utilities.dart'
    show Hct;

import 'hex.dart';
import 'mcu/dynamic_scheme.dart';
import 'mcu/schemes.dart';
import 'mcu/tonal_palette.dart';
import 'mcu/variant.dart';
import 'theme_header.dart';

/// Роли схемы в том же порядке и под теми же именами, что `ROLES` в android.js.
const List<String> m3eRoleNames = [
  'primary',
  'onPrimary',
  'primaryContainer',
  'onPrimaryContainer',
  'inversePrimary',
  'secondary',
  'onSecondary',
  'secondaryContainer',
  'onSecondaryContainer',
  'tertiary',
  'onTertiary',
  'tertiaryContainer',
  'onTertiaryContainer',
  'error',
  'onError',
  'errorContainer',
  'onErrorContainer',
  'background',
  'onBackground',
  'surface',
  'onSurface',
  'surfaceVariant',
  'onSurfaceVariant',
  'surfaceDim',
  'surfaceBright',
  'surfaceContainerLowest',
  'surfaceContainerLow',
  'surfaceContainer',
  'surfaceContainerHigh',
  'surfaceContainerHighest',
  'inverseSurface',
  'inverseOnSurface',
  'outline',
  'outlineVariant',
  'scrim',
  'shadow',
  'surfaceTint',
];

/// Цвет иконки лаунчера: знак на плашке.
class M3eIconColors {
  const M3eIconColors({required this.fg, required this.bg});
  final Color fg;
  final Color bg;
}

/// Готовая схема: 37 ролей M3 и цвета тематической иконки.
class M3eScheme {
  const M3eScheme._(this._argb, this.icon);

  final Map<String, int> _argb;

  /// Знак и плашка иконки по правилам лаунчера (iconloaderlib values-v31).
  final M3eIconColors icon;

  /// Цвет роли по имени из [m3eRoleNames]; неизвестное имя -- ошибка, а не молчаливый чёрный.
  Color role(String name) => Color(_argb[name]!);

  /// Hex роли в нижнем регистре (`#rrggbb`) -- для сверки с эталоном доски.
  String hex(String name) => hexFromArgb(_argb[name]!);

  Color get primary => role('primary');
  Color get onPrimary => role('onPrimary');
  Color get primaryContainer => role('primaryContainer');
  Color get onPrimaryContainer => role('onPrimaryContainer');
  Color get inversePrimary => role('inversePrimary');
  Color get secondary => role('secondary');
  Color get onSecondary => role('onSecondary');
  Color get secondaryContainer => role('secondaryContainer');
  Color get onSecondaryContainer => role('onSecondaryContainer');
  Color get tertiary => role('tertiary');
  Color get onTertiary => role('onTertiary');
  Color get tertiaryContainer => role('tertiaryContainer');
  Color get onTertiaryContainer => role('onTertiaryContainer');
  Color get error => role('error');
  Color get onError => role('onError');
  Color get errorContainer => role('errorContainer');
  Color get onErrorContainer => role('onErrorContainer');
  Color get background => role('background');
  Color get onBackground => role('onBackground');
  Color get surface => role('surface');
  Color get onSurface => role('onSurface');
  Color get surfaceVariant => role('surfaceVariant');
  Color get onSurfaceVariant => role('onSurfaceVariant');
  Color get surfaceDim => role('surfaceDim');
  Color get surfaceBright => role('surfaceBright');
  Color get surfaceContainerLowest => role('surfaceContainerLowest');
  Color get surfaceContainerLow => role('surfaceContainerLow');
  Color get surfaceContainer => role('surfaceContainer');
  Color get surfaceContainerHigh => role('surfaceContainerHigh');
  Color get surfaceContainerHighest => role('surfaceContainerHighest');
  Color get inverseSurface => role('inverseSurface');
  Color get inverseOnSurface => role('inverseOnSurface');
  Color get outline => role('outline');
  Color get outlineVariant => role('outlineVariant');
  Color get scrim => role('scrim');
  Color get shadow => role('shadow');
  Color get surfaceTint => role('surfaceTint');
}

/// Фильтры spec 2025; всё остальное идёт в CMF spec 2026 (как `VARIANTS[filter] || CMF` на доске).
const Map<String, McuVariant> _variants = {
  'tonal_spot': McuVariant.tonalSpot,
  'vibrant': McuVariant.vibrant,
  'expressive': McuVariant.expressive,
  'neutral': McuVariant.neutral,
};

/// Исходный цвет в HCT; неверный seed заменяется запасным, как `try/catch` на доске.
Hct m3eSeedHct(String seedHex) {
  final argb =
      argbFromHexOrNull(seedHex) ?? argbFromHexOrNull(m3eFallbackSeed)!;
  return Hct.fromInt(argb);
}

/// Схема MCU для seed/filter/тема -- общая основа [scheme] и главной.
McuDynamicScheme m3eMcuScheme(String seedHex, String filter,
    {required bool dark}) {
  final hct = m3eSeedHct(seedHex);
  final variant = _variants[filter];
  // Контраст 0: доска не использует повышенный контраст.
  return variant == null
      ? mcuSchemeCmf(hct, dark, 0)
      : mcuScheme2025(variant, hct, dark, 0);
}

final Map<String, M3eScheme> _cache = {};

/// Схема для [seedHex] с фильтром [filter]. Результат запоминается по `seed|filter|dark`,
/// как `schemes` на доске: построение даёт ~40 расчётов HCT, а вызывается на каждом кадре темы.
M3eScheme scheme(String seedHex, String filter, {required bool dark}) =>
    _cache.putIfAbsent('$seedHex|$filter|$dark', () {
      final s = m3eMcuScheme(seedHex, filter, dark: dark);
      final argb = {for (final r in m3eRoleNames) r: mcuRoleArgb(s, r)};

      // Иконка: оттенок из схемы приложения, насыщенность не выше системных палитр
      // Tonal Spot (36 и 16): без потолка CMF на неоне даёт кислотный фон.
      McuTonalPalette tame(McuTonalPalette pal, double max) =>
          McuTonalPalette.fromHueAndChroma(
              pal.hue, pal.chroma < max ? pal.chroma : max);
      final a1 = tame(s.primaryPalette, 36);
      final a2 = tame(s.secondaryPalette, 16);
      final icon = dark
          ? M3eIconColors(fg: Color(a1.tone(80)), bg: Color(a2.tone(20)))
          : M3eIconColors(fg: Color(a1.tone(30)), bg: Color(a1.tone(90)));
      return M3eScheme._(argb, icon);
    });
