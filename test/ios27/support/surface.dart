// Поверхности тестов iOS-редизайна: геометрия доски для golden (G4) и устройства iPhone для проверки раскладки (G3).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Устройство для теста: размер окна в dp, плотность и системные отступы.
///
/// [padding] кладётся и в `MediaQuery.padding`, и в `viewPadding` окна: во Flutter safe area
/// iOS приходит именно так (вырез и индикатор «домой»), клавиатуры нет (`viewInsets` ноль).
class Ios27Device {
  const Ios27Device({
    required this.name,
    required this.size,
    required this.dpr,
    required this.padding,
  });

  /// Название для сообщений об ошибках и имён golden-кадров.
  final String name;

  /// Размер окна в логических пикселях.
  final Size size;

  /// Плотность пикселей.
  final double dpr;

  /// Системные отступы сверху и снизу, dp.
  final EdgeInsets padding;

  /// Размер кадра в физических пикселях.
  Size get physicalSize => size * dpr;

  /// Ширина кадра, px.
  int get pixelWidth => physicalSize.width.round();

  /// Высота кадра, px.
  int get pixelHeight => physicalSize.height.round();
}

/// Экран колонки iOS доски (`[data-col="ios"] .app`): 411×914 dp, снимки 822×1828 px при dpr 2.
///
/// Отступы здесь не safe area Apple, а раскладочный контракт доски, он же эталон для golden:
///  - сверху 48: экраны доски отсчитывают верх от 48 (`.home__nav{top:48px}` app.css:132,
///    `.page__nav{top:48px}` app.css:153, комментарий «строка состояния 48 + панель 44» app.css:139),
///    хотя сама нарисованная строка состояния высотой 40 (`.sys-bar`, app.css:33-37);
///  - снизу 52: нижний ряд главной стоит на 52 выше края (`.home--b{padding:52px 16px 52px}`,
///    app.css:448; комментарий над правилом объясняет, что ниже жест «домой»). Индикатор «домой»
///    (`.sys-gesture`, app.css:39-42) занимает 902..906 и в раскладку не входит.
/// Те же числа лежат в `test/ios27/ref/layout.json`: `mask.statusBar` 411×40, `mask.homeIndicator`
/// (151.5, 902, 108, 4), нижний ряд главной заканчивается на y = 862 = 914 − 52.
const Ios27Device kIos27BoardDevice = Ios27Device(
  name: 'board-411x914',
  size: Size(411, 914),
  dpr: 2,
  padding: EdgeInsets.only(top: 48, bottom: 52),
);

// Устройства G3. Размеры и safe area: «Specifications» в Apple HIG (Layout), портретная ориентация,
// значения для верхней и нижней safe area. Это числа Apple, а не доски.

/// iPhone 8 / SE (2-го и 3-го поколения): 375×667 @2x, строка состояния 20, индикатора «домой» нет.
const Ios27Device kIos27IphoneSmall = Ios27Device(
  name: 'iphone-375x667',
  size: Size(375, 667),
  dpr: 2,
  padding: EdgeInsets.only(top: 20),
);

/// iPhone 12–14: 390×844 @3x, вырез 47, индикатор «домой» 34.
const Ios27Device kIos27IphoneMedium = Ios27Device(
  name: 'iphone-390x844',
  size: Size(390, 844),
  dpr: 3,
  padding: EdgeInsets.only(top: 47, bottom: 34),
);

/// iPhone 16 Pro Max: 440×956 @3x, Dynamic Island 62, индикатор «домой» 34.
const Ios27Device kIos27IphoneLarge = Ios27Device(
  name: 'iphone-440x956',
  size: Size(440, 956),
  dpr: 3,
  padding: EdgeInsets.only(top: 62, bottom: 34),
);

/// Устройства G3 по возрастанию размера.
const List<Ios27Device> kIos27Iphones = [
  kIos27IphoneSmall,
  kIos27IphoneMedium,
  kIos27IphoneLarge,
];

/// Ставит окно теста в геометрию [device] и сбрасывает его по окончании теста.
///
/// Отступы окна заданы в физических пикселях (`FakeViewPadding`), поэтому умножаются на dpr.
void setIos27Surface(
  WidgetTester tester, [
  Ios27Device device = kIos27BoardDevice,
]) {
  final padding = FakeViewPadding(
    top: device.padding.top * device.dpr,
    bottom: device.padding.bottom * device.dpr,
    left: device.padding.left * device.dpr,
    right: device.padding.right * device.dpr,
  );
  tester.view
    ..devicePixelRatio = device.dpr
    ..physicalSize = device.physicalSize
    ..padding = padding
    ..viewPadding = padding
    ..viewInsets = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}
