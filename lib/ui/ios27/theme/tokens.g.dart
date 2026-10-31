// СГЕНЕРИРОВАНО tool/canon/gen_ios_tokens.mjs из canon/dropweb (tokens.css, app.css, glass.css, motion.js) df156ea1. Не править руками.
// Значения сняты из Chromium: вычисленные свойства корня iOS-колонки, не текст CSS. Цвет — #RRGGBB или
// #RRGGBBAA доски, здесь ARGB. Акцент провайдера (--accent, --on-accent, --accent-soft, --orb1, --orb2) сюда не входит:
// на доске он выставлен инлайном и считается в accent.dart.

import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../../../enum/enum.dart';

/// Цветовые токены iOS-колонки одной темы. Поля названы по свойствам доски (`--label-2` -> `label2`).
class Ios27Palette {
  const Ios27Palette({
    required this.label,
    required this.label2,
    required this.label3,
    required this.label4,
    required this.fill1,
    required this.fill2,
    required this.fill3,
    required this.fill4,
    required this.separator,
    required this.bg,
    required this.card,
    required this.sheet,
    required this.sheetCard,
    required this.red,
    required this.redText,
    required this.orange,
    required this.orangeText,
    required this.green,
    required this.greenText,
    required this.gray,
    required this.glassLabel,
    required this.glassLabel2,
    required this.dim,
  });

  /// `--label`.
  final Color label;

  /// `--label-2`.
  final Color label2;

  /// `--label-3`.
  final Color label3;

  /// `--label-4`.
  final Color label4;

  /// `--fill-1`.
  final Color fill1;

  /// `--fill-2`.
  final Color fill2;

  /// `--fill-3`.
  final Color fill3;

  /// `--fill-4`.
  final Color fill4;

  /// `--separator`.
  final Color separator;

  /// `--bg`.
  final Color bg;

  /// `--card`.
  final Color card;

  /// `--sheet`.
  final Color sheet;

  /// `--sheet-card`.
  final Color sheetCard;

  /// `--red`.
  final Color red;

  /// `--red-text`.
  final Color redText;

  /// `--orange`.
  final Color orange;

  /// `--orange-text`.
  final Color orangeText;

  /// `--green`.
  final Color green;

  /// `--green-text`.
  final Color greenText;

  /// `--gray`.
  final Color gray;

  /// `--glass-label`.
  final Color glassLabel;

  /// `--glass-label-2`.
  final Color glassLabel2;

  /// `--dim`.
  final Color dim;

  /// Значения по именам свойств доски (`--label` -> ARGB): сверка с colors.json эталона.
  Map<String, int> toVars() => {
        '--label': label.toARGB32(),
        '--label-2': label2.toARGB32(),
        '--label-3': label3.toARGB32(),
        '--label-4': label4.toARGB32(),
        '--fill-1': fill1.toARGB32(),
        '--fill-2': fill2.toARGB32(),
        '--fill-3': fill3.toARGB32(),
        '--fill-4': fill4.toARGB32(),
        '--separator': separator.toARGB32(),
        '--bg': bg.toARGB32(),
        '--card': card.toARGB32(),
        '--sheet': sheet.toARGB32(),
        '--sheet-card': sheetCard.toARGB32(),
        '--red': red.toARGB32(),
        '--red-text': redText.toARGB32(),
        '--orange': orange.toARGB32(),
        '--orange-text': orangeText.toARGB32(),
        '--green': green.toARGB32(),
        '--green-text': greenText.toARGB32(),
        '--gray': gray.toARGB32(),
        '--glass-label': glassLabel.toARGB32(),
        '--glass-label-2': glassLabel2.toARGB32(),
        '--dim': dim.toARGB32(),
      };
}

/// Вариант стекла (`.glass`, `.glass--md`, ...) в одной теме. Слои заливки идут сверху вниз, как в CSS.
class Ios27GlassMaterial {
  const Ios27GlassMaterial({
    required this.radius,
    required this.blur,
    required this.saturation,
    required this.layers,
    this.opaque,
    this.tintAlpha,
  });

  /// `border-radius`, px (капсула — 9999).
  final double radius;

  /// `--g-blur`, px.
  final double blur;

  /// `--g-sat`.
  final double saturation;

