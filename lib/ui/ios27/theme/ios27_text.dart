// Текстовые стили iOS-редизайна: роли `.t-*` доски (tokens.css:101-113) плюс цвет темы и «Жирный текст».

import 'dart:math' as math;

import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart';
import 'package:flutter/widgets.dart';

/// Вес под «Жирный текст» iOS: на 200 тяжелее, не выше `w700`.
///
/// UIKit при включённом Bold Text поднимает regular до semibold, а semibold до bold, то есть сдвигает
/// вес на две ступени. В Onest веса только 300..700, поэтому всё, что тяжелее `w700`, упирается в него.
FontWeight ios27BoldWeight(FontWeight weight) =>
    // `value` у FontWeight 100..900; в списке `values` ступень n лежит под индексом n / 100 - 1.
    FontWeight.values[math.min(weight.value + 200, 700) ~/ 100 - 1];

/// Стиль роли без обращения к контексту: [color] и [bold] приходят снаружи.
///
/// Для тем и заглушек, где контекста ещё нет; в экранах пользуйтесь [ios27Text].
TextStyle ios27RoleStyle(
  Ios27TextRole role, {
  Color? color,
  bool bold = false,
}) {
  final base = Ios27Text.style(role, color: color);
  if (!bold) {
    return base;
  }
  return base.copyWith(fontWeight: ios27BoldWeight(role.fontWeight));
}

/// Стиль роли `.t-*` с цветом темы (`--label`, если [color] не задан) и учётом «Жирного текста».
///
/// Масштаб шрифта не трогаем: Dynamic Type решается отдельно (T4), он идёт через `textScaler`.
///
/// Ограничение Flutter: сам виджет `Text` при включённом `MediaQuery.boldTextOf` дописывает поверх
/// стиля `FontWeight.bold` (widgets/text.dart), и для `Text` итоговый вес всегда `w700`, какой бы
/// вес ни вернул этот хелпер. Ступенчатый сдвиг виден там, где стиль идёт мимо `Text`
/// (`RichText`, `TextPainter`, `TextSpan` без родительского `Text`).
TextStyle ios27Text(
  BuildContext context,
  Ios27TextRole role, {
  Color? color,
}) {
  // Цвет задан явно: тема не нужна, и стиль можно строить даже там, где её нет.
  final resolved = color ?? ios27ColorsFor(context).palette.label;
  return ios27RoleStyle(
    role,
    color: resolved,
    bold: MediaQuery.boldTextOf(context),
  );
}
