import 'dart:async';

import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/symbols.g.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/theme/tokens.g.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_dialog.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

const _sheetKey = ValueKey<String>('m3e.sheet');
const _titleKey = ValueKey<String>('m3e.sheet.title');
const _backKey = ValueKey<String>('m3e.sheet.back');
const _scrimKey = ValueKey<String>('m3e.scrim');
const _dialogKey = ValueKey<String>('m3e.dialog');
const _dialogScrimKey = ValueKey<String>('m3e.dialog.scrim');
const _homeKey = ValueKey<String>('home');
const _pushKey = ValueKey<String>('push');
const _axisKey = ValueKey<String>('m3e.sheet.axis');
const _axisFadeKey = ValueKey<String>('m3e.sheet.axis.fade');

/// flutter_test рисует тени жёсткой чёрной обводкой, а доска снята с мягкой тенью.
/// Для golden включаем реальные; флаг обязан вернуться до проверки инвариантов теста.
Future<void> _golden(WidgetTester tester, String name) async {
  try {
    await expectM3eGolden(tester, name);
  } finally {
    debugDisableShadows = true;
  }
}

/// Фон кадра `home.bg`; ключ `home` у кадра — место, откуда берётся контекст для показа.
Widget _app({bool reduceMotion = false}) => Builder(
      builder: (context) {
        Widget child = ColoredBox(
          key: _homeKey,
          color: M3eColors.of(context).home.bg,
          child: const SizedBox.expand(),
        );
        if (reduceMotion) {
          child = MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child,
          );
        }
        return child;
      },
    );

Future<void> _pump(
  WidgetTester tester, {
  int provider = 0,
  Brightness brightness = Brightness.light,
  bool shadows = false,
  bool reduceMotion = false,
}) async {
  debugDisableShadows = !shadows;
  final h = parseDropwebTheme(kBoardProviders[provider].theme);
  await pumpM3eBoard(
    tester,
    m3eBoardApp(
      seed: h.accent,
      filter: h.filter,
      brightness: brightness,
      child: _app(reduceMotion: reduceMotion),
    ),
  );
}

BuildContext _ctx(WidgetTester tester) => tester.element(find.byKey(_homeKey));

/// Тело-образец: строки в рамке, как список доски, но из простых виджетов.
Widget _rows(BuildContext context, List<String> labels) {
  final scheme = M3eColors.of(context).scheme;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final label in labels)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Container(
            height: 64,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(label, style: TextStyle(color: scheme.onSurface)),
          ),
        ),
    ],
  );
}

Widget _routeSheet(BuildContext context) => M3eSheetScaffold(
      title: 'Маршрут',
      body: _rows(context, ['Авто', 'Нидерланды', 'Финляндия', 'Германия']),
    );

Widget _stackSheet(BuildContext context) => M3eSheetStack(
      root: (context) => M3eSheetScaffold(
        title: 'Маршрут',
        body: Column(
          children: [
            _rows(context, ['Авто', 'Нидерланды']),
            TextButton(
              key: _pushKey,
              onPressed: () => M3eSheetStack.of(context).push(
                (c) => M3eSheetScaffold(
                  title: 'Серверы и группы',
                  body: _rows(c, ['Fastest', 'First Available', 'США']),
                ),
              ),
              child: const Text('Серверы и группы'),
            ),
          ],
        ),
      ),
    );

