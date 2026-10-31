// Цвета подвала объявления под карточкой главной (`.hig-foot`, canon/.omo/hig-cards/index.html:190-200).
//
// Подвал лежит прямо на живых обоях, без подложки, поэтому цвета подобраны отдельно от палитры
// ярлыков. Токены вынесены сюда, а
// не в `tokens.g.dart`: тот генерируется из `tokens.css` канона, а этих цветов там нет.

import 'dart:ui' show Color;

/// Цвета подвала объявления: текст и ссылка для светлой и тёмной темы.
abstract final class Ios27FooterColors {
  /// Живой вторичный уровень (HIG materials.md:44, просьба владельца 30.10 18:16): чёрный 0.65
  /// днём, белый 0.75 ночью. Цвета доски (`rgba(6,20,34,.72)` / `rgba(235,245,255,.72)`) на
  /// живых обоях читаются как серые.
  static const Color textLight = Color.fromRGBO(0, 0, 0, 0.65);
  static const Color textDark = Color.fromRGBO(255, 255, 255, 0.75);

  /// `light-dark(rgba(0, 18, 36, 0.92), #FFFFFF)`.
  static const Color linkLight = Color.fromRGBO(0, 18, 36, 0.92);
  static const Color linkDark = Color(0xFFFFFFFF);

  static Color text({required bool dark}) => dark ? textDark : textLight;

  static Color link({required bool dark}) => dark ? linkDark : linkLight;
}
