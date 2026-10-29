// Порт из MCU TS bd811e4 palettes/tonal_palette.ts (Apache-2.0, см. LICENSE).
//
// Своя реализация, а не пакетная: TonalPalette из material_color_utilities 0.13.0 не знает
// особого случая «жёлтый тон 99» и отдаёт getHct без округления до ARGB (см. SOURCE).

import 'package:material_color_utilities/material_color_utilities.dart'
    show Hct;

import 'hue_ranges.dart';

/// Палитра: оттенок + насыщенность, цвет по тону 0…100.
class McuTonalPalette {
  McuTonalPalette.fromHueAndChroma(this.hue, this.chroma);

  /// Как TonalPalette.fromInt в TS: оттенок и насыщенность берутся из самого цвета.
  factory McuTonalPalette.fromInt(int argb) {
    final hct = Hct.fromInt(argb);
    return McuTonalPalette.fromHueAndChroma(hct.hue, hct.chroma);
  }

  final double hue;
  final double chroma;

  // Кэш по тону: findBestToneForChroma и контрастные проходы просят один тон десятки раз.
  final Map<double, int> _cache = {};

  /// ARGB цвета на тоне [tone].
  int tone(double tone) {
    final cached = _cache[tone];
    if (cached != null) return cached;
    final int argb;
    if (tone == 99 && hueIsYellow(hue)) {
      argb = _averageArgb(this.tone(98), this.tone(100));
    } else {
      argb = Hct.from(hue, chroma, tone).toInt();
    }
    _cache[tone] = argb;
    return argb;
  }

  Hct getHct(double tone) => Hct.fromInt(this.tone(tone));

  static int _averageArgb(int argb1, int argb2) {
    final red1 = (argb1 >> 16) & 0xff;
    final green1 = (argb1 >> 8) & 0xff;
    final blue1 = argb1 & 0xff;
    final red2 = (argb2 >> 16) & 0xff;
    final green2 = (argb2 >> 8) & 0xff;
    final blue2 = argb2 & 0xff;
    // JS Math.round округляет половину вверх; для неотрицательных чисел Dart round() то же.
    final red = ((red1 + red2) / 2).round();
    final green = ((green1 + green2) / 2).round();
    final blue = ((blue1 + blue2) / 2).round();
    return (255 << 24) |
        ((red & 255) << 16) |
        ((green & 255) << 8) |
        (blue & 255);
  }
}
