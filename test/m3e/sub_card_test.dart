import 'dart:math' as math;

import 'package:dropweb/common/country_name.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/m3e/color/theme_header.dart';
import 'package:dropweb/ui/m3e/m3e_format.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_meter.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sub_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gate_support.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';

/// Объявление провайдера: копия `ANNOUNCE` из android.js (27-35), в app.js оно не экспортируется.
const _announceNormal = 'dropweb.org';
const _announceWorst =
    'Добавили серверы в Казахстане и Турции. Старые адреса в Нидерландах отключим 1 ноября, '
    'до этого дня обновите подписку в приложении. Новости, ответы на частые вопросы в канале '
    'https://t.me/dropweb_news';

/// Сцена доски (`SCENES` в app.js), только поля, влияющие на карточку.
class _Scene {
  const _Scene(
    this.id, {
    this.home = 'off',
    this.switching = false,
    this.net = true,
    this.sub = 'ok',
  });

  final String id;
  final String home;
  final bool switching;
  final bool net;
  final String sub;
}

const _scenes = [
  _Scene('home-off'),
  _Scene('connecting', home: 'connecting'),
  _Scene('switching', home: 'connecting', switching: true),
  _Scene('home-on', home: 'on'),
  _Scene('error', home: 'error'),
  _Scene('offline', net: false),
  _Scene('expiring', sub: 'expiring'),
  _Scene('traffic-low', sub: 'traffic-low'),
  _Scene('traffic-out', sub: 'traffic-out'),
  _Scene('expired', sub: 'expired'),
];

/// Таймер на эталоне home-on: часы доски на паузе.
const _timerOnBoard = '12:49';

/// Данные карточки по правилам `homeHtml()` (android.js 403-441).
M3eCardData _cardFor(
  AppLocalizations l,
  _Scene s,
  BoardData d, {
  required bool worst,
}) {
  final on = s.home == 'on';
  final conn = s.home == 'connecting';
  final traffic = switch (s.sub) {
    'traffic-low' => kBoardTrafficLow,
    'traffic-out' => kBoardTrafficOut,
    _ => d.traffic,
  };
  final best = d.countries.firstWhere((c) => c.id == d.best);
  final bad = !s.net || (!conn && s.home == 'error');

  final String status;
  if (conn) {
    status = s.switching ? l.m3eStatusSwitching : l.m3eStatusConnecting;
  } else if (!s.net) {
    status = l.m3eStatusOffline;
  } else if (on) {
    status = l.m3eStatusConnected;
  } else if (s.home == 'error') {
    status = l.m3eStatusError;
  } else {
    status = l.m3eStatusDisconnected;
  }

  final plan = planLine(
    l,
    traffic: traffic == null
        ? null
        : M3eTrafficInfo(
            used: traffic.used,
            total: traffic.total,
            left: traffic.left,
            pct: traffic.pct,
          ),
    until: d.until,
    state: switch (s.sub) {
      'expired' => M3eSubState.expired,
      'traffic-out' => M3eSubState.trafficOut,
      'expiring' => M3eSubState.expiring,
      _ => M3eSubState.ok,
    },
  );

  // Без VPN адрес тоже свой, но на карточке он не рисуется: вместо него страна выхода
  // (решение владельца 2026-10-30), а без адреса прочерк.
  final none = conn || !s.net;
  final address = none
      ? l.m3eStatNone
      : on
          ? (worst ? '2a0e:97c0:3e3:4f1::1c' : '185.107.56.12')
          : '95.24.118.7';
  final code = on ? best.id.toUpperCase() : 'RU';
  final country = none ? l.m3eStatNone : countryDisplayName(code, 'ru');

  return M3eCardData(
    providerName: d.profiles[0],
    dot: conn
        ? M3eDotState.busy
        : bad
            ? M3eDotState.bad
            : on
                ? M3eDotState.on
                : M3eDotState.off,
    statusText: status,
    statusVisible: bad,
    timer: on ? _timerOnBoard : null,
    planText: plan.text,
    planTone: plan.tone,
    meterPercent: traffic?.pct,
    meterTone:
        traffic == null ? M3eMeterTone.normal : meterToneFor(traffic.pct),
    ipFlag: none ? null : (on ? best.flag : '🇷🇺'),
    ipAddress: address,
    countryText: country,
    // Подключение и переключение: страна определяется (правило модели `ipLoading`).
    ipLoading: conn && s.net,
    announce: worst ? _announceWorst : _announceNormal,
    showRefresh: plan.needsRefresh,
  );
}

