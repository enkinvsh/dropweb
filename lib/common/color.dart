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

  Color get opacity0 => withAlpha(0);

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
