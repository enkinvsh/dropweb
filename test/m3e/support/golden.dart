import 'dart:ui' as ui;

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fonts.dart';
import 'surface.dart';

/// Ключ корневого RepaintBoundary: с него снимается весь экран, а не отдельный элемент.
const Key kM3eBoardRootKey = ValueKey('m3e-board-root');

/// Размер эталонов доски в физических пикселях: 411x914 dp при dpr 2.
const int kM3eGoldenWidth = 822;
const int kM3eGoldenHeight = 1828;

/// Корень образца: те же делегаты l10n, что в `lib/application.dart`, локаль ru.
///
/// Отступы доски (строка состояния 44, навбар 24) задаются и здесь через `MediaQuery`,
/// чтобы кадр не зависел от того, вызвали ли `setM3eBoardSurface`. Фальшивых полос
/// не рисуется: на устройстве их рисует система, а в golden их место остаётся пустым.
Widget m3eBoardApp({
  required Widget child,
  required String seed,
  required String filter,
  required Brightness brightness,
  List<Override> overrides = const [],
}) {
  const padding = EdgeInsets.only(top: kM3eStatusBar, bottom: kM3eNavBar);
  final dark = brightness == Brightness.dark;
  return RepaintBoundary(
    key: kM3eBoardRootKey,
    child: ProviderScope(
      overrides: overrides,
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            platformBrightness: brightness,
            padding: padding,
            viewPadding: padding,
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: m3eThemeData(
              scheme(seed, filter, dark: dark),
              brightness: brightness,
            ),
            locale: const Locale('ru'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            home: M3eThemeScope.explicit(
              seed: seed,
              filter: filter,
              brightness: brightness,
              // Material даёт текстам DefaultTextStyle: без него они рисуются
              // с жёлтым двойным подчёркиванием.
              child: Material(color: Colors.transparent, child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Готовит окно, шрифты и строки l10n и выводит [app] (результат [m3eBoardApp]).
///
/// Единственный путь подготовки: поверхность 411x914 при dpr 2 и сброс после теста.
Future<void> pumpM3eBoard(WidgetTester tester, Widget app) async {
  setM3eBoardSurface(tester);
  await tester.runAsync(() async {
    await loadM3eFonts();
    // Статический `AppLocalizations.current` нужен коду вне дерева (`appLocalizations`).
    await AppLocalizations.load(const Locale('ru'));
  });
  await tester.pumpWidget(app);
  await tester.pump();
}

/// Сравнивает весь экран с `test/m3e/goldens/<name>.png`, размер строго 822x1828.
///
/// `matchesGoldenFile(finder)` снимает слой с pixelRatio 1 и дал бы 411x914, поэтому
/// слой снимается вручную с dpr окна. Размер проверяется до сравнения: другой размер
/// означает ошибку раскладки или поверхности, а не расхождение пикселей.
Future<void> expectM3eGolden(WidgetTester tester, String name) async {
  final element = tester.element(find.byKey(kM3eBoardRootKey));
  final box = element.renderObject! as RenderRepaintBoundary;
  final dpr = tester.view.devicePixelRatio;
  final image = (await tester.runAsync<ui.Image>(
    () => box.toImage(pixelRatio: dpr),
  ))!;
  expect(
    (image.width, image.height),
    (kM3eGoldenWidth, kM3eGoldenHeight),
    reason: 'кадр $name должен быть 822x1828 как эталоны доски',
  );
  await expectLater(image, matchesGoldenFile('goldens/$name.png'));
}
