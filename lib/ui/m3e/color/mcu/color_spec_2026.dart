// Порт из MCU TS bd811e4 dynamiccolor/color_spec_2026.ts (Apache-2.0, см. LICENSE).
//
// Роли, которых нет в этом файле, остаются как в spec 2025 (inversePrimary, surfaceVariant,
// surfaceTint, background, onBackground, shadow, scrim): в TS они так же наследуются.
// В 2026 существует только вариант CMF; для остальных вариантов исходник отдаёт «неопределённые»
// значения (0), здесь они сохранены ради совпадения с исходником.

import 'package:material_color_utilities/material_color_utilities.dart'
    show MathUtils;

import 'color_spec_2025.dart';
import 'dynamic_color.dart';
import 'dynamic_scheme.dart';
import 'tone_delta_pair.dart';
import 'variant.dart';

/// Спецификация цветов ролей, spec 2026 (CMF).
class McuColorSpec2026 extends McuColorSpec2025 {
  const McuColorSpec2026();

  static bool _cmf(McuDynamicScheme s) => s.variant == McuVariant.cmf;

  @override
  McuDynamicColor surface() => McuDynamicColor.fromPalette(
        name: 'surface',
        palette: (s) => s.neutralPalette,
        tone: (s) => _cmf(s) ? (s.isDark ? 4 : 98) : 0,
        isBackground: true,
      );

  @override
  McuDynamicColor surfaceDim() => McuDynamicColor.fromPalette(
        name: 'surface_dim',
        palette: (s) => s.neutralPalette,
        tone: (s) => _cmf(s) ? (s.isDark ? 4 : 87) : 0,
        chromaMultiplier: (s) => _cmf(s) ? (s.isDark ? 1 : 1.7) : 0,
        isBackground: true,
      );

  @override
  McuDynamicColor surfaceBright() => McuDynamicColor.fromPalette(
        name: 'surface_bright',
        palette: (s) => s.neutralPalette,
        tone: (s) => _cmf(s) ? (s.isDark ? 18 : 98) : 0,
        chromaMultiplier: (s) => _cmf(s) ? (s.isDark ? 1.7 : 1) : 0,
        isBackground: true,
      );

  @override
  McuDynamicColor surfaceContainerLowest() => McuDynamicColor.fromPalette(
        name: 'surface_container_lowest',
        palette: (s) => s.neutralPalette,
        tone: (s) => _cmf(s) ? (s.isDark ? 0 : 100) : 0,
        isBackground: true,
      );

  @override
  McuDynamicColor surfaceContainerLow() => McuDynamicColor.fromPalette(
        name: 'surface_container_low',
        palette: (s) => s.neutralPalette,
        tone: (s) => _cmf(s) ? (s.isDark ? 6 : 96) : 0,
        chromaMultiplier: (s) => _cmf(s) ? 1.25 : 0,
        isBackground: true,
      );

  @override
  McuDynamicColor surfaceContainer() => McuDynamicColor.fromPalette(
        name: 'surface_container',
        palette: (s) => s.neutralPalette,
        tone: (s) => _cmf(s) ? (s.isDark ? 9 : 94) : 0,
        chromaMultiplier: (s) => _cmf(s) ? 1.4 : 0,
        isBackground: true,
      );

  @override
  McuDynamicColor surfaceContainerHigh() => McuDynamicColor.fromPalette(
        name: 'surface_container_high',
        palette: (s) => s.neutralPalette,
        tone: (s) => _cmf(s) ? (s.isDark ? 12 : 92) : 0,
        chromaMultiplier: (s) => _cmf(s) ? 1.5 : 0,
        isBackground: true,
      );

  @override
  McuDynamicColor surfaceContainerHighest() => McuDynamicColor.fromPalette(
        name: 'surface_container_highest',
        palette: (s) => s.neutralPalette,
        tone: (s) => _cmf(s) ? (s.isDark ? 15 : 90) : 0,
        chromaMultiplier: (s) => _cmf(s) ? 1.7 : 0,
        isBackground: true,
      );

  @override
  McuDynamicColor onSurface() => McuDynamicColor.fromPalette(
        name: 'on_surface',
        palette: (s) => s.neutralPalette,
        chromaMultiplier: (s) => _cmf(s) ? 1.7 : 0,
        background: highestSurface,
        contrastCurve: (s) => s.isDark ? mcuGetCurve(11) : mcuGetCurve(9),
      );

