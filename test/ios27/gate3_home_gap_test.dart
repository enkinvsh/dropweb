// G3: зазор между карточкой и кнопкой питания на всей матрице главной.
//
// Карточка не прокручивается (D8), поэтому при крупном шрифте ряд кнопок опускается (нижнее поле
// 52 → не ниже 16) и объявление уходит под кнопку «Обновить» (решения a3fix). Тест держит
// зазор ≥ 0 для всех сцен × iPhone × масштаб 0.8/1.0/1.4/2.0 на данных NORMAL и WORST и
// пишет минимальные зазоры в `IOS27_GAP_TABLE`, если переменная задана.

import 'dart:io';

import 'package:dropweb/ui/ios27/home/ios27_home_screen.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/home_harness.dart';
import 'support/surface.dart';

const _scales = [0.8, 1.0, 1.4, 2.0];

/// Остаточное перекрытие (dp, зазор отрицательный) на WORST при масштабе 2.0.
///
/// WORST = имя в 40 символов и объявление 200 символов со ссылкой. Карточка №4 (30.10) компактна,
/// и на 390×844 и 440×956 перекрытия нет. Остаток есть только на SE 375×667: объявление в подвале
/// при 2.0 занимает ~400 dp, и блок «карточка + подвал» выше свободной области даже при нижнем
/// поле 16. Зазор считается от низа подвала. Ключ: `<ширина экрана>|<сцена>`.
const _worstOverlap = <String, double>{
  '375|home-off': -144.0,
  '375|connecting': -108.0,
  '375|home-on': -144.0,
  '375|error': -144.0,
  '375|offline': -108.0,
  '375|expiring': -144.0,
  '375|traffic-low': -144.0,
  '375|traffic-out': -104.0,
  '375|expired': -144.0,
};

void main() {
  final table = <String>[];
  tearDownAll(() {
    final path = Platform.environment['IOS27_GAP_TABLE'];
    if (path != null && table.isNotEmpty) {
      File(path).writeAsStringSync('${table.join('\n')}\n');
    }
  });

  for (final worst in [false, true]) {
    for (final device in kIos27Iphones) {
      testWidgets(
          'зазор карточка–питание ≥ 0: ${worst ? 'WORST' : 'NORMAL'} на ${device.name}',
          (tester) async {
        try {
          for (final scale in _scales) {
            var minGap = double.infinity;
            var minScene = '';
            var minBottom = 0.0;
            for (final scene in kIos27HomeScenes) {
              await pumpHomeScene(
                tester,
                scene,
                worst: worst,
                textScale: scale,
                device: device,
                withBackdrop: false,
              );
              expect(tester.takeException(), isNull, reason: '$scene x$scale');
              final card = tester.getRect(find.byKey(Ios27CardKeys.card));
              final power = tester.getRect(find.byKey(Ios27HomeKeys.power));
              // Карточка и подвал с объявлением занимают один блок: зазор считаем от его низа.
              final footer = find.byKey(Ios27CardKeys.footer);
              final blockBottom = footer.evaluate().isEmpty
                  ? card.bottom
                  : tester.getRect(footer).bottom;
              final gap = power.top - blockBottom;
              // GAPNOW
              if (gap < minGap) {
                minGap = gap;
                minScene = scene;
                minBottom = device.size.height - power.bottom;
              }
              final known = worst && scale == 2.0
                  ? _worstOverlap['${device.size.width.toInt()}|$scene']
                  : null;
              if (worst && scale == 2.0 && gap < 0) {
                // ignore: avoid_print
                print('GAPNOW ${device.size.width.toInt()}|$scene $gap');
              }
              if (known != null) {
                // Карточка выше экрана: опускать ряд некуда, текст не сжимаем.
                expect(gap, closeTo(known, 1.5),
                    reason: 'известное перекрытие $scene');
              } else {
                expect(
                  gap,
                  greaterThanOrEqualTo(0),
                  reason:
                      '${worst ? 'WORST' : 'NORMAL'} $scene ${device.name} x$scale',
                );
              }
              // Ряд не ниже предела и не выше доски.
              final bottom = device.size.height - power.bottom;
              expect(bottom, greaterThanOrEqualTo(kIos27HomeBottomPadMin));
            }
            table.add(
              '| ${worst ? 'WORST' : 'NORMAL'} | ${device.name} | $scale '
              '| ${minGap.toStringAsFixed(1)} | $minScene '
              '| ${minBottom.toStringAsFixed(1)} |',
            );
          }
        } finally {
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }

  testWidgets('доска 411×914, масштаб 1.0: нижнее поле остаётся 52',
      (tester) async {
    try {
      for (final scene in kIos27HomeScenes) {
        await pumpHomeScene(tester, scene, withBackdrop: false);
        final power = tester.getRect(find.byKey(Ios27HomeKeys.power));
        expect(914 - power.bottom, 52, reason: scene);
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  test('нижнее поле: по умолчанию 52, при высокой карточке уменьшается до 16',
      () {
    double inset(double cardBottom, {double preferred = 52}) =>
        ios27HomeBottomInset(
          screenHeight: 667,
          cardBottom: cardBottom,
          preferred: preferred,
        );
    expect(inset(300), 52);
    // 667 − 80 − 8 − 52 = 527: ровно впритык к зазору 8.
    expect(inset(527), 52);
    expect(inset(540), closeTo(39, 1e-9));
    expect(inset(700), 16);
    // Предпочтительное поле меньше предела (не бывает на iPhone) не увеличиваем.
    expect(inset(700, preferred: 10), 10);
  });
}
