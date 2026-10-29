// Общая заготовка ворот 3/4/8: главная на стенде доски с подменой входа через Riverpod.
// Повторяет `_app` из home_test.dart (он приватный), чтобы новые тесты не копировали её.

import 'dart:io';

import 'package:dropweb/ui/m3e/color/theme_header.dart';
import 'package:dropweb/ui/m3e/home/m3e_elapsed_clock.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_providers.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_logo.dart'
    show m3eLogoSvgProvider;
import 'package:dropweb/ui/m3e/widgets/m3e_hero_button.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_home_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_scenes.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';

final String _logoSvg =
    File('test/m3e/fixtures/board_logo.svg').readAsStringSync();

/// Один фон главной без кнопки и карточки: в кадре двигается только волна,
/// поэтому счётчик тикеров относится именно к ней.
Widget gateBackdropApp(
  M3eHeroState state, {
  required Offset origin,
  bool reduced = false,
}) {
  final header = parseDropwebTheme(kBoardProviders[0].theme);
  return m3eBoardApp(
    seed: header.accent,
    filter: header.filter,
    brightness: Brightness.light,
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: SizedBox.expand(
          child: M3eHomeBackdrop(state: state, waveOrigin: origin),
        ),
      ),
    ),
  );
}

/// Главная сцены [scene] на данных NORMAL или WORST.
///
/// [reduced] — `MediaQuery.disableAnimations` (эталоны доски сняты так), [tickers] —
/// `TickerMode` над экраном (так Navigator глушит закрытый маршрут). [clock] подменяет
/// «сейчас»; по умолчанию фиксированный [kHomeNow]. [tickClock] — то же для секунд таймера.
Widget gateHomeApp(
  String scene, {
  int provider = 0,
  Brightness brightness = Brightness.light,
  bool worst = false,
  bool reduced = true,
  bool tickers = true,
  DateTime Function()? clock,
  DateTime Function()? tickClock,
  List<Override> extra = const [],
}) {
  final header = parseDropwebTheme(kBoardProviders[provider].theme);
  final data = worst ? kBoardWorst : kBoardNormal;
  return m3eBoardApp(
    seed: header.accent,
    filter: header.filter,
    brightness: brightness,
    overrides: [
      m3eHomeInputProvider.overrideWithValue(homeInputFor(scene, worst: worst)),
      m3eHomeClockProvider.overrideWithValue(clock ?? () => kHomeNow),
      // Часы таймера сеанса заморожены: секунды в golden и в тестах не плывут. Тесты
      // живого таймера подставляют часы fake-async через [tickClock].
      m3eTickClockProvider.overrideWithValue(tickClock ?? () => kHomeNow),
      // Сигнал и запуск проверки адреса читают globalState; в golden они не нужны.
      m3eIpCheckSignalProvider.overrideWithValue((0, false)),
      m3eIpRefreshProvider.overrideWithValue(
        M3eIpRefresh(read: () => null, reset: () {}, checkQuiet: () async {}),
      ),
      m3eIpLogProvider.overrideWithValue((_) {}),
      // Цель замера пинга читает runTime из globalState; в golden замеров нет.
      m3eRouteNodeProvider.overrideWithValue(null),
      // Сеть в тесте не нужна: логотип доски отдаётся из файла.
      if (data.logos[0] != null)
        m3eLogoSvgProvider(data.logos[0]!).overrideWith((ref) => _logoSvg),
      ...extra,
    ],
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: TickerMode(enabled: tickers, child: const M3eHome()),
      ),
    ),
  );
}