  @override
  McuDynamicColor onSurfaceVariant() => McuDynamicColor.fromPalette(
        name: 'on_surface_variant',
        palette: (s) => s.neutralPalette,
        chromaMultiplier: (s) => _cmf(s) ? 1.7 : 0,
        background: highestSurface,
        contrastCurve: (s) => s.isDark ? mcuGetCurve(6) : mcuGetCurve(4.5),
      );

  @override
  McuDynamicColor outline() => McuDynamicColor.fromPalette(
        name: 'outline',
        palette: (s) => s.neutralPalette,
        chromaMultiplier: (s) => _cmf(s) ? 1.7 : 0,
        background: highestSurface,
        contrastCurve: (s) => mcuGetCurve(3),
      );

  @override
  McuDynamicColor outlineVariant() => McuDynamicColor.fromPalette(
        name: 'outline_variant',
        palette: (s) => s.neutralPalette,
        chromaMultiplier: (s) => _cmf(s) ? 1.7 : 0,
        background: highestSurface,
        contrastCurve: (s) => mcuGetCurve(1.5),
      );

  @override
  McuDynamicColor inverseSurface() => McuDynamicColor.fromPalette(
        name: 'inverse_surface',
        palette: (s) => s.neutralPalette,
        tone: (s) => s.isDark ? 98 : 4,
        chromaMultiplier: (s) => _cmf(s) ? 1.7 : 0,
        isBackground: true,
      );

  @override
  McuDynamicColor inverseOnSurface() => McuDynamicColor.fromPalette(
        name: 'inverse_on_surface',
        palette: (s) => s.neutralPalette,
        background: (s) => inverseSurface(),
        contrastCurve: (s) => mcuGetCurve(7),
      );

  @override
  McuDynamicColor primary() => McuDynamicColor.fromPalette(
        name: 'primary',
        palette: (s) => s.primaryPalette,
        tone: (s) => s.sourceColorHct.chroma <= 12
            ? (s.isDark ? 80 : 40)
            : s.sourceColorHct.tone,
        isBackground: true,
        background: highestSurface,
        contrastCurve: (s) => mcuGetCurve(4.5),
        toneDeltaPair: (s) => McuToneDeltaPair(
          primaryContainer(),
          primary(),
          5,
          McuTonePolarity.relativeLighter,
          true,
          McuDeltaConstraint.farther,
        ),
      );

  @override
  McuDynamicColor onPrimary() => McuDynamicColor.fromPalette(
        name: 'on_primary',
        palette: (s) => s.primaryPalette,
        background: (s) => primary(),
        contrastCurve: (s) => mcuGetCurve(6),
      );

  @override
  McuDynamicColor primaryContainer() => McuDynamicColor.fromPalette(
        name: 'primary_container',
        palette: (s) => s.primaryPalette,
        tone: (s) {
          if (!s.isDark && s.sourceColorHct.chroma <= 12) return 90;
          return s.sourceColorHct.tone > 55
              ? MathUtils.clampDouble(61, 90, s.sourceColorHct.tone)
              : MathUtils.clampDouble(30, 49, s.sourceColorHct.tone);
        },
        isBackground: true,
        background: highestSurface,
        contrastCurve: (s) => s.contrastLevel > 0 ? mcuGetCurve(1.5) : null,
      );

  @override
  McuDynamicColor onPrimaryContainer() => McuDynamicColor.fromPalette(
        name: 'on_primary_container',
        palette: (s) => s.primaryPalette,
        background: (s) => primaryContainer(),
        contrastCurve: (s) => mcuGetCurve(6),
      );

  @override
  McuDynamicColor secondary() => McuDynamicColor.fromPalette(
        name: 'secondary',
        palette: (s) => s.secondaryPalette,
        tone: (s) =>
            s.isDark ? tMinC(s.secondaryPalette) : tMaxC(s.secondaryPalette),
        isBackground: true,
        background: highestSurface,
        contrastCurve: (s) => mcuGetCurve(4.5),
        toneDeltaPair: (s) => McuToneDeltaPair(
          secondaryContainer(),
          secondary(),
          5,
          McuTonePolarity.relativeLighter,
          true,
          McuDeltaConstraint.farther,
        ),
      );

