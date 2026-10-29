// Порт из MCU TS bd811e4 dynamiccolor/color_spec_2025.ts (+ shadow/scrim/highestSurface из
// color_spec_2021.ts, + карта ролей из material_dynamic_colors.ts) (Apache-2.0, см. LICENSE).
//
// Только платформа phone; ветки 'watch', роли *Fixed/*Dim и ключевые цвета палитр не портированы.

import 'package:material_color_utilities/material_color_utilities.dart'
    show Hct, MathUtils;

import 'contrast_curve.dart';
import 'dynamic_color.dart';
import 'dynamic_scheme.dart';
import 'hue_ranges.dart';
import 'tonal_palette.dart';
import 'tone_delta_pair.dart';
import 'variant.dart';

// Поиск тона перебирается по единице до сотни раз, а ролей десятки и многие вызываются
// по нескольку раз за схему, поэтому результат кэшируется.
final Map<String, double> _bestToneCache = {};

/// Максимальный тон, на котором палитра ещё даёт свою насыщенность.
double tMaxC(
  McuTonalPalette palette, [
  double lowerBound = 0,
  double upperBound = 100,
  double chromaMultiplier = 1,
]) {
  final answer = _findBestToneForChroma(
    palette.hue,
    palette.chroma * chromaMultiplier,
    100,
    true,
  );
  return MathUtils.clampDouble(lowerBound, upperBound, answer);
}

/// Минимальный тон, на котором палитра ещё даёт свою насыщенность.
double tMinC(
  McuTonalPalette palette, [
  double lowerBound = 0,
  double upperBound = 100,
]) {
  final answer = _findBestToneForChroma(palette.hue, palette.chroma, 0, false);
  return MathUtils.clampDouble(lowerBound, upperBound, answer);
}

double _findBestToneForChroma(
  double hue,
  double chroma,
  double tone,
  bool byDecreasingTone,
) {
  final key = '$hue|$chroma|$tone|$byDecreasingTone';
  final cached = _bestToneCache[key];
  if (cached != null) return cached;

  var answer = tone;
  var bestCandidate = Hct.from(hue, chroma, answer);
  while (bestCandidate.chroma < chroma) {
    if (tone < 0 || tone > 100) break;
    tone += byDecreasingTone ? -1.0 : 1.0;
    final newCandidate = Hct.from(hue, chroma, tone);
    if (bestCandidate.chroma < newCandidate.chroma) {
      bestCandidate = newCandidate;
      answer = tone;
    }
  }
  _bestToneCache[key] = answer;
  return answer;
}

/// Кривая контраста для базового значения (как getCurve в спецификации).
McuContrastCurve mcuGetCurve(double defaultContrast) {
  if (defaultContrast == 1.5) {
    return const McuContrastCurve(1.5, 1.5, 3, 5.5);
  } else if (defaultContrast == 3) {
    return const McuContrastCurve(3, 3, 4.5, 7);
  } else if (defaultContrast == 4.5) {
    return const McuContrastCurve(4.5, 4.5, 7, 11);
  } else if (defaultContrast == 6) {
    return const McuContrastCurve(6, 6, 7, 11);
  } else if (defaultContrast == 7) {
    return const McuContrastCurve(7, 7, 11, 21);
  } else if (defaultContrast == 9) {
    return const McuContrastCurve(9, 9, 11, 21);
  } else if (defaultContrast == 11) {
    return const McuContrastCurve(11, 11, 21, 21);
  } else if (defaultContrast == 21) {
    return const McuContrastCurve(21, 21, 21, 21);
  } else {
    return McuContrastCurve(defaultContrast, defaultContrast, 7, 21);
  }
}

/// Спецификация цветов ролей, spec 2025 (платформа phone).
///
/// Каждый метод создаёт роль заново, как в TS: роли ссылаются друг на друга через `this`,
/// поэтому McuColorSpec2026 подменяет часть ролей, а остальные автоматически берут
/// подменённые.
class McuColorSpec2025 {
  const McuColorSpec2025();

