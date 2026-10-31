// Главная iOS в настоящем `CommonScaffold(fullBleed: true)` и проводка провайдеров.
//
// Урок Android (чёрный экран): `CommonScaffold(fullBleed)` отдавал телу размер 0×0, а golden чистых
// экранов рисуют их без обвязки приложения и этого не ловят. Здесь `Ios27Home` стоит внутри
// настоящего скаффолда, а вход, часы, сессия адреса и действия подменены провайдерами.

import 'dart:async';

import 'package:dropweb/ui/ios27/home/ios27_home.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_actions.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_screen.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card.dart';
import 'package:dropweb/ui/m3e/home/m3e_elapsed_clock.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_providers.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart' show m3eHomeClockProvider;
import 'package:dropweb/widgets/scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_path_provider.dart';
import 'support/golden.dart';
import 'support/home_harness.dart';
import 'support/surface.dart';

const _bodyKey = ValueKey<String>('ios27-home-body');

/// Нажатия, дошедшие до действий главной.
class _Calls {
  final log = <String>[];
  Uri? link;

  Ios27HomeActions get actions => Ios27HomeActions(
        toggleVpn: (_, __) async => log.add('toggle'),
        refresh: (_, __) async => log.add('refresh'),
        openLink: (uri) {
          log.add('link');
          link = uri;
        },
        openSettings: (_) => log.add('settings'),
        openSubscriptions: (_) => log.add('subscriptions'),
        openRoute: (_) => log.add('route'),
      );
}

List<Override> _overrides(String scene, _Calls calls, {bool worst = false}) => [
      m3eHomeInputProvider.overrideWithValue(homeInputFor(scene, worst: worst)),
      m3eHomeClockProvider.overrideWithValue(() => kHomeNow),
      m3eTickClockProvider.overrideWithValue(() => kHomeNow),
      // Проверка внешнего адреса читает globalState: в тесте её нет.
      m3eIpCheckSignalProvider.overrideWithValue((0, false)),
      m3eIpRefreshProvider.overrideWithValue(
        M3eIpRefresh(read: () => null, reset: () {}, checkQuiet: () async {}),
      ),
      m3eIpLogProvider.overrideWithValue((_) {}),
      m3eRouteNodeProvider.overrideWithValue(null),
      ios27HomeActionsProvider.overrideWithValue(calls.actions),
    ];

Future<void> _pump(
  WidgetTester tester,
  String scene,
  _Calls calls, {
  bool worst = false,
  Ios27Device device = kIos27BoardDevice,
}) async {
  await pumpIos27Board(
    tester,
    ios27BoardApp(
      brightness: Brightness.dark,
      disableAnimations: true,
      device: device,
      overrides: _overrides(scene, calls, worst: worst),
      child: const CommonScaffold(
        // assert в build() требует заголовок даже у fullBleed.
        title: '',
        fullBleed: true,
        body: KeyedSubtree(key: _bodyKey, child: Ios27Home()),
      ),
    ),
    device: device,
  );
}

void main() {
  // commonPrint.log пишет в файловый журнал, которому нужен appPath. Без подмены на Linux
  // `getDownloadsDirectory()` бросает UnsupportedError раньше канала, и ошибка падает на
  // тест, который первым вывел плашку или строку журнала.
  useFakePathProvider();
  testWidgets('тело fullBleed занимает весь экран, карточка и ряд на месте',
      (tester) async {
    final calls = _Calls();
    try {
      await _pump(tester, 'home-off', calls);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(_bodyKey)), kIos27BoardDevice.size);
      expect(find.byKey(Ios27CardKeys.card), findsOneWidget);
      expect(
          tester.getSize(find.byKey(Ios27HomeKeys.power)), const Size(80, 80));
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('во время loadingRun полосы нет, тело на весь экран',
      (tester) async {
    final calls = _Calls();
    try {
      await _pump(tester, 'home-off', calls);
      final state =
          tester.state<CommonScaffoldState>(find.byType(CommonScaffold));
      final done = Completer<int>();
      final run = state.loadingRun<int>(() => done.future);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.getSize(find.byKey(_bodyKey)), kIos27BoardDevice.size);
      done.complete(42);
      expect(await run, 42);
      await tester.pump();
      expect(tester.getSize(find.byKey(_bodyKey)), kIos27BoardDevice.size);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('нажатия доходят до действий', (tester) async {
    final calls = _Calls();
    try {
      await _pump(tester, 'home-off', calls);
      await tester.tap(find.byKey(Ios27HomeKeys.power));
      await tester.tap(find.byKey(Ios27HomeKeys.settings));
      await tester.tap(find.byKey(Ios27HomeKeys.dockSub));
      await tester.tap(find.byKey(Ios27HomeKeys.dockRoute));
      await tester.pump();
      expect(calls.log, ['toggle', 'settings', 'subscriptions', 'route']);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('«Обновить» на закончившемся трафике зовёт refresh',
      (tester) async {
    final calls = _Calls();
    try {
      await _pump(tester, 'traffic-out', calls);
      await tester.tap(find.byKey(Ios27CardKeys.refresh));
      await tester.pump();
      expect(calls.log, ['refresh']);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('connecting: нажатие на питание не запускает действие повторно',
      (tester) async {
    final calls = _Calls();
    try {
      await _pump(tester, 'connecting', calls);
      await tester.tap(find.byKey(Ios27HomeKeys.power));
      await tester.pump();
      // heroPressable в адаптере ложно при подключении: повторный запуск запрещён.
      expect(calls.log, isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('home-on: таймер из часов провайдера, без исключений',
      (tester) async {
    final calls = _Calls();
    try {
      await _pump(tester, 'home-on', calls);
      expect(tester.takeException(), isNull);
      // Часы заморожены на kHomeNow: якорь = now − runTime, текст 12:49.
      expect(find.text('12:49'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('WORST на самом узком экране в скаффолде: без исключений',
      (tester) async {
    final calls = _Calls();
    try {
      await _pump(
        tester,
        'traffic-out',
        calls,
        worst: true,
        device: kIos27IphoneSmall,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(_bodyKey)), kIos27IphoneSmall.size);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('снятие главной не оставляет таймеров и слушателей',
      (tester) async {
    final calls = _Calls();
    await _pump(tester, 'home-on', calls);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'на iOS главная держит книжную ориентацию и отпускает её при снятии',
      (tester) async {
    final calls = <List<String>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          calls.add(List<String>.from(call.arguments as List));
        }
        return null;
      },
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _pump(tester, 'home-off', _Calls());
      expect(calls, [
        ['DeviceOrientation.portraitUp'],
      ]);
      await tester.pumpWidget(const SizedBox());
      expect(calls.last, isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    }
  });
}