  @override
  McuDynamicColor onSecondary() => McuDynamicColor.fromPalette(
        name: 'on_secondary',
        palette: (s) => s.secondaryPalette,
        background: (s) => secondary(),
        contrastCurve: (s) => mcuGetCurve(6),
      );

  @override
  McuDynamicColor secondaryContainer() => McuDynamicColor.fromPalette(
        name: 'secondary_container',
        palette: (s) => s.secondaryPalette,
        tone: (s) => s.isDark
            ? tMinC(s.secondaryPalette, 20, 49)
            : tMaxC(s.secondaryPalette, 61, 90),
        isBackground: true,
        background: highestSurface,
        contrastCurve: (s) => s.contrastLevel > 0 ? mcuGetCurve(1.5) : null,
      );

  @override
  McuDynamicColor onSecondaryContainer() => McuDynamicColor.fromPalette(
        name: 'on_secondary_container',
        palette: (s) => s.secondaryPalette,
        background: (s) => secondaryContainer(),
        contrastCurve: (s) => mcuGetCurve(6),
      );

  @override
  McuDynamicColor tertiary() => McuDynamicColor.fromPalette(
        name: 'tertiary',
        palette: (s) => s.tertiaryPalette,
        tone: (s) => s.sourceColorHcts.length > 1
            ? s.sourceColorHcts[1].tone
            : s.sourceColorHct.tone,
        isBackground: true,
        background: highestSurface,
        contrastCurve: (s) => mcuGetCurve(4.5),
        toneDeltaPair: (s) => McuToneDeltaPair(
          tertiaryContainer(),
          tertiary(),
          5,
          McuTonePolarity.relativeLighter,
          true,
          McuDeltaConstraint.farther,
        ),
      );

  @override
  McuDynamicColor onTertiary() => McuDynamicColor.fromPalette(
        name: 'on_tertiary',
        palette: (s) => s.tertiaryPalette,
        background: (s) => tertiary(),
        contrastCurve: (s) => mcuGetCurve(6),
      );

  @override
  McuDynamicColor tertiaryContainer() => McuDynamicColor.fromPalette(
        name: 'tertiary_container',
        palette: (s) => s.tertiaryPalette,
        tone: (s) {
          final secondarySource = s.sourceColorHcts.length > 1
              ? s.sourceColorHcts[1]
              : s.sourceColorHct;
          return secondarySource.tone > 55
              ? MathUtils.clampDouble(61, 90, secondarySource.tone)
              : MathUtils.clampDouble(20, 49, secondarySource.tone);
        },
        isBackground: true,
        background: highestSurface,
        contrastCurve: (s) => s.contrastLevel > 0 ? mcuGetCurve(1.5) : null,
      );

  @override
  McuDynamicColor onTertiaryContainer() => McuDynamicColor.fromPalette(
        name: 'on_tertiary_container',
        palette: (s) => s.tertiaryPalette,
        background: (s) => tertiaryContainer(),
        contrastCurve: (s) => mcuGetCurve(6),
      );

  @override
  McuDynamicColor error() => McuDynamicColor.fromPalette(
        name: 'error',
        palette: (s) => s.errorPalette,
        tone: (s) => tMaxC(s.errorPalette),
        isBackground: true,
        background: highestSurface,
        contrastCurve: (s) => mcuGetCurve(4.5),
        toneDeltaPair: (s) => McuToneDeltaPair(
          errorContainer(),
          error(),
          5,
          McuTonePolarity.relativeLighter,
          true,
          McuDeltaConstraint.farther,
        ),
      );

  @override
  McuDynamicColor onError() => McuDynamicColor.fromPalette(
        name: 'on_error',
        palette: (s) => s.errorPalette,
        background: (s) => error(),
        contrastCurve: (s) => mcuGetCurve(6),
      );

  @override
  McuDynamicColor errorContainer() => McuDynamicColor.fromPalette(
        name: 'error_container',
        palette: (s) => s.errorPalette,
        tone: (s) => s.isDark ? tMinC(s.errorPalette) : tMaxC(s.errorPalette),
        isBackground: true,
        background: highestSurface,
        contrastCurve: (s) => s.contrastLevel > 0 ? mcuGetCurve(1.5) : null,
      );

  @override
  McuDynamicColor onErrorContainer() => McuDynamicColor.fromPalette(
        name: 'on_error_container',
        palette: (s) => s.errorPalette,
        background: (s) => errorContainer(),
        contrastCurve: (s) => mcuGetCurve(6),
      );
}
