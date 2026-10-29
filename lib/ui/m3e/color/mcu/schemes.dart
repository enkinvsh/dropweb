// Порт из MCU TS bd811e4 scheme/scheme_cmf.ts, scheme_tonal_spot.ts, scheme_vibrant.ts,
// scheme_expressive.ts, scheme_neutral.ts (Apache-2.0, см. LICENSE).
//
// В TS это подклассы DynamicScheme; здесь — фабрики, потому что вся разница между ними
// в варианте и (для CMF) в явно заданных палитрах.

import 'package:material_color_utilities/material_color_utilities.dart'
    show Hct;

import 'color_spec_2025.dart';
import 'color_spec_2026.dart';
import 'dynamic_scheme.dart';
import 'tonal_palette.dart';
import 'variant.dart';

/// Схема CMF, spec 2026: primary-container ровно равен seed, нейтрали несут оттенок seed.
McuDynamicScheme mcuSchemeCmf(
    Hct sourceColorHct, bool isDark, double contrastLevel) {
  final primary = McuTonalPalette.fromHueAndChroma(
    sourceColorHct.hue,
    sourceColorHct.chroma,
  );
  final secondary = McuTonalPalette.fromHueAndChroma(
    sourceColorHct.hue,
    sourceColorHct.chroma * 0.5,
  );
  // Один исходный цвет: второй (secondarySourceColorHct) совпадает с первым.
  final tertiary = McuTonalPalette.fromHueAndChroma(
    sourceColorHct.hue,
    sourceColorHct.chroma * 0.75,
  );
  final neutral = McuTonalPalette.fromHueAndChroma(
    sourceColorHct.hue,
    sourceColorHct.chroma * 0.2,
  );
  final neutralVariant = McuTonalPalette.fromHueAndChroma(
    sourceColorHct.hue,
    sourceColorHct.chroma * 0.2,
  );
  final error = McuTonalPalette.fromHueAndChroma(
    mcuCmfErrorHue(sourceColorHct.hue, sourceColorHct.hue),
    sourceColorHct.chroma > 50.0 ? sourceColorHct.chroma : 50.0,
  );
  return McuDynamicScheme(
    sourceColorHct: sourceColorHct,
    variant: McuVariant.cmf,
    contrastLevel: contrastLevel,
    isDark: isDark,
    specVersion: McuSpecVersion.v2026,
    primaryPalette: primary,
    secondaryPalette: secondary,
    tertiaryPalette: tertiary,
    neutralPalette: neutral,
    neutralVariantPalette: neutralVariant,
    errorPalette: error,
  );
}

/// Оттенок error-палитры CMF по оттенкам primary и tertiary.
double mcuCmfErrorHue(double primaryHue, double tertiaryHue) {
  if (primaryHue <= 8) {
    return tertiaryHue <= 24 ? 28 : (tertiaryHue <= 32 ? 16 : 20);
  } else if (primaryHue <= 16) {
    return tertiaryHue <= 24 ? 32 : (tertiaryHue <= 32 ? 20 : 24);
  } else if (primaryHue <= 20) {
    return tertiaryHue <= 28 ? 32 : (tertiaryHue <= 32 ? 24 : 28);
  } else if (primaryHue <= 28) {
    return tertiaryHue <= 24 ? 32 : 16;
  } else if (primaryHue <= 32) {
    return tertiaryHue <= 20 ? 24 : (tertiaryHue <= 28 ? 16 : 20);
  } else if (primaryHue <= 40) {
    return (tertiaryHue > 20 && tertiaryHue <= 28) ? 16 : 24;
  } else if (primaryHue <= 152) {
    return (tertiaryHue > 24 && tertiaryHue <= 36) ? 20 : 32;
  } else if (primaryHue <= 272) {
    return (tertiaryHue > 20 && tertiaryHue <= 28) ? 16 : 24;
  } else {
    return (tertiaryHue > 12 && tertiaryHue <= 28) ? 32 : 16;
  }
}

/// Схема одного из четырёх вариантов spec 2025 (tonal_spot, vibrant, expressive, neutral).
McuDynamicScheme mcuScheme2025(
  McuVariant variant,
  Hct sourceColorHct,
  bool isDark,
  double contrastLevel,
) {
  assert(variant != McuVariant.cmf, 'CMF строится через mcuSchemeCmf');
  return McuDynamicScheme(
    sourceColorHct: sourceColorHct,
    variant: variant,
    contrastLevel: contrastLevel,
    isDark: isDark,
    specVersion: McuSpecVersion.v2025,
  );
}

const McuColorSpec2025 _spec2025 = McuColorSpec2025();
const McuColorSpec2026 _spec2026 = McuColorSpec2026();

/// Спецификация ролей, которой считается [scheme] (CMF → 2026, остальные → 2025).
McuColorSpec2025 mcuSpecFor(McuDynamicScheme scheme) =>
    scheme.specVersion == McuSpecVersion.v2026 ? _spec2026 : _spec2025;

/// ARGB роли [role] (имя из ROLES доски) в схеме [scheme].
int mcuRoleArgb(McuDynamicScheme scheme, String role) =>
    mcuSpecFor(scheme).byRole(role).getArgb(scheme);