  /// Слои `--g-bg` без цвета провайдера, сверху вниз.
  final List<Color> layers;

  /// Плотная заливка при «Уменьшении прозрачности»; у tint её нет — там цвет акцента.
  final Color? opaque;

  /// Доля акцента в заливке tint (`--g-tint` = 1); у остальных null.
  final double? tintAlpha;
}

/// Все варианты стекла одной темы.
class Ios27GlassSet {
  const Ios27GlassSet({
    required this.base,
    required this.md,
    required this.widget,
    required this.lg,
    required this.tint,
    required this.inactive,
  });

  /// `.glass`: кнопки и капсулы.
  final Ios27GlassMaterial base;

  /// `.glass--md`: листы и меню.
  final Ios27GlassMaterial md;

  /// `.glass--widget`: карточка главной.
  final Ios27GlassMaterial widget;

  /// `.glass--lg`: алерты.
  final Ios27GlassMaterial lg;

  /// `.glass--tint`: акцентная кнопка.
  final Ios27GlassMaterial tint;

  /// `.glass--inactive`: недоступное.
  final Ios27GlassMaterial inactive;
}

/// Цвета, меры и стекло iOS-колонки.
abstract final class Ios27Tokens {
  static const Ios27Palette light = Ios27Palette(
    label: Color(0xFF000000),
    label2: Color(0x993C3C43),
    label3: Color(0x4C3C3C43),
    label4: Color(0x2E3C3C43),
    fill1: Color(0x33787880),
    fill2: Color(0x29787880),
    fill3: Color(0x1F767680),
    fill4: Color(0x14747480),
    separator: Color(0x1F000000),
    bg: Color(0xFFF2F2F7),
    card: Color(0xFFFFFFFF),
    sheet: Color(0xFFF2F2F7),
    sheetCard: Color(0xFFFFFFFF),
    red: Color(0xFFFF383C),
    redText: Color(0xFFE9152D),
    orange: Color(0xFFFF8D28),
    orangeText: Color(0xFFC55300),
    green: Color(0xFF34C759),
    greenText: Color(0xFF008932),
    gray: Color(0xFF8E8E93),
    glassLabel: Color(0xFF1A1A1A),
    glassLabel2: Color(0xFF727272),
    dim: Color(0x33000000),
  );

  static const Ios27Palette dark = Ios27Palette(
    label: Color(0xFFFFFFFF),
    label2: Color(0x99EBEBF5),
    label3: Color(0x4CEBEBF5),
    label4: Color(0x29EBEBF5),
    fill1: Color(0x5C787880),
    fill2: Color(0x52787880),
    fill3: Color(0x3D767680),
    fill4: Color(0x2E767680),
    separator: Color(0x1FFFFFFF),
    bg: Color(0xFF000000),
    card: Color(0xFF1C1C1E),
    sheet: Color(0xFF1C1C1E),
    sheetCard: Color(0xFF2C2C2E),
    red: Color(0xFFFF4245),
    redText: Color(0xFFFF6165),
    orange: Color(0xFFFF9230),
    orangeText: Color(0xFFFFA056),
    green: Color(0xFF30D158),
    greenText: Color(0xFF4AD968),
    gray: Color(0xFF8E8E93),
    glassLabel: Color(0xFFEDEDED),
    glassLabel2: Color(0xFF8A8A8A),
    dim: Color(0x7A000000),
  );

  static const Ios27Palette lightIncreasedContrast = Ios27Palette(
    label: Color(0xFF000000),
    label2: Color(0x993C3C43),
    label3: Color(0x4C3C3C43),
    label4: Color(0x2E3C3C43),
    fill1: Color(0x33787880),
    fill2: Color(0x29787880),
    fill3: Color(0x1F767680),
    fill4: Color(0x14747480),
    separator: Color(0x1F000000),
    bg: Color(0xFFF2F2F7),
    card: Color(0xFFFFFFFF),
    sheet: Color(0xFFF2F2F7),
    sheetCard: Color(0xFFFFFFFF),
    red: Color(0xFFE9152D),
    redText: Color(0xFFE9152D),
    orange: Color(0xFFC55300),
    orangeText: Color(0xFFC55300),
    green: Color(0xFF008932),
    greenText: Color(0xFF008932),
    gray: Color(0xFF6C6C70),
    glassLabel: Color(0xFF1A1A1A),
    glassLabel2: Color(0xFF727272),
    dim: Color(0x33000000),
  );

