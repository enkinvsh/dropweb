// G4-lite: рамки карточки №4 против доски карточек (`canon/.omo/hig-cards/index.html`), ±2 dp.
//
// Эталон `test/ios27/ref/card-v4.json` снят Playwright-ом (`.omo/ios/g6/card-v4/ref.mjs`):
// провайдер emerald, состояния on/off/connecting/expired/worst, светлая и тёмная тема; рамки
// относительно левого верхнего угла карточки, CSS px. Данные теста повторяют `stateModel` доски
// слово в слово, чтобы совпадали и ширины текстов.
//
// Если задана `IOS27_CARD_V4_TABLE`, в файл пишется таблица всех сверок (parity.md).

import 'dart:convert';
import 'dart:io';

import 'package:dropweb/common/country_name.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card_data.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/board_providers.dart';
import 'support/golden.dart';

const _tolerance = 2.0;

/// Данные карточки по `stateModel` доски карточек.
Ios27CardData _hig(String state, {DateTime? since}) {
  const longAnnounce =
      'Добавили серверы в Казахстане и Турции. Старые адреса в Нидерландах отключим 1 ноября, '
      'обновите подписку в приложении. Новости в канале https://t.me/dropweb_news';
  switch (state) {
    case 'off':
      return Ios27CardData(
        title: 'dropweb',
        dot: Ios27DotKind.off,
        statusText: 'Не подключено',
        planText: 'Безлимит · до 8 февраля 2027',
        countryLabel: 'Страна',
        countryText: countryDisplayName('RU', 'ru'),
        countryFlag: '🇷🇺',
        countryLoadingLabel: 'Подключение…',
        announce: 'dropweb.org',
        semanticsLabel: 'x',
      );
    case 'connecting':
      return const Ios27CardData(
        title: 'dropweb',
        dot: Ios27DotKind.busy,
        statusText: 'Подключение…',
        planText: 'Безлимит · до 8 февраля 2027',
        countryLabel: 'Страна',
        countryPending: true,
        countryLoadingLabel: 'Подключение…',
        announce: 'dropweb.org',
        semanticsLabel: 'x',
      );
    case 'expired':
      return Ios27CardData(
        title: 'dropweb',
        dot: Ios27DotKind.bad,
        statusText: 'Не подключено',
        planText: 'Подписка закончилась',
        planTone: Ios27CardTone.bad,
        countryLabel: 'Страна',
        countryText: countryDisplayName('RU', 'ru'),
        countryFlag: '🇷🇺',
        countryLoadingLabel: 'Подключение…',
        announce: 'dropweb.org',
        refreshLabel: 'Обновить',
        semanticsLabel: 'x',
      );
    case 'worst':
      return Ios27CardData(
        title: 'Dropweb Global Enterprise Profile',
        dot: Ios27DotKind.on,
        statusText: 'Подключено',
        since: since,
        planText: 'Осталось 0,8 ГБ · до 8 февраля 2027',
        planTone: Ios27CardTone.warn,
        meterPercent: 94,
        countryLabel: 'Страна',
        countryText: countryDisplayName('NL', 'ru'),
        countryFlag: '🇳🇱',
        countryLoadingLabel: 'Подключение…',
        announce: longAnnounce,
        semanticsLabel: 'x',
      );
    default:
      return Ios27CardData(
        title: 'dropweb',
        dot: Ios27DotKind.on,
        statusText: 'Подключено',
        since: since,
        planText: 'Безлимит · до 8 февраля 2027',
        countryLabel: 'Страна',
        countryText: countryDisplayName('DE', 'ru'),
        countryFlag: '🇩🇪',
        countryLoadingLabel: 'Подключение…',
        announce: 'dropweb.org',
        semanticsLabel: 'x',
      );
  }
}

/// Какие стороны элемента сверять: у текстов ширина зависит от шрифта, а не от раскладки.
enum _Check { left, right, top, bottom, centerX, centerY, width, height }

class _Spec {
  const _Spec(this.name, this.key, this.refName, this.checks);

  final String name;
  final ValueKey<String> key;
  final String refName;
  final List<_Check> checks;
}

