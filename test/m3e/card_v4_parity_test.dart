// Рамки компактной карточки против доски карточек iOS-ветки
// (`canon/.omo/hig-cards/index.html`, вариант №4), допуск ±2 dp.
//
// Решение владельца 2026-10-30: «стиль карточки инфо не перенесли из ios» — Android-карточка
// следует варианту №4, а не прежней карточке `.dr-card` из android.css. Поэтому старый
// паритет внутренностей карточки с `test/m3e/ref/layout.json` заменён этим тестом; у самой
// главной по-прежнему сверяются левый край, верх и ширина карточки (`home_test.dart`).
//
// Эталон `test/m3e/ref/card-v4.json` снят Playwright-ом (провайдер emerald, состояния
// on/off/connecting/expired/worst, светлая и тёмная тема); рамки в CSS px относительно левого
// верхнего угла карточки. Данные теста повторяют `stateModel` доски слово в слово.
//
// У текстов сверяем только то, что задаёт раскладка (края, высоты): ширины зависят от шрифта,
// а доска набрана Onest, у Android — Roboto Flex.
//
// Если задана `M3E_CARD_V4_TABLE`, в файл пишется таблица всех сверок (parity.md).

import 'dart:convert';
import 'dart:io';

import 'package:dropweb/common/country_name.dart';
import 'package:dropweb/ui/m3e/color/theme_header.dart';
import 'package:dropweb/ui/m3e/m3e_format.dart' show M3ePlanTone;
import 'package:dropweb/ui/m3e/widgets/m3e_meter.dart' show M3eMeterTone;
import 'package:dropweb/ui/m3e/widgets/m3e_sub_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

const _tolerance = 2.0;

const _longAnnounce =
    'Добавили серверы в Казахстане и Турции. Старые адреса в Нидерландах отключим 1 ноября, '
    'обновите подписку в приложении. Новости в канале https://t.me/dropweb_news';

/// Данные карточки по `stateModel` доски карточек.
M3eCardData _hig(String state, {String? timer}) {
  switch (state) {
    case 'off':
      return M3eCardData(
        providerName: 'dropweb',
        dot: M3eDotState.off,
        statusText: 'Не подключено',
        statusVisible: false,
        planText: 'Безлимит · до 8 февраля 2027',
        ipFlag: '🇷🇺',
        ipAddress: '95.24.118.7',
        countryText: countryDisplayName('RU', 'ru'),
        announce: 'dropweb.org',
      );
    case 'connecting':
      return const M3eCardData(
        providerName: 'dropweb',
        dot: M3eDotState.busy,
        statusText: 'Подключение…',
        statusVisible: false,
        planText: 'Безлимит · до 8 февраля 2027',
        ipAddress: '—',
        countryText: '—',
        ipLoading: true,
        announce: 'dropweb.org',
      );
    case 'expired':
      return M3eCardData(
        providerName: 'dropweb',
        dot: M3eDotState.bad,
        statusText: 'Не подключено',
        statusVisible: true,
        planText: 'Подписка закончилась',
        planTone: M3ePlanTone.bad,
        ipFlag: '🇷🇺',
        ipAddress: '95.24.118.7',
        countryText: countryDisplayName('RU', 'ru'),
        announce: 'dropweb.org',
        showRefresh: true,
      );
    case 'worst':
      return M3eCardData(
        providerName: 'Dropweb Global Enterprise Profile',
        dot: M3eDotState.on,
        statusText: 'Подключено',
        statusVisible: false,
        timer: timer,
        planText: 'Осталось 0,8 ГБ · до 8 февраля 2027',
        planTone: M3ePlanTone.warn,
        meterPercent: 94,
        meterTone: M3eMeterTone.low,
        ipFlag: '🇳🇱',
        ipAddress: '185.107.56.12',
        countryText: countryDisplayName('NL', 'ru'),
        announce: _longAnnounce,
      );
    default:
      return M3eCardData(
        providerName: 'dropweb',
        dot: M3eDotState.on,
        statusText: 'Подключено',
        statusVisible: false,
        timer: timer,
        planText: 'Безлимит · до 8 февраля 2027',
        ipFlag: '🇩🇪',
        ipAddress: '152.53.236.227',
        countryText: countryDisplayName('DE', 'ru'),
        announce: 'dropweb.org',
      );
  }
}

