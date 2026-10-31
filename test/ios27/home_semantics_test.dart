// Идентификаторы для автотестов через adb (`docs/adb-remote.md`, раздел uiautomator):
// `Semantics(identifier:)` попадает в `resource-id` дампа uiautomator, поэтому их потеря ломает
// внешние сценарии. Плюс подписи VoiceOver главной (inventory.md, app.js:547-561).

import 'dart:ui' show Tristate;

import 'package:dropweb/ui/ios27/home/ios27_empty_home.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_screen.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden.dart';
import 'support/home_harness.dart';

/// Главная с нажимаемыми кнопками: без колбэков узлы остаются «выключенными».
Future<void> _pump(WidgetTester tester, String scene) => pumpIos27Board(
      tester,
      ios27BoardApp(
        brightness: Brightness.light,
        disableAnimations: true,
        child: ios27HomeFrame(
          input: homeInputFor(scene),
          now: tester.binding.clock.now,
          ipPending: scene == 'connecting',
          onToggle: () {},
          onSettings: () {},
          onSubscriptions: () {},
          onRoute: () {},
          onRefresh: () {},
        ),
      ),
    );

SemanticsNode _node(WidgetTester tester, String id) =>
    tester.getSemantics(find.bySemanticsIdentifier(id));

void main() {
  testWidgets('главная: dw_connect и dw_exit с меткой и нажимаемостью',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await _pump(tester, 'home-off');
      expect(find.bySemanticsIdentifier('dw_connect'), findsOneWidget);
      expect(find.bySemanticsIdentifier('dw_exit'), findsOneWidget);

      final power = _node(tester, 'dw_connect');
      expect(power.label, 'Подключить VPN');
      expect(power.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      // Узел кнопки, а не объемлющий ряд.
      expect(power.rect.width, lessThan(100));

      final exit = _node(tester, 'dw_exit');
      expect(exit.label, startsWith('Маршрут: '));
      expect(exit.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(exit.rect.width, lessThan(100));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('метка питания следует состоянию (app.js:547)', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      const labels = {
        'home-off': 'Подключить VPN',
        'home-on': 'Отключить VPN',
        'connecting': 'Отменить подключение',
        'error': 'Повторить подключение',
        'offline': 'Подключить VPN',
      };
      for (final MapEntry(key: scene, value: label) in labels.entries) {
        await _pump(tester, scene);
        expect(_node(tester, 'dw_connect').label, label, reason: scene);
      }
    } finally {
      handle.dispose();
    }
  });

  testWidgets('home-on: питание отмечено включённым', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await _pump(tester, 'home-on');
      final data = _node(tester, 'dw_connect').getSemanticsData();
      expect(data.flagsCollection.isToggled, Tristate.isTrue);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('карточка, шестерёнка и левая кнопка подписаны', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await _pump(tester, 'home-off');
      expect(find.bySemanticsLabel('Настройки'), findsOneWidget);
      expect(find.bySemanticsLabel('Подписка'), findsOneWidget);
      expect(find.bySemanticsLabel('Подключение и страна'), findsOneWidget);
      // Карточка — группа, а не кнопка: нажимаемы только настоящие кнопки внутри.
      final card = tester.getSemantics(find.byKey(Ios27CardKeys.card));
      expect(card.getSemanticsData().flagsCollection.isButton, isFalse);
      // Одна фраза: имя, план, страна и статус; IP нигде нет (карточка №4, 30.10).
      expect(card.label, startsWith('DROPWEB'));
      expect(card.label, contains('Страна: '));
      expect(card.label, contains('Не подключено'));
      expect(card.label, isNot(matches(RegExp(r'\d+\.\d+\.\d+'))));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('закончилась подписка: «Обновить» доступна для VoiceOver',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await _pump(tester, 'expired');
      final refresh = tester.getSemantics(find.bySemanticsLabel('Обновить'));
      expect(refresh.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(refresh.getSemanticsData().flagsCollection.isButton, isTrue);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('пустая главная: кнопки и шестерёнка подписаны', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          child: Ios27EmptyView(
            onSettings: () {},
            onPaste: () {},
            onScan: () {},
          ),
        ),
      );
      expect(find.bySemanticsLabel('Вставить ссылку'), findsWidgets);
      expect(find.bySemanticsLabel('Сканировать QR-код'), findsWidgets);
      expect(find.bySemanticsLabel('Настройки'), findsWidgets);
      expect(find.byKey(Ios27HomeKeys.settings), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });
}