  static const Ios27Palette darkIncreasedContrast = Ios27Palette(
    label: Color(0xFFFFFFFF),
    label2: Color(0x99EBEBF5),
    label3: Color(0x4CEBEBF5),
    label4: Color(0x29EBEBF5),
    fill1: Color(0x5C787880),
    fill2: Color(0x52787880),
    fill3: Color(0x3D767680),
    fill4: Color(0x2E767680),
    separator: Color(0x1FFFFFFF),
    bg: Color(0xFF000000),
    card: Color(0xFF1C1C1E),
    sheet: Color(0xFF1C1C1E),
    sheetCard: Color(0xFF2C2C2E),
    red: Color(0xFFFF6165),
    redText: Color(0xFFFF6165),
    orange: Color(0xFFFFA056),
    orangeText: Color(0xFFFFA056),
    green: Color(0xFF4AD968),
    greenText: Color(0xFF4AD968),
    gray: Color(0xFFAEAEB2),
    glassLabel: Color(0xFFEDEDED),
    glassLabel2: Color(0xFF8A8A8A),
    dim: Color(0x7A000000),
  );

  /// Набор цветов темы; [increasedContrast] — «Увеличение контраста» (`MediaQuery.highContrast`).
  static Ios27Palette palette(
          {required bool dark, bool increasedContrast = false}) =>
      dark
          ? (increasedContrast ? darkIncreasedContrast : Ios27Tokens.dark)
          : (increasedContrast ? lightIncreasedContrast : light);

  static const Ios27GlassSet glassLight = Ios27GlassSet(
    base: Ios27GlassMaterial(
        radius: 9999.0,
        blur: 4.0,
        saturation: 1.6,
        layers: [Color(0x40FFFFFF), Color(0x40000000), Color(0x33F8F8F8)],
        opaque: Color(0xFFF2F2F2)),
    md: Ios27GlassMaterial(
        radius: 20.0,
        blur: 10.0,
        saturation: 1.4,
        layers: [Color(0x06000000), Color(0x00000000)],
        opaque: Color(0xFFF2F2F2)),
    widget: Ios27GlassMaterial(
        radius: 9999.0,
        blur: 12.0,
        saturation: 1.6,
        layers: [Color(0x66FFFFFF)],
        opaque: Color(0xFFF2F2F2)),
    lg: Ios27GlassMaterial(
        radius: 34.0,
        blur: 15.0,
        saturation: 1.4,
        layers: [Color(0x1ABFBFBF), Color(0xB3FFFFFF)],
        opaque: Color(0xFFF2F2F2)),
    tint: Ios27GlassMaterial(
        radius: 9999.0,
        blur: 4.0,
        saturation: 1.4,
        layers: [],
        tintAlpha: 0.96),
    inactive: Ios27GlassMaterial(
        radius: 9999.0,
        blur: 0.0,
        saturation: 1.0,
        layers: [Color(0x05000000)],
        opaque: Color(0xFFF2F2F2)),
  );

  static const Ios27GlassSet glassDark = Ios27GlassSet(
    base: Ios27GlassMaterial(
        radius: 9999.0,
        blur: 4.0,
        saturation: 1.6,
        layers: [Color(0x00000000), Color(0x00000000), Color(0x2B999999)],
        opaque: Color(0xFF2A2A2A)),
    md: Ios27GlassMaterial(
        radius: 20.0,
        blur: 10.0,
        saturation: 1.4,
        layers: [Color(0x4C1A1A1A), Color(0x4C1A1A1A)],
        opaque: Color(0xFF2A2A2A)),
    widget: Ios27GlassMaterial(
        radius: 9999.0,
        blur: 12.0,
        saturation: 1.6,
        layers: [Color(0x47000000)],
        opaque: Color(0xFF2A2A2A)),
    lg: Ios27GlassMaterial(
        radius: 34.0,
        blur: 15.0,
        saturation: 1.4,
        layers: [Color(0x00000000), Color(0xF21A1A1A)],
        opaque: Color(0xFF2A2A2A)),
    tint: Ios27GlassMaterial(
        radius: 9999.0, blur: 4.0, saturation: 1.4, layers: [], tintAlpha: 0.5),
    inactive: Ios27GlassMaterial(
        radius: 9999.0,
        blur: 0.0,
        saturation: 1.0,
        layers: [Color(0x3D767680)],
        opaque: Color(0xFF2A2A2A)),
  );

