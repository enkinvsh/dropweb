// Смешивание как CSS `color-mix(in oklab, A, B k%)`.
//
// Доска красит часть цветов главной именно так (ink2, line, lv-a..lv-c). Смешение в sRGB
// дало бы другие оттенки, поэтому повторяем то, что делает Chromium:
// sRGB -> линейный sRGB -> OKLab, линейная интерполяция, обратно, обрезка по гамме sRGB
// и округление до 8 бит (так Chromium кладёт цвет в пиксель).

import 'dart:math' as math;

double _toLinear(double c) {
  final a = c.abs();
  final lin =
      a <= 0.04045 ? a / 12.92 : math.pow((a + 0.055) / 1.055, 2.4).toDouble();
  return c < 0 ? -lin : lin;
}

double _fromLinear(double c) {
  final a = c.abs();
  final enc = a <= 0.0031308 ? a * 12.92 : 1.055 * math.pow(a, 1 / 2.4) - 0.055;
  return c < 0 ? -enc : enc;
}

double _cbrt(double x) =>
    x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

// Матрицы Ottosson напрямую «линейный sRGB <-> OKLab», без обхода через XYZ D65 из CSS Color 4:
// Chromium считает именно так. На 60 реальных смесях главной обход через XYZ даёт два
// расхождения в 1/255 (значение вида 152.5048 округляется вверх, а Chromium рисует 152).
List<double> _argbToOklab(int argb) {
  final r = _toLinear(((argb >> 16) & 0xFF) / 255);
  final g = _toLinear(((argb >> 8) & 0xFF) / 255);
  final b = _toLinear((argb & 0xFF) / 255);

  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);

  return [
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  ];
}

int _oklabToArgb(List<double> lab) {
  final l = math
      .pow(lab[0] + 0.3963377774 * lab[1] + 0.2158037573 * lab[2], 3)
      .toDouble();
  final m = math
      .pow(lab[0] - 0.1055613458 * lab[1] - 0.0638541728 * lab[2], 3)
      .toDouble();
  final s = math
      .pow(lab[0] - 0.0894841775 * lab[1] - 1.2914855480 * lab[2], 3)
      .toDouble();

  final r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
  final g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
  final b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;

  int to8(double lin) => (_fromLinear(lin).clamp(0.0, 1.0) * 255).round();
  return 0xFF000000 | (to8(r) << 16) | (to8(g) << 8) | to8(b);
}

/// ARGB результата `color-mix(in oklab, [a], [b] [bPercent]%)`: вес [b] равен [bPercent],
/// вес [a] — остаток до 100.
int oklabMixArgb(int a, int b, num bPercent) {
  final p = bPercent / 100;
  final la = _argbToOklab(a);
  final lb = _argbToOklab(b);
  return _oklabToArgb([
    for (var i = 0; i < 3; i++) la[i] * (1 - p) + lb[i] * p,
  ]);
}
