// Ворота 8: движение. Вращение Cookie, волна фона и индикатор подключения не должны
// крутить кадры, когда включён «меньше движения», когда экран закрыт непрозрачным
// маршрутом и когда приложение в фоне.

import 'dart:async';

import 'package:dropweb/state.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_hero_button.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_home_backdrop.dart';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';

import 'gate_support.dart';
import 'support/golden.dart';

const _coverKey = ValueKey<String>('gate8.cover');

Future<void> _pump(WidgetTester tester, Widget app) async {
  await pumpM3eBoard(tester, app);
  await tester.pump(const Duration(seconds: 1));
}

/// Непрозрачный маршрут без анимаций: как страница настроек, закрывающая главную.
Future<void> _pushCover(WidgetTester tester) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  unawaited(
    nav.push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) =>
            const ColoredBox(key: _coverKey, color: Colors.black),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _popCover(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Кадр всего экрана: сравнением двух снимков проверяем, что форма не вращается.
Future<Uint8List> _shot(WidgetTester tester) async {
  final box = tester.element(find.byKey(kM3eBoardRootKey)).renderObject!
      as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await box.toImage();
    final data = await image.toByteData();
    return data!.buffer.asUint8List();
  }))!;
}

/// Запрашивал ли кто-то кадр, пока шли [span] виртуального времени без наших `pump`.
/// Таймер, который дёргает `setState` или `notifyListeners`, оставляет запрос кадра;
/// спокойное дерево не оставляет ничего.
Future<bool> _framesRequested(WidgetTester tester, Duration span) async {
  await tester.pump();
  expect(tester.binding.hasScheduledFrame, isFalse,
      reason: 'перед замером очередь кадров должна быть пустой');
  await tester.binding.delayed(span);
  return tester.binding.hasScheduledFrame;
}

