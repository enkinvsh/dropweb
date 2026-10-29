// Порт из MCU TS bd811e4 dynamiccolor/dynamic_scheme.ts (Apache-2.0, см. LICENSE).
//
// Только платформа phone и палитры spec 2025 для четырёх вариантов (neutral, tonal_spot,
// vibrant, expressive) + явные палитры для CMF. Ветки 'watch' и spec 2021 не портированы.

import 'package:material_color_utilities/material_color_utilities.dart'
    show Hct, MathUtils;

import 'hue_ranges.dart';
import 'tonal_palette.dart';
import 'variant.dart';

/// Версия спецификации. Порядок значений важен: сравнение «версия >= X» идёт по индексу.
enum McuSpecVersion { v2025, v2026 }

/// Набор палитр + параметры (тёмная ли тема, уровень контраста), по которым
/// McuDynamicColor считает цвета ролей.
class McuDynamicScheme {
  McuDynamicScheme({
    required this.sourceColorHct,
    required this.variant,
    required this.contrastLevel,
    required this.isDark,
    McuSpecVersion specVersion = McuSpecVersion.v2025,
    McuTonalPalette? primaryPalette,
    McuTonalPalette? secondaryPalette,
    McuTonalPalette? tertiaryPalette,
    McuTonalPalette? neutralPalette,
    McuTonalPalette? neutralVariantPalette,
    McuTonalPalette? errorPalette,
  })  : sourceColorHcts = [sourceColorHct],
        specVersion = _maybeFallbackSpecVersion(specVersion, variant),
        primaryPalette =
            primaryPalette ?? _primary(variant, sourceColorHct, isDark),
        secondaryPalette =
            secondaryPalette ?? _secondary(variant, sourceColorHct, isDark),
        tertiaryPalette =
            tertiaryPalette ?? _tertiary(variant, sourceColorHct, isDark),
        neutralPalette =
            neutralPalette ?? _neutral(variant, sourceColorHct, isDark),
        neutralVariantPalette = neutralVariantPalette ??
            _neutralVariant(variant, sourceColorHct, isDark),
        errorPalette = errorPalette ?? _error(variant, sourceColorHct);

  final Hct sourceColorHct;

  /// Исходные цвета; у доски он всегда один (второй цвет CMF не используется).
  final List<Hct> sourceColorHcts;
  final McuVariant variant;

  /// −1…1; доска считает с 0.
  final double contrastLevel;
  final bool isDark;
  final McuSpecVersion specVersion;

  final McuTonalPalette primaryPalette;
  final McuTonalPalette secondaryPalette;
  final McuTonalPalette tertiaryPalette;
  final McuTonalPalette neutralPalette;
  final McuTonalPalette neutralVariantPalette;
  final McuTonalPalette errorPalette;

  // Четыре варианта не умеют spec 2026 и откатываются на 2025; CMF — только 2026.
  static McuSpecVersion _maybeFallbackSpecVersion(
    McuSpecVersion specVersion,
    McuVariant variant,
  ) {
    if (variant == McuVariant.cmf) return specVersion;
    return specVersion == McuSpecVersion.v2026
        ? McuSpecVersion.v2025
        : specVersion;
  }

  /// Новый оттенок по кусочной функции от исходного оттенка.
  static double getPiecewiseHue(
    Hct sourceColorHct,
    List<double> hueBreakpoints,
    List<double> hues,
  ) {
    final size = hueBreakpoints.length - 1 < hues.length
        ? hueBreakpoints.length - 1
        : hues.length;
    final sourceHue = sourceColorHct.hue;
    for (var i = 0; i < size; i++) {
      if (sourceHue >= hueBreakpoints[i] && sourceHue < hueBreakpoints[i + 1]) {
        return MathUtils.sanitizeDegreesDouble(hues[i]);
      }
    }
    return sourceHue;
  }

  /// Исходный оттенок, повёрнутый на величину из кусочной функции.
  static double getRotatedHue(
    Hct sourceColorHct,
    List<double> hueBreakpoints,
    List<double> rotations,
  ) {
    var rotation = getPiecewiseHue(sourceColorHct, hueBreakpoints, rotations);
    final size = hueBreakpoints.length - 1 < rotations.length
        ? hueBreakpoints.length - 1
        : rotations.length;
    if (size <= 0) rotation = 0;
    return MathUtils.sanitizeDegreesDouble(sourceColorHct.hue + rotation);
  }

  // ---- палитры spec 2025, платформа phone ----

  static McuTonalPalette _primary(McuVariant v, Hct src, bool isDark) {
    switch (v) {
      case McuVariant.neutral:
        return McuTonalPalette.fromHueAndChroma(
          src.hue,
          hueIsBlue(src.hue) ? 12 : 8,
        );
      case McuVariant.tonalSpot:
        return McuTonalPalette.fromHueAndChroma(src.hue, isDark ? 26 : 32);
      case McuVariant.expressive:
        return McuTonalPalette.fromHueAndChroma(src.hue, isDark ? 36 : 48);
      case McuVariant.vibrant:
        return McuTonalPalette.fromHueAndChroma(src.hue, 74);
      case McuVariant.cmf:
        throw StateError('Палитры CMF задаются явно в mcuSchemeCmf');
    }
  }

