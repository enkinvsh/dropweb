// «Добавить подписку» iOS: худшие данные × масштаб шрифта × iPhone и клавиатура 336 dp на обоих входах.
//
// Урок 26 (Android abf5d919): клавиатуру нельзя считать дважды, листом и телом. Здесь настоящие
// `viewInsets.bottom = 336` и textScale 2.0; поле и «Добавить» целиком над клавиатурой.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_add_support.dart';
import 'support/surface.dart';

/// Длинная строка без пробелов и без схемы: поле не ужимается, а отправка даёт ошибку.
final String _longUrl = 'subscription.example-provider.com/s/${'a1b2c3' * 30}';

const _frameKey = ValueKey<String>('ios27.sheet.frame');

void main() {
  for (final entry in AddEntry.values) {
    for (final device in kIos27Iphones) {
      for (final scale in [0.8, 1.0, 1.4, 2.0]) {
        testWidgets('худший случай: ${entry.name} / ${device.name} / ×$scale',
            (tester) async {
          // Ошибка тоже в кадре: самая длинная раскладка формы.
          await pumpAdd(
            tester,
            entry,
            device: device,
            textScale: scale,
            initialUrl: entry == AddEntry.sheet ? _longUrl : null,
          );
          if (entry == AddEntry.step) {
            await tester.enterText(
                find.descendant(
                    of: find.byKey(addFieldInput),
                    matching: find.byType(TextField)),
                _longUrl);
          }
          await tester.tap(find.byKey(addButton), warnIfMissed: false);
          await settleAdd(tester);
          expect(tester.takeException(), isNull);
          expect(find.byKey(addFieldInput), findsOneWidget);
        });
      }
    }
  }

  for (final entry in AddEntry.values) {
    for (final device in kIos27Iphones) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('клавиатура 336: ${entry.name} / ${device.name} / ×$scale',
            (tester) async {
          await pumpAdd(
            tester,
            entry,
            device: device,
            textScale: scale,
            disableAnimations: false,
          );
          showKeyboard(tester, device);
          await tester.tap(find.byKey(addFieldInput));
          await settleAdd(tester, 400);
          await tester.enterText(
              find.descendant(
                of: find.byKey(addFieldInput),
                matching: find.byType(TextField),
              ),
              'https://dropweb.site/s/7f3a9c2e');
          await settleAdd(tester, 400);
          expect(tester.takeException(), isNull,
              reason: 'нет переполнения (BOTTOM OVERFLOWED)');

          final keyboardTop = device.size.height - kAddKeyboard;
          final frame = rectOf(tester, find.byKey(_frameKey));
          // Лист стоит на 8 выше клавиатуры ровно один раз.
          expect(frame.bottom, closeTo(keyboardTop - 8, 0.01));

          final field = rectOf(tester, find.byKey(addFieldInput));
          final button = rectOf(tester, find.byKey(addButton));
          // Поле целиком ниже шапки (64 + 4) и выше кнопки.
          expect(field.top, greaterThanOrEqualTo(frame.top + 68 - 0.5),
              reason: 'поле не уехало под шапку: $field');
          expect(field.bottom, lessThanOrEqualTo(button.top),
              reason: 'поле не перекрыто кнопкой: $field / $button');
          // Кнопка целиком в листе, над клавиатурой.
          expect(button.bottom, lessThanOrEqualTo(frame.bottom));
          expect(button.bottom, lessThanOrEqualTo(keyboardTop));
          expect(button.height, greaterThanOrEqualTo(50));
          // Потомки не получают viewInsets второй раз.
          final inner =
              MediaQuery.of(tester.element(find.byKey(addFieldInput)));
          expect(inner.viewInsets.bottom, 0);
        });
      }
    }
  }
}
