// Акцент iOS-редизайна: порт `accentVars` и палитр с доски (canon/dropweb/app.js, коммит df156ea1).
//
// Руками написанный файл, не генерируется: логика с ветвлениями на доске живёт в JS, а не в CSS,
// поэтому снять её Chromium'ом нельзя. Любое расхождение с доской ловит
// `test/ios27/accent_test.dart` (значения из JS доски) и `test/ios27/gate2_colors_test.dart` (колонка iOS).
//
// Цвета провайдера приходят из заголовка `dropweb-theme`; разбор общий с Android-веткой
// (`parseDropwebTheme`), он один в один повторяет `parseTheme` доски. Смешение в OKLab
// (`oklabMixArgb`) здесь не нужно: все `color-mix` iOS-колонки идут `in srgb` и считаются в стекле.

import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:dropweb/ui/ios27/theme/tokens.g.dart';
import 'package:dropweb/ui/m3e/color/color.dart'
    show m3eFallbackSeed, parseDropwebTheme;

// ---------------------------------------------------------------------------------------------
// Контраст (app.js:84-100)
// ---------------------------------------------------------------------------------------------

/// Цвет как тройка 0..255: так доска считает контраст и подгоняет акцент.
class Ios27Rgb {
  const Ios27Rgb(this.r, this.g, this.b);

  /// `#RRGGBB` (доска берёт `slice(1, 7)`, альфа игнорируется). Неразобранное даёт чёрный, как `NaN & 255` в JS.
  factory Ios27Rgb.fromHex(String h) {
    final s = h.length > 1 ? h.substring(1, math.min(7, h.length)) : '';
    final n = int.tryParse(s, radix: 16) ?? 0;
    return Ios27Rgb((n >> 16) & 255, (n >> 8) & 255, n & 255);
  }

  final int r;
  final int g;
  final int b;

  static const Ios27Rgb white = Ios27Rgb(255, 255, 255);
  static const Ios27Rgb black = Ios27Rgb(0, 0, 0);

  /// Относительная яркость WCAG с порогом 0.03928, как на доске (не 0.04045 из sRGB).
  double get luminance =>
      0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b);

  /// `#RRGGBB` в верхнем регистре.
  String get hex {
    String two(int v) => v.toRadixString(16).padLeft(2, '0');
    return '#${two(r)}${two(g)}${two(b)}'.toUpperCase();
  }

  /// Непрозрачный [Color].
  Color get color => Color.fromARGB(255, r, g, b);

  @override
  bool operator ==(Object other) =>
      other is Ios27Rgb && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);

  @override
  String toString() => 'Ios27Rgb($hex)';
}