  /// Роль по имени из ROLES доски (camelCase, как в android.js).
  McuDynamicColor byRole(String role) {
    switch (role) {
      case 'primary':
        return primary();
      case 'onPrimary':
        return onPrimary();
      case 'primaryContainer':
        return primaryContainer();
      case 'onPrimaryContainer':
        return onPrimaryContainer();
      case 'inversePrimary':
        return inversePrimary();
      case 'secondary':
        return secondary();
      case 'onSecondary':
        return onSecondary();
      case 'secondaryContainer':
        return secondaryContainer();
      case 'onSecondaryContainer':
        return onSecondaryContainer();
      case 'tertiary':
        return tertiary();
      case 'onTertiary':
        return onTertiary();
      case 'tertiaryContainer':
        return tertiaryContainer();
      case 'onTertiaryContainer':
        return onTertiaryContainer();
      case 'error':
        return error();
      case 'onError':
        return onError();
      case 'errorContainer':
        return errorContainer();
      case 'onErrorContainer':
        return onErrorContainer();
      case 'background':
        return background();
      case 'onBackground':
        return onBackground();
      case 'surface':
        return surface();
      case 'onSurface':
        return onSurface();
      case 'surfaceVariant':
        return surfaceVariant();
      case 'onSurfaceVariant':
        return onSurfaceVariant();
      case 'surfaceDim':
        return surfaceDim();
      case 'surfaceBright':
        return surfaceBright();
      case 'surfaceContainerLowest':
        return surfaceContainerLowest();
      case 'surfaceContainerLow':
        return surfaceContainerLow();
      case 'surfaceContainer':
        return surfaceContainer();
      case 'surfaceContainerHigh':
        return surfaceContainerHigh();
      case 'surfaceContainerHighest':
        return surfaceContainerHighest();
      case 'inverseSurface':
        return inverseSurface();
      case 'inverseOnSurface':
        return inverseOnSurface();
      case 'outline':
        return outline();
      case 'outlineVariant':
        return outlineVariant();
      case 'scrim':
        return scrim();
      case 'shadow':
        return shadow();
      case 'surfaceTint':
        return surfaceTint();
    }
    throw ArgumentError.value(role, 'role', 'неизвестная роль');
  }

  /// Самая «яркая» поверхность схемы: фон, относительно которого считается контраст текста.
  McuDynamicColor highestSurface(McuDynamicScheme s) =>
      s.isDark ? surfaceBright() : surfaceDim();

  // ---- Поверхности ----

  McuDynamicColor surface() => McuDynamicColor.fromPalette(
        name: 'surface',
        palette: (s) => s.neutralPalette,
        tone: (s) {
          if (s.isDark) return 4;
          if (hueIsYellow(s.neutralPalette.hue)) return 99;
          if (s.variant == McuVariant.vibrant) return 97;
          return 98;
        },
        isBackground: true,
      );

  McuDynamicColor surfaceDim() => McuDynamicColor.fromPalette(
        name: 'surface_dim',
        palette: (s) => s.neutralPalette,
        tone: (s) {
          if (s.isDark) return 4;
          if (hueIsYellow(s.neutralPalette.hue)) return 90;
          if (s.variant == McuVariant.vibrant) return 85;
          return 87;
        },
        isBackground: true,
        chromaMultiplier: (s) {
          if (!s.isDark) {
            switch (s.variant) {
              case McuVariant.neutral:
                return 2.5;
              case McuVariant.tonalSpot:
                return 1.7;
              case McuVariant.expressive:
                return hueIsYellow(s.neutralPalette.hue) ? 2.7 : 1.75;
              case McuVariant.vibrant:
                return 1.36;
              case McuVariant.cmf:
                break;
            }
          }
          return 1;
        },
      );

  McuDynamicColor surfaceBright() => McuDynamicColor.fromPalette(
        name: 'surface_bright',
        palette: (s) => s.neutralPalette,
        tone: (s) {
          if (s.isDark) return 18;
          if (hueIsYellow(s.neutralPalette.hue)) return 99;
          if (s.variant == McuVariant.vibrant) return 97;
          return 98;
        },
        isBackground: true,
        chromaMultiplier: (s) {
          if (s.isDark) {
            switch (s.variant) {
              case McuVariant.neutral:
                return 2.5;
              case McuVariant.tonalSpot:
                return 1.7;
              case McuVariant.expressive:
                return hueIsYellow(s.neutralPalette.hue) ? 2.7 : 1.75;
              case McuVariant.vibrant:
                return 1.36;
              case McuVariant.cmf:
                break;
            }
          }
          return 1;
        },
      );

