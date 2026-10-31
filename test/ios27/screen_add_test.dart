// Экран «Добавить подписку» iOS: поведение обоих входов, импорт, ошибка, вставка, QR, шаг листа.

import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_add_support.dart';

Finder _input() => find.descendant(
      of: find.byKey(addFieldInput),
      matching: find.byType(TextField),
    );

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_input(), text);
  await tester.pump();
}

bool _addEnabled(WidgetTester tester) =>
    tester.widget<Ios27Button>(find.byKey(addButton)).onPressed != null;

void main() {
  for (final entry in AddEntry.values) {
    group('вход ${entry.name}', () {
      testWidgets('пустое поле: «Добавить» выключена, ошибки нет',
          (tester) async {
        await pumpAdd(tester, entry);
        expect(tester.takeException(), isNull);
        expect(find.text('Добавить подписку'), findsWidgets);
        expect(find.text('Ссылка на подписку'), findsOneWidget);
        expect(find.text('Вставить'), findsOneWidget);
        expect(
            find.byKey(const ValueKey<String>('ios27.add.qr')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('sheet.fieldError')),
            findsNothing);
        expect(_addEnabled(tester), isFalse);
        await _type(tester, 'https://x.io/s/1');
        expect(_addEnabled(tester), isTrue);
        await _type(tester, '   ');
        expect(_addEnabled(tester), isFalse);
      });

      testWidgets('верная ссылка: лист закрывается, импорт вызван',
          (tester) async {
        final spy = AddSpy();
        await pumpAdd(tester, entry, spy: spy);
        await _type(tester, '  https://dropweb.site/s/7f3a9c2e ');
        await tester.tap(find.byKey(addButton));
        await settleAdd(tester);
        expect(spy.imported, ['https://dropweb.site/s/7f3a9c2e']);
        // Лист целиком ушёл, а не только шаг.
        expect(find.byKey(const ValueKey<String>('ios27.sheet.frame')),
            findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('неверная ссылка: форма остаётся, ошибка, импорта нет',
          (tester) async {
        final spy = AddSpy();
        await pumpAdd(tester, entry, spy: spy);
        await _type(tester, 'abc');
        await tester.tap(find.byKey(addButton));
        await settleAdd(tester);
        expect(spy.imported, isEmpty);
        expect(
            find.text('Ссылка должна начинаться с https://'), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('ios27.sheet.frame')),
            findsOneWidget);
        // Правка снимает ошибку.
        await _type(tester, 'abc1');
        expect(find.text('Ссылка должна начинаться с https://'), findsNothing);
      });

      testWidgets('«Вставить» берёт ссылку из буфера и снимает ошибку',
          (tester) async {
        await pumpAdd(tester, entry);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => call.method == 'Clipboard.getData'
              ? <String, dynamic>{'text': ' https://dropweb.site/s/1 '}
              : null,
        );
        addTearDown(() => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null));
        await _type(tester, 'bad');
        await tester.tap(find.byKey(addButton));
        await tester.pump();
        expect(
            find.text('Ссылка должна начинаться с https://'), findsOneWidget);
        await tester.tap(find.text('Вставить'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final field = tester.widget<TextField>(_input());
        expect(field.controller!.text, 'https://dropweb.site/s/1');
        expect(find.text('Ссылка должна начинаться с https://'), findsNothing);
      });

      testWidgets('«Сканировать QR-код» зовёт сканер M3E, лист остаётся',
          (tester) async {
        final spy = AddSpy();
        await pumpAdd(tester, entry, spy: spy);
        await tester.tap(find.byKey(const ValueKey<String>('ios27.add.qr')));
        await tester.pump();
        expect(spy.scans, 1);
        expect(find.byKey(const ValueKey<String>('ios27.sheet.frame')),
            findsOneWidget);
      });

      testWidgets('Enter на клавиатуре отправляет форму', (tester) async {
        final spy = AddSpy();
        await pumpAdd(tester, entry, spy: spy);
        await _type(tester, 'https://a.io/x');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settleAdd(tester);
        expect(spy.imported, ['https://a.io/x']);
      });

      testWidgets('тёмная тема и «Уменьшить прозрачность» выкл: без исключений',
          (tester) async {
        await pumpAdd(
          tester,
          entry,
          brightness: Brightness.dark,
          reduceTransparency: false,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Добавить'), findsOneWidget);
      });
    });
  }

  testWidgets('отдельный лист: initialUrl подставляется, «Добавить» включена',
      (tester) async {
    await pumpAdd(tester, AddEntry.sheet,
        initialUrl: 'https://dropweb.site/s/9');
    expect(tester.widget<TextField>(_input()).controller!.text,
        'https://dropweb.site/s/9');
    expect(_addEnabled(tester), isTrue);
  });

  testWidgets(
      'шаг листа: «Назад» возвращает на корневую страницу, форма сброшена',
      (tester) async {
    await pumpAdd(tester, AddEntry.step);
    expect(
        find.byKey(const ValueKey<String>('ios27.sheet.back')), findsOneWidget);
    await _type(tester, 'https://a.io/x');
    await tester.tap(find.byKey(const ValueKey<String>('ios27.sheet.back')));
    await settleAdd(tester);
    expect(find.byKey(addFieldInput), findsNothing);
    expect(find.byKey(const ValueKey<String>('ios27.sheet.frame')),
        findsOneWidget);
    // Снова открыли: поле чистое.
    await tester.tap(find.byKey(const ValueKey<String>('test.stepRoot.open')));
    await settleAdd(tester);
    expect(tester.widget<TextField>(_input()).controller!.text, isEmpty);
  });

  testWidgets('отдельный лист: «Закрыть» убирает лист без импорта',
      (tester) async {
    final spy = AddSpy();
    await pumpAdd(tester, AddEntry.sheet, spy: spy);
    await tester.tap(find.byKey(const ValueKey<String>('ios27.sheet.close')));
    await settleAdd(tester);
    expect(
        find.byKey(const ValueKey<String>('ios27.sheet.frame')), findsNothing);
    expect(spy.imported, isEmpty);
  });

  testWidgets('Gate8: после выезда нет тикеров, без движения тоже',
      (tester) async {
    for (final reduced in [true, false]) {
      await pumpAdd(tester, AddEntry.sheet, disableAnimations: reduced);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0,
          reason: 'disableAnimations=$reduced');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Gate8: TickerMode(false) гасит тикеры формы', (tester) async {
    await pumpAdd(tester, AddEntry.sheet, disableAnimations: false);
    await tester.tap(find.byKey(addFieldInput));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('шаг: ключи страницы и типизированный вход', (tester) async {
    await pumpAdd(tester, AddEntry.step);
    final ctx = tester.element(find.byKey(addButton));
    expect(Ios27SheetNavigator.depthOf(ctx), 2);
  });

  testWidgets('a11y: поле, «Вставить», QR и «Добавить» доступны VoiceOver',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAdd(tester, AddEntry.sheet);
    expect(find.bySemanticsLabel('Ссылка на подписку'), findsWidgets);
    expect(find.bySemanticsLabel('Вставить'), findsOneWidget);
    expect(find.bySemanticsLabel('Сканировать QR-код'), findsWidgets);
    expect(find.bySemanticsLabel('Добавить'), findsOneWidget);
    // Ошибка объявляется как живая область.
    await _type(tester, 'abc');
    await tester.tap(find.byKey(addButton));
    await tester.pump();
    final err = tester.getSemantics(
      find.text('Ссылка должна начинаться с https://'),
    );
    expect(err.label, contains('https://'));
    handle.dispose();
  });
}
