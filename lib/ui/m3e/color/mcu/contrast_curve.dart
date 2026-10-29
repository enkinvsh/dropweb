// Порт из MCU TS bd811e4 dynamiccolor/contrast_curve.ts (Apache-2.0, см. LICENSE).

import 'package:material_color_utilities/material_color_utilities.dart'
    show MathUtils;

/// Целевой контраст в зависимости от уровня контраста схемы (−1…1).
class McuContrastCurve {
  const McuContrastCurve(this.low, this.normal, this.medium, this.high);

  final double low;
  final double normal;
  final double medium;
  final double high;

  double get(double contrastLevel) {
    if (contrastLevel <= -1.0) {
      return low;
    } else if (contrastLevel < 0.0) {
      return MathUtils.lerp(low, normal, (contrastLevel - (-1)) / 1);
    } else if (contrastLevel < 0.5) {
      return MathUtils.lerp(normal, medium, (contrastLevel - 0) / 0.5);
    } else if (contrastLevel < 1.0) {
      return MathUtils.lerp(medium, high, (contrastLevel - 0.5) / 0.5);
    } else {
      return high;
    }
  }
}