/// Карточка с подвалом (16,108, ширина 379) на фоне кадра.
Widget _frame(
  M3eCardData data, {
  VoidCallback? onRefresh,
  void Function(Uri)? onLink,
}) =>
    Builder(
      builder: (context) => ColoredBox(
        color: M3eColors.of(context).home.bg,
        child: SizedBox.expand(
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
                    M3eSubCard(
                      data: data,
                      // Без обработчика кнопка рисуется выключенной, а на доске она живая.
                      onRefresh: onRefresh ?? () {},
                    ),
                    M3eCardFooter(text: data.announce, onLink: onLink),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

Widget _app(
  int provider,
  Brightness brightness,
  Widget child,
) {
  final header = parseDropwebTheme(kBoardProviders[provider].theme);
  return m3eBoardApp(
    seed: header.accent,
    filter: header.filter,
    brightness: brightness,
    child: child,
  );
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.load(const Locale('ru'));
  });

  group('golden: сцены доски', () {
    for (final scene in _scenes) {
      for (final brightness in Brightness.values) {
        for (final p in const [0, 5]) {
          final name = 'card_${scene.id}_${brightness.name}_p$p';
          testWidgets(name, (tester) async {
            final data = _cardFor(
              l,
              scene,
              kBoardNormal,
              worst: false,
            );
            await pumpM3eBoard(tester, _app(p, brightness, _frame(data)));
            expect(tester.takeException(), isNull);
            await expectM3eGolden(tester, name);
          });
        }
      }
    }
  });

  group('golden: худшие данные', () {
    for (final scene in [_scenes[0], _scenes[3]]) {
      for (final brightness in Brightness.values) {
        final name = 'card_worst_${scene.id}_${brightness.name}_p0';
        testWidgets(name, (tester) async {
          final data = _cardFor(
            l,
            scene,
            kBoardWorst,
            worst: true,
          );
          await pumpM3eBoard(tester, _app(0, brightness, _frame(data)));
          // Переполнение строки сообщается как исключение кадра.
          expect(tester.takeException(), isNull);
          // Страна на худших данных не обрезана многоточием.
          final text = find.descendant(
            of: find.byKey(M3eCardKeys.country),
            matching: find.byType(RichText),
          );
          // Первым идёт глиф флага, название страны последним.
          final paragraph = tester.renderObject<RenderParagraph>(text.last);
          expect(paragraph.didExceedMaxLines, isFalse,
              reason: 'страна обрезана');
          await expectM3eGolden(tester, name);
        });
      }
    }
  });

  group('поведение', () {
    testWidgets('таймер простым текстом, слово статуса справа без пульса',
        (tester) async {
      final on = _cardFor(l, _scenes[3], kBoardNormal, worst: false);
      final handle = tester.ensureSemantics();
      await pumpM3eBoard(tester, _app(0, Brightness.light, _frame(on)));
      await tester.pump();
      final timer = find.byKey(M3eCardKeys.timer);
      expect(timer, findsOneWidget);
      expect(tester.widget<Text>(timer).data, '12:49');
      // Слово статуса стоит справа внизу, а не вместо таймера.
      expect(
        find.descendant(
            of: find.byKey(M3eCardKeys.state),
            matching: find.text(l.m3eStatusConnected)),
        findsOneWidget,
      );
      // Живая область держит «Подключено» для диктора, но таймер в ней не читается.
      expect(
        find.semantics.byPredicate((n) =>
            n.flagsCollection.isLiveRegion && n.label == l.m3eStatusConnected),
        findsOneWidget,
      );
      expect(
        find.semantics.byPredicate(
            (n) => n.flagsCollection.isLiveRegion && n.label.contains('12:49')),
        findsNothing,
        reason: 'таймер читается диктором каждую секунду',
      );
      handle.dispose();

      final err = _cardFor(l, _scenes[4], kBoardNormal, worst: false);
      await tester.pumpWidget(_app(0, Brightness.light, _frame(err)));
      await tester.pump();
      expect(find.byKey(M3eCardKeys.timer), findsNothing);
      expect(
        find.descendant(
            of: find.byKey(M3eCardKeys.state),
            matching: find.text(l.m3eStatusError)),
        findsOneWidget,
      );
    });

    testWidgets('«Обновить» вместо статуса, цель нажатия не меньше 48 dp',
        (tester) async {
      var taps = 0;
      final expired = _cardFor(l, _scenes[9], kBoardNormal, worst: false);
      await pumpM3eBoard(
        tester,
        _app(0, Brightness.light, _frame(expired, onRefresh: () => taps++)),
      );
      expect(find.text(l.m3eRefresh), findsOneWidget);
      // Слово статуса и «Обновить» не бывают вместе.
      expect(find.byKey(M3eCardKeys.state), findsNothing);
      expect(
        tester.getSize(find.byKey(M3eCardKeys.refresh)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byKey(M3eCardKeys.refresh));
      await tester.pump();
      expect(taps, 1);

      final ok = _cardFor(l, _scenes[0], kBoardNormal, worst: false);
      await tester.pumpWidget(_app(0, Brightness.light, _frame(ok)));
      await tester.pump();
      expect(find.text(l.m3eRefresh), findsNothing);
      expect(find.byKey(M3eCardKeys.refresh), findsNothing);
      expect(find.byKey(M3eCardKeys.state), findsOneWidget);
    });

    testWidgets('«Обновить» отдельная кнопка для диктора', (tester) async {
      final handle = tester.ensureSemantics();
      final expired = _cardFor(l, _scenes[9], kBoardNormal, worst: false);
      await pumpM3eBoard(
        tester,
        _app(0, Brightness.light, _frame(expired, onRefresh: () {})),
      );
      final button = find.semantics.byPredicate(
          (n) => n.label == l.m3eRefresh && n.flagsCollection.isButton);
      expect(button, findsOneWidget);
      handle.dispose();
    });

    testWidgets('пока страна определяется: «Подключение…», статуса нет',
        (tester) async {
      final conn = _cardFor(l, _scenes[1], kBoardNormal, worst: false);
      await pumpM3eBoard(tester, _app(0, Brightness.light, _frame(conn)));
      expect(conn.ipLoading, isTrue);
      expect(find.text(l.m3eStatusConnecting), findsOneWidget);
      expect(find.byKey(M3eCardKeys.state), findsNothing);
      expect(find.byKey(M3eCardKeys.refresh), findsNothing);
    });

    testWidgets('нет сети: «—» вместо страны, красное слово статуса',
        (tester) async {
      final off = _cardFor(l, _scenes[5], kBoardNormal, worst: false);
      await pumpM3eBoard(tester, _app(0, Brightness.light, _frame(off)));
      expect(
        find.descendant(
            of: find.byKey(M3eCardKeys.country),
            matching: find.text(l.m3eStatNone)),
        findsOneWidget,
      );
      expect(find.byKey(M3eCardKeys.flag), findsNothing);
      expect(
        find.descendant(
            of: find.byKey(M3eCardKeys.state),
            matching: find.text(l.m3eStatusOffline)),
        findsOneWidget,
      );
    });

    testWidgets('карточка читается одной фразой, адреса в семантике нет',
        (tester) async {
      final handle = tester.ensureSemantics();
      final off = _cardFor(l, _scenes[0], kBoardNormal, worst: false);
      await pumpM3eBoard(tester, _app(0, Brightness.light, _frame(off)));
      expect(
        find.semantics.byLabel(
          'DROPWEB. Безлимит · бессрочно. Страна: Россия. Не подключено.',
        ),
        findsOneWidget,
      );
      // «Страна» с двоеточием входит в фразу, а прежние подписи колонок не читаются.
      expect(
        find.semantics.byPredicate((n) => n.label.contains('95.24.118.7')),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('фраза карточки по сценам', (tester) async {
      final on = _cardFor(l, _scenes[3], kBoardNormal, worst: false);
      expect(
        m3eCardLabel(l, on),
        'DROPWEB. Безлимит · бессрочно. Страна: Нидерланды. Подключено.',
      );
      final conn = _cardFor(l, _scenes[1], kBoardNormal, worst: false);
      // Определение страны: статус не дублируем, «…» не получает точку.
      expect(
        m3eCardLabel(l, conn),
        'DROPWEB. Безлимит · бессрочно. ${l.m3eStatusConnecting}',
      );
      final offline = _cardFor(l, _scenes[5], kBoardNormal, worst: false);
      expect(
        m3eCardLabel(l, offline),
        'DROPWEB. Безлимит · бессрочно. ${l.m3eStatusOffline}.',
      );
    });

    testWidgets('адреса нет ни на экране, ни в семантике ни в одной сцене',
        (tester) async {
      final handle = tester.ensureSemantics();
      for (final scene in _scenes) {
        final data = _cardFor(l, scene, kBoardNormal, worst: false);
        await pumpM3eBoard(tester, _app(0, Brightness.light, _frame(data)));
        for (final ip in const ['185.107.56.12', '95.24.118.7']) {
          expect(find.textContaining(ip), findsNothing, reason: scene.id);
          expect(
            find.semantics.byPredicate((n) => n.label.contains(ip)),
            findsNothing,
            reason: scene.id,
          );
        }
      }
      handle.dispose();
    });

    testWidgets('объявление в подвале сразу под карточкой', (tester) async {
      final data = _cardFor(l, _scenes[0], kBoardNormal, worst: false);
      await pumpM3eBoard(tester, _app(0, Brightness.light, _frame(data)));
      final card = tester.getRect(find.byKey(M3eCardKeys.card));
      final footer = tester.getRect(find.byKey(M3eCardKeys.footer));
      expect(footer.top, closeTo(card.bottom, 0.01));
      expect(footer.left, closeTo(card.left, 0.01));
      expect(footer.width, closeTo(card.width, 0.01));
      // Объявления внутри карточки больше нет.
      expect(
        find.descendant(
            of: find.byKey(M3eCardKeys.card),
            matching: find.text(_announceNormal)),
        findsNothing,
      );
      expect(
        find.descendant(
            of: find.byKey(M3eCardKeys.footer),
            matching: find.textContaining(_announceNormal)),
        findsOneWidget,
      );
    });

    testWidgets('пустое объявление: подвала нет', (tester) async {
      final base = _cardFor(l, _scenes[0], kBoardNormal, worst: false);
      final empty = M3eCardData(
        providerName: base.providerName,
        dot: base.dot,
        statusText: base.statusText,
        statusVisible: base.statusVisible,
        planText: base.planText,
        ipAddress: base.ipAddress,
        countryText: base.countryText,
        announce: '',
      );
      await pumpM3eBoard(tester, _app(0, Brightness.light, _frame(empty)));
      expect(find.byKey(M3eCardKeys.footer), findsNothing);
    });

    testWidgets('ссылка в подвале подчёркнута и отдаёт Uri', (tester) async {
      Uri? opened;
      final worst = _cardFor(l, _scenes[0], kBoardWorst, worst: true);
      await pumpM3eBoard(
        tester,
        _app(0, Brightness.light, _frame(worst, onLink: (u) => opened = u)),
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(M3eCardKeys.footerText),
          matching: find.byType(Text),
        ),
      );
      final taps = <TapGestureRecognizer>[];
      text.textSpan!.visitChildren((span) {
        if (span is TextSpan && span.recognizer is TapGestureRecognizer) {
          expect(span.style?.decoration, TextDecoration.underline);
          taps.add(span.recognizer! as TapGestureRecognizer);
        }
        return true;
      });
      expect(taps, hasLength(1));
      taps.single.onTap!();
      expect(opened, Uri.parse('https://t.me/dropweb_news'));
    });

    testWidgets('без обработчика ссылка видна, но не нажимается',
        (tester) async {
      final worst = _cardFor(l, _scenes[0], kBoardWorst, worst: true);
      await pumpM3eBoard(tester, _app(0, Brightness.light, _frame(worst)));
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(M3eCardKeys.footerText),
          matching: find.byType(Text),
        ),
      );
      var links = 0;
      text.textSpan!.visitChildren((span) {
        if (span is TextSpan && span.recognizer is TapGestureRecognizer) {
          links++;
          expect((span.recognizer! as TapGestureRecognizer).onTap, isNull);
        }
        return true;
      });
      expect(links, 1);
    });

    testWidgets('в нижней строке страна, а не адрес и не трафик',
        (tester) async {
      final on = _cardFor(l, _scenes[3], kBoardNormal, worst: false);
      await pumpM3eBoard(tester, _app(0, Brightness.light, _frame(on)));
      expect(find.text('Нидерланды'), findsOneWidget);
      expect(find.text('185.107.56.12'), findsNothing);
      expect(find.text(l.m3eStatIp), findsNothing);
      expect(find.text(l.m3eStatTraffic), findsNothing);
    });
  });

  group('контраст слова статуса', () {
    // Слово статуса 13 sp: нужен контраст 4,5:1 на заливке карточки в обеих темах;
    // цвет состояния, который столько не набирает, уступает основному цвету.
    double lum(Color c) {
      double f(double v) => v <= .03928
          ? v / 12.92
          : math.pow((v + .055) / 1.055, 2.4).toDouble();
      return .2126 * f(c.r) + .7152 * f(c.g) + .0722 * f(c.b);
    }

    double ratio(Color a, Color b) {
      final x = lum(a), y = lum(b);
      return (math.max(x, y) + .05) / (math.min(x, y) + .05);
    }

    for (final brightness in Brightness.values) {
      for (final scene in [3, 4, 0]) {
        testWidgets('${brightness.name}: сцена $scene', (tester) async {
          late Color card;
          final data = _cardFor(l, _scenes[scene], kBoardNormal, worst: false);
          await pumpM3eBoard(
            tester,
            _app(
              0,
              brightness,
              Builder(builder: (context) {
                card = M3eColors.of(context).home.card;
                return _frame(data);
              }),
            ),
          );
          final word = tester.widget<Text>(find.descendant(
            of: find.byKey(M3eCardKeys.state),
            matching: find.byType(Text),
          ));
          expect(
            ratio(word.style!.color!, card),
            greaterThanOrEqualTo(4.5),
            reason: '${brightness.name}: слово «${word.data}» на карточке',
          );
        });
      }
    }
  });

  group('масштаб текста приложения', () {
    // Данные владельца 2026-10-29: масштаб приложения до 1,4, системный 1,15 и выше.
    M3eCardData owner({
      String country = 'Германия',
      String? flag = '🇩🇪',
      String ip = '152.53.236.227',
    }) =>
        M3eCardData(
          providerName: 'dropweb',
          dot: M3eDotState.on,
          statusText: l.m3eStatusConnected,
          statusVisible: false,
          timer: '3:07',
          planText: 'Безлимит · до 16 декабря 2026',
          ipFlag: flag,
          ipAddress: ip,
          countryText: country,
          announce: 'dropweb.org',
        );

    // Худший случай для строки: самое длинное название, маска IPv6 без флага, прочерк.
    final variants = <(String, M3eCardData Function())>[
      ('Германия', owner),
      (
        'длинное название',
        () => owner(country: 'Центральноафриканская Республика'),
      ),
      (
        'маска IPv6 без флага',
        () => owner(
              country: maskIpAddress('2a0e:97c0:3e3:4f1::1c'),
              flag: null,
              ip: '2a0e:97c0:3e3:4f1::1c',
            ),
      ),
      ('прочерк', () => owner(country: '—', flag: null, ip: '—')),
    ];

    Widget scaled(double scale, M3eCardData data) => Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: _frame(data),
          ),
        );

    /// Все `Text` карточки: бокс не ниже строки шрифта, значит верх и низ глифов не срезаны.
    void expectBoxesFitLines(WidgetTester tester, double scale) {
      final card = find.byKey(M3eCardKeys.card);
      for (final e in find
          .descendant(of: card, matching: find.byType(RichText))
          .evaluate()) {
        final paragraph = e.renderObject! as RenderParagraph;
        final style = paragraph.text.style;
        if (style == null || style.fontSize == null || style.height == null) {
          continue;
        }
        // Свой масштаб у абзаца: глиф флага считает размер сам (noScaling).
        final line =
            paragraph.textScaler.scale(style.fontSize!) * style.height!;
        expect(
          paragraph.size.height,
          greaterThanOrEqualTo(line - 0.5),
          reason: '«${paragraph.text.toPlainText()}» при x$scale ниже строки',
        );
      }
    }

    for (final scale in const [0.8, 1.0, 1.15, 1.4, 2.0]) {
      for (final (name, build) in variants) {
        testWidgets('x$scale $name: без переполнений, ничего не срезано',
            (tester) async {
          final data = build();
          await pumpM3eBoard(
            tester,
            _app(5, Brightness.dark, scaled(scale, data)),
          );
          expect(tester.takeException(), isNull);
          expectBoxesFitLines(tester, scale);
          // Название страны переносится на следующую строку, а не выходит за карточку.
          final value = find.descendant(
            of: find.byKey(M3eCardKeys.country),
            matching: find.text(data.countryText),
          );
          expect(value, findsOneWidget);
          final card = tester.getRect(find.byKey(M3eCardKeys.card));
          expect(tester.getRect(value).right, lessThanOrEqualTo(card.right));
          expect(card.right, lessThanOrEqualTo(411));
        });
      }
    }

    testWidgets('с ростом масштаба карточка растёт вниз', (tester) async {
      final heights = <double>[];
      for (final scale in const [1.0, 1.15, 1.4, 2.0]) {
        await pumpM3eBoard(
          tester,
          _app(0, Brightness.light, scaled(scale, owner())),
        );
        heights.add(tester.getSize(find.byKey(M3eCardKeys.card)).height);
      }
      for (var i = 1; i < heights.length; i++) {
        expect(heights[i], greaterThan(heights[i - 1]), reason: '$heights');
      }
      expect(heights.first, closeTo(117, 4));
    });

    testWidgets('x2.0: длинное название переносится, а не обрезается',
        (tester) async {
      await pumpM3eBoard(
        tester,
        _app(
          5,
          Brightness.dark,
          scaled(2.0, owner(country: 'Центральноафриканская Республика')),
        ),
      );
      expect(tester.takeException(), isNull);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(M3eCardKeys.country),
          matching: find.text('Центральноафриканская Республика'),
        ),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.size.height,
          greaterThan(paragraph.textScaler.scale(15) * 20 / 15 * 1.5),
          reason: 'название должно занять больше одной строки');
    });

    testWidgets('golden x1.4 тёмная p5', (tester) async {
      await pumpM3eBoard(
        tester,
        _app(5, Brightness.dark, scaled(1.4, owner())),
      );
      await expectM3eGolden(tester, 'card_scale_140_dark_p5');
    });

    testWidgets('golden x2.0 светлая p0 с кнопкой Обновить и причиной',
        (tester) async {
      final data = owner(
        country: 'Центральноафриканская Республика',
        ip: '2a0e:97c0:3e3:4f1::1c',
      );
      final expired = M3eCardData(
        providerName: data.providerName,
        dot: M3eDotState.bad,
        statusText: l.m3eStatusError,
        statusVisible: true,
        planText: l.m3ePlanExpired,
        planTone: M3ePlanTone.bad,
        ipFlag: data.ipFlag,
        ipAddress: data.ipAddress,
        countryText: data.countryText,
        announce: data.announce,
        showRefresh: true,
      );
      await pumpM3eBoard(
        tester,
        _app(0, Brightness.light, scaled(2.0, expired)),
      );
      expect(tester.takeException(), isNull);
      await expectM3eGolden(tester, 'card_scale_200_light_p0');
    });

    // Главная целиком на 411x914: карточка растёт вниз и не должна наезжать на ряд кнопок.
    // При 1,4 (максимум настройки приложения) проверяем худшие данные, при системных 2,0
    // только обычные: худший текст объявления на 2,0 не помещается в экран 411x914
    // (карточка высотой больше экрана), это вынесено в отчёт.
    for (final (scale, worst) in const [(1.4, true), (2.0, false)]) {
      for (final scene in const ['home-on', 'error', 'expired']) {
        testWidgets('главная x$scale $scene: карточка выше ряда кнопок',
            (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpM3eBoard(
            tester,
            gateHomeApp(scene, brightness: Brightness.dark, worst: worst),
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
          // Карточка и подвал с объявлением меряются вместе.
          final footer = find.byKey(M3eCardKeys.footer).evaluate().isNotEmpty
              ? tester.getRect(find.byKey(M3eCardKeys.footer)).bottom
              : tester.getRect(find.byKey(M3eCardKeys.card)).bottom;
          final joy = tester.getRect(find.byKey(kM3eJoyKey));
          expect(footer, lessThanOrEqualTo(joy.top),
              reason: 'карточка с подвалом наезжает на ряд кнопок');
        });
      }
    }
  });
}
