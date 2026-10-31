// Раскрытие VPN на iOS: ссылка на политику, согласие, тексты без Android, golden.

import 'package:dropweb/common/vpn_consent.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/layers/ios27_alert.dart';
import 'package:dropweb/ui/ios27/layers/ios27_disclosure.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/m3e/screens/m3e_about.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/golden.dart';
import 'support/layer_harness.dart';
import 'support/layout.dart';
import 'support/surface.dart';

Widget _app({
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Ios27Device device = kIos27BoardDevice,
  Locale locale = const Locale('ru'),
}) =>
    ios27BoardApp(
      brightness: brightness,
      textScale: textScale,
      device: device,
      locale: locale,
      overrides: layerOverrides(),
      child: Builder(
        builder: (context) =>
            ColoredBox(color: ios27ColorsFor(context).palette.bg),
      ),
    );

BuildContext _root(WidgetTester tester) =>
    tester.element(find.byType(Navigator).first);

/// Все тексты дерева: `Text` и `RichText` (в том числе внутри кнопок).
Iterable<String> _allText(WidgetTester tester) sync* {
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    yield w.data ?? w.textSpan?.toPlainText() ?? '';
  }
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    yield w.text.toPlainText();
  }
}

Rect _rect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero) & box.size;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Future<bool?>> open(
    WidgetTester tester, {
    List<String>? opened,
  }) async {
    final future = showIos27VpnDisclosure(
      _root(tester),
      openUrl: (url) async => opened?.add(url),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return future;
  }

  // UIAlertController раскладывает кнопки столбиком, когда в ряд не выходит: при 2.0 «Продолжить»
  // не помещается в половину карточки и обрезалась бы многоточием.
  for (final dark in [false, true]) {
    testWidgets(
        'textScale 2.0 на iPhone SE (${dark ? 'тёмная' : 'светлая'}): '
        'обе кнопки столбиком, без многоточия и переполнения', (tester) async {
      await pumpIos27Board(
        tester,
        _app(
          brightness: dark ? Brightness.dark : Brightness.light,
          textScale: 2.0,
          device: kIos27IphoneSmall,
        ),
        device: kIos27IphoneSmall,
      );
      await open(tester);
      expect(tester.takeException(), isNull);
      final alert = _rect(tester, find.byType(Ios27Alert));
      final cancel = _rect(tester, find.widgetWithText(TextButton, 'Отмена'));
      final next = _rect(tester, find.widgetWithText(TextButton, 'Продолжить'));
      // Столбиком в заданном порядке: «Отмена» сверху, обе на всю ширину области действий.
      expect(cancel.bottom, lessThan(next.top));
      expect(cancel.width, closeTo(next.width, 0.01));
      expect(cancel.width, closeTo(alert.width - 32, 0.01));
      for (final label in ['Отмена', 'Продолжить']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.widgetWithText(TextButton, label),
            matching: find.byType(RichText),
          ),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        expect(
            paragraph.size.width, lessThanOrEqualTo(cancel.width - 24 + 0.01),
            reason: label);
      }
      // Карточка целиком на экране, кнопки внутри неё.
      const screen = Rect.fromLTWH(0, 0, 375, 667);
      expect(alert.top, greaterThanOrEqualTo(20));
      expect(screen.contains(alert.bottomRight), isTrue);
      expect(alert.contains(next.bottomRight), isTrue);
    });
  }

  testWidgets('textScale 1.0: кнопки по-прежнему в ряд поровну',
      (tester) async {
    await pumpIos27Board(tester, _app());
    await open(tester);
    final cancel = _rect(tester, find.widgetWithText(TextButton, 'Отмена'));
    final next = _rect(tester, find.widgetWithText(TextButton, 'Продолжить'));
    expect(cancel.top, closeTo(next.top, 0.01));
    expect(cancel.width, closeTo(next.width, 0.01));
  });

  testWidgets('тексты из ios27Disclosure*, без слова Android', (tester) async {
    await pumpIos27Board(tester, _app());
    await open(tester);
    expect(find.text('Перед подключением'), findsOneWidget);
    expect(find.text('Политика конфиденциальности'), findsOneWidget);
    expect(find.text('Отмена'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
    final texts = _allText(tester).toList();
    expect(
        texts.any((t) => t.startsWith('dropweb создаёт VPN-туннель')), isTrue);
    for (final t in texts) {
      expect(t.toLowerCase(), isNot(contains('android')), reason: t);
    }
    expect(tester.takeException(), isNull);
  });

  // Решение владельца 30.10: идентификатор устройства отключить нельзя (без него не работает
  // подписка), поэтому раскрытие не обещает такой возможности.
  testWidgets('в окне нет обещания отключить идентификатор устройства',
      (tester) async {
    await pumpIos27Board(tester, _app());
    await open(tester);
    final texts = _allText(tester).toList();
    final body = texts.firstWhere((t) => t.startsWith('dropweb создаёт'));
    expect(body, endsWith('ваш IP-адрес и идентификатор устройства.'));
    for (final t in texts) {
      final lower = t.toLowerCase();
      expect(lower, isNot(contains('отключено')), reason: t);
      expect(lower, isNot(contains('в настройках')), reason: t);
    }
  });

  // Окно на каждом из четырёх языков: перевод есть, слова Android нет, обещания отключить нет.
  for (final locale in const [
    Locale('ru'),
    Locale('en'),
    Locale('ja'),
    Locale('zh', 'CN'),
  ]) {
    testWidgets(
        'язык ${locale.toLanguageTag()}: окно переведено, без Android '
        'и обещания отключить', (tester) async {
      await tester.runAsync(() => AppLocalizations.load(locale));
      await pumpIos27Board(tester, _app(locale: locale), locale: locale);
      await open(tester);
      final l = AppLocalizations.current;
      final texts = _allText(tester).toList();
      expect(texts, contains(l.ios27DisclosureTitle));
      expect(texts, contains(l.ios27DisclosureBody));
      expect(find.text(l.ios27DisclosurePolicy), findsOneWidget);
      expect(find.text(l.cancel), findsOneWidget);
      expect(find.text(l.vpnDisclosureContinue), findsOneWidget);
      for (final t in texts) {
        final lower = t.toLowerCase();
        expect(lower, isNot(contains('android')), reason: t);
        for (final promise in const [
          'отключено', 'unless', 'disabled', '設定で', '無効', '设置中', '关闭', //
        ]) {
          expect(lower, isNot(contains(promise)), reason: t);
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ссылка на политику открывает адрес и не закрывает окно',
      (tester) async {
    await pumpIos27Board(tester, _app());
    final opened = <String>[];
    final result = await open(tester, opened: opened);
    await tester.tap(find.text('Политика конфиденциальности'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(opened, [m3ePrivacyUrl()]);
    expect(find.byType(Ios27Alert), findsOneWidget);
    // Согласие не записано: ссылка не «Продолжить».
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getBool(VpnConsent.storageKey), isNull);
    // Закрываем, чтобы не оставлять маршрут.
    await tester.tap(find.text('Отмена'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(await tester.runAsync(() => result), isFalse);
  });

  testWidgets('«Продолжить»: true и согласие записано', (tester) async {
    await pumpIos27Board(tester, _app());
    final result = await open(tester);
    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(await tester.runAsync(() => result), isTrue);
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getBool(VpnConsent.storageKey), isTrue);
    expect(find.byType(Ios27Alert), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('«Отмена»: false, согласия нет', (tester) async {
    await pumpIos27Board(tester, _app());
    final result = await open(tester);
    await tester.tap(find.text('Отмена'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(await tester.runAsync(() => result), isFalse);
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getBool(VpnConsent.storageKey), isNull);
  });

  testWidgets('окно обязательное: затемнение и «назад» не закрывают',
      (tester) async {
    await pumpIos27Board(tester, _app());
    await open(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Ios27Alert), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Ios27Alert), findsOneWidget);
  });

  testWidgets('геометрия доски: карточка, заголовок, кнопки', (tester) async {
    await pumpIos27Board(tester, _app());
    await open(tester);
    final ref = Ios27RefLayout.load('disclosure-light-rt-p0');
    final alert = _rect(tester, find.byType(Ios27Alert));
    final refAlert = ref.element('alert')!;
    expect(alert.width, closeTo(refAlert.width, 0.5));
    expect(alert.center.dx, closeTo(refAlert.center.dx, 0.5));
    // ИЗВЕСТНОЕ ОТЛИЧИЕ ОТ ДОСКИ (решение владельца 30.10): в тексте раскрытия нет оговорки
    // «если это не отключено в настройках» (app.js:801): идентификатор устройства отключить
    // нельзя, без него не работает подписка. Текст короче на одну строку 15/20 (доска 10
    // строк, приложение 9), карточка ниже ровно на 20 dp. Допуск остальных размеров не тронут.
    const lineHeight = 20.0;
    expect(alert.height, closeTo(refAlert.height - lineHeight, 1));
    // Карточка по-прежнему по центру экрана, как на доске.
    expect(alert.center.dy, closeTo(refAlert.center.dy, 1));
    final link = _rect(tester, find.text('Политика конфиденциальности'));
    expect(link.left, closeTo(ref.element('alert.link')!.left, 0.5));
    final slots = find.byType(Ios27AlertActionSlot);
    final buttons = ref.all('alert.btn');
    for (var i = 0; i < 2; i++) {
      final r = _rect(tester, slots.at(i));
      expect(r.height, 48);
      expect(r.width, closeTo(buttons[i].width, 0.5));
    }
  });

  testWidgets('ссылка в цвете подписи с подчёркиванием, не акцент',
      (tester) async {
    await pumpIos27Board(tester, _app());
    await open(tester);
    final element = tester.element(find.text('Политика конфиденциальности'));
    final style =
        tester.widget<Text>(find.text('Политика конфиденциальности')).style!;
    final palette = ios27ColorsFor(element).palette;
    expect(style.color, palette.glassLabel);
    expect(style.decoration, TextDecoration.underline);
  });

  testWidgets('golden disclosure', (tester) async {
    await pumpIos27Board(tester, _app());
    await open(tester);
    await expectIos27Golden(tester, 'layer_disclosure');
  });
}