const _specs = [
  _Spec('card', Ios27CardKeys.card, 'card', [_Check.width, _Check.height]),
  _Spec('name', Ios27CardKeys.name, 'name',
      [_Check.left, _Check.top, _Check.height]),
  _Spec('timer', Ios27CardKeys.timer, 'timer',
      [_Check.right, _Check.top, _Check.height]),
  _Spec('plan', Ios27CardKeys.plan, 'plan',
      [_Check.left, _Check.top, _Check.width, _Check.height]),
  _Spec('meter', Ios27CardKeys.meter, 'meter',
      [_Check.left, _Check.top, _Check.width, _Check.height]),
  _Spec('separator', Ios27CardKeys.separator, 'sep',
      [_Check.left, _Check.top, _Check.width]),
  _Spec('bar', Ios27CardKeys.bar, 'bar',
      [_Check.left, _Check.centerY, _Check.width]),
  _Spec('country', Ios27CardKeys.country, 'loc',
      [_Check.left, _Check.centerY, _Check.width]),
  _Spec('flag', Ios27CardKeys.flag, 'flag',
      [_Check.left, _Check.top, _Check.width, _Check.height]),
  // Спица на доске вращается, и рамка снимка зависит от фазы: сверяем только центр.
  _Spec('spinner', Ios27CardKeys.spinner, 'spin',
      [_Check.centerX, _Check.centerY]),
  _Spec('state', Ios27CardKeys.state, 'state',
      [_Check.right, _Check.centerY, _Check.height]),
  _Spec('dot', Ios27CardKeys.dot, 'dot',
      [_Check.top, _Check.width, _Check.height]),
  // Цель нажатия 44 pt шире надписи: сверяем правый край и середину строки.
  _Spec(
      'refresh', Ios27CardKeys.refresh, 'act', [_Check.right, _Check.centerY]),
  _Spec('footer', Ios27CardKeys.footer, 'foot',
      [_Check.left, _Check.top, _Check.width, _Check.height]),
];

double _value(Rect r, _Check c) => switch (c) {
      _Check.left => r.left,
      _Check.right => r.right,
      _Check.top => r.top,
      _Check.bottom => r.bottom,
      _Check.centerX => r.center.dx,
      _Check.centerY => r.center.dy,
      _Check.width => r.width,
      _Check.height => r.height,
    };

void main() {
  final ref = jsonDecode(File('test/ios27/ref/card-v4.json').readAsStringSync())
      as Map<String, dynamic>;
  final rows = <String>[];
  var worstDelta = 0.0;

  tearDownAll(() {
    final path = Platform.environment['IOS27_CARD_V4_TABLE'];
    if (path == null || path.isEmpty) {
      return;
    }
    final b = StringBuffer()
      ..writeln('# Карточка №4: рамки виджета против доски карточек')
      ..writeln()
      ..writeln('Допуск ±$_tolerance dp. Эталон: `test/ios27/ref/card-v4.json` '
          '(Playwright, `ref.mjs`), рамки относительно угла карточки.')
      ..writeln()
      ..writeln('Максимальное отклонение: ${worstDelta.toStringAsFixed(2)} dp.')
      ..writeln()
      ..writeln('| сцена | элемент | сторона | доска | виджет | Δ |')
      ..writeln('|---|---|---|---|---|---|')
      ..writeAll(rows.map((r) => '$r\n'));
    File(path).writeAsStringSync(b.toString());
  });

  for (final state in ['on', 'off', 'connecting', 'expired', 'worst']) {
    for (final brightness in Brightness.values) {
      final mode = brightness.name;
      testWidgets('рамки №4: $state / $mode', (tester) async {
        try {
          final since = state == 'worst'
              ? tester.binding.clock
                  .now()
                  .subtract(const Duration(hours: 1, minutes: 8, seconds: 42))
              : state == 'on'
                  ? tester.binding.clock
                      .now()
                      .subtract(const Duration(seconds: 4))
                  : null;
          final data = _hig(state, since: since);
          await pumpIos27Board(
            tester,
            ios27BoardApp(
              brightness: brightness,
              theme: Ios27ProviderTheme.fromHeader(kBoardProviders[0].theme),
              disableAnimations: true,
              child: Builder(
                builder: (context) => ColoredBox(
                  color: Ios27Colors.of(context).palette.bg,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 16,
                        top: 108,
                        width: 379,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Ios27Card(
                              data: data,
                              now: tester.binding.clock.now,
                              onRefresh: () {},
                            ),
                            Ios27CardFooter(text: data.announce),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);

          final expected = ref['$state-$mode'] as Map<String, dynamic>;
          final origin = tester.getTopLeft(find.byKey(Ios27CardKeys.card));
          for (final spec in _specs) {
            final want = expected[spec.refName];
            final finder = find.byKey(spec.key);
            if (want == null) {
              expect(finder, findsNothing,
                  reason: '$state/$mode: ${spec.name} на доске нет');
              continue;
            }
            expect(finder, findsOneWidget,
                reason: '$state/$mode: ${spec.name} есть на доске');
            final w = want as Map<String, dynamic>;
            final wantRect = Rect.fromLTWH(
              (w['x'] as num).toDouble(),
              (w['y'] as num).toDouble(),
              (w['w'] as num).toDouble(),
              (w['h'] as num).toDouble(),
            );
            final got = tester.getRect(finder).shift(-origin);
            for (final c in spec.checks) {
              final d = (_value(got, c) - _value(wantRect, c)).abs();
              worstDelta = d > worstDelta ? d : worstDelta;
              rows.add('| $state-$mode | ${spec.name} | ${c.name} | '
                  '${_value(wantRect, c).toStringAsFixed(2)} | '
                  '${_value(got, c).toStringAsFixed(2)} | '
                  '${d.toStringAsFixed(2)} |');
              expect(d, lessThanOrEqualTo(_tolerance),
                  reason: '$state/$mode ${spec.name}.${c.name}: '
                      'доска ${_value(wantRect, c)}, виджет ${_value(got, c)}');
            }
          }
        } finally {
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }
}