  McuDynamicColor surfaceContainerLowest() => McuDynamicColor.fromPalette(
        name: 'surface_container_lowest',
        palette: (s) => s.neutralPalette,
        tone: (s) => s.isDark ? 0 : 100,
        isBackground: true,
      );

  McuDynamicColor surfaceContainerLow() => McuDynamicColor.fromPalette(
        name: 'surface_container_low',
        palette: (s) => s.neutralPalette,
        tone: (s) {
          if (s.isDark) return 6;
          if (hueIsYellow(s.neutralPalette.hue)) return 98;
          if (s.variant == McuVariant.vibrant) return 95;
          return 96;
        },
        isBackground: true,
        chromaMultiplier: (s) {
          switch (s.variant) {
            case McuVariant.neutral:
              return 1.3;
            case McuVariant.tonalSpot:
              return 1.25;
            case McuVariant.expressive:
              return hueIsYellow(s.neutralPalette.hue) ? 1.3 : 1.15;
            case McuVariant.vibrant:
              return 1.08;
            case McuVariant.cmf:
              return 1;
          }
        },
      );

  McuDynamicColor surfaceContainer() => McuDynamicColor.fromPalette(
        name: 'surface_container',
        palette: (s) => s.neutralPalette,
        tone: (s) {
          if (s.isDark) return 9;
          if (hueIsYellow(s.neutralPalette.hue)) return 96;
          if (s.variant == McuVariant.vibrant) return 92;
          return 94;
        },
        isBackground: true,
        chromaMultiplier: (s) {
          switch (s.variant) {
            case McuVariant.neutral:
              return 1.6;
            case McuVariant.tonalSpot:
              return 1.4;
            case McuVariant.expressive:
              return hueIsYellow(s.neutralPalette.hue) ? 1.6 : 1.3;
            case McuVariant.vibrant:
              return 1.15;
            case McuVariant.cmf:
              return 1;
          }
        },
      );

  McuDynamicColor surfaceContainerHigh() => McuDynamicColor.fromPalette(
        name: 'surface_container_high',
        palette: (s) => s.neutralPalette,
        tone: (s) {
          if (s.isDark) return 12;
          if (hueIsYellow(s.neutralPalette.hue)) return 94;
          if (s.variant == McuVariant.vibrant) return 90;
          return 92;
        },
        isBackground: true,
        chromaMultiplier: (s) {
          switch (s.variant) {
            case McuVariant.neutral:
              return 1.9;
            case McuVariant.tonalSpot:
              return 1.5;
            case McuVariant.expressive:
              return hueIsYellow(s.neutralPalette.hue) ? 1.95 : 1.45;
            case McuVariant.vibrant:
              return 1.22;
            case McuVariant.cmf:
              return 1;
          }
        },
      );

  McuDynamicColor surfaceContainerHighest() => McuDynamicColor.fromPalette(
        name: 'surface_container_highest',
        palette: (s) => s.neutralPalette,
        tone: (s) {
          if (s.isDark) return 15;
          if (hueIsYellow(s.neutralPalette.hue)) return 92;
          if (s.variant == McuVariant.vibrant) return 88;
          return 90;
        },
        isBackground: true,
        chromaMultiplier: (s) {
          switch (s.variant) {
            case McuVariant.neutral:
              return 2.2;
            case McuVariant.tonalSpot:
              return 1.7;
            case McuVariant.expressive:
              return hueIsYellow(s.neutralPalette.hue) ? 2.3 : 1.6;
            case McuVariant.vibrant:
              return 1.29;
            case McuVariant.cmf:
              return 1;
          }
        },
      );

