// Карточка главной показывает страну, а не IP (решение владельца 2026-10-30: адрес
// попадает на скриншоты и в запись экрана). Проверяем весь путь «вход → модель → виджет»
// и дерево доступности: диктор тоже не должен читать полный адрес.

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/m3e/color/theme_header.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_model.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sub_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_scenes.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';

Widget _host(M3eCardData data) {
  final header = parseDropwebTheme(kBoardProviders[0].theme);
  return m3eBoardApp(
    seed: header.accent,
    filter: header.filter,
    brightness: Brightness.light,
    child: Builder(
      builder: (context) => ColoredBox(
        color: M3eColors.of(context).home.bg,
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned(
                left: 16,
                top: 108,
                width: 379,
                child: M3eSubCard(data: data, onRefresh: () {}),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Весь текст, который узлы доступности отдают диктору: метка, значение, подсказка.
List<String> _spoken(WidgetTester tester) {
  final out = <String>[];
  void walk(SemanticsNode node) {
    final data = node.getSemanticsData();
    out
      ..add(data.label)
      ..add(data.value)
      ..add(data.hint)
      ..add(data.tooltip);
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(tester
      .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
  return out.where((t) => t.isNotEmpty).toList();
}

/// Весь нарисованный текст карточки.
List<String> _painted(WidgetTester tester) => find
    .descendant(
      of: find.byKey(M3eCardKeys.card),
      matching: find.byType(RichText),
    )
    .evaluate()
    .map((e) => (e.widget as RichText).text.toPlainText())
    .toList();

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.load(const Locale('ru'));
  });

  M3eCardData cardOf({String? ip, String? code, bool online = true}) =>
      buildM3eHomeView(
        l,
        M3eHomeInput(
          vpnOn: true,
          runTime: kHomeRunTime,
          online: online,
          ipAddress: ip,
          ipCountryCode: code,
          providerName: 'dropweb',
          announce: 'dropweb.org',
        ),
        now: kHomeNow,
        locale: 'ru',
      ).card;

  Future<void> show(WidgetTester tester, M3eCardData data) async {
    await pumpM3eBoard(tester, _host(data));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  }

  for (final (ip, code, country) in const [
    ('185.107.56.12', 'NL', 'Нидерланды'),
    ('94.183.247.4', 'US', 'США'),
    ('2a0e:97c0:3e3:4f1::1c', 'DE', 'Германия'),
  ]) {
    testWidgets('$country: полного адреса нет ни на экране, ни у диктора',
        (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester, cardOf(ip: ip, code: code));

      expect(find.textContaining(ip), findsNothing);
      expect(_painted(tester).where((t) => t.contains(ip)), isEmpty);
      expect(_spoken(tester).where((t) => t.contains(ip)), isEmpty,
          reason: 'диктор прочитал бы адрес: ${_spoken(tester)}');

      expect(find.text(country), findsOneWidget);
      expect(
        _spoken(tester)
            .any((t) => t.contains('${l.m3eStatCountry}: $country.')),
        isTrue,
        reason: 'страна входит в фразу карточки: ${_spoken(tester)}',
      );
      handle.dispose();
    });
  }

  testWidgets('кода страны нет: видна только маска адреса', (tester) async {
    final handle = tester.ensureSemantics();
    await show(tester, cardOf(ip: '94.183.247.4'));

    expect(find.text('94.183.•••.•••'), findsOneWidget);
    expect(_painted(tester).where((t) => t.contains('94.183.247.4')), isEmpty);
    expect(_spoken(tester).where((t) => t.contains('94.183.247.4')), isEmpty);
    expect(
      _spoken(tester)
          .any((t) => t.contains('${l.m3eStatCountry}: 94.183.•••.•••.')),
      isTrue,
    );
    handle.dispose();
  });

  testWidgets('IPv6 без кода страны: маска, адрес целиком скрыт',
      (tester) async {
    final handle = tester.ensureSemantics();
    await show(tester, cardOf(ip: '2a0e:97c0:3e3:4f1::1c'));

    expect(find.text('2a0e:97c0:•••'), findsOneWidget);
    expect(_spoken(tester).where((t) => t.contains('3e3:4f1')), isEmpty);
    handle.dispose();
  });

  testWidgets('нет сети: прочерк, колонок «IP-адрес» и «Трафик» нет',
      (tester) async {
    final handle = tester.ensureSemantics();
    await show(tester, cardOf(ip: '185.107.56.12', code: 'NL', online: false));

    expect(
      find.descendant(
        of: find.byKey(M3eCardKeys.country),
        matching: find.text(l.m3eStatNone),
      ),
      findsOneWidget,
    );
    // Без сети страны в фразе нет совсем, а не «Страна: —».
    expect(_spoken(tester).where((t) => t.contains('${l.m3eStatCountry}:')),
        isEmpty);
    expect(
      _spoken(tester).any((t) => t.endsWith('${l.m3eStatusOffline}.')),
      isTrue,
    );
    expect(find.text(l.m3eStatIp), findsNothing);
    handle.dispose();
  });
}
