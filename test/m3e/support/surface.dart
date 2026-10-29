import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Размер экрана доски в логических пикселях (`.droid`: 411x914).
const Size kM3eBoardSize = Size(411, 914);

/// Плотность пикселей снимков доски: физически 822x1828.
const double kM3eBoardDpr = 2;

/// Отступы системных панелей доски: строка состояния 44 dp, жестовая полоса 24 dp.
const double kM3eStatusBar = 44;
const double kM3eNavBar = 24;

/// Ставит окно теста в геометрию доски и сбрасывает его по окончании теста.
void setM3eBoardSurface(WidgetTester tester) {
  const padding = FakeViewPadding(
    top: kM3eStatusBar * kM3eBoardDpr,
    bottom: kM3eNavBar * kM3eBoardDpr,
  );
  tester.view
    ..devicePixelRatio = kM3eBoardDpr
    ..physicalSize = kM3eBoardSize * kM3eBoardDpr
    ..padding = padding
    ..viewPadding = padding
    ..viewInsets = FakeViewPadding.zero;
  addTearDown(() {
    tester.view.reset();
  });
}
