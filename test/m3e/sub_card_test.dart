import 'dart:convert';
import 'dart:io';

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

  // Без VPN показываем настоящий адрес: видно, что трафик идёт напрямую.
  final none = conn || !s.net;
  final address = none
      ? l.m3eStatNone
      : on
          ? (worst ? '2a0e:97c0:3e3:4f1::1c' : '185.107.56.12')
          : '95.24.118.7';
  final usedGb = switch (s.sub) {
    'traffic-low' => 49.2,
    'traffic-out' => 50.0,
    _ => d.usedGB,
  };

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
    ipLong: address.contains(':'),
    trafficText: gbText(l, usedGb),
    announce: worst ? _announceWorst : _announceNormal,
    showRefresh: plan.needsRefresh,
  );
}

/// Карточка на месте доски (16,108, ширина 379) на фоне кадра.
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
                child: M3eSubCard(
                  data: data,
                  // Без обработчика кнопка рисуется выключенной, а на доске она живая.
                  onRefresh: onRefresh ?? () {},
                  onLink: onLink,
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
          // Числа в показателях не обрезаны многоточием.
          for (var i = 0; i < 2; i++) {
            final text = find.descendant(
              of: find.byKey(M3eCardKeys.statValue(i)),
              matching: find.byType(RichText),
            );
            // В IP первым идёт глиф флага, значение последним.
            final paragraph = tester.renderObject<RenderParagraph>(text.last);
            expect(paragraph.didExceedMaxLines, isFalse,
                reason: 'значение $i обрезано');
          }
          await expectM3eGolden(tester, name);
        });
      }
    }
  });

  group('паритет раскладки с layout.json (±4 dp)', () {
    final layout =
        jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
            as Map<String, dynamic>;

    const tolerance = 4.0;
    const named = <String, ValueKey<String>>{
      'card': M3eCardKeys.card,
      'card.head': M3eCardKeys.head,
      'card.plan': M3eCardKeys.plan,
      'card.line': M3eCardKeys.line,
      'card.meter': M3eCardKeys.meter,
      'card.stats': M3eCardKeys.stats,
      'card.sub': M3eCardKeys.sub,
      'card.site': M3eCardKeys.site,
      'card.refresh': M3eCardKeys.refresh,
      'card.name': M3eCardKeys.name,
      'card.state': M3eCardKeys.state,
      'card.dot': M3eCardKeys.dot,
      'card.timer': M3eCardKeys.timer,
      'card.why': M3eCardKeys.why,
    };

    void expectRect(Rect actual, Map<String, dynamic> ref, String what) {
      final r = {
        'x': actual.left,
        'y': actual.top,
        'w': actual.width,
        'h': actual.height,
      };
      for (final k in r.keys) {
        expect(
          r[k],
          closeTo((ref[k] as num).toDouble(), tolerance),
          reason: '$what.$k: у нас ${r[k]}, на доске ${ref[k]}',
        );
      }
    }

    for (final id in const ['home-off', 'home-on', 'error', 'expired']) {
      testWidgets('$id-light-p0', (tester) async {
        final scene = _scenes.firstWhere((s) => s.id == id);
        final data = _cardFor(
          l,
          scene,
          kBoardNormal,
          worst: false,
        );
        await pumpM3eBoard(tester, _app(0, Brightness.light, _frame(data)));
        expect(tester.takeException(), isNull);

        final elements = (layout['$id-light-p0']
            as Map<String, dynamic>)['elements'] as Map<String, dynamic>;
        for (final e in named.entries) {
          final ref = elements[e.key];
          final finder = find.byKey(e.value);
          if (ref == null) {
            expect(finder, findsNothing, reason: '${e.key} не должно быть');
          } else {
            expect(finder, findsOneWidget, reason: '${e.key} нет в дереве');
            expectRect(
                tester.getRect(finder), ref as Map<String, dynamic>, e.key);
          }
        }
        // Пинг убран с карточки по решению владельца 2026-10-29: вместо трёх равных
        // колонок доски две (адрес занимает остаток, трафик по своей ширине), поэтому
        // x и w показателей не сверяем. Строка показателей не должна съехать по вертикали.
        for (final group in const ['stat', 'statValue']) {
          final refs = elements['card.$group'] as List<dynamic>;
          for (var i = 0; i < 2; i++) {
            final key = group == 'stat'
                ? M3eCardKeys.stat(i)
                : M3eCardKeys.statValue(i);
            final actual = tester.getRect(find.byKey(key));
            final ref = refs[i] as Map<String, dynamic>;
            expect(actual.top, closeTo((ref['y'] as num).toDouble(), tolerance),
                reason: 'card.$group.$i.y');
            expect(
                actual.height, closeTo((ref['h'] as num).toDouble(), tolerance),
                reason: 'card.$group.$i.h');
          }
        }
      });
    }
  });

  group('поведение', () {
    testWidgets('таймер вне живой области, причина ошибки внутри',
        (tester) async {
      final on = _cardFor(l, _scenes[3], kBoardNormal, worst: false);
      final handle = tester.ensureSemantics();
      await pumpM3eBoard(tester, _app(0, Brightness.light, _frame(on)));
      await tester.pump();
      expect(find.byKey(M3eCardKeys.timer), findsOneWidget);
      expect(find.byKey(M3eCardKeys.why), findsNothing);
      // Живая область держит «Подключено» для диктора, но на экране её нет.
      final live = find.semantics.byPredicate((n) =>
          n.flagsCollection.isLiveRegion && n.label == l.m3eStatusConnected);
      expect(live, findsOneWidget);
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
      expect(find.text(l.m3eStatusError), findsOneWidget);
    });

    testWidgets('«Обновить» только когда нужна, нажатие доходит',
        (tester) async {
      var taps = 0;
      final expired = _cardFor(l, _scenes[9], kBoardNormal, worst: false);
      await pumpM3eBoard(
        tester,
        _app(0, Brightness.light, _frame(expired, onRefresh: () => taps++)),
      );
      expect(find.text(l.m3eRefresh), findsOneWidget);
      await tester.tap(find.byKey(M3eCardKeys.refresh));
      await tester.pump();
      expect(taps, 1);

      final ok = _cardFor(l, _scenes[0], kBoardNormal, worst: false);
      await tester.pumpWidget(_app(0, Brightness.light, _frame(ok)));
      await tester.pump();
      expect(find.text(l.m3eRefresh), findsNothing);
      expect(find.byKey(M3eCardKeys.refresh), findsNothing);
    });

    testWidgets('ссылка в объявлении отдаёт Uri', (tester) async {
      Uri? opened;
      final worst = _cardFor(l, _scenes[0], kBoardWorst, worst: true);
      await pumpM3eBoard(
        tester,
        _app(0, Brightness.light, _frame(worst, onLink: (u) => opened = u)),
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(M3eCardKeys.site),
          matching: find.byType(Text),
        ),
      );
      final taps = <TapGestureRecognizer>[];
      text.textSpan!.visitChildren((span) {
        if (span is TextSpan && span.recognizer is TapGestureRecognizer) {
          taps.add(span.recognizer! as TapGestureRecognizer);
        }
        return true;
      });
      expect(taps, hasLength(1));
      taps.single.onTap!();
      expect(opened, Uri.parse('https://t.me/dropweb_news'));
    });

    testWidgets('значения показателей хранят неразрывный пробел',
        (tester) async {
      final on = _cardFor(l, _scenes[3], kBoardNormal, worst: false);
      await pumpM3eBoard(tester, _app(0, Brightness.light, _frame(on)));
      expect(find.text('0,23\u00a0ГБ'), findsOneWidget);
      expect(find.text('185.107.56.12'), findsOneWidget);
    });
  });

  group('масштаб текста приложения', () {
    // Данные владельца 2026-10-29: масштаб приложения до 1,4, системный 1,15 и выше.
    M3eCardData owner({String ip = '152.53.236.227', bool long = false}) =>
        M3eCardData(
          providerName: 'dropweb',
          dot: M3eDotState.on,
          statusText: l.m3eStatusConnected,
          statusVisible: false,
          timer: '3:07',
          planText: 'Безлимит · до 16 декабря 2026',
          ipFlag: '🇩🇪',
          ipAddress: ip,
          ipLong: long,
          trafficText: gbText(l, 344.4, locale: 'ru'),
          announce: 'dropweb.org',
        );

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
      for (final long in const [false, true]) {
        testWidgets(
            'x$scale ${long ? 'IPv6' : 'IPv4'}: без переполнений, ничего не срезано',
            (tester) async {
          final data = owner(
            ip: long ? '2a0e:97c0:3e3:4f1::1c' : '152.53.236.227',
            long: long,
          );
          await pumpM3eBoard(
            tester,
            _app(5, Brightness.dark, scaled(scale, data)),
          );
          expect(tester.takeException(), isNull);
          expectBoxesFitLines(tester, scale);
          // Трафик целиком, без многоточия.
          for (final i in [1]) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: find.byKey(M3eCardKeys.statValue(i)),
                matching: find.byType(RichText),
              ),
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: 'значение $i');
          }
          // Карточка внутри экрана по ширине.
          final rect = tester.getRect(find.byKey(M3eCardKeys.card));
          expect(rect.right, lessThanOrEqualTo(411));
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
      expect(heights.first, closeTo(189, 4));
    });

    testWidgets('x1.4: IPv4 ужимается, но не обрезается многоточием',
        (tester) async {
      await pumpM3eBoard(
        tester,
        _app(5, Brightness.dark, scaled(1.4, owner())),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(M3eCardKeys.statValue(0)),
          matching: find.text('152.53.236.227'),
        ),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
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
      final data = owner(ip: '2a0e:97c0:3e3:4f1::1c', long: true);
      final expired = M3eCardData(
        providerName: data.providerName,
        dot: M3eDotState.bad,
        statusText: l.m3eStatusError,
        statusVisible: true,
        planText: l.m3ePlanExpired,
        planTone: M3ePlanTone.bad,
        ipFlag: data.ipFlag,
        ipAddress: data.ipAddress,
        ipLong: true,
        trafficText: data.trafficText,
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
          final card = tester.getRect(find.byKey(M3eCardKeys.card));
          final joy = tester.getRect(find.byKey(kM3eJoyKey));
          expect(card.bottom, lessThanOrEqualTo(joy.top),
              reason: 'карточка наезжает на ряд кнопок');
        });
      }
    }
  });
}