void main() {
  tearDown(() => debugDisableShadows = true);

  group('ворота 8: disableAnimations', () {
    testWidgets('home-on: тикеров нет, форма стоит между кадрами',
        (tester) async {
      await _pump(tester, gateHomeApp('home-on'));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);

      final first = await _shot(tester);
      await tester.pump(const Duration(seconds: 3));
      final second = await _shot(tester);
      expect(listEquals(first, second), isTrue,
          reason: 'при reduced motion Cookie не вращается');
    });

    testWidgets('home-on с анимациями: форма вращается', (tester) async {
      await _pump(tester, gateHomeApp('home-on', reduced: false));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      final first = await _shot(tester);
      await tester.pump(const Duration(seconds: 3));
      final second = await _shot(tester);
      expect(listEquals(first, second), isFalse,
          reason: 'без reduced motion Cookie вращается (24 с на оборот)');
    });

    testWidgets(
        'connecting: вместо индикатора статичный SoftBurst, без тикеров',
        (tester) async {
      await _pump(tester, gateHomeApp('connecting'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
      expect(
          await _framesRequested(tester, const Duration(seconds: 3)), isFalse);
    });
  });

  group('ворота 8: экран закрыт непрозрачным маршрутом', () {
    testWidgets('home-on: вращение останавливается и возобновляется',
        (tester) async {
      await _pump(tester, gateHomeApp('home-on', reduced: false));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await _pushCover(tester);
      expect(find.byKey(_coverKey), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0,
          reason: 'TickerMode закрытого маршрута глушит вращение и фон');

      await _popCover(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, greaterThan(0),
          reason: 'после возврата вращение идёт снова');
    });

    testWidgets('connecting: индикатор не дёргает кадры под закрытым маршрутом',
        (tester) async {
      await _pump(tester, gateHomeApp('connecting', reduced: false));
      // Кнопка и адрес на карточке (адрес ждётся при подключении).
      expect(find.byType(ExpressiveLoadingIndicator), findsNWidgets(2));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await _pushCover(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
      // Внутри пакета Timer.periodic(650 мс) сам не смотрит на TickerMode и
      // сбрасывает контроллер: без замены индикатора на статичную форму он
      // просил бы кадр каждые 650 мс, пока закрыт экран.
      expect(
          await _framesRequested(tester, const Duration(seconds: 4)), isFalse,
          reason: 'индикатор под закрытым маршрутом не должен будить кадры');

      await _popCover(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ExpressiveLoadingIndicator), findsNWidgets(2),
          reason: 'после возврата индикаторы снова живые');
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets(
        'подключено + закрыт: ни тикеров, ни таймера секунд, ни запросов кадра',
        (tester) async {
      final start = tester.binding.clock.now();
      await _pump(
        tester,
        gateHomeApp('home-on',
            reduced: false, tickClock: tester.binding.clock.now),
      );
      // Открытый экран живой: пульс точки и вращение формы просят кадры.
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await _pushCover(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0,
          reason: 'пульс точки и секунды под закрытым маршрутом молчат');
      expect(
          await _framesRequested(tester, const Duration(seconds: 30)), isFalse,
          reason: 'таймер секунд не должен будить кадры под закрытым экраном');

      // По возвращении таймер показывает настоящее время сеанса, а не замершее.
      await _popCover(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final shown = RegExp(r'^(\d+):(\d\d)$');
      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere(shown.hasMatch, orElse: () => '');
      final m = shown.firstMatch(text)!;
      final seconds = int.parse(m[1]!) * 60 + int.parse(m[2]!);
      final expected =
          12 * 60 + 49 + tester.binding.clock.now().difference(start).inSeconds;
      expect((seconds - expected).abs(), lessThanOrEqualTo(1));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('connecting под TickerMode(enabled: false) без индикатора',
        (tester) async {
      await _pump(
        tester,
        gateHomeApp('connecting', reduced: false, tickers: false),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
      expect(
          await _framesRequested(tester, const Duration(seconds: 4)), isFalse);
    });
  });

  group('ворота 8: часы главной', () {
    testWidgets('у экрана нет своего таймера: выключен VPN', (tester) async {
      var calls = 0;
      DateTime clock() {
        calls++;
        return kNow;
      }

      await _pump(
          tester, gateHomeApp('home-off', reduced: false, clock: clock));
      final built = calls;
      expect(built, greaterThan(0));
      expect(
          await _framesRequested(tester, const Duration(seconds: 30)), isFalse);
      await tester.pump(const Duration(seconds: 30));
      expect(calls, built, reason: 'экран не перестраивается сам по таймеру');
    });

    testWidgets('у экрана нет своего таймера: включён VPN, экран закрыт',
        (tester) async {
      var calls = 0;
      DateTime clock() {
        calls++;
        return kNow;
      }

      await _pump(tester, gateHomeApp('home-on', reduced: false, clock: clock));
      await _pushCover(tester);
      await tester.pump(const Duration(seconds: 1));
      final built = calls;
      expect(
          await _framesRequested(tester, const Duration(seconds: 30)), isFalse);
      await tester.pump(const Duration(seconds: 30));
      expect(calls, built,
          reason:
              'секунды под закрытым маршрутом не считаются: таймер экрана остановлен');
    });
  });

  group('ворота 8: цепочка тиков globalState (источник «12:48»)', () {
    // Секунды работы приходят из runTimeProvider; его пишет цепочка
    // globalState.startUpdateTasks раз в 2 с. Она должна останавливаться в фоне
    // (AppLifecycleState != resumed) и при выключении VPN.
    testWidgets('тикает при включённом VPN, молчит в фоне и после остановки',
        (tester) async {
      var ticks = 0;
      Future<void> task() async => ticks++;

      unawaited(globalState.startUpdateTasks([task]));
      await tester.pump();
      await tester.binding.delayed(const Duration(seconds: 7));
      final running = ticks;
      expect(running, greaterThanOrEqualTo(3), reason: 'раз в 2 с');

      // Приложение ушло в фон: App Nap/Doze не должны получать таймер UI.
      globalState.pauseUpdateTasks();
      await tester.binding.delayed(const Duration(seconds: 30));
      expect(ticks, running, reason: 'в фоне цепочка не тикает');

      globalState.resumeUpdateTasks();
      await tester.pump();
      await tester.binding.delayed(const Duration(seconds: 5));
      expect(ticks, greaterThan(running),
          reason: 'на переднем плане снова идёт');

      // VPN выключен: цепочка снята совсем.
      globalState.stopUpdateTasks();
      final stopped = ticks;
      await tester.binding.delayed(const Duration(seconds: 30));
      expect(ticks, stopped, reason: 'после остановки VPN тиков нет');
    });
  });

  group('ворота 8: волна фона', () {
    const origin = Offset(205.5, 822);

    Widget app(M3eHeroState state, {bool reduced = false}) => gateBackdropApp(
          state,
          origin: origin,
          reduced: reduced,
        );

    testWidgets('после перехода тикеров фона нет', (tester) async {
      await _pump(tester, app(M3eHeroState.off));
      await tester.pumpWidget(app(M3eHeroState.on));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0),
          reason: 'волна идёт');
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0, reason: 'волна села');
    });

    testWidgets('при disableAnimations переход мгновенный', (tester) async {
      await _pump(tester, app(M3eHeroState.off, reduced: true));
      await tester.pumpWidget(app(M3eHeroState.on, reduced: true));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      final jumped = await _shot(tester);

      // Тот же кадр, но дошедший пружиной: итог переходов совпадает.
      await _pump(tester, app(M3eHeroState.off));
      await tester.pumpWidget(app(M3eHeroState.on));
      await tester.pump(const Duration(seconds: 2));
      final animated = await _shot(tester);
      expect(listEquals(jumped, animated), isTrue,
          reason: 'мгновенный переход и дошедшая пружина дают один кадр');
    });

    testWidgets('переход посреди хода под закрытым маршрутом замирает',
        (tester) async {
      await _pump(tester, app(M3eHeroState.off));
      await tester.pumpWidget(app(M3eHeroState.on));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await _pushCover(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0,
          reason: 'контроллеры фона глушит TickerMode закрытого маршрута');
      expect(find.byKey(kM3eBackdropKey, skipOffstage: false), findsOneWidget);
    });
  });
}

/// «Сейчас» для счётчика вызовов часов: значение не важно, важно число вызовов.
final DateTime kNow = DateTime(2026, 10, 29, 12);
