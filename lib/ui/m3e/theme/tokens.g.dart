// СГЕНЕРИРОВАНО tool/canon/gen_tokens.py. Не править руками.
// Источник: /Users/mac/Documents/projects/canon/material-3-expressive/sources/code/tokens.json
// Пути в JSON: typescale.roles, shape.corner_scale, shape.asymmetric, elevation.levels,
// state.layer_opacity, motion.springs, motion.legacy.durations_ms, motion.legacy.easing.

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Роль типошкалы M3 (в sp/dp Flutter это логические пиксели).
class M3eTypeStyle {
  const M3eTypeStyle({
    required this.size,
    required this.lineHeight,
    required this.tracking,
    required this.weight,
    required this.brand,
  });

  final double size;
  final double lineHeight;

  /// Разрядка в логических пикселях (tracking_sp), в Flutter это `letterSpacing`.
  final double tracking;
  final int weight;

  /// Роль принадлежит brand-гарнитуре (display, headline, title-large), остальные — plain.
  final bool brand;

  /// Множитель `TextStyle.height`: у Flutter высота строки задаётся долей кегля.
  double get height => lineHeight / size;

  FontWeight get fontWeight => FontWeight.values[weight ~/ 100 - 1];
}

abstract final class M3eType {
  static const displayLarge = M3eTypeStyle(
      size: 57.0, lineHeight: 64.0, tracking: -0.2, weight: 400, brand: true);
  static const displayMedium = M3eTypeStyle(
      size: 45.0, lineHeight: 52.0, tracking: 0.0, weight: 400, brand: true);
  static const displaySmall = M3eTypeStyle(
      size: 36.0, lineHeight: 44.0, tracking: 0.0, weight: 400, brand: true);
  static const headlineLarge = M3eTypeStyle(
      size: 32.0, lineHeight: 40.0, tracking: 0.0, weight: 400, brand: true);
  static const headlineMedium = M3eTypeStyle(
      size: 28.0, lineHeight: 36.0, tracking: 0.0, weight: 400, brand: true);
  static const headlineSmall = M3eTypeStyle(
      size: 24.0, lineHeight: 32.0, tracking: 0.0, weight: 400, brand: true);
  static const titleLarge = M3eTypeStyle(
      size: 22.0, lineHeight: 28.0, tracking: 0.0, weight: 400, brand: true);
  static const titleMedium = M3eTypeStyle(
      size: 16.0, lineHeight: 24.0, tracking: 0.2, weight: 500, brand: false);
  static const titleSmall = M3eTypeStyle(
      size: 14.0, lineHeight: 20.0, tracking: 0.1, weight: 500, brand: false);
  static const bodyLarge = M3eTypeStyle(
      size: 16.0, lineHeight: 24.0, tracking: 0.5, weight: 400, brand: false);
  static const bodyMedium = M3eTypeStyle(
      size: 14.0, lineHeight: 20.0, tracking: 0.2, weight: 400, brand: false);
  static const bodySmall = M3eTypeStyle(
      size: 12.0, lineHeight: 16.0, tracking: 0.4, weight: 400, brand: false);
  static const labelLarge = M3eTypeStyle(
      size: 14.0, lineHeight: 20.0, tracking: 0.1, weight: 500, brand: false);
  static const labelMedium = M3eTypeStyle(
      size: 12.0, lineHeight: 16.0, tracking: 0.5, weight: 500, brand: false);
  static const labelSmall = M3eTypeStyle(
      size: 11.0, lineHeight: 16.0, tracking: 0.5, weight: 500, brand: false);
  static const displayLargeEmphasized = M3eTypeStyle(
      size: 57.0, lineHeight: 64.0, tracking: 0.0, weight: 500, brand: true);
  static const displayMediumEmphasized = M3eTypeStyle(
      size: 45.0, lineHeight: 52.0, tracking: 0.0, weight: 500, brand: true);
  static const displaySmallEmphasized = M3eTypeStyle(
      size: 36.0, lineHeight: 44.0, tracking: 0.0, weight: 500, brand: true);
  static const headlineLargeEmphasized = M3eTypeStyle(
      size: 32.0, lineHeight: 40.0, tracking: 0.0, weight: 500, brand: true);
  static const headlineMediumEmphasized = M3eTypeStyle(
      size: 28.0, lineHeight: 36.0, tracking: 0.0, weight: 500, brand: true);
  static const headlineSmallEmphasized = M3eTypeStyle(
      size: 24.0, lineHeight: 32.0, tracking: 0.0, weight: 500, brand: true);
  static const titleLargeEmphasized = M3eTypeStyle(
      size: 22.0, lineHeight: 28.0, tracking: 0.0, weight: 500, brand: true);
  static const titleMediumEmphasized = M3eTypeStyle(
      size: 16.0, lineHeight: 24.0, tracking: 0.15, weight: 700, brand: false);
  static const titleSmallEmphasized = M3eTypeStyle(
      size: 14.0, lineHeight: 20.0, tracking: 0.1, weight: 700, brand: false);
  static const bodyLargeEmphasized = M3eTypeStyle(
      size: 16.0, lineHeight: 24.0, tracking: 0.15, weight: 500, brand: false);
  static const bodyMediumEmphasized = M3eTypeStyle(
      size: 14.0, lineHeight: 20.0, tracking: 0.25, weight: 500, brand: false);
  static const bodySmallEmphasized = M3eTypeStyle(
      size: 12.0, lineHeight: 16.0, tracking: 0.4, weight: 500, brand: false);
  static const labelLargeEmphasized = M3eTypeStyle(
      size: 14.0, lineHeight: 20.0, tracking: 0.1, weight: 700, brand: false);
  static const labelMediumEmphasized = M3eTypeStyle(
      size: 12.0, lineHeight: 16.0, tracking: 0.5, weight: 700, brand: false);
  static const labelSmallEmphasized = M3eTypeStyle(
      size: 11.0, lineHeight: 16.0, tracking: 0.5, weight: 700, brand: false);
}

