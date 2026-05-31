import 'dart:math';

import 'package:dropweb/common/lumina.dart';
import 'package:flutter/material.dart';

extension ColorExtension on Color {
  Color get opacity80 => withAlpha(204);

  Color get opacity60 => withAlpha(153);

  Color get opacity50 => withAlpha(128);

  Color get opacity38 => withAlpha(97);

  Color get opacity30 => withAlpha(77);

  Color get opacity15 => withAlpha(38);

  Color get opacity10 => withAlpha(15);

  Color get opacity3 => withAlpha(76);

  Color get opacity0 => withAlpha(0);

  int get value32bit =>
      _floatToInt8(a) << 24 |
      _floatToInt8(r) << 16 |
      _floatToInt8(g) << 8 |
      _floatToInt8(b) << 0;

  int get alpha8bit => (0xff000000 & value32bit) >> 24;

  int get red8bit => (0x00ff0000 & value32bit) >> 16;

  int get green8bit => (0x0000ff00 & value32bit) >> 8;

  int get blue8bit => (0x000000ff & value32bit) >> 0;

  int _floatToInt8(double x) => (x * 255.0).round() & 0xff;

  Color lighten([double amount = 10]) {
    if (amount <= 0) return this;
    if (amount > 100) return Colors.white;
    final hsl = this == const Color(0xFF000000)
        ? HSLColor.fromColor(this).withSaturation(0)
        : HSLColor.fromColor(this);
    return hsl
        .withLightness(min(1, max(0, hsl.lightness + amount / 100)))
        .toColor();
  }

  String get hex {
    final value = toARGB32();
    final red = (value >> 16) & 0xFF;
    final green = (value >> 8) & 0xFF;
    final blue = value & 0xFF;
    return '#${red.toRadixString(16).padLeft(2, '0')}'
            '${green.toRadixString(16).padLeft(2, '0')}'
            '${blue.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  Color darken([final int amount = 10]) {
    if (amount <= 0) return this;
    if (amount > 100) return Colors.black;
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness(min(1, max(0, hsl.lightness - amount / 100)))
        .toColor();
  }

  Color blendDarken(
    BuildContext context, {
    double factor = 0.1,
  }) {
    final brightness = Theme.of(context).brightness;
    return Color.lerp(
      this,
      brightness == Brightness.dark ? Colors.white : Colors.black,
      factor,
    )!;
  }

  Color blendLighten(
    BuildContext context, {
    double factor = 0.1,
  }) {
    final brightness = Theme.of(context).brightness;
    return Color.lerp(
      this,
      brightness == Brightness.dark ? Colors.black : Colors.white,
      factor,
    )!;
  }
}

/// HSL transform of the accent per scheme variant; preserves hue/lightness.
Color applyColorFilter(Color base, DynamicSchemeVariant variant) {
  final hsl = HSLColor.fromColor(base);
  switch (variant) {
    case DynamicSchemeVariant.vibrant:
      return hsl
          .withSaturation((hsl.saturation * 1.4).clamp(0.0, 1.0))
          .toColor();
    case DynamicSchemeVariant.monochrome:
      return hsl.withSaturation(0.0).toColor();
    case DynamicSchemeVariant.neutral:
      return hsl
          .withSaturation((hsl.saturation * 0.3).clamp(0.0, 1.0))
          .toColor();
    case DynamicSchemeVariant.expressive:
      return hsl.withHue((hsl.hue + 30.0) % 360.0).toColor();
    case DynamicSchemeVariant.fidelity:
    default:
      return base;
  }
}

/// Image-space equivalent of [applyColorFilter]: returns a [ColorFilter] that
/// applies the active scheme variant's transform to an entire image (e.g. a
/// provider logo), so logos follow the same filter as the accent/orbs.
/// Returns null for `fidelity` (image rendered in its original colors).
ColorFilter? imageColorFilter(DynamicSchemeVariant variant) {
  switch (variant) {
    case DynamicSchemeVariant.vibrant:
      return _saturationColorFilter(1.4);
    case DynamicSchemeVariant.monochrome:
      return _saturationColorFilter(0.0);
    case DynamicSchemeVariant.neutral:
      return _saturationColorFilter(0.3);
    case DynamicSchemeVariant.expressive:
      return _hueRotateColorFilter(30.0);
    case DynamicSchemeVariant.fidelity:
    default:
      return null;
  }
}

/// Saturation color matrix (s=0 grayscale, s=1 identity, s>1 boosts).
ColorFilter _saturationColorFilter(double s) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final ir = (1 - s) * lr;
  final ig = (1 - s) * lg;
  final ib = (1 - s) * lb;
  return ColorFilter.matrix(<double>[
    ir + s, ig, ib, 0, 0, //
    ir, ig + s, ib, 0, 0, //
    ir, ig, ib + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}

/// Luminance-preserving hue-rotation color matrix (degrees).
ColorFilter _hueRotateColorFilter(double degrees) {
  final rad = degrees * pi / 180.0;
  final c = cos(rad);
  final s = sin(rad);
  const lr = 0.213, lg = 0.715, lb = 0.072;
  return ColorFilter.matrix(<double>[
    lr + c * (1 - lr) + s * (-lr),
    lg + c * (-lg) + s * (-lg),
    lb + c * (-lb) + s * (1 - lb),
    0, 0, //
    lr + c * (-lr) + s * 0.143,
    lg + c * (1 - lg) + s * 0.140,
    lb + c * (-lb) + s * (-0.283),
    0, 0, //
    lr + c * (-lr) + s * (-(1 - lr)),
    lg + c * (-lg) + s * lg,
    lb + c * (1 - lb) + s * lb,
    0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}

extension ColorSchemeExtension on ColorScheme {
  ColorScheme toPureBlack(bool isPureBlack) {
    if (!isPureBlack) return this;
    return copyWith(
      surface: Lumina.void_,
      surfaceContainerLowest: Lumina.surface1,
      surfaceContainerLow: Lumina.surface2,
      surfaceContainer: Lumina.surface3,
      surfaceContainerHigh: Lumina.surface4,
      surfaceContainerHighest: Lumina.surface5,
    );
  }
}
