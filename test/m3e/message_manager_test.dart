import 'dart:async';

import 'package:dropweb/common/context.dart';
import 'package:dropweb/manager/message_manager.dart';
import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/symbols.g.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_source.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_symbol.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

const _toastKey = ValueKey<String>('m3e.toast');
const _fadeKey = ValueKey<String>('m3e.toast.fade');
const _motionKey = ValueKey<String>('m3e.toast.motion');

/// Менеджер стоит так же, как в `lib/application.dart`: внутри `MaterialApp`, над
/// содержимым, с `ProviderScope` выше (его даёт `m3eBoardApp`).
Future<MessageManagerState> _pump(
  WidgetTester tester, {
  bool useM3e = true,
  bool reduceMotion = false,
  Widget content = const SizedBox.expand(),
}) async {
  final h = parseDropwebTheme(kBoardProviders[0].theme);
  final manager = MessageManager(
    useM3e: useM3e,
    child: content,
  );
  // MediaQuery с отключёнными анимациями стоит выше менеджера, как у системной настройки.
  final child = reduceMotion
      ? Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: manager,
          ),
        )
      : manager;
  await pumpM3eBoard(
    tester,
    m3eBoardApp(
      seed: h.accent,
      filter: h.filter,
      brightness: Brightness.light,
      // В приложении источник темы читает настройки из globalState; в тесте его нет.
      overrides: [
        m3eThemeSourceProvider.overrideWithValue(
          M3eThemeSource(seed: h.accent, filter: h.filter),
        ),
      ],
      child: child,
    ),
  );
  return tester.state<MessageManagerState>(find.byType(MessageManager));
}

void main() {
  setUp(() => debugDisableShadows = true);

  double top(WidgetTester tester) => tester.getRect(find.byKey(_toastKey)).top;

  group('путь M3E', () {
    testWidgets(
        'показывает плашку на линии кнопки настроек, уходит через 2200+200 мс',
        (tester) async {
      final manager = await _pump(tester);
      expect(find.byKey(_toastKey), findsNothing);

      unawaited(manager.message('А'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(_toastKey), findsOneWidget);
      expect(find.text('А'), findsOneWidget);
      expect(top(tester), closeTo(44 + kM3eToastTopGap, 0.5));

      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.byKey(_toastKey), findsOneWidget);
      // Вошла на 0, держится 2200 мс; уход ещё 200.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(_toastKey), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'два сообщения подряд: второе не раньше чем через 1 с и заменяет',
        (tester) async {
      final manager = await _pump(tester);
      unawaited(manager.message('первое'));
      unawaited(manager.message('второе'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('первое'), findsOneWidget);
      expect(find.text('второе'), findsNothing);

      await tester.pump(const Duration(milliseconds: 400));
      // 900 мс после показа первого.
      expect(find.text('первое'), findsOneWidget);
      expect(find.text('второе'), findsNothing);

      await tester.pump(const Duration(milliseconds: 150));
      // 1050 мс: пауза прошла, второе заменило первое.
      expect(find.text('первое'), findsNothing);
      expect(find.text('второе'), findsOneWidget);

      // Второе держится свои 2200 мс от своего показа и уходит; новых таймеров нет.
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(_toastKey), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('сообщение после паузы в 1 с заменяет показанное сразу',
        (tester) async {
      final manager = await _pump(tester);
      unawaited(manager.message('первое'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      unawaited(manager.message('второе'));
      await tester.pump();
      expect(find.text('первое'), findsNothing);
      expect(find.text('второе'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2700));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(_toastKey), findsNothing);
    });

    testWidgets('kind: alert — значок есть; без kind — значка нет',
        (tester) async {
      final manager = await _pump(tester);
      unawaited(manager.message('ошибка', kind: M3eToastKind.alert));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.descendant(
          of: find.byKey(_toastKey),
          matching: find.byType(M3eSymbolIcon),
        ),
        findsOneWidget,
      );

      // Заменяем после паузы в 1 с обычным сообщением без типа.
      await tester.pump(const Duration(milliseconds: 600));
      unawaited(manager.message('просто текст'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('просто текст'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_toastKey),
          matching: find.byType(M3eSymbolIcon),
        ),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 2700));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(_toastKey), findsNothing);
    });

    testWidgets('при отключённых анимациях только прозрачность',
        (tester) async {
      final manager = await _pump(tester, reduceMotion: true);
      unawaited(manager.message('А'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      final opacity = tester.widget<Opacity>(find.byKey(_fadeKey)).opacity;
      expect(opacity, closeTo(0.5, 0.01));
      expect(find.byKey(_motionKey), findsNothing);
      expect(top(tester), closeTo(44 + kM3eToastTopGap, 0.01));

      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(_toastKey), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets(
        'после ухода нет тикеров и таймеров; после dispose сообщение не падает',
        (tester) async {
      final manager = await _pump(tester);
      unawaited(manager.message('А'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(_toastKey), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);

      // Сообщение и сразу снятие дерева: таймер паузы и держания обязаны сняться.
      unawaited(manager.message('Б'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      unawaited(manager.message('В'));
      // Тест завершится без «A Timer is still pending», если ничего не осталось.
    });
  });

  testWidgets('снятие менеджера, ни разу не показавшего сообщение, не падает',
      (tester) async {
    await _pump(tester);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  group('тип через context.showNotifier', () {
    // Старый код зовёт `context.showNotifier(text, kind: …)`: тип обязан дойти до плашки.
    Future<void> shown(
      WidgetTester tester,
      M3eToastKind? kind,
    ) async {
      late BuildContext inner;
      await _pump(
        tester,
        content: Builder(
          builder: (context) {
            inner = context;
            return const SizedBox.expand();
          },
        ),
      );
      unawaited(inner.showNotifier('текст', kind: kind));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    M3eSymbol? symbolOf(WidgetTester tester) {
      final icons = find.descendant(
        of: find.byKey(_toastKey),
        matching: find.byType(M3eSymbolIcon),
      );
      return icons.evaluate().isEmpty
          ? null
          : tester.widget<M3eSymbolIcon>(icons).symbol;
    }

    for (final (kind, symbol) in [
      (M3eToastKind.check, M3eToastKind.check.symbol),
      (M3eToastKind.alert, M3eToastKind.alert.symbol),
      (null, null),
    ]) {
      testWidgets('kind: ${kind?.name ?? 'нет'}', (tester) async {
        await shown(tester, kind);
        expect(find.text('текст'), findsOneWidget);
        expect(symbolOf(tester), symbol);
        await tester.pump(const Duration(milliseconds: 2700));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byKey(_toastKey), findsNothing);
      });
    }
  });

  group('старый путь', () {
    testWidgets('useM3e: false рисует _LiquidToast, а не плашку M3E',
        (tester) async {
      final manager = await _pump(tester, useM3e: false);
      unawaited(manager.message('А'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(_toastKey), findsNothing);
      expect(find.text('А'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_LiquidToast',
        ),
        findsOneWidget,
      );
      // Старый путь живёт на своих задержках (1 с + 3 с); дожимаем до конца.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
