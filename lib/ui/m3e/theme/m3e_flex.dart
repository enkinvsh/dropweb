import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

import '../../../enum/enum.dart';
import 'm3e_text.dart';

/// Стили Roboto Flex для главной: значения из `.dr-main` в android.css (строки 97-141).
///
/// Ось `opsz` ставится всегда равной кеглю: в браузере её подбирает
/// `font-optical-sizing: auto`, а Flutter сам этого не делает. Диапазон оси шрифта 8..144.
abstract final class M3eFlex {
  static TextStyle _style({
    required double size,
    required double lineHeight,
    required double wght,
    double wdth = 100,
    bool tabular = false,
    double? letterSpacing,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: FontFamily.robotoFlex.value,
        fontFamilyFallback: m3eFontFallback,
        fontSize: size,
        height: lineHeight / size,
        // Запасное целое начертание, если вариации недоступны; точное значение задаёт wght.
        fontWeight: FontWeight.values[(wght / 100).round().clamp(1, 9) - 1],
        fontVariations: [
          FontVariation('wght', wght),
          FontVariation('wdth', wdth),
          FontVariation('opsz', size.clamp(8, 144).toDouble()),
        ],
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
        letterSpacing: letterSpacing,
        color: color,
        leadingDistribution: TextLeadingDistribution.even,
      );

  /// `.dr-card__line`: строка карточки, 15/20, wght 450.
  static TextStyle cardLine({Color? color}) =>
      _style(size: 15, lineHeight: 20, wght: 450, color: color);

  /// `.dr-card__name`: имя провайдера, 17/22, wght 620.
  static TextStyle cardName({Color? color}) =>
      _style(size: 17, lineHeight: 22, wght: 620, color: color);

  /// `.dr-card__why`: причина вместо таймера, 17/22, wght 450.
  static TextStyle cardWhy({Color? color}) =>
      _style(size: 17, lineHeight: 22, wght: 450, color: color);

  /// `.dr-card__timer`: таймер, 17/22, wght 520, широкое начертание wdth 118, цифры моноширинные.
  static TextStyle cardTimer({Color? color}) => _style(
      size: 17,
      lineHeight: 22,
      wght: 520,
      wdth: 118,
      tabular: true,
      color: color);

  /// `.dr-stat__k`: подпись показателя, 13/18, wght 500.
  static TextStyle statKey({Color? color}) =>
      _style(size: 13, lineHeight: 18, wght: 500, color: color);

  /// `.dr-stat__v`: значение показателя, 17/22, wght 680, wdth 108, цифры моноширинные.
  static TextStyle statValue({Color? color}) => _style(
      size: 17,
      lineHeight: 22,
      wght: 680,
      wdth: 108,
      tabular: true,
      color: color);

  /// `.dr-stat__v.is-long`: длинное значение (IPv6 с флагом), wdth 84 и трекинг -0.1.
  /// Кегль приходит параметром: на доске он считается по ширине колонки
  /// `clamp(12px, 10.5cqi - 3.45px, 17px)`, а строка остаётся 22.
  static TextStyle statValueLong({required double fontSize, Color? color}) =>
      _style(
        size: fontSize,
        lineHeight: 22,
        wght: 680,
        wdth: 84,
        tabular: true,
        letterSpacing: -0.1,
        color: color,
      );
}
