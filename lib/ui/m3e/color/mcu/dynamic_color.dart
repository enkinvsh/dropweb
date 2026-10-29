// Порт из MCU TS bd811e4 dynamiccolor/dynamic_color.ts (Apache-2.0, см. LICENSE).
//
// Только расчёт для spec 2025/2026 (ColorCalculationDelegateImpl2025). Расчёт 2021,
// extendSpecVersion и кэш Hct по схеме не нужны: схемы доски всегда >= 2025, а
// выбор цвета по версии спецификации сделан наследованием McuColorSpec2026 от 2025.

import 'package:material_color_utilities/material_color_utilities.dart'
    show Contrast, Hct, MathUtils;

import 'contrast_curve.dart';
import 'dynamic_scheme.dart';
import 'hue_ranges.dart';
import 'tonal_palette.dart';
import 'tone_delta_pair.dart';

typedef McuSchemeFn<T> = T Function(McuDynamicScheme s);

/// Роль, цвет которой подстраивается под схему: палитра, тон, фон и контраст к нему.
class McuDynamicColor {
  McuDynamicColor({
    required this.name,
    required this.palette,
    required this.tone,
    required this.isBackground,
    this.chromaMultiplier,
    this.background,
    this.secondBackground,
    this.contrastCurve,
    this.toneDeltaPair,
  });

  /// Как DynamicColor.fromPalette: без явного тона он равен тону фона (или 50).
  factory McuDynamicColor.fromPalette({
    required String name,
    required McuSchemeFn<McuTonalPalette> palette,
    McuSchemeFn<double>? tone,
    bool isBackground = false,
    McuSchemeFn<double>? chromaMultiplier,
    McuSchemeFn<McuDynamicColor?>? background,
    McuSchemeFn<McuDynamicColor?>? secondBackground,
    McuSchemeFn<McuContrastCurve?>? contrastCurve,
    McuSchemeFn<McuToneDeltaPair?>? toneDeltaPair,
  }) =>
      McuDynamicColor(
        name: name,
        palette: palette,
        tone: tone ?? getInitialToneFromBackground(background),
        isBackground: isBackground,
        chromaMultiplier: chromaMultiplier,
        background: background,
        secondBackground: secondBackground,
        contrastCurve: contrastCurve,
        toneDeltaPair: toneDeltaPair,
      );

  final String name;
  final McuSchemeFn<McuTonalPalette> palette;
  final McuSchemeFn<double> tone;
  final bool isBackground;
  final McuSchemeFn<double>? chromaMultiplier;
  final McuSchemeFn<McuDynamicColor?>? background;
  final McuSchemeFn<McuDynamicColor?>? secondBackground;
  final McuSchemeFn<McuContrastCurve?>? contrastCurve;
  final McuSchemeFn<McuToneDeltaPair?>? toneDeltaPair;

  /// Копия с другим именем и/или тоном (Object.assign(color.clone(), {...}) в TS).
  McuDynamicColor copyWith({String? name, McuSchemeFn<double>? tone}) =>
      McuDynamicColor(
        name: name ?? this.name,
        palette: palette,
        tone: tone ?? this.tone,
        isBackground: isBackground,
        chromaMultiplier: chromaMultiplier,
        background: background,
        secondBackground: secondBackground,
        contrastCurve: contrastCurve,
        toneDeltaPair: toneDeltaPair,
      );

  static McuSchemeFn<double> getInitialToneFromBackground(
    McuSchemeFn<McuDynamicColor?>? background,
  ) {
    if (background == null) return (s) => 50;
    return (s) {
      final bg = background(s);
      return bg != null ? bg.getTone(s) : 50;
    };
  }

  /// ARGB цвета роли в схеме [scheme].
  int getArgb(McuDynamicScheme scheme) => getHct(scheme).toInt();

  Hct getHct(McuDynamicScheme scheme) {
    final pal = palette(scheme);
    final toneValue = getTone(scheme);
    final multiplier = chromaMultiplier != null ? chromaMultiplier!(scheme) : 1;
    if (multiplier == 1) {
      return pal.getHct(toneValue);
    }
    final chroma = pal.chroma * multiplier;
    if (toneValue == 99 && hueIsYellow(pal.hue)) {
      return McuTonalPalette.fromHueAndChroma(pal.hue, chroma)
          .getHct(toneValue);
    }
    return Hct.from(pal.hue, chroma, toneValue);
  }

