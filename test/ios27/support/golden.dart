import 'dart:ui' as ui;

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text_scale.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_data.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fonts.dart';
import 'surface.dart';

/// Ключ корневого RepaintBoundary: с него снимается весь экран, а не отдельный элемент.
const Key kIos27BoardRootKey = ValueKey('ios27-board-root');

/// Корень образца: те же делегаты l10n, что в `lib/application.dart` (219-224), локаль ru.
///
/// Системные настройки задаются здесь, а не флагами платформы теста, чтобы кадр не зависел от
/// окружения: яркость, «Повышенная контрастность», «Жирный текст», масштаб шрифта, «Уменьшить
/// движение». «Уменьшить прозрачность» идёт мимо `MediaQuery`, через `Ios27A11y.debugOverride`
/// (по умолчанию включена: стекло рисуется непрозрачной заглушкой, как в режиме RT доски, и golden
/// детерминированы); сброс при завершении теста регистрируется здесь же.
///
/// Системные панели не рисуются: на устройстве их рисует система, а в golden их место пусто.
/// Размер окна задаёт [pumpIos27Board] (или [setIos27Surface]); [device] здесь определяет только
/// отступы `MediaQuery`.
Widget ios27BoardApp({
  required Widget child,
  required Brightness brightness,
  Ios27ProviderTheme theme = Ios27ProviderTheme.defaults,
  bool highContrast = false,
  bool boldText = false,
  bool reduceTransparency = true,
  double textScale = 1.0,
  bool disableAnimations = false,
  List<Override> overrides = const [],
  Locale locale = const Locale('ru'),
  Ios27Device device = kIos27BoardDevice,
}) {
  Ios27A11y.debugOverride = reduceTransparency;
  addTearDown(Ios27A11y.debugReset);
  // Внутри скоупа масштаб текста системный, а не из предка: кадр задаёт его подменой источника,
  // чтобы он не зависел от настроек машины, на которой идёт тест.
  Ios27SystemTextScale.debugOverride = textScale;
  addTearDown(Ios27SystemTextScale.debugReset);

  // Тема для самого MaterialApp: диалоги и листы, открытые мимо скоупа, берут цвета отсюда.
  final colors = Ios27Colors.from(
    theme: theme,
    brightness: brightness,
    highContrast: highContrast,
    child: const SizedBox.shrink(),
  );

  return RepaintBoundary(
    key: kIos27BoardRootKey,
    child: ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ios27ThemeData(colors),
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        // Системные настройки подменяются под Navigator: MaterialApp сам читает MediaQuery окна,
        // и обёртка снаружи не всегда доходит до `home`.
        builder: (context, navigator) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            platformBrightness: brightness,
            padding: device.padding,
            viewPadding: device.padding,
            highContrast: highContrast,
            boldText: boldText,
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: navigator!,
        ),
        home: Ios27ThemeScope.explicit(
          theme: theme,
          brightness: brightness,
          highContrast: highContrast,
          // Material даёт текстам DefaultTextStyle: без него они рисуются с жёлтым
          // двойным подчёркиванием.
          child: Material(color: Colors.transparent, child: child),
        ),
      ),
    ),
  );
}

/// Готовит окно, шрифты и строки l10n и выводит [app] (результат [ios27BoardApp]).
///
/// Единственный путь подготовки: поверхность [device] и сброс после теста, шрифты Onest и
/// Twemoji, статические строки `AppLocalizations.current` (нужны коду вне дерева).
Future<void> pumpIos27Board(
  WidgetTester tester,
  Widget app, {
  Ios27Device device = kIos27BoardDevice,
  Locale locale = const Locale('ru'),
}) async {
  setIos27Surface(tester, device);
  await tester.runAsync(() async {
    await loadIos27Fonts();
    await AppLocalizations.load(locale);
  });
  await tester.pumpWidget(app);
  await tester.pump();
}

/// Сравнивает весь экран с `goldens/<name>.png` рядом с тестовым файлом.
///
/// `matchesGoldenFile(finder)` снимает слой с pixelRatio 1 и дал бы 411×914, поэтому слой
/// снимается вручную с dpr окна. Размер проверяется до сравнения: другой размер означает ошибку
/// раскладки или поверхности, а не расхождение пикселей. Для доски это 822×1828, как PNG эталонов.
Future<void> expectIos27Golden(
  WidgetTester tester,
  String name, {
  Ios27Device device = kIos27BoardDevice,
}) async {
  final element = tester.element(find.byKey(kIos27BoardRootKey));
  final box = element.renderObject! as RenderRepaintBoundary;
  final image = (await tester.runAsync<ui.Image>(
    () => box.toImage(pixelRatio: tester.view.devicePixelRatio),
  ))!;
  expect(
    (image.width, image.height),
    (device.pixelWidth, device.pixelHeight),
    reason: 'кадр $name должен быть ${device.pixelWidth}×${device.pixelHeight} '
        '(${device.name})',
  );
  await expectLater(image, matchesGoldenFile('goldens/$name.png'));
}
