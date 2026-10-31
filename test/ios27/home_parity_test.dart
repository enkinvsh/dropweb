// G4: рамки элементов экрана главной против `layout.json` доски (±4 dp) на каждой сцене и теме.
//
// Таблица всех отклонений пишется в `IOS27_PARITY_TABLE`, если переменная задана
// (`.omo/ios/parity.md`); сам допуск проверяется всегда.

import 'package:dropweb/ui/ios27/home/ios27_home_screen.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/home_harness.dart';
import 'support/layout.dart';

Finder _byKey(ValueKey<String> k) => find.byKey(k);

/// Имена `layout.json` → искатели. Внутренности карточки сюда не входят: с 30.10 она собрана
/// по hig-cards №4, и её рамки сверяет `card_v4_parity_test.dart` с доской карточек.
Map<String, Finder> parityElements() => {
      'settings': _byKey(Ios27HomeKeys.settings),
      'dock': _byKey(Ios27HomeKeys.dock),
      'dock-sub': _byKey(Ios27HomeKeys.dockSub),
      'power': _byKey(Ios27HomeKeys.power),
      'dock-route': _byKey(Ios27HomeKeys.dockRoute),
    };

/// Положение карточки на главной: левый край, верх и ширина держат доску, высота у №4 своя.
void _expectCardAnchor(WidgetTester tester, String refKey) {
  final ref = Ios27RefLayout.load(refKey).rects['card']!.first;
  final got = tester.getRect(find.byKey(Ios27CardKeys.card));
  expect(got.left, closeTo(ref.left, 4), reason: 'card.left');
  expect(got.top, closeTo(ref.top, 4), reason: 'card.top');
  expect(got.width, closeTo(ref.width, 4), reason: 'card.width');
}

void main() {
  for (final scene in kIos27HomeScenes) {
    for (final brightness in Brightness.values) {
      final mode = brightness.name;
      testWidgets('рамки: $scene / $mode', (tester) async {
        try {
          // Рамки не зависят от фона: прогрев пропускаем, это экономит секунды на сцену.
          await pumpHomeScene(
            tester,
            scene,
            brightness: brightness,
            withBackdrop: false,
          );
          expect(tester.takeException(), isNull);
          expectIos27Parity(
            ios27Parity(tester, '$scene-$mode-rt-p0', parityElements()),
          );
          _expectCardAnchor(tester, '$scene-$mode-rt-p0');
        } finally {
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }

  // Сцена support = home-off + тост: рамки главной те же, тост сверяет его собственный тест.
  testWidgets('рамки: support / light (главная под тостом)', (tester) async {
    try {
      await pumpHomeScene(tester, 'home-off', withBackdrop: false);
      expectIos27Parity(
        ios27Parity(tester, 'support-light-rt-p0', parityElements()),
      );
      _expectCardAnchor(tester, 'support-light-rt-p0');
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });
}