  double getTone(McuDynamicScheme scheme) {
    final pair = toneDeltaPair != null ? toneDeltaPair!(scheme) : null;

    // Случай 0: ограничение на разницу тонов с парной ролью.
    if (pair != null) {
      final roleA = pair.roleA;
      final roleB = pair.roleB;
      final polarity = pair.polarity;
      final constraint = pair.constraint;
      final absoluteDelta = polarity == McuTonePolarity.darker ||
              (polarity == McuTonePolarity.relativeLighter && scheme.isDark) ||
              (polarity == McuTonePolarity.relativeDarker && !scheme.isDark)
          ? -pair.delta
          : pair.delta;

      final amRoleA = name == roleA.name;
      final selfRole = amRoleA ? roleA : roleB;
      final refRole = amRoleA ? roleB : roleA;
      var selfTone = selfRole.tone(scheme);
      final refTone = refRole.getTone(scheme);
      final relativeDelta = absoluteDelta * (amRoleA ? 1 : -1);

      if (constraint == McuDeltaConstraint.exact) {
        selfTone = MathUtils.clampDouble(0, 100, refTone + relativeDelta);
      } else if (constraint == McuDeltaConstraint.nearer) {
        if (relativeDelta > 0) {
          selfTone = MathUtils.clampDouble(
            0,
            100,
            MathUtils.clampDouble(refTone, refTone + relativeDelta, selfTone),
          );
        } else {
          selfTone = MathUtils.clampDouble(
            0,
            100,
            MathUtils.clampDouble(refTone + relativeDelta, refTone, selfTone),
          );
        }
      } else if (constraint == McuDeltaConstraint.farther) {
        if (relativeDelta > 0) {
          selfTone =
              MathUtils.clampDouble(refTone + relativeDelta, 100, selfTone);
        } else {
          selfTone =
              MathUtils.clampDouble(0, refTone + relativeDelta, selfTone);
        }
      }

      if (background != null && contrastCurve != null) {
        final bg = background!(scheme);
        final curve = contrastCurve!(scheme);
        if (bg != null && curve != null) {
          final bgTone = bg.getTone(scheme);
          final selfContrast = curve.get(scheme.contrastLevel);
          selfTone = Contrast.ratioOfTones(bgTone, selfTone) >= selfContrast &&
                  scheme.contrastLevel >= 0
              ? selfTone
              : foregroundTone(bgTone, selfContrast);
        }
      }

      // Обходим «неудобную» зону тонов 50–59 для фоновых ролей (кроме *_fixed_dim).
      if (isBackground && !name.endsWith('_fixed_dim')) {
        if (selfTone >= 57) {
          selfTone = MathUtils.clampDouble(65, 100, selfTone);
        } else {
          selfTone = MathUtils.clampDouble(0, 49, selfTone);
        }
      }

      return selfTone;
    }

    // Случай 1: пары нет, роль решает сама за себя.
    var answer = tone(scheme);

    if (background == null ||
        background!(scheme) == null ||
        contrastCurve == null ||
        contrastCurve!(scheme) == null) {
      return answer; // у роли без фона тон не подстраивается
    }

    final bgTone = background!(scheme)!.getTone(scheme);
    final desiredRatio = contrastCurve!(scheme)!.get(scheme.contrastLevel);

    // Пересчитываем тон, если контраста не хватает или уровень контраста снижен (<0).
    answer = Contrast.ratioOfTones(bgTone, answer) >= desiredRatio &&
            scheme.contrastLevel >= 0
        ? answer
        : foregroundTone(bgTone, desiredRatio);

    if (isBackground && !name.endsWith('_fixed_dim')) {
      if (answer >= 57) {
        answer = MathUtils.clampDouble(65, 100, answer);
      } else {
        answer = MathUtils.clampDouble(0, 49, answer);
      }
    }

    if (secondBackground == null || secondBackground!(scheme) == null) {
      return answer;
    }

    // Случай 2: два фона.
    final bgTone1 = background!(scheme)!.getTone(scheme);
    final bgTone2 = secondBackground!(scheme)!.getTone(scheme);
    final upper = bgTone1 > bgTone2 ? bgTone1 : bgTone2;
    final lower = bgTone1 < bgTone2 ? bgTone1 : bgTone2;

    if (Contrast.ratioOfTones(upper, answer) >= desiredRatio &&
        Contrast.ratioOfTones(lower, answer) >= desiredRatio) {
      return answer;
    }

    final lightOption = Contrast.lighter(tone: upper, ratio: desiredRatio);
    final darkOption = Contrast.darker(tone: lower, ratio: desiredRatio);

    final availables = <double>[];
    if (lightOption != -1) availables.add(lightOption);
    if (darkOption != -1) availables.add(darkOption);

    final prefersLight = tonePrefersLightForeground(bgTone1) ||
        tonePrefersLightForeground(bgTone2);
    if (prefersLight) {
      return lightOption < 0 ? 100 : lightOption;
    }
    if (availables.length == 1) {
      return availables[0];
    }
    return darkOption < 0 ? 0 : darkOption;
  }

  /// Тон переднего плана, дающий контраст, максимально близкий к [ratio] с фоном [bgTone].
  static double foregroundTone(double bgTone, double ratio) {
    final lighterTone = Contrast.lighterUnsafe(tone: bgTone, ratio: ratio);
    final darkerTone = Contrast.darkerUnsafe(tone: bgTone, ratio: ratio);
    final lighterRatio = Contrast.ratioOfTones(lighterTone, bgTone);
    final darkerRatio = Contrast.ratioOfTones(darkerTone, bgTone);
    final preferLighter = tonePrefersLightForeground(bgTone);

    if (preferLighter) {
      // Крайний случай: исходный контраст высок, оба направления не дотягивают до ratio.
      final negligibleDifference = (lighterRatio - darkerRatio).abs() < 0.1 &&
          lighterRatio < ratio &&
          darkerRatio < ratio;
      return lighterRatio >= ratio ||
              lighterRatio >= darkerRatio ||
              negligibleDifference
          ? lighterTone
          : darkerTone;
    } else {
      return darkerRatio >= ratio || darkerRatio >= lighterRatio
          ? darkerTone
          : lighterTone;
    }
  }

  // Math.round в JS округляет половину вверх, Dart round() — от нуля; тоны неотрицательны,
  // поэтому результат одинаков.
  static bool tonePrefersLightForeground(double tone) => tone.round() < 60.0;
}
