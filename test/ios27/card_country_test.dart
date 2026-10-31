// Карточка главной показывает страну выхода вместо IP-адреса и без «Трафика» (решение владельца
// 30.10 13:48: IP на экране попадает на скриншоты). С карточкой №4 слова «Страна» на экране нет:
// страну опознаёт флаг, а само слово живёт в общей подписи для VoiceOver («Страна: Нидерланды»).
//
// Проверяется весь путь «вход приложения → адаптер → виджет»: тексты дерева виджетов и дерево
// семантики (то, что читает VoiceOver) не должны содержать ни полного адреса, ни слова «Трафик».

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_view.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden.dart';

const _ip = '94.183.12.34';
const _ipV6 = '2a0e:97c0:3e3:4f1::1c';
final _now = DateTime(2026, 10, 30, 12);

Future<void> _pump(
  WidgetTester tester, {
  required String lang,
  required M3eHomeInput input,
  bool pending = false,
  double textScale = 1.0,
}) async {
  final locale = lang.contains('_')
      ? Locale(lang.split('_').first, lang.split('_').last)
      : Locale(lang);
  final l = await tester.runAsync(() => AppLocalizations.load(locale));
  final data = buildIos27HomeData(
    l!,
    input,
    now: _now,
    locale: lang,
    ipPending: pending,
  ).card;
  await pumpIos27Board(
    tester,
    ios27BoardApp(
      brightness: Brightness.light,
      disableAnimations: true,
      textScale: textScale,
      locale: locale,
      child: Builder(
        builder: (context) => ColoredBox(
          color: Ios27Colors.of(context).palette.bg,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Ios27Card(data: data, now: () => _now),
            ),
          ),
        ),
      ),
    ),
  );
}

M3eHomeInput _input(
        {String? ip = _ip, String? code = 'NL', bool online = true}) =>
    M3eHomeInput(
      providerName: 'SPACE VPN',
      ipAddress: ip,
      ipCountryCode: code,
      online: online,
    );

/// Все тексты дерева виджетов одной строкой.
String _widgetTexts(WidgetTester tester) => [
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        t.data ?? t.textSpan?.toPlainText() ?? '',
    ].join('|');

/// Подписи и значения всех узлов семантики карточки одной строкой.
String _semanticsTexts(WidgetTester tester) {
  final buf = StringBuffer();
  void visit(SemanticsNode node) {
    final d = node.getSemanticsData();
    buf
      ..write(d.label)
      ..write('|')
      ..write(d.value)
      ..write('|');
    node.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(tester.getSemantics(find.byType(Ios27Card)));
  return buf.toString();
}

void main() {
  testWidgets('ru: флаг и название, «Страна» в подписи, адреса нет нигде',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await _pump(tester, lang: 'ru', input: _input());
      expect(find.text('Страна'), findsNothing);
      expect(find.text('Нидерланды'), findsOneWidget);
      expect(find.byKey(Ios27CardKeys.flag), findsOneWidget);
      final texts = _widgetTexts(tester);
      final sem = _semanticsTexts(tester);
      for (final all in [texts, sem]) {
        expect(all, isNot(contains(_ip)));
        expect(all, isNot(contains('94.183')));
        expect(all, isNot(contains('IP')));
        expect(all, isNot(contains('Трафик')));
      }
      expect(sem, contains('Страна: Нидерланды'));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('en: английское название и подпись Country', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await _pump(tester, lang: 'en', input: _input());
      expect(find.text('Netherlands'), findsOneWidget);
      expect(_semanticsTexts(tester), contains('Country: Netherlands'));
      expect(_widgetTexts(tester), isNot(contains('Traffic')));
      expect(_widgetTexts(tester), isNot(contains(_ip)));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('США пишутся коротко, без официального названия CLDR',
      (tester) async {
    try {
      await _pump(tester, lang: 'ru', input: _input(code: 'US'));
      expect(find.text('США'), findsOneWidget);
      expect(_widgetTexts(tester), isNot(contains('Соединенные')));
      await _pump(tester, lang: 'en', input: _input(code: 'US'));
      expect(find.text('United States'), findsOneWidget);
      await _pump(tester, lang: 'ja', input: _input(code: 'US'));
      expect(find.text('アメリカ'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('ja и zh_CN: название и подпись на своём языке', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await _pump(tester, lang: 'ja', input: _input());
      expect(find.text('オランダ'), findsOneWidget);
      expect(_semanticsTexts(tester), contains('国: オランダ'));
      await _pump(tester, lang: 'zh_CN', input: _input());
      expect(find.text('荷兰'), findsOneWidget);
      expect(_semanticsTexts(tester), contains('国家: 荷兰'));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('страна стоит в нижней строке слева, статус справа',
      (tester) async {
    await _pump(tester, lang: 'ru', input: _input());
    final bar = tester.getRect(find.byKey(Ios27CardKeys.bar));
    final country = tester.getRect(find.byKey(Ios27CardKeys.country));
    final state = tester.getRect(find.byKey(Ios27CardKeys.state));
    expect(country.left, bar.left);
    expect(state.right, bar.right);
    expect(country.right, lessThan(state.left));
    expect(find.text('Не подключено'), findsOneWidget);
  });

  testWidgets('кода страны нет: адрес маскируется, полный не показывается',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await _pump(tester, lang: 'ru', input: _input(code: null));
      expect(find.text('94.183.•••.•••'), findsOneWidget);
      expect(_widgetTexts(tester), isNot(contains(_ip)));
      expect(_semanticsTexts(tester), isNot(contains(_ip)));
      await _pump(tester, lang: 'ru', input: _input(ip: _ipV6, code: ''));
      expect(find.text('2a0e:97c0:•••'), findsOneWidget);
      expect(_widgetTexts(tester), isNot(contains('3e3')));
      expect(find.byKey(Ios27CardKeys.flag), findsNothing);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('страна определяется: индикатор, а не прочерк (D9)',
      (tester) async {
    await _pump(tester,
        lang: 'ru', input: _input(ip: null, code: null), pending: true);
    expect(find.byKey(Ios27CardKeys.spinner), findsOneWidget);
    expect(find.text('—'), findsNothing);
    // Рядом с индикатором «Подключение…»; слова статуса справа в это время нет.
    expect(find.text('Подключение…'), findsOneWidget);
    expect(find.byKey(Ios27CardKeys.state), findsNothing);
  });

  testWidgets('сети нет: прочерк без индикатора', (tester) async {
    await _pump(tester,
        lang: 'ru', input: _input(online: false), pending: true);
    expect(find.text('—'), findsOneWidget);
    expect(find.byKey(Ios27CardKeys.spinner), findsNothing);
  });

  testWidgets(
      'длинное название при крупном шрифте переносится, карточка растёт',
      (tester) async {
    await _pump(
      tester,
      lang: 'ru',
      input: _input(code: 'US'),
    );
    final h1 = tester.getSize(find.byKey(Ios27CardKeys.card)).height;
    await _pump(
      tester,
      lang: 'ru',
      input: _input(code: 'US'),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
    expect(
        tester.getSize(find.byKey(Ios27CardKeys.card)).height, greaterThan(h1));
  });
}
