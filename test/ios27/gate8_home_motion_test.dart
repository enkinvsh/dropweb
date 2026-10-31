// G8: движение экрана главной iOS целиком (карточка + фон + кнопки).
//
// Что проверяется: бесконечные анимации не крутятся вхолостую — при «Уменьшить движение»,
// под TickerMode(false), под закрывающим маршрутом и в фоне приложения кадры не запрашиваются;
// на живой сцене home-on таймер идёт раз в секунду простым текстом. Карточка №4 (владелец 30.10)
// без бесконечного движения: ни кольца точки, ни переката цифр.
// Образцы: test/m3e/gate8_motion_test.dart, test/m3e/live_timer_test.dart.

import 'dart:async';

import 'package:dropweb/ui/ios27/home/ios27_home_screen.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden.dart';
import 'support/home_harness.dart';

Future<void> _pump(
  WidgetTester tester,
  String scene, {
  bool reduce = false,
  bool tickers = true,
}) async {
  // Сеанс начат `12:49.3` назад: следующая граница секунды через 700 мс.
  final since = scene == 'home-on'
      ? tester.binding.clock.now().subtract(
            kHomeRunTime + const Duration(milliseconds: 300),
          )
      : null;
  await pumpIos27Board(
    tester,
    ios27BoardApp(
      brightness: Brightness.light,
      disableAnimations: reduce,
      child: TickerMode(
        enabled: tickers,
        child: ios27HomeFrame(
          input: homeInputFor(scene),
          since: since,
          now: tester.binding.clock.now,
          ipPending: scene == 'connecting',
        ),
      ),
    ),
  );
}

Future<void> _close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  group('покой', () {
    for (final scene in ['home-off', 'home-on', 'traffic-out', 'error']) {
      testWidgets('«Уменьшить движение»: $scene не просит кадров',
          (tester) async {
        try {
          await _pump(tester, scene, reduce: true);
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.binding.transientCallbackCount, 0, reason: scene);
          // Через несколько секунд тоже тихо (таймер — Timer, а не Ticker).
          await tester.pump(const Duration(seconds: 3));
          expect(tester.binding.transientCallbackCount, 0, reason: scene);
        } finally {
          await _close(tester);
        }
      });
    }

    for (final scene in ['home-off', 'traffic-out', 'error', 'offline']) {
      testWidgets('обычный режим: $scene после оседания не просит кадров',
          (tester) async {
        try {
          await _pump(tester, scene);
          await tester.pump(const Duration(seconds: 3));
          expect(tester.binding.transientCallbackCount, 0, reason: scene);
        } finally {
          await _close(tester);
        }
      });
    }

    testWidgets('TickerMode(false): home-on стоит, таймер не идёт',
        (tester) async {
      try {
        await _pump(tester, 'home-on', tickers: false);
        await tester.pump(const Duration(seconds: 3));
        expect(tester.binding.transientCallbackCount, 0);
        expect(find.text('12:49'), findsOneWidget);
      } finally {
        await _close(tester);
      }
    });

    testWidgets('TickerMode(false): connecting стоит (точка и индикатор)',
        (tester) async {
      try {
        await _pump(tester, 'connecting', tickers: false);
        await tester.pump(const Duration(seconds: 2));
        expect(tester.binding.transientCallbackCount, 0);
      } finally {
        await _close(tester);
      }
    });

    testWidgets('маршрут поверх главной останавливает секундный таймер под ним',
        (tester) async {
      try {
        await _pump(tester, 'home-on');
        await tester.pump(const Duration(milliseconds: 100));

        final context = tester.element(find.byType(Ios27HomeScreen));
        unawaited(Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold()),
        ));
        // Переход маршрута сам просит кадры; ждём его конца.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 3));
        expect(tester.binding.transientCallbackCount, 0);
        // Таймер под непрозрачным маршрутом стоит: строка не уходит вперёд.
        // Главная под маршрутом скрыта от поиска (Offstage), поэтому skipOffstage: false.
        final frozen = find.byKey(Ios27CardKeys.timer, skipOffstage: false);
        final before = (tester.widget(frozen) as Text).data;
        await tester.pump(const Duration(seconds: 5));
        expect((tester.widget(frozen) as Text).data, before);
      } finally {
        await _close(tester);
      }
    });
  });

  group('живая сцена home-on', () {
    testWidgets('таймер идёт раз в секунду простым текстом, кольца нет',
        (tester) async {
      try {
        await _pump(tester, 'home-on');
        expect(find.text('12:49'), findsOneWidget);
        expect(find.byKey(Ios27CardKeys.dot), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(Ios27CardKeys.dot),
            matching: find.byType(CustomPaint),
          ),
          findsNothing,
          reason: 'точка статична, кольца нет',
        );
        expect(tester.binding.transientCallbackCount, 0);

        // До границы секунды остаётся 700 мс: за 600 мс цифры стоят.
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('12:49'), findsOneWidget);
        // Тик на 705 мс: новая строка появляется сразу, без переката.
        await tester.pump(const Duration(milliseconds: 110));
        expect(find.text('12:50'), findsOneWidget);
        // Следующий тик на 1705 мс — ровно секундой позже.
        await tester.pump(const Duration(milliseconds: 1000));
        expect(find.text('12:51'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
      } finally {
        await _close(tester);
      }
    });

    testWidgets('«Уменьшить движение»: таймер идёт так же', (tester) async {
      try {
        await _pump(tester, 'home-on', reduce: true);
        await tester.pump(const Duration(milliseconds: 710));
        expect(find.text('12:50'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
      } finally {
        await _close(tester);
      }
    });

    testWidgets('в фоне приложения всё стоит, при возврате идёт',
        (tester) async {
      try {
        await _pump(tester, 'home-on');
        await tester.pump(const Duration(milliseconds: 100));

        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
          ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        expect(tester.binding.transientCallbackCount, 0);
        expect(find.text('12:49'), findsOneWidget);

        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump(const Duration(milliseconds: 100));
        // Время пересчитано по часам: прошло ≥ 3 с, строка не осталась на замороженной секунде.
        expect(find.text('12:49'), findsNothing);
        expect(find.textContaining('12:5'), findsOneWidget);
      } finally {
        await _close(tester);
      }
    });

    testWidgets('снятие экрана не оставляет таймеров и контроллеров',
        (tester) async {
      await _pump(tester, 'home-on');
      await tester.pump(const Duration(milliseconds: 300));
      await _close(tester);
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });
  });
}
