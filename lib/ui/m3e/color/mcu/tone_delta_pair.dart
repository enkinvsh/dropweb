// Порт из MCU TS bd811e4 dynamiccolor/tone_delta_pair.ts (Apache-2.0, см. LICENSE).

import 'dynamic_color.dart';

/// Куда смещается тон роли A относительно роли B.
enum McuTonePolarity {
  darker,
  lighter,
  nearer,
  farther,
  relativeDarker,
  relativeLighter,
}

/// Ограничение на дельту: точная, не ближе, не дальше.
enum McuDeltaConstraint { exact, nearer, farther }

/// Пара ролей с ограничением на разницу тонов.
class McuToneDeltaPair {
  const McuToneDeltaPair(
    this.roleA,
    this.roleB,
    this.delta,
    this.polarity,
    this.stayTogether, [
    this.constraint = McuDeltaConstraint.exact,
  ]);

  final McuDynamicColor roleA;
  final McuDynamicColor roleB;
  final double delta;
  final McuTonePolarity polarity;
  final bool stayTogether;
  final McuDeltaConstraint constraint;
}