/// Первый кадр после запуска анимации только заводит тикер, время идёт со второго.
Future<void> _settle(WidgetTester tester, [int ms = 600]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

Future<T?> _openSheet<T>(
  WidgetTester tester, [
  WidgetBuilder builder = _routeSheet,
]) {
  final future = showM3eSheet<T>(_ctx(tester), builder: builder);
  return future;
}

Future<T?> _openDialog<T>(
  WidgetTester tester,
  List<M3eDialogAction<T>> actions, {
  M3eSymbol icon = M3eSymbol.vpnKey,
}) =>
    showM3eDialog<T>(
      _ctx(tester),
      icon: icon,
      title: 'Перед подключением',
      text: 'Android попросит разрешение на VPN. Трафик пойдёт через серверы '
          'вашей подписки, dropweb его не читает и не хранит.',
      actions: actions,
    );

/// Открывает лист и не ждёт результата: закрытие проверяется по дереву.
void _showSheet<T>(WidgetTester tester,
        [WidgetBuilder builder = _routeSheet]) =>
    unawaited(_openSheet<T>(tester, builder));

void _showDialog<T>(WidgetTester tester, List<M3eDialogAction<T>> actions) =>
    unawaited(_openDialog<T>(tester, actions));

void _showDialogRaw<T>(
  BuildContext context, {
  required M3eSymbol icon,
  required String title,
  required String text,
  required List<M3eDialogAction<T>> actions,
}) =>
    unawaited(
      showM3eDialog<T>(
        context,
        icon: icon,
        title: title,
        text: text,
        actions: actions,
      ),
    );

void main() {
  group('golden', () {
    for (final (name, brightness) in [
      ('light', Brightness.light),
      ('dark', Brightness.dark),
    ]) {
      testWidgets('sheet_list_${name}_p0', (tester) async {
        await _pump(tester, brightness: brightness, shadows: true);
        _showSheet<void>(tester);
        await _settle(tester);
        await _golden(tester, 'sheet_list_${name}_p0');
      });

      testWidgets('sheet_stack_${name}_p0', (tester) async {
        await _pump(tester, brightness: brightness, shadows: true);
        _showSheet<void>(tester, _stackSheet);
        await _settle(tester);
        await tester.tap(find.byKey(_pushKey));
        await _settle(tester);
        await _golden(tester, 'sheet_stack_${name}_p0');
      });

      testWidgets('dialog_disclosure_${name}_p0', (tester) async {
        await _pump(tester, brightness: brightness, shadows: true);
        _showDialog<String>(tester, const [
          M3eDialogAction('Отмена', 'cancel'),
          M3eDialogAction('Продолжить', 'ok'),
        ]);
        await _settle(tester);
        await _golden(tester, 'dialog_disclosure_${name}_p0');
      });

      testWidgets('dialog_delete_${name}_p0', (tester) async {
        await _pump(tester, brightness: brightness, shadows: true);
        _showDialogRaw<String>(
          _ctx(tester),
          icon: M3eSymbol.delete,
          title: 'Удалить «DROPWEB»?',
          text: 'Оплаченная подписка у провайдера останется.',
          actions: const [
            M3eDialogAction('Отмена', 'cancel'),
            M3eDialogAction('Удалить', 'delete', danger: true),
          ],
        );
        await _settle(tester);
        await _golden(tester, 'dialog_delete_${name}_p0');
      });
    }
  });

  group('лист', () {
    testWidgets('геометрия: внизу, на всю ширину, углы 28, ключи на месте',
        (tester) async {
      await _pump(tester);
      _showSheet<void>(tester);
      await _settle(tester);
      final rect = tester.getRect(find.byKey(_sheetKey));
      expect(rect.left, 0);
      expect(rect.width, 411);
      expect(rect.bottom, closeTo(914, 0.01));
      final material = tester.widget<Material>(find.byKey(_sheetKey));
      final shape = material.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        M3eShapeAsymmetric.extraLargeTop.borderRadius,
      );
      expect(find.byKey(_scrimKey), findsOneWidget);
      expect(find.byKey(_titleKey), findsOneWidget);
      expect(find.byKey(_backKey), findsNothing);
      // Заголовок: левое поле 24 от края листа.
      expect(tester.getTopLeft(find.byKey(_titleKey)).dx, 24);
    });

    testWidgets('высокое тело упирается в 72 dp от верха и прокручивается',
        (tester) async {
      await _pump(tester);
      _showSheet<void>(
        tester,
        (context) => M3eSheetScaffold(
          title: 'Длинный',
          body: _rows(context, [for (var i = 0; i < 30; i++) 'Строка $i']),
        ),
      );
      await _settle(tester);
      expect(tester.getRect(find.byKey(_sheetKey)).top, closeTo(72, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('длинный заголовок обрезается многоточием в одну строку',
        (tester) async {
      await _pump(tester);
      _showSheet<void>(
        tester,
        (context) => M3eSheetScaffold(
          title: 'Очень длинное название группы серверов ' * 4,
          body: _rows(context, ['a']),
        ),
      );
      await _settle(tester);
      final text = tester.widget<Text>(find.byKey(_titleKey));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.getSize(find.byKey(_titleKey)).height, 28);
    });

    testWidgets('закрытие по scrim возвращает null и убирает тикеры',
        (tester) async {
      await _pump(tester);
      var result = 'не вернулось';
      unawaited(_openSheet<String>(tester).then((v) => result = '$v'));
      await _settle(tester);
      await tester.tapAt(const Offset(205, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_sheetKey), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(_sheetKey), findsNothing);
      expect(result, 'null');
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('системная «Назад» закрывает лист', (tester) async {
      await _pump(tester);
      _showSheet<void>(tester);
      await _settle(tester);
      await tester.binding.handlePopRoute();
      await _settle(tester, 300);
      expect(find.byKey(_sheetKey), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('Navigator.pop(value) отдаёт значение', (tester) async {
      await _pump(tester);
      String? result;
      unawaited(_openSheet<String>(
        tester,
        (context) => M3eSheetScaffold(
          title: 'Выбор',
          body: TextButton(
            key: _pushKey,
            onPressed: () => Navigator.of(context).pop('да'),
            child: const Text('ok'),
          ),
        ),
      ).then((v) => result = v));
      await _settle(tester);
      await tester.tap(find.byKey(_pushKey));
      await _settle(tester, 300);
      expect(result, 'да');
      expect(find.byKey(_sheetKey), findsNothing);
    });

    testWidgets('вход: за ~400 мс лист на месте, scrim 32 %', (tester) async {
      await _pump(tester);
      _showSheet<void>(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getRect(find.byKey(_sheetKey)).top;
      await tester.pump(const Duration(milliseconds: 400));
      final end = tester.getRect(find.byKey(_sheetKey)).top;
      expect(mid, greaterThan(end));
      final scrim = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(_scrimKey),
          matching: find.byType(ColoredBox),
        ),
      );
      final colors = M3eColors.of(_ctx(tester));
      expect(scrim.color.a, closeTo(0.32, 0.005));
      expect(
        scrim.color.withValues(alpha: 1),
        colors.scheme.scrim.withValues(alpha: 1),
      );
    });

    testWidgets('отключённые анимации: только прозрачность 150 мс, без сдвига',
        (tester) async {
      await _pump(tester, reduceMotion: true);
      _showSheet<void>(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      final mid = tester.getRect(find.byKey(_sheetKey));
      final opacity = tester
          .widget<Opacity>(
            find.ancestor(
              of: find.byKey(_sheetKey),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      expect(opacity, closeTo(0.5, 0.02));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(find.byKey(_sheetKey)), mid);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.byKey(_sheetKey), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    group('свайп вниз', () {
      testWidgets('за ручку дальше порога закрывает лист', (tester) async {
        await _pump(tester);
        _showSheet<void>(tester);
        await _settle(tester);
        final top = tester.getTopLeft(find.byKey(_sheetKey));
        await tester.dragFrom(
            top + const Offset(200, 24), const Offset(0, 160));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(_sheetKey), findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
      });

      testWidgets('за заголовок тоже закрывает', (tester) async {
        await _pump(tester);
        _showSheet<void>(tester);
        await _settle(tester);
        await tester.drag(find.byKey(_titleKey), const Offset(0, 200));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(_sheetKey), findsNothing);
      });

      testWidgets('короче порога пружиной возвращает на место', (tester) async {
        await _pump(tester);
        _showSheet<void>(tester);
        await _settle(tester);
        final before = tester.getRect(find.byKey(_sheetKey));
        final g = await tester.startGesture(
          before.topLeft + const Offset(200, 24),
        );
        await g.moveBy(const Offset(0, 30));
        await tester.pump();
        expect(
          tester.getRect(find.byKey(_sheetKey)).top,
          closeTo(before.top + 30, 0.5),
        );
        // Отпускание без скорости: тайм-метки событий теста одинаковые.
        await g.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1500));
        expect(find.byKey(_sheetKey), findsOneWidget);
        expect(tester.getRect(find.byKey(_sheetKey)).top,
            closeTo(before.top, 0.5));
        expect(tester.binding.transientCallbackCount, 0);
      });
    });
  });

  group('стек экранов', () {
    testWidgets('push показывает назад, «Назад» сначала снимает экран',
        (tester) async {
      await _pump(tester);
      _showSheet<void>(tester, _stackSheet);
      await _settle(tester);
      expect(find.byKey(_backKey), findsNothing);
      expect(tester.widget<Text>(find.byKey(_titleKey)).data, 'Маршрут');

      await tester.tap(find.byKey(_pushKey));
      await _settle(tester);
      expect(
          tester.widget<Text>(find.byKey(_titleKey)).data, 'Серверы и группы');
      expect(find.byKey(_backKey), findsOneWidget);
      // С «Назад» левое поле заголовка 8 + кнопка 40 + 4.
      expect(tester.getTopLeft(find.byKey(_titleKey)).dx, 52);
      expect(tester.getSize(find.byKey(_backKey)), const Size(40, 40));

      // Системная «Назад»: сначала внутри листа.
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(_titleKey)).data, 'Маршрут');
      expect(find.byKey(_backKey), findsNothing);

      // На корне закрывает лист.
      await tester.binding.handlePopRoute();
      await _settle(tester, 300);
      expect(find.byKey(_sheetKey), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('кнопка «Назад» снимает экран, подпись для диктора',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);
      _showSheet<void>(tester, _stackSheet);
      await _settle(tester);
      await tester.tap(find.byKey(_pushKey));
      await _settle(tester);
      expect(tester.getSemantics(find.byKey(_backKey)).label, 'Назад');
      await tester.tap(find.byKey(_backKey));
      await _settle(tester);
      expect(tester.widget<Text>(find.byKey(_titleKey)).data, 'Маршрут');
      semantics.dispose();
    });

    testWidgets('новый экран входит с сдвигом 30 dp справа, назад слева',
        (tester) async {
      await _pump(tester);
      _showSheet<void>(tester, _stackSheet);
      await _settle(tester);
      await tester.tap(find.byKey(_pushKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final fwd = tester.widget<Transform>(find.byKey(_axisKey));
      expect(fwd.transform.getTranslation().x, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(_backKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final back = tester.widget<Transform>(find.byKey(_axisKey));
      expect(back.transform.getTranslation().x, lessThan(0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('при отключённых анимациях экран появляется без сдвига',
        (tester) async {
      await _pump(tester, reduceMotion: true);
      _showSheet<void>(tester, _stackSheet);
      await _settle(tester, 300);
      await tester.tap(find.byKey(_pushKey));
      await tester.pump();
      final t = tester.widget<Transform>(find.byKey(_axisKey));
      expect(t.transform.getTranslation().x, 0);
      expect(
        tester.widget<Opacity>(find.byKey(_axisFadeKey)).opacity,
        1,
      );
    });

    testWidgets('canBack и onBack задаются явно вне стека', (tester) async {
      await _pump(tester);
      var backs = 0;
      _showSheet<void>(
        tester,
        (context) => M3eSheetScaffold(
          title: 'Свой цвет',
          canBack: true,
          onBack: () => backs++,
          body: _rows(context, ['a']),
        ),
      );
      await _settle(tester);
      await tester.tap(find.byKey(_backKey));
      expect(backs, 1);
    });

    testWidgets('footer стоит в конце прокручиваемой области', (tester) async {
      await _pump(tester);
      _showSheet<void>(
        tester,
        (context) => M3eSheetScaffold(
          title: 'Добавить',
          body: _rows(context, ['a']),
          footer: const Text('footer'),
        ),
      );
      await _settle(tester);
      final body = tester.getRect(find.text('a'));
      final footer = tester.getRect(find.text('footer'));
      expect(footer.top, greaterThan(body.bottom));
    });
  });

  group('диалог', () {
    testWidgets('геометрия: ширина 312 по центру, ключи на месте',
        (tester) async {
      await _pump(tester);
      _showDialog<String>(tester, const [
        M3eDialogAction('Отмена', 'cancel'),
        M3eDialogAction('Продолжить', 'ok'),
      ]);
      await _settle(tester);
      final rect = tester.getRect(find.byKey(_dialogKey));
      expect(rect.width, 312);
      expect(rect.center.dx, closeTo(205.5, 0.01));
      expect(rect.center.dy, closeTo(457, 1));
      final shape = tester.widget<Material>(find.byKey(_dialogKey)).shape!
          as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(28));
      expect(find.byKey(const ValueKey('m3e.dialog.title')), findsOneWidget);
      expect(find.byKey(const ValueKey('m3e.dialog.action.0')), findsOneWidget);
      expect(find.byKey(const ValueKey('m3e.dialog.action.1')), findsOneWidget);
      // Подтверждение правее отказа.
      expect(
        tester.getRect(find.byKey(const ValueKey('m3e.dialog.action.1'))).left,
        greaterThan(
          tester
              .getRect(find.byKey(const ValueKey('m3e.dialog.action.0')))
              .right,
        ),
      );
    });

    testWidgets('кнопка возвращает своё значение, тикеров после закрытия нет',
        (tester) async {
      await _pump(tester);
      String? result;
      unawaited(_openDialog<String>(tester, const [
        M3eDialogAction('Отмена', 'cancel'),
        M3eDialogAction('Продолжить', 'ok'),
      ]).then((v) => result = v));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('m3e.dialog.action.1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_dialogKey), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_dialogKey), findsNothing);
      expect(result, 'ok');
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('scrim и «Назад» возвращают null', (tester) async {
      await _pump(tester);
      final results = <String>[];
      unawaited(_openDialog<String>(
              tester, const [M3eDialogAction('Отмена', 'cancel')])
          .then((v) => results.add('scrim:$v')));
      await _settle(tester);
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester, 300);
      expect(find.byKey(_dialogKey), findsNothing);

      unawaited(_openDialog<String>(
              tester, const [M3eDialogAction('Отмена', 'cancel')])
          .then((v) => results.add('back:$v')));
      await _settle(tester);
      await tester.binding.handlePopRoute();
      await _settle(tester, 300);
      expect(find.byKey(_dialogKey), findsNothing);
      expect(results, ['scrim:null', 'back:null']);
    });

    testWidgets('danger красит подпись в error, обычная — в primary',
        (tester) async {
      await _pump(tester);
      _showDialog<String>(tester, const [
        M3eDialogAction('Отмена', 'cancel'),
        M3eDialogAction('Удалить', 'delete', danger: true),
      ]);
      await _settle(tester);
      final scheme = M3eColors.of(_ctx(tester)).scheme;
      Color colorOf(String label) =>
          tester.widget<Text>(find.text(label)).style!.color!;
      expect(colorOf('Отмена'), scheme.primary);
      expect(colorOf('Удалить'), scheme.error);
    });

    testWidgets('вход пружиной со scale .85 и прозрачностью, выход 150 мс',
        (tester) async {
      await _pump(tester);
      _showDialog<String>(tester, const [M3eDialogAction('Ок', 'ok')]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final scaleAt = tester
          .widget<Transform>(
            find.byKey(const ValueKey('m3e.dialog.motion')),
          )
          .transform
          .storage[0];
      expect(scaleAt, lessThan(1));
      expect(scaleAt, greaterThanOrEqualTo(0.85));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.getRect(find.byKey(_dialogKey)).width,
        closeTo(312, 0.01),
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(find.byKey(_dialogKey), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_dialogKey), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('отключённые анимации: прозрачность 150 мс без масштаба',
        (tester) async {
      await _pump(tester, reduceMotion: true);
      _showDialog<String>(tester, const [M3eDialogAction('Ок', 'ok')]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      final transform = tester.widget<Transform>(
        find.byKey(const ValueKey('m3e.dialog.motion')),
      );
      expect(transform.transform.storage[0], 1);
      final opacity = tester
          .widget<Opacity>(
            find.byKey(const ValueKey('m3e.dialog.fade')),
          )
          .opacity;
      expect(opacity, closeTo(0.5, 0.02));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('диалог поверх листа: сначала закрывается диалог',
        (tester) async {
      await _pump(tester);
      _showSheet<void>(tester);
      await _settle(tester);
      _showDialog<String>(tester, const [M3eDialogAction('Ок', 'ok')]);
      await _settle(tester);
      expect(find.byKey(_dialogKey), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester, 300);
      expect(find.byKey(_dialogKey), findsNothing);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(find.byKey(_dialogScrimKey), findsNothing);
    });
  });
}