/// Радиусы скругления в dp. `full` — CircleShape: радиус больше любой стороны,
/// RRect во Flutter сам ужимает его до половины меньшей стороны.
abstract final class M3eShape {
  static const none = 0.0;
  static const extraSmall = 4.0;
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const largeIncreased = 20.0;
  static const extraLarge = 28.0;
  static const extraLargeIncreased = 32.0;
  static const extraExtraLarge = 48.0;
  static const full = 9999.0;
}

/// Несимметричные углы (tl, tr, br, bl) в dp.
class M3eCorners {
  const M3eCorners(
      this.topLeft, this.topRight, this.bottomRight, this.bottomLeft);

  final double topLeft;
  final double topRight;
  final double bottomRight;
  final double bottomLeft;

  BorderRadius get borderRadius => BorderRadius.only(
        topLeft: Radius.circular(topLeft),
        topRight: Radius.circular(topRight),
        bottomRight: Radius.circular(bottomRight),
        bottomLeft: Radius.circular(bottomLeft),
      );
}

abstract final class M3eShapeAsymmetric {
  static const extraLargeTop = M3eCorners(28.0, 28.0, 0.0, 0.0);
  static const extraSmallTop = M3eCorners(4.0, 4.0, 0.0, 0.0);
  static const largeEnd = M3eCorners(0.0, 16.0, 16.0, 0.0);
  static const largeStart = M3eCorners(16.0, 0.0, 0.0, 16.0);
  static const largeTop = M3eCorners(16.0, 16.0, 0.0, 0.0);
}

/// Уровни высоты в dp. Тень рисует платформа, токены задают только Z.
abstract final class M3eElevation {
  static const level0 = 0.0;
  static const level1 = 1.0;
  static const level2 = 3.0;
  static const level3 = 6.0;
  static const level4 = 8.0;
  static const level5 = 12.0;
}

/// Прозрачности state layer и доля цвета для отключённого содержимого.
abstract final class M3eState {
  static const hover = 0.08;
  static const focus = 0.1;
  static const pressed = 0.1;
  static const dragged = 0.16;
  static const disabledContent = 0.38;
}

/// Пружина M3: относительное демпфирование (ratio) и жёсткость.
class M3eSpringSpec {
  const M3eSpringSpec({required this.damping, required this.stiffness});

  final double damping;
  final double stiffness;

  /// Масса 1; критическое демпфирование = 2*sqrt(k), абсолютное = ratio * оно.
  SpringDescription get description => SpringDescription.withDampingRatio(
      mass: 1, stiffness: stiffness, ratio: damping);
}

/// Пружины схемы expressive (motion.springs.expressive).
abstract final class M3eSpring {
  static const fastSpatial = M3eSpringSpec(damping: 0.6, stiffness: 800.0);
  static const defaultSpatial = M3eSpringSpec(damping: 0.8, stiffness: 380.0);
  static const slowSpatial = M3eSpringSpec(damping: 0.8, stiffness: 200.0);
  static const fastEffects = M3eSpringSpec(damping: 1.0, stiffness: 3800.0);
  static const defaultEffects = M3eSpringSpec(damping: 1.0, stiffness: 1600.0);
  static const slowEffects = M3eSpringSpec(damping: 1.0, stiffness: 800.0);
}

/// Пружины схемы standard (motion.springs.standard).
abstract final class M3eSpringStandard {
  static const fastSpatial = M3eSpringSpec(damping: 0.9, stiffness: 1400.0);
  static const defaultSpatial = M3eSpringSpec(damping: 0.9, stiffness: 700.0);
  static const slowSpatial = M3eSpringSpec(damping: 0.9, stiffness: 300.0);
  static const fastEffects = M3eSpringSpec(damping: 1.0, stiffness: 3800.0);
  static const defaultEffects = M3eSpringSpec(damping: 1.0, stiffness: 1600.0);
  static const slowEffects = M3eSpringSpec(damping: 1.0, stiffness: 800.0);
}

abstract final class M3eEasing {
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const standardAccelerate = Cubic(0.3, 0.0, 1.0, 1.0);
  static const standardDecelerate = Cubic(0.0, 0.0, 0.0, 1.0);
  static const legacy = Cubic(0.4, 0.0, 0.2, 1.0);
  static const legacyAccelerate = Cubic(0.4, 0.0, 1.0, 1.0);
  static const legacyDecelerate = Cubic(0.0, 0.0, 0.2, 1.0);
  static const linear = Cubic(0.0, 0.0, 1.0, 1.0);
}

abstract final class M3eDuration {
  static const short1 = Duration(milliseconds: 50);
  static const short2 = Duration(milliseconds: 100);
  static const short3 = Duration(milliseconds: 150);
  static const short4 = Duration(milliseconds: 200);
  static const medium1 = Duration(milliseconds: 250);
  static const medium2 = Duration(milliseconds: 300);
  static const medium3 = Duration(milliseconds: 350);
  static const medium4 = Duration(milliseconds: 400);
  static const long1 = Duration(milliseconds: 450);
  static const long2 = Duration(milliseconds: 500);
  static const long3 = Duration(milliseconds: 550);
  static const long4 = Duration(milliseconds: 600);
  static const extraLong1 = Duration(milliseconds: 700);
  static const extraLong2 = Duration(milliseconds: 800);
  static const extraLong3 = Duration(milliseconds: 900);
  static const extraLong4 = Duration(milliseconds: 1000);
}
