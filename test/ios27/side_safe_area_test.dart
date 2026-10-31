// Боковые safe area iPhone Duo: колонка Dynamic Island и строки состояния вдоль торцевого края.
//
// HIG «Designing for iPhone Duo»: система уводит их в вертикальную колонку, и она приходит как
// `MediaQuery.padding.left/right`. Содержимое обязано стоять внутри: иначе колонка закрывает
// шестерёнку, конец текста карточки, кнопку «закрыть» листа. Каждая проверка кладёт отступ
// справа (торцевая колонка у правого края) и слева (зеркально, обратная альбомная ориентация).

import 'dart:async';

import 'package:dropweb/ui/ios27/home/ios27_empty_home.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_screen.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card.dart';
import 'package:dropweb/ui/ios27/layers/ios27_alert.dart';
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/layers/ios27_toast.dart';
import 'package:dropweb/ui/ios27/pages/ios27_page.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden.dart';
import 'support/home_harness.dart';
import 'support/layer_harness.dart';
import 'support/surface.dart';

/// Ширина колонки, dp: порядок величины, который Duo отдаёт под Dynamic Island и строку состояния.
const double _inset = 75;

const _scales = [1.0, 2.0];

/// iPhone 12–14 с боковой колонкой справа.
const Ios27Device _duoRight = Ios27Device(
  name: 'duo-right-75',
  size: Size(390, 844),
  dpr: 3,
  padding: EdgeInsets.only(top: 0, right: _inset),
);

/// То же зеркально: колонка слева.
const Ios27Device _duoLeft = Ios27Device(
  name: 'duo-left-75',
  size: Size(390, 844),
  dpr: 3,
  padding: EdgeInsets.only(top: 0, left: _inset),
);

const _devices = [_duoRight, _duoLeft];

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder);

/// [r] целиком лежит между боковыми отступами [device].
void _expectBetweenInsets(Rect r, Ios27Device device, String what) {
  final left = device.padding.left;
  final right = device.size.width - device.padding.right;
  expect(
    r.left,
    greaterThanOrEqualTo(left - 0.01),
    reason: '$what (${device.name}): левый край $r заходит за отступ $left',
  );
  expect(
    r.right,
    lessThanOrEqualTo(right + 0.01),
    reason: '$what (${device.name}): правый край $r заходит за отступ $right',
  );
}

/// Контекст корневого навигатора: выше любой области темы.
BuildContext _root(WidgetTester tester) =>
    tester.element(find.byType(Navigator).first);

Widget _layerApp(
  Ios27Device device,
  double textScale, {
  Widget? child,
}) =>
    ios27BoardApp(
      brightness: Brightness.light,
      textScale: textScale,
      device: device,
      overrides: layerOverrides(),
      child: child ??
          Builder(
            builder: (context) =>
                ColoredBox(color: ios27ColorsFor(context).palette.bg),
          ),
    );