enum _Check { left, right, top, centerX, centerY, width, height }

class _Spec {
  const _Spec(this.name, this.key, this.refName, this.checks);

  final String name;
  final ValueKey<String> key;
  final String refName;
  final List<_Check> checks;
}

const _specs = [
  _Spec('card', M3eCardKeys.card, 'card', [_Check.width, _Check.height]),
  _Spec('name', M3eCardKeys.name, 'name',
      [_Check.left, _Check.top, _Check.height]),
  _Spec('timer', M3eCardKeys.timer, 'timer',
      [_Check.right, _Check.top, _Check.height]),
  _Spec('plan', M3eCardKeys.plan, 'plan',
      [_Check.left, _Check.top, _Check.width, _Check.height]),
  _Spec('meter', M3eCardKeys.meter, 'meter',
      [_Check.left, _Check.top, _Check.width, _Check.height]),
  _Spec('separator', M3eCardKeys.separator, 'sep',
      [_Check.left, _Check.top, _Check.width]),
  _Spec('bar', M3eCardKeys.bar, 'bar',
      [_Check.left, _Check.centerY, _Check.width]),
  _Spec('country', M3eCardKeys.country, 'loc', [_Check.left, _Check.centerY]),
  _Spec('flag', M3eCardKeys.flag, 'flag',
      [_Check.left, _Check.top, _Check.width, _Check.height]),
  _Spec('state', M3eCardKeys.state, 'state', [_Check.right, _Check.centerY]),
  _Spec(
      'dot', M3eCardKeys.dot, 'dot', [_Check.top, _Check.width, _Check.height]),
  // Цель нажатия 48 dp шире надписи: сверяем правый край и середину строки.
  _Spec('refresh', M3eCardKeys.refresh, 'act', [_Check.right, _Check.centerY]),
  _Spec('footer', M3eCardKeys.footer, 'foot',
      [_Check.left, _Check.top, _Check.width]),
];

double _value(Rect r, _Check c) => switch (c) {
      _Check.left => r.left,
      _Check.right => r.right,
      _Check.top => r.top,
      _Check.centerX => r.center.dx,
      _Check.centerY => r.center.dy,
      _Check.width => r.width,
      _Check.height => r.height,
    };

void main() {
  final ref = jsonDecode(File('test/m3e/ref/card-v4.json').readAsStringSync())
      as Map<String, dynamic>;
  final rows = <String>[];
  var worstDelta = 0.0;

  tearDownAll(() {
    final path = Platform.environment['M3E_CARD_V4_TABLE'];
    if (path == null || path.isEmpty) return;
    final b = StringBuffer()
      ..writeln('# Карточка Android: рамки против доски карточек №4')
      ..writeln()
      ..writeln('Допуск ±$_tolerance dp. Эталон: `test/m3e/ref/card-v4.json` '
          '(Playwright, доска карточек iOS-ветки), рамки относительно угла карточки.')
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
        final header = parseDropwebTheme(kBoardProviders[0].theme);
        final data = _hig(state, timer: '0:04');
        await pumpM3eBoard(
          tester,
          m3eBoardApp(
            seed: header.accent,
            filter: header.filter,
            brightness: brightness,
            child: Builder(
              builder: (context) => MediaQuery(
                // Эталон снят без движения: спиннер в позе покоя.
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, top: 108),
                    child: SizedBox(
                      width: 379,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          M3eSubCard(data: data, onRefresh: () {}),
                          M3eCardFooter(text: data.announce),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);

        final expected = ref['$state-$mode'] as Map<String, dynamic>;
        final origin = tester.getTopLeft(find.byKey(M3eCardKeys.card));
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
      });
    }
  }
}
