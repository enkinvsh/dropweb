import 'package:flutter/material.dart';

import '../../../enum/enum.dart';
import 'tokens.g.dart';

/// Семейство plain-ролей: на Android это системный Roboto, в приложение он не кладётся.
const String m3ePlainFamily = 'Roboto';

/// Запасные гарнитуры: флаги и эмодзи в названиях групп рисует Twemoji, а не системный набор.
final List<String> m3eFontFallback = [FontFamily.twEmoji.value];

/// Роль типошкалы как [TextStyle]: brand-роли (display, headline, title-large) идут
/// в Onest, остальные в Roboto, как `--dr-brand-font` и `--md-sys-typescale-font` на доске.
TextStyle m3eTextStyle(M3eTypeStyle role, {Color? color}) => TextStyle(
      fontFamily: role.brand ? FontFamily.onest.value : m3ePlainFamily,
      fontFamilyFallback: m3eFontFallback,
      fontSize: role.size,
      // Высота строки в токенах задана в пикселях, во Flutter это доля кегля.
      height: role.height,
      letterSpacing: role.tracking,
      fontWeight: role.fontWeight,
      color: color,
      // Строка по CSS делит свободное место поровну сверху и снизу.
      leadingDistribution: TextLeadingDistribution.even,
    );

/// TextTheme из 15 базовых ролей M3. Emphasized-варианты в TextTheme не помещаются,
/// их берут через [m3eTextStyle] и `M3eType.*Emphasized`.
TextTheme m3eTextTheme() => TextTheme(
      displayLarge: m3eTextStyle(M3eType.displayLarge),
      displayMedium: m3eTextStyle(M3eType.displayMedium),
      displaySmall: m3eTextStyle(M3eType.displaySmall),
      headlineLarge: m3eTextStyle(M3eType.headlineLarge),
      headlineMedium: m3eTextStyle(M3eType.headlineMedium),
      headlineSmall: m3eTextStyle(M3eType.headlineSmall),
      titleLarge: m3eTextStyle(M3eType.titleLarge),
      titleMedium: m3eTextStyle(M3eType.titleMedium),
      titleSmall: m3eTextStyle(M3eType.titleSmall),
      bodyLarge: m3eTextStyle(M3eType.bodyLarge),
      bodyMedium: m3eTextStyle(M3eType.bodyMedium),
      bodySmall: m3eTextStyle(M3eType.bodySmall),
      labelLarge: m3eTextStyle(M3eType.labelLarge),
      labelMedium: m3eTextStyle(M3eType.labelMedium),
      labelSmall: m3eTextStyle(M3eType.labelSmall),
    );
