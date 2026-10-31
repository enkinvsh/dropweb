// Общая заготовка тестов главной iOS: сцены доски → вход приложения → экран, прогрев фона.
//
// Сцены берутся из `test/m3e/home_scenes.dart`: это те же входы, какими кормит модель реальный
// конфиг владельца (данные доски NORMAL/WORST), поэтому golden и parity проверяют настоящий путь
// «вход → адаптер → экран», а не отдельные тестовые данные.

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_screen.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_view.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_backdrop.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../m3e/home_scenes.dart';
import '../fixtures/board_providers.dart';
import 'golden.dart';
import 'surface.dart';

export '../../m3e/home_scenes.dart'
    show
        kHomeAnnounceNormal,
        kHomeAnnounceWorst,
        kHomeNow,
        kHomeRunTime,
        kHomeSceneIds,
        homeInputFor;

/// Сцены главной, где есть карточка и нижний ряд (без `switching`: R10, и без `empty`).
const List<String> kIos27HomeScenes = [
  'home-off',
  'connecting',
  'home-on',
  'error',
  'offline',
  'expiring',
  'traffic-low',
  'traffic-out',
  'expired',
];

Ios27ProviderTheme homeProviderTheme(int provider) =>
    Ios27ProviderTheme.fromHeader(kBoardProviders[provider].theme);

/// Цвета для расчёта фона: те же, что строит скоуп кадра.
Ios27Colors homeColors(int provider, Brightness brightness) => Ios27Colors.from(
      theme: homeProviderTheme(provider),
      brightness: brightness,
      child: const SizedBox.shrink(),
    );

/// Состояние фона сцены главной (как выбирает адаптер).
Ios27BackdropState homeBackdropFor(String scene) => switch (scene) {
      'home-on' => Ios27BackdropState.on,
      'connecting' => Ios27BackdropState.connecting,
      _ => Ios27BackdropState.off,
    };

/// Считает фон заранее: `Isolate.run` из FakeAsync-зоны теста не возвращается, поэтому картинка
/// кладётся в кэш вне неё.
Future<void> prewarmHomeBackdrop(
  WidgetTester tester,
  Ios27Colors colors,
  Ios27BackdropState state,
) =>
    tester.runAsync(
      () => Ios27BackdropRenderer.debugPrewarm(
        Ios27BackdropSpec.fromColors(colors, on: state.target),
      ),
    );

/// Даёт `.then(setState)` фона дойти до кадра.
Future<void> settleHomeBackdrop(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
}

/// Экран главной на входе [input]: данные строит настоящий адаптер.
Widget ios27HomeFrame({
  required M3eHomeInput input,
  DateTime? since,
  DateTime Function()? now,
  bool ipPending = false,
  String? routeName,
  bool glassAway = false,
  VoidCallback? onToggle,
  VoidCallback? onSettings,
  VoidCallback? onSubscriptions,
  VoidCallback? onRoute,
  VoidCallback? onRefresh,
  ValueChanged<String>? onLink,
  Widget? overlay,
}) =>
    Builder(
      builder: (context) {
        final data = buildIos27HomeData(
          AppLocalizations.of(context),
          input,
          now: kHomeNow,
          locale: 'ru',
          ipPending: ipPending,
          since: since,
          routeName: routeName,
        );
        final screen = Ios27HomeScreen(
          data: data,
          now: now ?? DateTime.now,
          glassAway: glassAway,
          onToggle: onToggle,
          onSettings: onSettings,
          onSubscriptions: onSubscriptions,
          onRoute: onRoute,
          onRefresh: onRefresh,
          onLink: onLink,
        );
        if (overlay == null) {
          return screen;
        }
        return Stack(children: [Positioned.fill(child: screen), overlay]);
      },
    );

/// Выводит сцену доски [scene] с готовым фоном.
///
/// `disableAnimations` по умолчанию включён: эталоны сняты с reducedMotion, значит без кольца
/// точки и с телом таймера без перекатов.
Future<void> pumpHomeScene(
  WidgetTester tester,
  String scene, {
  Brightness brightness = Brightness.light,
  int provider = 0,
  bool worst = false,
  double textScale = 1.0,
  Ios27Device device = kIos27BoardDevice,
  bool disableAnimations = true,
  bool reduceTransparency = true,
  bool ipPending = false,
  bool withBackdrop = true,
  Widget? overlay,
}) async {
  if (withBackdrop) {
    await prewarmHomeBackdrop(
      tester,
      homeColors(provider, brightness),
      homeBackdropFor(scene),
    );
  }
  final since = scene == 'home-on'
      ? tester.binding.clock.now().subtract(kHomeRunTime)
      : null;
  await pumpIos27Board(
    tester,
    ios27BoardApp(
      brightness: brightness,
      theme: homeProviderTheme(provider),
      disableAnimations: disableAnimations,
      reduceTransparency: reduceTransparency,
      textScale: textScale,
      device: device,
      child: ios27HomeFrame(
        input: homeInputFor(scene, worst: worst),
        since: since,
        now: tester.binding.clock.now,
        ipPending: ipPending || scene == 'connecting',
        overlay: overlay,
      ),
    ),
    device: device,
  );
  if (withBackdrop) {
    await settleHomeBackdrop(tester);
  }
}