double _lin(int channel) {
  final c = channel / 255;
  return c <= 0.03928
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

/// Контраст двух цветов (WCAG): (светлый + 0.05) / (тёмный + 0.05).
double ios27Contrast(Ios27Rgb a, Ios27Rgb b) {
  final la = a.luminance;
  final lb = b.luminance;
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Сдвигает [base] к [toward] шагами по 2 %, пока контраст к [bg] не достигнет [target].
///
/// Порядок операций и накопление `k += 0.02` в double те же, что в `fit` на доске: иначе округление
/// на границе шага даст соседний оттенок. Округление `Math.round` == `round()` при неотрицательных значениях.
Ios27Rgb ios27Fit(
  Ios27Rgb base,
  Ios27Rgb bg,
  double target,
  Ios27Rgb toward,
) {
  var c = base;
  int mix(int v, int t, double k) => (v + (t - v) * k).round();
  for (var k = 0.02; ios27Contrast(c, bg) < target && k <= 1; k += 0.02) {
    c = Ios27Rgb(
      mix(base.r, toward.r, k),
      mix(base.g, toward.g, k),
      mix(base.b, toward.b, k),
    );
  }
  return c;
}

// ---------------------------------------------------------------------------------------------
// accentVars (app.js:130-140)
// ---------------------------------------------------------------------------------------------

/// `--accent`, `--on-accent`, `--accent-soft` для обеих тем.
///
/// Провайдер присылает любой цвет: неоновый `#29FF76` на белом даёт 1.3:1, поэтому для светлой
/// темы цвет затемняют до 3.2:1 к белому, для тёмной осветляют до 4.5:1 к чёрному. Текст на акценте
/// белый, если белый даёт хотя бы 3:1 (так делает Apple: белый на системном синем это 3.6:1).
class Ios27AccentVars {
  const Ios27AccentVars({required this.light, required this.dark});

  /// Акцент светлой темы (`--accent`).
  final Ios27Rgb light;

  /// Акцент тёмной темы (`--accent`).
  final Ios27Rgb dark;

  /// Прозрачность `--accent-soft`: `1F` в светлой теме, `29` в тёмной (app.js:138).
  static const int softAlphaLight = 0x1F;
  static const int softAlphaDark = 0x29;

  Ios27Rgb _of(bool dark) => dark ? this.dark : light;

  /// `--accent`.
  Color accent({required bool dark}) => _of(dark).color;

  /// `--on-accent`: белый или чёрный.
  ///
  /// Белый и чёрный берутся из тех же `WHITE`/`BLACK`, по которым доска считает контраст
  /// (app.js:94-95, 134), а не отдельными литералами цвета.
  Color onAccent({required bool dark}) =>
      ios27Contrast(_of(dark), Ios27Rgb.white) >= 3
          ? Ios27Rgb.white.color
          : Ios27Rgb.black.color;

  /// `--accent-soft`: акцент с прозрачностью 12 % (светлая) или 16 % (тёмная).
  Color soft({required bool dark}) =>
      _of(dark).color.withAlpha(dark ? softAlphaDark : softAlphaLight);

  /// Значения по именам свойств доски (ARGB): сверка с эталоном G2.
  Map<String, int> toVars({required bool dark}) => {
        '--accent': accent(dark: dark).toARGB32(),
        '--on-accent': onAccent(dark: dark).toARGB32(),
        '--accent-soft': soft(dark: dark).toARGB32(),
      };

  @override
  String toString() =>
      'Ios27AccentVars(light: ${light.hex}, dark: ${dark.hex})';
}

/// Строковая ветка `accentVars(h)`: цвет провайдера или свой, любой `#RRGGBB`.
/// Единственная, которую вызывает доска (`applyAccent`).
Ios27AccentVars ios27AccentVars(String hex) {
  final b = Ios27Rgb.fromHex(hex);
  return Ios27AccentVars(
    light: ios27Fit(b, Ios27Rgb.white, 3.2, Ios27Rgb.black),
    dark: ios27Fit(b, Ios27Rgb.black, 4.5, Ios27Rgb.white),
  );
}

/// Объектная ветка `accentVars(h)`: готовая пара цветов без подгонки. Светлая тема берёт `ic`
/// (тёмный вариант для светлого фона), если он есть, иначе `light`. На доске эта ветка не вызывается
/// (в `applyAccent` всегда строка), но в коде она есть, поэтому портирована и покрыта тестом.
Ios27AccentVars ios27AccentVarsFromPreset(Ios27AccentPreset p) =>
    Ios27AccentVars(
      light: Ios27Rgb.fromHex(p.ic ?? p.light),
      dark: Ios27Rgb.fromHex(p.dark),
    );

// ---------------------------------------------------------------------------------------------
// Палитры (app.js:103-128)
// ---------------------------------------------------------------------------------------------

/// Системный цвет Apple 27 для ряда Swatches в «Оформлении» (app.js:103-112).
class Ios27AccentPreset {
  const Ios27AccentPreset({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
    this.ic,
  });

  final String id;

  /// Название в интерфейсе (русское, как на доске).
  final String name;

  /// Цвет светлой темы, `#RRGGBB`.
  final String light;

  /// Цвет тёмной темы.
  final String dark;

  /// Затемнённый вариант для светлого фона (поле `ic` доски): есть у оранжевого, жёлтого, зелёного.
  final String? ic;
}

/// Восемь сохранённых цветов под сеткой палитры (app.js:103-112).
const List<Ios27AccentPreset> kIos27AccentPresets = [
  Ios27AccentPreset(
      id: 'blue', name: 'Синий', light: '#0088FF', dark: '#0091FF'),
  Ios27AccentPreset(
      id: 'purple', name: 'Фиолетовый', light: '#CB30E0', dark: '#DB34F2'),
  Ios27AccentPreset(
      id: 'pink', name: 'Розовый', light: '#FF2D55', dark: '#FF375F'),
  Ios27AccentPreset(
      id: 'red', name: 'Красный', light: '#FF383C', dark: '#FF4245'),
  Ios27AccentPreset(
      id: 'orange',
      name: 'Оранжевый',
      light: '#FF8D28',
      dark: '#FF9230',
      ic: '#C55300'),
  Ios27AccentPreset(
      id: 'yellow',
      name: 'Жёлтый',
      light: '#FFCC00',
      dark: '#FFD600',
      ic: '#A16A00'),
  Ios27AccentPreset(
      id: 'green',
      name: 'Зелёный',
      light: '#34C759',
      dark: '#30D158',
      ic: '#008932'),
  Ios27AccentPreset(
      id: 'graphite', name: 'Графитовый', light: '#8E8E93', dark: '#8E8E93'),
];

// Сетка палитры iOS (UIColorPickerViewController, вкладка Grid): 12 × 10, значения из символа
// «Color Pickers/Color Grid» UI Kit iOS 27. Первая строка серая, дальше оттенки от тёмных к светлым
// (app.js:116-125). Порядок строк и столбцов существенен: он же порядок ячеек на экране.
const String _gridSource = '''
FEFFFE EBEBEB D6D6D6 C2C2C2 ADADAD 999999 858585 707070 5C5C5C 474747 333333 000000
00374A 011D57 11053B 2E063D 3C071B 5C0701 5A1C00 583300 563D00 666100 4F5504 263E0F
004D65 012F7B 1A0A52 450D59 551029 831100 7B2900 7A4A00 785800 8D8602 6F760A 38571A
016E8F 0042A9 2C0977 61187C 791A3D B51A00 AD3E00 A96800 A67B01 C4BC00 9BA50E 4E7A27
008CB4 0056D6 371A94 7A219E 99244F E22400 DA5100 D38301 D19D01 F5EC00 C3D117 669D34
00A1D8 0061FD 4D22B2 982ABC B92D5D FF4015 FF6A00 FFAB01 FCC700 FEFB41 D9EC37 76BB40
01C7FC 3A87FD 5E30EB BE38F3 E63B7A FE6250 FE8648 FEB43F FECB3E FFF76B E4EF65 96D35F
52D6FC 74A7FF 864FFD D357FE EE719E FF8C82 FEA57D FEC777 FED977 FFF994 EAF28F B1DD8B
93E3FC A7C6FF B18CFE E292FE F4A4C0 FFB5AF FFC5AB FED9A8 FDE4A8 FFFBB9 F1F7B7 CDE8B5
CBF0FF D2E2FE D8C9FE EFCAFE F9D3E0 FFDAD8 FFE2D6 FEECD4 FEF1D5 FDFBDD F6FADB DEEED4''';

/// Число столбцов сетки.
const int kIos27ColorGridColumns = 12;

/// 120 цветов сетки `#RRGGBB`, по строкам слева направо.
final List<String> kIos27ColorGrid = List.unmodifiable(
  _gridSource.trim().split(RegExp(r'\s+')).map((h) => '#$h'),
);

/// Слот цвета в «Оформлении»: три своих цвета, как три цвета провайдера в `dropweb-theme`.
enum Ios27ColorSlot {
  /// Кнопки (акцент).
  accent('Кнопки'),

  /// Фон сверху (`orb1`).
  orb1('Фон сверху'),

  /// Фон снизу (`orb2`).
  orb2('Фон снизу');

  const Ios27ColorSlot(this.label);

  /// Подпись слота (app.js:128).
  final String label;
}

// ---------------------------------------------------------------------------------------------
// Тема провайдера и свои цвета (app.js:77-82, 258, 410-423)
// ---------------------------------------------------------------------------------------------

/// Три цвета приложения: акцент, верхний и нижний орб фона, плюс размытие 1..5.
///
/// Это `theme` доски (результат `parseTheme`) и `palette()`, когда включены «Свои» цвета.
class Ios27ProviderTheme {
  const Ios27ProviderTheme({
    required this.accent,
    required this.orb1,
    required this.orb2,
    this.blur = 3,
  });

  /// Из заголовка `dropweb-theme`: `<filter>,<accent>,<orb1>,<orb2>,<blur>`. Разбор общий с M3E.
  factory Ios27ProviderTheme.fromHeader(String header) {
    final h = parseDropwebTheme(header);
    return Ios27ProviderTheme(
      accent: h.accent,
      orb1: h.orb1,
      orb2: h.orb2,
      blur: h.blur,
    );
  }

  /// Тема по умолчанию: акцент `#29FF76`, орбы следуют за ним.
  ///
  /// На доске это `parseTheme(PROVIDERS[0].theme)`, то есть настоящий заголовок DROPWEB.
  /// Среди восьми [kIos27AccentPresets] этого цвета нет: цвет по умолчанию принадлежит провайдеру.
  static const Ios27ProviderTheme defaults = Ios27ProviderTheme(
    accent: m3eFallbackSeed,
    orb1: m3eFallbackSeed,
    orb2: m3eFallbackSeed,
  );

  /// `#RRGGBB`.
  final String accent;
  final String orb1;
  final String orb2;

  /// Размытие 1..5.
  final double blur;

  /// Свои цвета поверх этой темы: размытие остаётся провайдерским (`{...st.own, blur: theme.blur}`).
  Ios27ProviderTheme withOwn({
    String? accent,
    String? orb1,
    String? orb2,
  }) =>
      Ios27ProviderTheme(
        accent: accent ?? this.accent,
        orb1: orb1 ?? this.orb1,
        orb2: orb2 ?? this.orb2,
        blur: blur,
      );

  /// Цвет слота по имени.
  String slot(Ios27ColorSlot s) => switch (s) {
        Ios27ColorSlot.accent => accent,
        Ios27ColorSlot.orb1 => orb1,
        Ios27ColorSlot.orb2 => orb2,
      };

  /// То, что делает `applyAccent`: подгонка акцента и цвета орбов.
  Ios27AppliedAccent apply() => Ios27AppliedAccent(
        vars: ios27AccentVars(accent),
        orb1: Ios27Rgb.fromHex(orb1).color,
        orb2: Ios27Rgb.fromHex(orb2).color,
      );

  @override
  bool operator ==(Object other) =>
      other is Ios27ProviderTheme &&
      other.accent == accent &&
      other.orb1 == orb1 &&
      other.orb2 == orb2 &&
      other.blur == blur;

  @override
  int get hashCode => Object.hash(accent, orb1, orb2, blur);

  @override
  String toString() => 'Ios27ProviderTheme($accent, $orb1, $orb2, blur: $blur)';
}

/// Результат `applyAccent` на доске: `--accent`, `--on-accent`, `--accent-soft`, `--orb1`, `--orb2`.
class Ios27AppliedAccent {
  const Ios27AppliedAccent({
    required this.vars,
    required this.orb1,
    required this.orb2,
  });

  final Ios27AccentVars vars;

  /// `--orb1`.
  final Color orb1;

  /// `--orb2`.
  final Color orb2;

  /// Все пять свойств по именам доски (ARGB).
  Map<String, int> toVars({required bool dark}) => {
        ...vars.toVars(dark: dark),
        '--orb1': orb1.toARGB32(),
        '--orb2': orb2.toARGB32(),
      };
}

// ---------------------------------------------------------------------------------------------
// Значки строк всегда серые (решение владельца 26.10)
// ---------------------------------------------------------------------------------------------

/// Цвета значков в строках списков.
///
/// Решение владельца 26.10: значки строк не берут акцент провайдера и всегда серые, в любой теме
/// и при любом провайдере. Поэтому это токены палитры, а не [Ios27AccentVars].
abstract final class Ios27RowIconColors {
  /// Плитка 32×32 за значком: `--fill-3` (app.css:215).
  static Color tile(Ios27Palette p) => p.fill3;

  /// Глиф на плитке: `--label` (app.css:215).
  static Color glyph(Ios27Palette p) => p.label;

  /// Шеврон и прочие значки в конце строки: `--label-3` (app.css:240).
  static Color trailing(Ios27Palette p) => p.label3;
}