  // Множитель насыщенности текстовых ролей поверхности (onSurface и т.п.).
  double _onSurfaceChroma(McuDynamicScheme s) {
    switch (s.variant) {
      case McuVariant.neutral:
        return 2.2;
      case McuVariant.tonalSpot:
        return 1.7;
      case McuVariant.expressive:
        return hueIsYellow(s.neutralPalette.hue) ? (s.isDark ? 3.0 : 2.3) : 1.6;
      case McuVariant.vibrant:
      case McuVariant.cmf:
        return 1;
    }
  }

  McuDynamicColor onSurface() => McuDynamicColor.fromPalette(
        name: 'on_surface',
        palette: (s) => s.neutralPalette,
        tone: (s) {
          if (s.variant == McuVariant.vibrant) {
            return tMaxC(s.neutralPalette, 0, 100, 1.1);
          }
          // Остальные варианты: начальный тон равен тону фона.
          return McuDynamicColor.getInitialToneFromBackground(
            highestSurface,
          )(s);
        },
        chromaMultiplier: _onSurfaceChroma,
        background: highestSurface,
        contrastCurve: (s) => s.isDark ? mcuGetCurve(11) : mcuGetCurve(9),
      );

  McuDynamicColor onSurfaceVariant() => McuDynamicColor.fromPalette(
        name: 'on_surface_variant',
        palette: (s) => s.neutralPalette,
        chromaMultiplier: _onSurfaceChroma,
        background: highestSurface,
        contrastCurve: (s) => s.isDark ? mcuGetCurve(6) : mcuGetCurve(4.5),
      );

  McuDynamicColor outline() => McuDynamicColor.fromPalette(
        name: 'outline',
        palette: (s) => s.neutralPalette,
        chromaMultiplier: _onSurfaceChroma,
        background: highestSurface,
        contrastCurve: (s) => mcuGetCurve(3),
      );

  McuDynamicColor outlineVariant() => McuDynamicColor.fromPalette(
        name: 'outline_variant',
        palette: (s) => s.neutralPalette,
        chromaMultiplier: _onSurfaceChroma,
        background: highestSurface,
        contrastCurve: (s) => mcuGetCurve(1.5),
      );

  McuDynamicColor inverseSurface() => McuDynamicColor.fromPalette(
        name: 'inverse_surface',
        palette: (s) => s.neutralPalette,
        tone: (s) => s.isDark ? 98 : 4,
        isBackground: true,
      );

  McuDynamicColor inverseOnSurface() => McuDynamicColor.fromPalette(
        name: 'inverse_on_surface',
        palette: (s) => s.neutralPalette,
        background: (s) => inverseSurface(),
        contrastCurve: (s) => mcuGetCurve(7),
      );

  /// Из color_spec_2021.ts: spec 2025 эту роль не переопределяет.
  McuDynamicColor shadow() => McuDynamicColor.fromPalette(
        name: 'shadow',
        palette: (s) => s.neutralPalette,
        tone: (s) => 0,
      );

  /// Из color_spec_2021.ts: spec 2025 эту роль не переопределяет.
  McuDynamicColor scrim() => McuDynamicColor.fromPalette(
        name: 'scrim',
        palette: (s) => s.neutralPalette,
        tone: (s) => 0,
      );

  // ---- Primary ----