  static McuTonalPalette _secondary(McuVariant v, Hct src, bool isDark) {
    switch (v) {
      case McuVariant.neutral:
        return McuTonalPalette.fromHueAndChroma(
          src.hue,
          hueIsBlue(src.hue) ? 6 : 4,
        );
      case McuVariant.tonalSpot:
        return McuTonalPalette.fromHueAndChroma(src.hue, 16);
      case McuVariant.expressive:
        return McuTonalPalette.fromHueAndChroma(
          getRotatedHue(
            src,
            [0, 105, 140, 204, 253, 278, 300, 333, 360],
            [-160, 155, -100, 96, -96, -156, -165, -160],
          ),
          isDark ? 16 : 24,
        );
      case McuVariant.vibrant:
        return McuTonalPalette.fromHueAndChroma(
          getRotatedHue(
            src,
            [0, 38, 105, 140, 333, 360],
            [-14, 10, -14, 10, -14],
          ),
          56,
        );
      case McuVariant.cmf:
        throw StateError('Палитры CMF задаются явно в mcuSchemeCmf');
    }
  }

  static McuTonalPalette _tertiary(McuVariant v, Hct src, bool isDark) {
    switch (v) {
      case McuVariant.neutral:
        return McuTonalPalette.fromHueAndChroma(
          getRotatedHue(
            src,
            [0, 38, 105, 161, 204, 278, 333, 360],
            [-32, 26, 10, -39, 24, -15, -32],
          ),
          20,
        );
      case McuVariant.tonalSpot:
        return McuTonalPalette.fromHueAndChroma(
          getRotatedHue(
            src,
            [0, 20, 71, 161, 333, 360],
            [-40, 48, -32, 40, -32],
          ),
          28,
        );
      case McuVariant.expressive:
        return McuTonalPalette.fromHueAndChroma(
          getRotatedHue(
            src,
            [0, 105, 140, 204, 253, 278, 300, 333, 360],
            [-165, 160, -105, 101, -101, -160, -170, -165],
          ),
          48,
        );
      case McuVariant.vibrant:
        return McuTonalPalette.fromHueAndChroma(
          getRotatedHue(
            src,
            [0, 38, 71, 105, 140, 161, 253, 333, 360],
            [-72, 35, 24, -24, 62, 50, 62, -72],
          ),
          56,
        );
      case McuVariant.cmf:
        throw StateError('Палитры CMF задаются явно в mcuSchemeCmf');
    }
  }

  static double _expressiveNeutralHue(Hct src) => getRotatedHue(
        src,
        [0, 71, 124, 253, 278, 300, 360],
        [10, 0, 10, 0, 10, 0],
      );

  static double _expressiveNeutralChroma(Hct src, bool isDark) {
    final neutralHue = _expressiveNeutralHue(src);
    return isDark ? (hueIsYellow(neutralHue) ? 6 : 14) : 18;
  }

  static double _vibrantNeutralHue(Hct src) => getRotatedHue(
        src,
        [0, 38, 105, 140, 333, 360],
        [-14, 10, -14, 10, -14],
      );

  static McuTonalPalette _neutral(McuVariant v, Hct src, bool isDark) {
    switch (v) {
      case McuVariant.neutral:
        return McuTonalPalette.fromHueAndChroma(src.hue, 1.4);
      case McuVariant.tonalSpot:
        return McuTonalPalette.fromHueAndChroma(src.hue, 5);
      case McuVariant.expressive:
        return McuTonalPalette.fromHueAndChroma(
          _expressiveNeutralHue(src),
          _expressiveNeutralChroma(src, isDark),
        );
      case McuVariant.vibrant:
        return McuTonalPalette.fromHueAndChroma(_vibrantNeutralHue(src), 28);
      case McuVariant.cmf:
        throw StateError('Палитры CMF задаются явно в mcuSchemeCmf');
    }
  }

  static McuTonalPalette _neutralVariant(McuVariant v, Hct src, bool isDark) {
    switch (v) {
      case McuVariant.neutral:
        return McuTonalPalette.fromHueAndChroma(src.hue, 1.4 * 2.2);
      case McuVariant.tonalSpot:
        return McuTonalPalette.fromHueAndChroma(src.hue, 5 * 1.7);
      case McuVariant.expressive:
        final hue = _expressiveNeutralHue(src);
        final chroma = _expressiveNeutralChroma(src, isDark);
        return McuTonalPalette.fromHueAndChroma(
          hue,
          chroma * (hue >= 105 && hue < 125 ? 1.6 : 2.3),
        );
      case McuVariant.vibrant:
        return McuTonalPalette.fromHueAndChroma(
            _vibrantNeutralHue(src), 28 * 1.29);
      case McuVariant.cmf:
        throw StateError('Палитры CMF задаются явно в mcuSchemeCmf');
    }
  }

  static McuTonalPalette _error(McuVariant v, Hct src) {
    final errorHue = getPiecewiseHue(
      src,
      [0, 3, 13, 23, 33, 43, 153, 273, 360],
      [12, 22, 32, 12, 22, 32, 22, 12],
    );
    switch (v) {
      case McuVariant.neutral:
        return McuTonalPalette.fromHueAndChroma(errorHue, 50);
      case McuVariant.tonalSpot:
        return McuTonalPalette.fromHueAndChroma(errorHue, 60);
      case McuVariant.expressive:
        return McuTonalPalette.fromHueAndChroma(errorHue, 64);
      case McuVariant.vibrant:
        return McuTonalPalette.fromHueAndChroma(errorHue, 80);
      case McuVariant.cmf:
        throw StateError('Палитры CMF задаются явно в mcuSchemeCmf');
    }
  }
}