  /// Стекло темы.
  static Ios27GlassSet glass({required bool dark}) =>
      dark ? glassDark : glassLight;

  /// `--margin`, логических пикселей.
  static const double margin = 16.0;

  /// `--r-capsule`, логических пикселей.
  static const double rCapsule = 9999.0;

  /// `--r-card`, логических пикселей.
  static const double rCard = 26.0;

  /// `--r-menu`, логических пикселей.
  static const double rMenu = 32.0;

  /// `--r-alert`, логических пикселей.
  static const double rAlert = 34.0;

  /// `--hit`, логических пикселей.
  static const double hit = 44.0;

  /// `--font`: Onest, затем Twemoji для флагов и эмодзи.
  static String get fontFamily => FontFamily.onest.value;

  /// Запасные гарнитуры: флаги и эмодзи рисует Twemoji, а не системный набор.
  static List<String> get fontFallback => [FontFamily.twEmoji.value];
}

/// Стиль текста iOS (`.t-*` в tokens.css): кегль, интерлиньяж, насыщенность, трекинг.
class Ios27TextRole {
  const Ios27TextRole({
    required this.size,
    required this.lineHeight,
    required this.weight,
    required this.tracking,
  });

  final double size;

  /// Интерлиньяж, px.
  final double lineHeight;
  final int weight;

  /// Разрядка, px (`letter-spacing` из em уже пересчитан браузером).
  final double tracking;

  /// Множитель `TextStyle.height`: во Flutter высота строки — доля кегля.
  double get height => lineHeight / size;

  FontWeight get fontWeight => FontWeight.values[weight ~/ 100 - 1];
}

abstract final class Ios27Text {
  /// `.t-large`.
  static const large =
      Ios27TextRole(size: 34.0, lineHeight: 41.0, weight: 700, tracking: -0.68);

  /// `.t-title1`.
  static const title1 =
      Ios27TextRole(size: 28.0, lineHeight: 34.0, weight: 700, tracking: -0.42);

  /// `.t-title2`.
  static const title2 =
      Ios27TextRole(size: 22.0, lineHeight: 28.0, weight: 700, tracking: -0.22);

  /// `.t-title3`.
  static const title3 =
      Ios27TextRole(size: 20.0, lineHeight: 25.0, weight: 600, tracking: 0.0);

  /// `.t-headline`.
  static const headline =
      Ios27TextRole(size: 17.0, lineHeight: 22.0, weight: 600, tracking: 0.0);

  /// `.t-body`.
  static const body =
      Ios27TextRole(size: 17.0, lineHeight: 22.0, weight: 400, tracking: 0.0);

  /// `.t-callout`.
  static const callout =
      Ios27TextRole(size: 16.0, lineHeight: 21.0, weight: 400, tracking: 0.0);

  /// `.t-subhead`.
  static const subhead =
      Ios27TextRole(size: 15.0, lineHeight: 20.0, weight: 400, tracking: 0.0);

  /// `.t-footnote`.
  static const footnote =
      Ios27TextRole(size: 13.0, lineHeight: 18.0, weight: 400, tracking: 0.0);

  /// `.t-caption`.
  static const caption =
      Ios27TextRole(size: 12.0, lineHeight: 16.0, weight: 400, tracking: 0.0);

  /// Роль как [TextStyle] в Onest с Twemoji в запасных.
  static TextStyle style(Ios27TextRole role, {Color? color}) => TextStyle(
        fontFamily: FontFamily.onest.value,
        fontFamilyFallback: [FontFamily.twEmoji.value],
        fontSize: role.size,
        height: role.height,
        letterSpacing: role.tracking,
        fontWeight: role.fontWeight,
        color: color,
        // Строка по CSS делит свободное место поровну сверху и снизу.
        leadingDistribution: TextLeadingDistribution.even,
      );
}