void main() {
  group('главная', () {
    for (final device in _devices) {
      for (final scale in _scales) {
        for (final worst in [false, true]) {
          testWidgets(
              'шестерёнка, карточка, подвал и нижний ряд внутри отступов: '
              '${device.name}, x$scale${worst ? ', WORST' : ''}',
              (tester) async {
            await pumpHomeScene(
              tester,
              'home-on',
              device: device,
              textScale: scale,
              worst: worst,
              withBackdrop: false,
            );
            expect(tester.takeException(), isNull);

            final left = device.padding.left + kIos27HomeSidePad;
            final right =
                device.size.width - device.padding.right - kIos27HomeSidePad;

            final gear = _rect(tester, find.byKey(Ios27HomeKeys.settings));
            _expectBetweenInsets(gear, device, 'шестерёнка');
            expect(gear.right, closeTo(right, 0.01));

            // Карточка занимает всю область между отступами с полем 16 с каждой стороны.
            final card = _rect(tester, find.byKey(Ios27CardKeys.card));
            _expectBetweenInsets(card, device, 'карточка');
            expect(card.left, closeTo(left, 0.01));
            expect(card.right, closeTo(right, 0.01));

            final footer = find.byType(Ios27CardFooter);
            expect(footer, findsOneWidget);
            _expectBetweenInsets(_rect(tester, footer), device, 'подвал');

            final dock = _rect(tester, find.byKey(Ios27HomeKeys.dock));
            _expectBetweenInsets(dock, device, 'нижний ряд');
            expect(dock.left, closeTo(left, 0.01));
            expect(dock.right, closeTo(right, 0.01));
            for (final key in [
              Ios27HomeKeys.dockSub,
              Ios27HomeKeys.power,
              Ios27HomeKeys.dockRoute,
            ]) {
              _expectBetweenInsets(
                _rect(tester, find.byKey(key)),
                device,
                'кнопка $key',
              );
            }
          });
        }
      }
    }
  });

  group('пустая главная', () {
    for (final device in _devices) {
      for (final scale in _scales) {
        testWidgets(
            'шестерёнка и блок действий внутри отступов: '
            '${device.name}, x$scale', (tester) async {
          await pumpIos27Board(
            tester,
            ios27BoardApp(
              brightness: Brightness.light,
              disableAnimations: true,
              textScale: scale,
              device: device,
              child: Ios27EmptyView(
                onSettings: () {},
                onPaste: () {},
                onScan: () {},
              ),
            ),
            device: device,
          );
          expect(tester.takeException(), isNull);

          final gear = _rect(tester, find.byKey(Ios27HomeKeys.settings));
          _expectBetweenInsets(gear, device, 'шестерёнка');
          expect(
            gear.right,
            closeTo(
              device.size.width - device.padding.right - kIos27HomeSidePad,
              0.01,
            ),
          );
          for (final key in [
            Ios27EmptyKeys.icon,
            Ios27EmptyKeys.title,
            Ios27EmptyKeys.paste,
            Ios27EmptyKeys.scan,
          ]) {
            _expectBetweenInsets(
              _rect(tester, find.byKey(key)),
              device,
              'элемент $key',
            );
          }
        });
      }
    }
  });

  group('лист', () {
    for (final device in _devices) {
      for (final scale in _scales) {
        testWidgets(
            'стекло, шапка и кнопка «закрыть» внутри отступов: '
            '${device.name}, x$scale', (tester) async {
          await pumpIos27Board(
            tester,
            _layerApp(device, scale),
            device: device,
          );
          unawaited(showIos27Sheet<void>(
            _root(tester),
            title: 'Маршрут',
            builder: (_) => const SizedBox.expand(),
          ));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);

          final frame = _rect(
            tester,
            find.byKey(const ValueKey<String>('ios27.sheet.frame')),
          );
          _expectBetweenInsets(frame, device, 'стекло листа');
          // Поле листа от торцевого края: 8 плюс отступ.
          expect(frame.left, closeTo(device.padding.left + 8, 0.01));
          expect(
            frame.right,
            closeTo(device.size.width - device.padding.right - 8, 0.01),
          );
          _expectBetweenInsets(
            _rect(tester,
                find.byKey(const ValueKey<String>('ios27.sheet.close'))),
            device,
            'кнопка «закрыть»',
          );
          _expectBetweenInsets(
            _rect(tester,
                find.byKey(const ValueKey<String>('ios27.sheet.title'))),
            device,
            'заголовок листа',
          );
        });
      }
    }
  });

  group('алерт', () {
    for (final device in _devices) {
      for (final scale in _scales) {
        testWidgets(
            'карточка по центру между отступами: ${device.name}, x$scale',
            (tester) async {
          await pumpIos27Board(
            tester,
            _layerApp(device, scale),
            device: device,
          );
          unawaited(showIos27Alert<bool>(
            _root(tester),
            builder: (context) => Center(
              child: Ios27Alert(
                title: 'Удалить «DROPWEB»?',
                body: const Text('Оплаченная подписка у провайдера останется.'),
                actions: [
                  Ios27AlertButton(label: 'Отмена', onPressed: () {}),
                  Ios27AlertButton(
                    label: 'Удалить',
                    destructive: true,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);

          final alert = _rect(tester, find.byType(Ios27Alert));
          _expectBetweenInsets(alert, device, 'алерт');
          final middle =
              (device.padding.left + device.size.width - device.padding.right) /
                  2;
          expect(alert.center.dx, closeTo(middle, 0.5));
        });
      }
    }
  });

  group('тост', () {
    for (final device in _devices) {
      for (final scale in _scales) {
        testWidgets(
            'плашка не заходит за отступ и не задевает шестерёнку: '
            '${device.name}, x$scale', (tester) async {
          await pumpIos27Board(
            tester,
            ios27BoardApp(
              brightness: Brightness.light,
              textScale: scale,
              device: device,
              child: const Stack(
                children: [
                  Positioned.fill(
                    child: Ios27ToastPresenter(
                      message: M3eToastMessage(
                        kind: M3eToastKind.alert,
                        text: 'Очень длинное сообщение об ошибке, которое не '
                            'помещается в две строки тоста и обрезается '
                            'многоточием в конце',
                      ),
                      hold: null,
                    ),
                  ),
                ],
              ),
            ),
            device: device,
          );
          await tester.pump(const Duration(seconds: 2));
          expect(tester.takeException(), isNull);

          final toast =
              _rect(tester, find.byKey(const ValueKey<String>('ios27.toast')));
          _expectBetweenInsets(toast, device, 'тост');
          // Слева и справа от плашки остаётся место под кнопки панели: 16 + 44 + 8.
          expect(
            toast.left,
            greaterThanOrEqualTo(
              device.padding.left + kIos27ToastSideInset - 0.01,
            ),
          );
          expect(
            toast.right,
            lessThanOrEqualTo(
              device.size.width -
                  device.padding.right -
                  kIos27ToastSideInset +
                  0.01,
            ),
          );
        });
      }
    }
  });

  group('страница', () {
    for (final device in _devices) {
      for (final scale in _scales) {
        testWidgets(
            'кнопки панели, заголовок и список внутри отступов: '
            '${device.name}, x$scale', (tester) async {
          await pumpIos27Board(
            tester,
            ios27BoardApp(
              brightness: Brightness.light,
              disableAnimations: true,
              textScale: scale,
              device: device,
              child: const Ios27Page(
                title: 'Настройки',
                trailing: SizedBox.square(
                  key: ValueKey<String>('trailing'),
                  dimension: 44,
                ),
                child: Ios27List(children: [
                  Ios27ListRow(title: 'Язык', detail: 'Как в системе'),
                  Ios27ListRow(title: 'Оформление', detail: 'Провайдер'),
                ]),
              ),
            ),
            device: device,
          );
          expect(tester.takeException(), isNull);

          for (final key in const [
            ValueKey<String>('page.back'),
            ValueKey<String>('trailing'),
            ValueKey<String>('page.title'),
            ValueKey<String>('page.small'),
          ]) {
            _expectBetweenInsets(
              _rect(tester, find.byKey(key)),
              device,
              'элемент ${key.value}',
            );
          }
          _expectBetweenInsets(
            _rect(tester, find.byType(Ios27List)),
            device,
            'список',
          );
        });
      }
    }
  });
}
