// Алерт iOS-редизайна: открытие корневым контекстом, dismissible, клавиатура, движение, golden.

import 'dart:async';

import 'package:dropweb/ui/ios27/layers/ios27_alert.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/widgets/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden.dart';
import 'support/layer_harness.dart';
import 'support/layout.dart';
import 'support/surface.dart';

Widget _app({
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  double textScale = 1.0,
  Ios27Device device = kIos27BoardDevice,
}) =>
    ios27BoardApp(
      brightness: brightness,
      disableAnimations: disableAnimations,
      textScale: textScale,
      device: device,
      overrides: layerOverrides(),
      child: Builder(
        builder: (context) =>
            ColoredBox(color: ios27ColorsFor(context).palette.bg),
      ),
    );

/// Контекст корневого навигатора: выше любой области темы (рецепт `test/m3e/dialogs_test.dart`).
BuildContext _root(WidgetTester tester) =>
    tester.element(find.byType(Navigator).first);

Widget _deleteAlert(BuildContext context, {VoidCallback? onDelete}) => Center(
      child: Ios27Alert(
        title: 'Удалить «DROPWEB»?',
        body: const Text('Оплаченная подписка у провайдера останется.'),
        actions: [
          Ios27AlertButton(
            label: 'Отмена',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          Ios27AlertButton(
            label: 'Удалить',
            destructive: true,
            onPressed: onDelete ?? () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

Future<Future<bool?>> _open(
  WidgetTester tester, {
  bool dismissible = true,
}) async {
  final future = showIos27Alert<bool>(
    _root(tester),
    dismissible: dismissible,
    builder: _deleteAlert,
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return future;
}

Rect _rect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero) & box.size;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
        'корневой контекст ${brightness.name}: алерт в цветах iOS, без исключений',
        (tester) async {
      await pumpIos27Board(tester, _app(brightness: brightness));
      await _open(tester);
      final element = tester.element(find.byType(Ios27Alert));
      final colors = Ios27Colors.maybeOf(element);
      expect(colors, isNotNull,
          reason: '$brightness: тема iOS пришла из маршрута');
      expect(colors!.dark, brightness == Brightness.dark);
      expect(find.text('Удалить «DROPWEB»?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Кнопка «Удалить» красным текстом на сером фоне (странность доски).
      final button = tester.widget<TextButton>(
        find.ancestor(
            of: find.text('Удалить'), matching: find.byType(TextButton)),
      );
      final fg = button.style!.foregroundColor!.resolve(<WidgetState>{});
      expect(fg, colors.palette.redText);
    });
  }

  testWidgets('геометрия доски: 300 по центру, капсулы 48, текст алерта',
      (tester) async {
    await pumpIos27Board(tester, _app());
    await _open(tester);
    final ref = Ios27RefLayout.load('delete-alert-light-rt-p0');
    final alert = _rect(tester, find.byType(Ios27Alert));
    final refAlert = ref.element('alert')!;
    expect(alert.width, closeTo(refAlert.width, 0.5));
    expect(alert.height, closeTo(refAlert.height, 4));
    expect(alert.center.dx, closeTo(refAlert.center.dx, 0.5));
    expect(alert.center.dy, closeTo(refAlert.center.dy, 4));
    final buttons = ref.all('alert.btn');
    final slots = find.byType(Ios27AlertActionSlot);
    expect(slots, findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      final r = _rect(tester, slots.at(i));
      expect(r.height, 48);
      expect(r.width, closeTo(buttons[i].width, 0.5));
      expect(r.left, closeTo(buttons[i].left, 0.5));
    }
  });

  group('dismissible', () {
    testWidgets('false: тап по затемнению и «назад» не закрывают',
        (tester) async {
      await pumpIos27Board(tester, _app());
      await _open(tester, dismissible: false);
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Ios27Alert), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Ios27Alert), findsOneWidget);
      // Закрыть можно кнопкой изнутри.
      await tester.tap(find.text('Отмена'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Ios27Alert), findsNothing);
    });

    testWidgets('true: тап по затемнению закрывает', (tester) async {
      await pumpIos27Board(tester, _app());
      final result = await _open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Ios27Alert), findsNothing);
      expect(await result, isNull);
    });

    testWidgets('true: «назад» закрывает', (tester) async {
      await pumpIos27Board(tester, _app());
      await _open(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Ios27Alert), findsNothing);
    });
  });

  testWidgets('кнопка возвращает результат, тикеров после закрытия нет',
      (tester) async {
    await pumpIos27Board(tester, _app());
    final result = await _open(tester);
    await tester.tap(find.text('Удалить'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(await result, isTrue);
    expect(find.byType(Ios27Alert), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('Reduce Motion: проявление за 100 мс без масштаба',
      (tester) async {
    await pumpIos27Board(tester, _app(disableAnimations: true));
    unawaited(
      showIos27Alert<bool>(_root(tester), builder: _deleteAlert),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Ios27Alert), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(Ios27Alert),
        matching: find.byType(FadeTransition),
      ),
      findsWidgets,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
      'клавиатура через CommonDialog: поле над клавиатурой, inset один раз',
      (tester) async {
    await pumpIos27Board(tester, _app(textScale: 2.0));
    tester.view.viewInsets =
        const FakeViewPadding(bottom: 600); // 300 dp при dpr 2
    addTearDown(tester.view.resetViewInsets);
    unawaited(
      showIos27Alert<void>(
        _root(tester),
        builder: (_) => const CommonDialog(
          title: 'Имя',
          useIos27: true,
          child: TextField(key: ValueKey('field')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    const keyboardTop = 914 - 300.0;
    final field = _rect(tester, find.byKey(const ValueKey('field')));
    expect(field.bottom, lessThanOrEqualTo(keyboardTop));
    final alert = _rect(tester, find.byType(Ios27Alert));
    expect(alert.bottom, lessThanOrEqualTo(keyboardTop));
    // Потомки не получают viewInsets второй раз.
    final inner =
        MediaQuery.of(tester.element(find.byKey(const ValueKey('field'))));
    expect(inner.viewInsets.bottom, 0);
  });

  testWidgets(
      'клавиатура 336 dp на 375×667: карточка не лезет под строку состояния',
      (tester) async {
    await pumpIos27Board(
      tester,
      _app(device: kIos27IphoneSmall),
      device: kIos27IphoneSmall,
    );
    tester.view.viewInsets =
        const FakeViewPadding(bottom: 672); // 336 dp при dpr 2
    addTearDown(tester.view.resetViewInsets);
    unawaited(
      showIos27Alert<void>(
        _root(tester),
        builder: (_) => CommonDialog(
          title: 'Длинный диалог',
          useIos27: true,
          child: Column(
            children: [for (var i = 0; i < 40; i++) Text('Строка $i')],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    final alert = _rect(tester, find.byType(Ios27Alert));
    const keyboardTop = 667 - 336.0;
    // Высота считается от видимой области без клавиатуры минус 96: 235.
    expect(alert.height, lessThanOrEqualTo(keyboardTop - 96 + 0.01));
    expect(alert.top, greaterThanOrEqualTo(20));
    expect(alert.bottom, lessThanOrEqualTo(keyboardTop));
  });

  group('golden', () {
    for (final brightness in Brightness.values) {
      testWidgets('delete-alert ${brightness.name}', (tester) async {
        await pumpIos27Board(tester, _app(brightness: brightness));
        await _open(tester);
        await expectIos27Golden(
          tester,
          brightness == Brightness.light
              ? 'layer_delete_alert'
              : 'layer_delete_alert_dark',
        );
      });
    }
  });
}