/// Пружина SwiftUI `.spring(duration:bounce:)`, подобранная по таблице linear() доски.
class Ios27SpringSpec {
  const Ios27SpringSpec(
      {required this.duration, required this.bounce, required this.settle});

  /// Параметр `duration` SwiftUI, секунды.
  final double duration;

  /// Параметр `bounce` SwiftUI: 0 — без отскока.
  final double bounce;

  /// Время затухания до 0.1 % (`--spring-*-dur` доски).
  final Duration settle;

  /// Единичная масса; жёсткость (2π/duration)², демпфирование 4π(1 - bounce)/duration.
  SpringDescription get description => SpringDescription(
        mass: 1,
        stiffness: math.pow(2 * math.pi / duration, 2).toDouble(),
        damping: 4 * math.pi * (1 - bounce) / duration,
      );
}

/// Движение iOS 27: пружины, кривая угасания и безразмерные константы motion.js.
abstract final class Ios27Motion {
  /// `--spring-smooth`: затухает за 735.0 мс (невязка подбора 0.00100).
  static const springSmooth = Ios27SpringSpec(
      duration: 0.5, bounce: 0.0, settle: Duration(milliseconds: 735));

  /// `--spring-snappy`: затухает за 700.0 мс (невязка подбора 0.00095).
  static const springSnappy = Ios27SpringSpec(
      duration: 0.5, bounce: 0.15, settle: Duration(milliseconds: 700));

  /// `--spring-bouncy`: затухает за 820.0 мс (невязка подбора 0.00099).
  static const springBouncy = Ios27SpringSpec(
      duration: 0.5, bounce: 0.3, settle: Duration(milliseconds: 820));

  /// `--spring-interactive`: затухает за 210.0 мс (невязка подбора 0.00097).
  static const springInteractive = Ios27SpringSpec(
      duration: 0.15, bounce: 0.14, settle: Duration(milliseconds: 210));

  /// `--ease-out`: угасание прозрачности, где пружина не нужна.
  static const easeOut = Cubic(0.23, 1.0, 0.32, 1.0);

  /// fade(): короткое угасание вместо движения (Reduce Motion), мс.
  static const fade = Duration(milliseconds: 180);

  /// vanish(): снимок уходит в размытие, мс.
  static const vanish = Duration(milliseconds: 300);

  /// vanish(): масштаб в конце.
  static const double vanishScale = 0.96;

  /// vanish(): размытие в конце, px.
  static const double vanishBlur = 6.0;

  /// zoomOut(): доля длительности пружины smooth.
  static const double zoomOutDurationFactor = 0.75;

  /// zoomIn/zoomOut: масштаб значка кнопки внутри растущего стекла.
  static const double zoomIconScale = 1.6;

  /// zoomIn/zoomOut: размытие значка кнопки, px.
  static const double zoomIconBlur = 6.0;

  /// morph(): масштаб уходящего и приходящего содержимого.
  static const double morphScale = 0.8;

  /// morph(): размытие при замене, px.
  static const double morphBlur = 6.0;

  /// emerge(): начальный масштаб нового стекла.
  static const double emergeFrom = 0.94;

  /// roll(): доля длительности у уходящей цифры.
  static const double rollOutDurationFactor = 0.6;

  /// roll(): сдвиг цифры, em.
  static const double rollOffsetEm = 0.6;

  /// roll(): размытие цифры, px.
  static const double rollBlur = 3.0;

  /// appear(icon): начальный масштаб значка (symbolEffect .replace).
  static const double replaceIconScale = 0.5;

  /// appear(word): начальный масштаб слова (blurReplace).
  static const double replaceWordScale = 0.92;

  /// appear(icon): размытие, px.
  static const double replaceIconBlur = 4.0;

  /// appear(word): размытие, px.
  static const double replaceWordBlur = 6.0;

  /// slide(): на какую долю ширины уходит нижний экран.
  static const double slideUnderFraction = 0.3;

  /// slide(): прозрачность нижнего экрана в конце.
  static const double slideUnderOpacity = 0.6;

  /// drop(): когда строка успевает погаснуть (доля пружины).
  static const double rowFadeOffset = 0.35;
}
