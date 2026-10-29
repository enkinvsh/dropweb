import 'package:flutter/material.dart';

import '../color/color.dart';
import 'm3e_text.dart';

/// ThemeData новых экранов: роли схемы переносятся в [ColorScheme] один к одному.
///
/// `ColorScheme.fromSeed` и `fromScheme` не используются: они пересчитывают роли
/// по spec 2021 из пакета Flutter и разошлись бы с доской.
ThemeData m3eThemeData(M3eScheme s, {required Brightness brightness}) {
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: s.primary,
    onPrimary: s.onPrimary,
    primaryContainer: s.primaryContainer,
    onPrimaryContainer: s.onPrimaryContainer,
    secondary: s.secondary,
    onSecondary: s.onSecondary,
    secondaryContainer: s.secondaryContainer,
    onSecondaryContainer: s.onSecondaryContainer,
    tertiary: s.tertiary,
    onTertiary: s.onTertiary,
    tertiaryContainer: s.tertiaryContainer,
    onTertiaryContainer: s.onTertiaryContainer,
    error: s.error,
    onError: s.onError,
    errorContainer: s.errorContainer,
    onErrorContainer: s.onErrorContainer,
    surface: s.surface,
    onSurface: s.onSurface,
    surfaceDim: s.surfaceDim,
    surfaceBright: s.surfaceBright,
    surfaceContainerLowest: s.surfaceContainerLowest,
    surfaceContainerLow: s.surfaceContainerLow,
    surfaceContainer: s.surfaceContainer,
    surfaceContainerHigh: s.surfaceContainerHigh,
    surfaceContainerHighest: s.surfaceContainerHighest,
    onSurfaceVariant: s.onSurfaceVariant,
    outline: s.outline,
    outlineVariant: s.outlineVariant,
    shadow: s.shadow,
    scrim: s.scrim,
    inverseSurface: s.inverseSurface,
    onInverseSurface: s.inverseOnSurface,
    inversePrimary: s.inversePrimary,
    surfaceTint: s.surfaceTint,
    // Три устаревшие роли: у схемы доски они свои (surfaceVariant не равен
    // surfaceContainerHighest), а без явной передачи Flutter подставит surface.
    // ignore: deprecated_member_use
    background: s.background,
    // ignore: deprecated_member_use
    onBackground: s.onBackground,
    // ignore: deprecated_member_use
    surfaceVariant: s.surfaceVariant,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: s.surface,
    canvasColor: s.surface,
    textTheme: m3eTextTheme(),
    // Семейство по умолчанию: текст вне TextTheme (например, в виджетах без стиля) тоже Roboto.
    fontFamily: m3ePlainFamily,
    fontFamilyFallback: m3eFontFallback,
  );
}
