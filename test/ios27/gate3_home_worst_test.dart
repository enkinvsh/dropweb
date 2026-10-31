// G3: худшие данные доски (WORST) на экране главной при масштабе шрифта 0.8–2.0 и трёх iPhone.
//
// Что проверяется: нет исключений переполнения, карточка растёт вместе с текстом (D8) и не
// прокручивается, кнопки нижнего ряда остаются на своих местах и на экране.

import 'package:dropweb/ui/ios27/home/ios27_home_screen.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/home_harness.dart';
import 'support/surface.dart';

const _scales = [0.8, 1.0, 1.4, 2.0];

// Сцены с самым длинным содержимым: имя в одну строку с таймером, IPv6, шкала и «Обновить».
const _scenes = ['home-on', 'traffic-low', 'traffic-out', 'error', 'offline'];

Rect _rect(WidgetTester tester, Finder f) => tester.getRect(f);

void main() {
  for (final device in kIos27Iphones) {
    for (final scene in _scenes) {
      testWidgets('WORST: $scene на ${device.name}', (tester) async {
        final heights = <double, double>{};
        try {
          for (final scale in _scales) {
            for (final brightness in Brightness.values) {
              await pumpHomeScene(
                tester,
                scene,
                brightness: brightness,
                worst: true,
                textScale: scale,
                device: device,
                withBackdrop: false,
              );
              expect(
                tester.takeException(),
                isNull,
                reason: '$scene ${device.name} x$scale ${brightness.name}',
              );
              final card = _rect(tester, find.byKey(Ios27CardKeys.card));
              expect(card.left, 16);
              expect(card.width, device.size.width - 32);
              expect(
                card.top,
                closeTo(device.padding.top + kIos27HomeCardTop, 0.01),
              );
              // Карточка не прокручивается (D8).
              expect(
                find.descendant(
                  of: find.byKey(Ios27CardKeys.card),
                  matching: find.byType(Scrollable),
                ),
                findsNothing,
              );
              // Нижний ряд на месте и целиком на экране.
              final power = _rect(tester, find.byKey(Ios27HomeKeys.power));
              expect(power.size, const Size(80, 80));
              expect(power.bottom, lessThanOrEqualTo(device.size.height));
              expect(power.center.dx, closeTo(device.size.width / 2, 0.01));
              if (brightness == Brightness.light) {
                heights[scale] = card.height;
              }
            }
          }
          // D8: карточка растёт вместе с текстом, а не режется.
          expect(heights[1.4], greaterThan(heights[1.0]!), reason: scene);
          expect(heights[2.0], greaterThan(heights[1.4]!), reason: scene);
          expect(heights[0.8], lessThanOrEqualTo(heights[1.0]!), reason: scene);
        } finally {
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }
}