  McuDynamicColor primary() => McuDynamicColor.fromPalette(
        name: 'primary',
        palette: (s) => s.primaryPalette,
        tone: (s) {
          switch (s.variant) {
            case McuVariant.neutral:
              return s.isDark ? 80 : 40;
            case McuVariant.tonalSpot:
              return s.isDark ? 80 : tMaxC(s.primaryPalette);
            case McuVariant.expressive:
              return tMaxC(
                s.primaryPalette,
                0,
                s.isDark
                    ? (hueIsCyan(s.primaryPalette.hue) ? 88 : 98)
                    : (hueIsYellow(s.primaryPalette.hue) ? 25 : 98),
              );
            case McuVariant.vibrant:
            case McuVariant.cmf:
              return tMaxC(
                s.primaryPalette,
                0,
                hueIsCyan(s.primaryPalette.hue) ? 88 : 98,
              );
          }
        },
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

  McuDynamicColor onPrimary() => McuDynamicColor.fromPalette(
        name: 'on_primary',
        palette: (s) => s.primaryPalette,
        background: (s) => primary(),
        contrastCurve: (s) => mcuGetCurve(6),
      );

  McuDynamicColor primaryContainer() => McuDynamicColor.fromPalette(
        name: 'primary_container',
        palette: (s) => s.primaryPalette,
        tone: (s) {
          switch (s.variant) {
            case McuVariant.neutral:
              return s.isDark ? 30 : 90;
            case McuVariant.tonalSpot:
              return s.isDark
                  ? tMinC(s.primaryPalette, 35, 93)
                  : tMaxC(s.primaryPalette, 0, 90);
            case McuVariant.expressive:
              return s.isDark
                  ? tMinC(s.primaryPalette, 30, 93)
                  : tMaxC(
                      s.primaryPalette,
                      78,
                      hueIsCyan(s.primaryPalette.hue) ? 88 : 90,
                    );
            case McuVariant.vibrant:
            case McuVariant.cmf:
              return s.isDark
                  ? tMinC(s.primaryPalette, 66, 93)
                  : tMaxC(
                      s.primaryPalette,
                      66,
                      hueIsCyan(s.primaryPalette.hue) ? 88 : 93,
                    );
          }
        },
        isBackground: true,
        background: highestSurface,
        contrastCurve: (s) => s.contrastLevel > 0 ? mcuGetCurve(1.5) : null,
      );

  McuDynamicColor onPrimaryContainer() => McuDynamicColor.fromPalette(
        name: 'on_primary_container',
        palette: (s) => s.primaryPalette,
        background: (s) => primaryContainer(),
        contrastCurve: (s) => mcuGetCurve(6),
      );

  McuDynamicColor inversePrimary() => McuDynamicColor.fromPalette(
        name: 'inverse_primary',
        palette: (s) => s.primaryPalette,
        tone: (s) => tMaxC(s.primaryPalette),
        background: (s) => inverseSurface(),
        contrastCurve: (s) => mcuGetCurve(6),
      );

  // ---- Secondary ----

  McuDynamicColor secondary() => McuDynamicColor.fromPalette(
        name: 'secondary',
        palette: (s) => s.secondaryPalette,
        tone: (s) {
          switch (s.variant) {
            case McuVariant.neutral:
              return s.isDark
                  ? tMinC(s.secondaryPalette, 0, 98)
                  : tMaxC(s.secondaryPalette);
            case McuVariant.vibrant:
              return tMaxC(s.secondaryPalette, 0, s.isDark ? 90 : 98);
            case McuVariant.expressive:
            case McuVariant.tonalSpot:
            case McuVariant.cmf:
              return s.isDark ? 80 : tMaxC(s.secondaryPalette);
          }
        },
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

  McuDynamicColor onSecondary() => McuDynamicColor.fromPalette(
        name: 'on_secondary',
        palette: (s) => s.secondaryPalette,
        background: (s) => secondary(),
        contrastCurve: (s) => mcuGetCurve(6),
      );

  McuDynamicColor secondaryContainer() => McuDynamicColor.fromPalette(
        name: 'secondary_container',
        palette: (s) => s.secondaryPalette,
        tone: (s) {
          switch (s.variant) {
            case McuVariant.vibrant:
              return s.isDark
                  ? tMinC(s.secondaryPalette, 30, 40)
                  : tMaxC(s.secondaryPalette, 84, 90);
            case McuVariant.expressive:
              return s.isDark ? 15 : tMaxC(s.secondaryPalette, 90, 95);
            case McuVariant.neutral:
            case McuVariant.tonalSpot:
            case McuVariant.cmf:
              return s.isDark ? 25 : 90;
          }
        },
        isBackground: true,
        background: highestSurface,
        contrastCurve: (s) => s.contrastLevel > 0 ? mcuGetCurve(1.5) : null,
      );

  McuDynamicColor onSecondaryContainer() => McuDynamicColor.fromPalette(
        name: 'on_secondary_container',
        palette: (s) => s.secondaryPalette,
        background: (s) => secondaryContainer(),
        contrastCurve: (s) => mcuGetCurve(6),
      );

  // ---- Tertiary ----

  McuDynamicColor tertiary() => McuDynamicColor.fromPalette(
        name: 'tertiary',
        palette: (s) => s.tertiaryPalette,
        tone: (s) {
          if (s.variant == McuVariant.expressive ||
              s.variant == McuVariant.vibrant) {
            return tMaxC(
              s.tertiaryPalette,
              0,
              hueIsCyan(s.tertiaryPalette.hue) ? 88 : (s.isDark ? 98 : 100),
            );
          }
          // neutral и tonal_spot
          return s.isDark
              ? tMaxC(s.tertiaryPalette, 0, 98)
              : tMaxC(s.tertiaryPalette);
        },
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

  McuDynamicColor onTertiary() => McuDynamicColor.fromPalette(
        name: 'on_tertiary',
        palette: (s) => s.tertiaryPalette,
        background: (s) => tertiary(),
        contrastCurve: (s) => mcuGetCurve(6),
      );

  McuDynamicColor tertiaryContainer() => McuDynamicColor.fromPalette(
        name: 'tertiary_container',
        palette: (s) => s.tertiaryPalette,
        tone: (s) {
          switch (s.variant) {
            case McuVariant.neutral:
              return s.isDark
                  ? tMaxC(s.tertiaryPalette, 0, 93)
                  : tMaxC(s.tertiaryPalette, 0, 96);
            case McuVariant.tonalSpot:
              return tMaxC(s.tertiaryPalette, 0, s.isDark ? 93 : 100);
            case McuVariant.expressive:
              return tMaxC(
                s.tertiaryPalette,
                75,
                hueIsCyan(s.tertiaryPalette.hue) ? 88 : (s.isDark ? 93 : 100),
              );
            case McuVariant.vibrant:
            case McuVariant.cmf:
              return s.isDark
                  ? tMaxC(s.tertiaryPalette, 0, 93)
                  : tMaxC(s.tertiaryPalette, 72, 100);
          }
        },
        isBackground: true,
        background: highestSurface,
        contrastCurve: (s) => s.contrastLevel > 0 ? mcuGetCurve(1.5) : null,
      );

  McuDynamicColor onTertiaryContainer() => McuDynamicColor.fromPalette(
        name: 'on_tertiary_container',
        palette: (s) => s.tertiaryPalette,
        background: (s) => tertiaryContainer(),
        contrastCurve: (s) => mcuGetCurve(6),
      );

  // ---- Error ----

  McuDynamicColor error() => McuDynamicColor.fromPalette(
        name: 'error',
        palette: (s) => s.errorPalette,
        tone: (s) =>
            s.isDark ? tMinC(s.errorPalette, 0, 98) : tMaxC(s.errorPalette),
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

  McuDynamicColor onError() => McuDynamicColor.fromPalette(
        name: 'on_error',
        palette: (s) => s.errorPalette,
        background: (s) => error(),
        contrastCurve: (s) => mcuGetCurve(6),
      );

  McuDynamicColor errorContainer() => McuDynamicColor.fromPalette(
        name: 'error_container',
        palette: (s) => s.errorPalette,
        tone: (s) => s.isDark
            ? tMinC(s.errorPalette, 30, 93)
            : tMaxC(s.errorPalette, 0, 90),
        isBackground: true,
        background: highestSurface,
        contrastCurve: (s) => s.contrastLevel > 0 ? mcuGetCurve(1.5) : null,
      );

  McuDynamicColor onErrorContainer() => McuDynamicColor.fromPalette(
        name: 'on_error_container',
        palette: (s) => s.errorPalette,
        background: (s) => errorContainer(),
        contrastCurve: (s) => mcuGetCurve(4.5),
      );

  // ---- Переименованные роли ----

  McuDynamicColor surfaceVariant() =>
      surfaceContainerHighest().copyWith(name: 'surface_variant');

  McuDynamicColor surfaceTint() => primary().copyWith(name: 'surface_tint');

  McuDynamicColor background() => surface().copyWith(name: 'background');

  McuDynamicColor onBackground() => onSurface().copyWith(
        name: 'on_background',
        tone: (s) => onSurface().getTone(s),
      );
}
