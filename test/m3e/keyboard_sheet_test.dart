// Лист «Добавить подписку» с открытой клавиатурой на телефоне владельца
// (Pixel 10, 411x914 dp, клавиатура ≈ 350 dp, крупный шрифт приложения 1.4).
// Баг: отступ под клавиатуру считался дважды (в маршруте листа и в самом виде),
// область содержимого схлопывалась до нуля, а над заголовком загоралась полоса
// «BOTTOM OVERFLOWED».
import 'dart:async';

import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/screens/m3e_add_subscription.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

const _homeKey = ValueKey<String>('home');
const _titleKey = ValueKey<String>('m3e.sheet.title');
const _pushKey = ValueKey<String>('push');

/// 350 dp клавиатуры при dpr 2.
const _keyboardPx = 700.0;
const _keyboardTop = 914 - 350.0;

List<Override> _overrides() => [
      m3eAddImportProvider.overrideWithValue((url) async {}),
      m3eAddScanProvider.overrideWithValue((context) async {}),
      accountLoginAvailableProvider.overrideWithValue(false),
    ];

Widget _app() => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: ColoredBox(
          key: _homeKey,
          color: M3eColors.of(context).home.bg,
          child: const SizedBox.expand(),
        ),
      ),
    );

Future<void> _pump(WidgetTester tester, double textScale) async {
  debugDisableShadows = true;
  // Масштаб задаётся окну, а не экрану: маршрут листа живёт в root-навигаторе
  // выше экрана и иначе не увидел бы крупный шрифт, как на телефоне владельца.
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final h = parseDropwebTheme(kBoardProviders[0].theme);
  await pumpM3eBoard(
    tester,
    m3eBoardApp(
      seed: h.accent,
      filter: h.filter,
      brightness: Brightness.light,
      overrides: _overrides(),
      child: _app(),
    ),
  );
}

Future<void> _settle(WidgetTester tester, [int ms = 600]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

BuildContext _ctx(WidgetTester tester) => tester.element(find.byKey(_homeKey));

Future<void> _openStandalone(WidgetTester tester) async {
  unawaited(showM3eAddSubscription(_ctx(tester)));
  await _settle(tester);
}

Future<void> _openInStack(WidgetTester tester) async {
  unawaited(
    showM3eSheet<void>(
      _ctx(tester),
      builder: (context) => M3eSheetStack(
        root: (context) => M3eSheetScaffold(
          title: 'Подписка',
          body: TextButton(
            key: _pushKey,
            onPressed: () => M3eSheetStack.of(context).push(
              (c) => const M3eAddSubscriptionView(),
            ),
            child: const Text('Добавить'),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  await tester.tap(find.byKey(_pushKey));
  await _settle(tester);
}

/// Поднимает клавиатуру и фокусирует поле ссылки, как делает пользователь.
Future<void> _typeWithKeyboard(WidgetTester tester) async {
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardPx);
  addTearDown(tester.view.resetViewInsets);
  await tester.tap(find.byKey(kM3eAddFieldInputKey));
  await _settle(tester, 400);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  tearDown(() => debugDisableShadows = true);

  for (final entry in <(String, Future<void> Function(WidgetTester))>[
    ('отдельный лист', _openStandalone),
    ('шаг в стеке листа', _openInStack),
  ]) {
    for (final scale in <double>[1.0, 1.4, 1.61, 2.0]) {
      testWidgets('${entry.$1}, шрифт ×$scale: клавиатура ничего не ломает',
          (tester) async {
        await _pump(tester, scale);
        await entry.$2(tester);
        await _typeWithKeyboard(tester);

        // Нет полосы «BOTTOM OVERFLOWED» и других исключений раскладки.
        expect(tester.takeException(), isNull);
        expect(find.byKey(_titleKey), findsOneWidget);

        // Область прокрутки не схлопнута и лежит над клавиатурой: прежний баг
        // оставлял в ней пару десятков dp (rect поля при этом не менялся).
        final viewport = tester.getRect(find.descendant(
          of: find.byKey(const ValueKey<String>('m3e.sheet')),
          matching: find.byType(SingleChildScrollView),
        ));
        expect(viewport.bottom, lessThanOrEqualTo(_keyboardTop));
        expect(viewport.height, greaterThanOrEqualTo(160),
            reason: 'область прокрутки схлопнулась: $viewport');

        // Поле в фокусе и целиком над клавиатурой.
        final field = tester.getRect(find.byKey(kM3eAddFieldInputKey));
        expect(field.height, greaterThan(0));
        expect(field.bottom, lessThanOrEqualTo(_keyboardTop),
            reason: 'поле перекрыто клавиатурой: $field');
        expect(field.top, greaterThan(0));

        // Вставка, QR и «Добавить» есть; при необходимости до них долистывают,
        // и после этого они тоже над клавиатурой.
        for (final key in [
          kM3eAddFieldPasteKey,
          kM3eAddQrKey,
          kM3eAddSubmitKey
        ]) {
          expect(find.byKey(key), findsOneWidget, reason: '$key не построен');
          await tester.ensureVisible(find.byKey(key));
          await tester.pump();
          final r = tester.getRect(find.byKey(key));
          expect(r.bottom, lessThanOrEqualTo(_keyboardTop),
              reason: '$key под клавиатурой: $r');
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('${entry.$1}, шрифт ×1.0: всё содержимое видно без прокрутки',
        (tester) async {
      await _pump(tester, 1);
      await entry.$2(tester);
      await _typeWithKeyboard(tester);
      expect(tester.takeException(), isNull);
      final viewport = tester.getRect(find.descendant(
        of: find.byKey(const ValueKey<String>('m3e.sheet')),
        matching: find.byType(SingleChildScrollView),
      ));
      for (final key in [
        kM3eAddFieldInputKey,
        kM3eAddQrKey,
        kM3eAddSubmitKey,
      ]) {
        final r = tester.getRect(find.byKey(key));
        expect(r.bottom, lessThanOrEqualTo(viewport.bottom),
            reason: '$key выходит из области прокрутки $viewport: $r');
      }
    });
  }
}
