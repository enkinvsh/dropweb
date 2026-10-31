// Карточка главной iOS (№4 «Компактная плашка»): golden на 9 сцен × светлая/тёмная и WORST-данные.
// Рамки против доски карточек — `card_v4_parity_test.dart`.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dropweb/common/country_name.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card_data.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_footer_colors.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/board_providers.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';
import 'support/layout.dart';
import 'support/surface.dart';

/// Сцены главной, где на доске есть карточка (`empty` — отдельный экран без неё).
const _scenes = [
  'home-off',
  'connecting',
  'home-on',
  'error',
  'offline',
  'expiring',
  'traffic-low',
  'traffic-out',
  'expired',
];

/// Данные карточки сцены с доски: тексты из `board_fixtures.dart` (app.js:481-531).
Ios27CardData sceneData(
  String scene, {
  Ios27BoardData board = kIos27BoardNormal,
  DateTime? since,
  Ios27BoardTraffic? traffic,
}) {
  final t = traffic ??
      switch (scene) {
        'traffic-low' => kIos27BoardTrafficLow,
        'traffic-out' => kIos27BoardTrafficOut,
        _ => board.traffic,
      };
  final sub = switch (scene) {
    'expired' => 'expired',
    'traffic-out' => 'traffic-out',
    'expiring' => 'expiring',
    _ => null,
  };
  final plan = ios27BoardPlanLine(board, traffic: t, sub: sub);
  final tone = sub == 'expired' || sub == 'traffic-out'
      ? Ios27CardTone.bad
      : (sub == 'expiring' || (t != null && t.pct > 90))
          ? Ios27CardTone.warn
          : Ios27CardTone.normal;
  final on = scene == 'home-on';
  final connecting = scene == 'connecting';
  final offline = scene == 'offline';
  final bad = scene == 'error' || offline;

  return Ios27CardData(
    title: board.profiles.first,
    dot: on
        ? Ios27DotKind.on
        : connecting
            ? Ios27DotKind.busy
            : bad
                ? Ios27DotKind.bad
                : Ios27DotKind.off,
    statusText: on
        ? kIos27BoardStatusOn
        : connecting
            ? kIos27BoardStatusConnecting
            : scene == 'error'
                ? kIos27BoardStatusError
                : offline
                    ? kIos27BoardStatusNoNetwork
                    : kIos27BoardStatusOff,
    since: on ? since : null,
    planText: plan,
    planTone: tone,
    meterPercent: t?.pct,
    countryLabel: 'Страна',
    countryText: offline || connecting
        ? null
        : countryDisplayName(on ? 'NL' : 'RU', 'ru'),
    countryFlag: offline || connecting
        ? ''
        : on
            ? '🇳🇱'
            : kIos27BoardFlagOff,
    countryPending: connecting,
    countryLoadingLabel: kIos27BoardStatusConnecting,
    announce: board.announce,
    refreshLabel: sub == 'expired' || sub == 'traffic-out' ? 'Обновить' : null,
    semanticsLabel: 'Подключение и подписка',
  );
}

/// Кадр доски 411×914 с карточкой на её месте (`Positioned(16, 108, 379)`) поверх плоского `--bg`.
/// Под карточкой, как на экране, стоит подвал с объявлением.
Widget _frame(Ios27CardData data, {DateTime Function()? now}) => Builder(
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
                    now: now ?? DateTime.now,
                    onRefresh: () {},
                  ),
                  Ios27CardFooter(text: data.announce, onLink: (_) {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );

Ios27CardData _withoutAnnounce(Ios27CardData d) => Ios27CardData(
      title: d.title,
      dot: d.dot,
      statusText: d.statusText,
      planText: d.planText,
      planTone: d.planTone,
      meterPercent: d.meterPercent,
      countryLabel: d.countryLabel,
      countryText: d.countryText,
      countryFlag: d.countryFlag,
      countryLoadingLabel: d.countryLoadingLabel,
      semanticsLabel: d.semanticsLabel,
    );

/// Все `TextSpan` текста, включая вложенные: `Text.rich` оборачивает свои дети ещё одним уровнем.
List<TextSpan> _spans(RichText text) {
  final out = <TextSpan>[];
  text.text.visitChildren((span) {
    if (span is TextSpan) {
      out.add(span);
    }
    return true;
  });
  return out;
}

Finder _byKey(ValueKey<String> k) => find.byKey(k);

/// Снимок корня в байтах (RGBA) для побайтового сравнения p0 и p5.
Future<Uint8List> _rootBytes(WidgetTester tester) async {
  final element = tester.element(find.byKey(kIos27BoardRootKey));
  final box = element.renderObject! as RenderRepaintBoundary;
  final image = (await tester.runAsync<ui.Image>(
    () => box.toImage(pixelRatio: tester.view.devicePixelRatio),
  ))!;
  final data = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  return data.buffer.asUint8List();
}

Future<void> _pumpScene(
  WidgetTester tester,
  String scene,
  Brightness brightness, {
  int provider = 0,
}) async {
  final since = scene == 'home-on'
      // 12 мин 49 с: ровно то, что показывает доска на снимке (app.js:252).
      ? tester.binding.clock
          .now()
          .subtract(const Duration(minutes: 12, seconds: 49))
      : null;
  await pumpIos27Board(
    tester,
    ios27BoardApp(
      brightness: brightness,
      theme: Ios27ProviderTheme.fromHeader(kBoardProviders[provider].theme),
      // Эталоны сняты с reducedMotion: без кольца точки.
      disableAnimations: true,
      child: _frame(
        sceneData(scene, since: since),
        now: tester.binding.clock.now,
      ),
    ),
  );
}

void main() {
  for (final scene in _scenes) {
    for (final brightness in Brightness.values) {
      final mode = brightness.name;
      testWidgets('golden: $scene / $mode', (tester) async {
        try {
          await _pumpScene(tester, scene, brightness);
          expect(tester.takeException(), isNull);
          await expectIos27Golden(tester, 'card_${scene}_$mode');
        } finally {
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }

  testWidgets('карточка не зависит от провайдера (p0 и p5 побайтово равны)',
      (tester) async {
    try {
      for (final scene in ['home-off', 'home-on', 'traffic-low', 'error']) {
        await _pumpScene(tester, scene, Brightness.light);
        final p0 = await _rootBytes(tester);
        await _pumpScene(tester, scene, Brightness.light, provider: 5);
        final p5 = await _rootBytes(tester);
        expect(p5, p0,
            reason: 'сцена $scene: на карточке нет цвета провайдера');
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('empty: на доске карточки нет, в layout.json её тоже нет',
      (tester) async {
    final layout = Ios27RefLayout.load('empty-light-rt-p0');
    expect(layout.all('card'), isEmpty);
  });

  // Картинки для глаз: самый длинный набор на iPhone среднего размера при крупном шрифте.
  for (final entry in {
    'home-on': 1.4,
    'traffic-out': 2.0,
  }.entries) {
    testWidgets('golden WORST: ${entry.key} ×${entry.value}', (tester) async {
      try {
        await pumpIos27Board(
          tester,
          ios27BoardApp(
            brightness: Brightness.light,
            textScale: entry.value,
            device: kIos27IphoneLarge,
            disableAnimations: true,
            child: Builder(
              builder: (context) => ColoredBox(
                color: Ios27Colors.of(context).palette.bg,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                    child: Ios27Card(
                      data: sceneData(
                        entry.key,
                        board: kIos27BoardWorst,
                        since: DateTime(2026),
                      ),
                      now: () => DateTime(2026).add(
                        const Duration(hours: 10, minutes: 5, seconds: 9),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          device: kIos27IphoneLarge,
        );
        expect(tester.takeException(), isNull);
        await expectIos27Golden(
          tester,
          'card_worst_${entry.key}_x${entry.value}',
          device: kIos27IphoneLarge,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    });
  }

  group('WORST', () {
    Ios27CardData worst(String scene) =>
        sceneData(scene, board: kIos27BoardWorst, since: DateTime(2026));

    for (final scene in ['home-on', 'traffic-out', 'connecting', 'offline']) {
      testWidgets('растёт с масштабом, без переполнения: $scene',
          (tester) async {
        try {
          for (final device in kIos27Iphones) {
            double? previous;
            for (final scale in [0.8, 1.0, 1.4, 2.0]) {
              await pumpIos27Board(
                tester,
                ios27BoardApp(
                  brightness: Brightness.light,
                  textScale: scale,
                  device: device,
                  disableAnimations: true,
                  child: Builder(
                    builder: (context) => ColoredBox(
                      color: Ios27Colors.of(context).palette.bg,
                      // Экран главной прокручивается; сама карточка нет (D8).
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Ios27Card(
                            data: worst(scene),
                            now: () => DateTime(2026).add(const Duration(
                                hours: 10, minutes: 5, seconds: 9)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                device: device,
              );
              expect(
                tester.takeException(),
                isNull,
                reason: '${device.name} ×$scale',
              );
              final height = tester.getSize(_byKey(Ios27CardKeys.card)).height;
              if (previous != null) {
                expect(
                  height,
                  greaterThan(previous),
                  reason: '${device.name} ×$scale: карточка должна расти (D8)',
                );
              }
              previous = height;
            }
          }
        } finally {
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  });

  group('поведение карточки №4', () {
    Future<void> pumpData(
      WidgetTester tester,
      Ios27CardData data, {
      Brightness brightness = Brightness.light,
      double textScale = 1.0,
      void Function(String url)? onLink,
      VoidCallback? onRefresh,
    }) =>
        pumpIos27Board(
          tester,
          ios27BoardApp(
            brightness: brightness,
            textScale: textScale,
            disableAnimations: true,
            child: Builder(
              builder: (context) => ColoredBox(
                color: Ios27Colors.of(context).palette.bg,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 108, 16, 0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Ios27Card(data: data, onRefresh: onRefresh),
                        Ios27CardFooter(text: data.announce, onLink: onLink),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets('поверхность — Widget Glass, заголовок красится ярлыком стекла',
        (tester) async {
      try {
        for (final brightness in Brightness.values) {
          await pumpData(tester, sceneData('home-off'), brightness: brightness);
          final glass =
              tester.widget<Ios27Glass>(find.byKey(Ios27CardKeys.card));
          expect(glass.variant, Ios27GlassVariant.widget);
          final p =
              Ios27Colors.of(tester.element(find.byKey(Ios27CardKeys.card)))
                  .palette;
          Color? colorOf(ValueKey<String> key) {
            final finder = find.descendant(
              of: find.byKey(key),
              matching: find.byType(Text),
            );
            final text = tester.widget<Text>(
              finder.evaluate().isEmpty ? find.byKey(key) : finder.first,
            );
            return text.style?.color;
          }

          expect(colorOf(Ios27CardKeys.name), p.glassLabel);
          expect(colorOf(Ios27CardKeys.plan), isNot(p.glassLabel2));
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets(
        'вторичный текст — живой белый/чёрный с альфой, не плоский серый',
        (tester) async {
      try {
        const expected = {
          Brightness.dark: Color.fromRGBO(255, 255, 255, 0.80),
          Brightness.light: Color.fromRGBO(0, 0, 0, 0.70),
        };
        const footer = {
          Brightness.dark: Color.fromRGBO(255, 255, 255, 0.75),
          Brightness.light: Color.fromRGBO(0, 0, 0, 0.65),
        };
        for (final brightness in Brightness.values) {
          await pumpData(
            tester,
            sceneData('home-on', since: DateTime(2026)),
            brightness: brightness,
          );
          final p = Ios27Colors.of(
            tester.element(find.byKey(Ios27CardKeys.card)),
          ).palette;
          Color? colorOf(ValueKey<String> key) =>
              tester.widget<Text>(find.byKey(key)).style?.color;
          expect(colorOf(Ios27CardKeys.timer), expected[brightness]);
          expect(colorOf(Ios27CardKeys.timer), isNot(p.glassLabel2));
          final plan = tester.widget<Text>(
            find.descendant(
              of: find.byKey(Ios27CardKeys.plan),
              matching: find.byType(Text),
            ),
          );
          expect(plan.style?.color, expected[brightness]);
          final text = tester.widget<RichText>(
            find.descendant(
              of: find.byKey(Ios27CardKeys.footerText),
              matching: find.byType(RichText),
            ),
          );
          expect(text.text.style!.color, footer[brightness]);
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('«Обновить» — отдельная кнопка с целью нажатия ≥ 44 pt',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        for (final scale in [1.0, 1.4, 2.0]) {
          var taps = 0;
          await pumpData(
            tester,
            sceneData('expired'),
            textScale: scale,
            onRefresh: () => taps++,
          );
          final target = tester.getSize(
            find.descendant(
              of: find.byKey(Ios27CardKeys.refresh),
              matching: find.byType(GestureDetector),
            ),
          );
          expect(target.height, greaterThanOrEqualTo(44), reason: '×$scale');
          await tester.tap(find.byKey(Ios27CardKeys.refresh));
          expect(taps, 1, reason: '×$scale');
        }
        final node =
            tester.getSemantics(find.bySemanticsLabel('Обновить').first);
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
        // Состояния рядом нет: справа либо «Обновить», либо слово статуса.
        expect(find.byKey(Ios27CardKeys.state), findsNothing);
      } finally {
        handle.dispose();
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('подвал: ссылка подчёркнута, нажимается, цвета из токенов',
        (tester) async {
      try {
        for (final brightness in Brightness.values) {
          final dark = brightness == Brightness.dark;
          String? opened;
          await pumpData(
            tester,
            sceneData('home-off', board: kIos27BoardWorst),
            brightness: brightness,
            onLink: (u) => opened = u,
          );
          final text = tester.widget<RichText>(
            find.descendant(
              of: find.byKey(Ios27CardKeys.footerText),
              matching: find.byType(RichText),
            ),
          );
          expect(text.text.style!.color, Ios27FooterColors.text(dark: dark));
          final link = _spans(text).firstWhere((s) => s.recognizer != null);
          expect(link.style!.decoration, TextDecoration.underline);
          expect(link.style!.fontWeight, FontWeight.w500);
          expect(link.style!.color, Ios27FooterColors.link(dark: dark));
          (link.recognizer! as TapGestureRecognizer).onTap!();
          expect(opened, startsWith('https://t.me/'));
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets(
        'без объявления подвала нет; без обработчика ссылки не нажимаются',
        (tester) async {
      try {
        await pumpData(tester, _withoutAnnounce(sceneData('home-off')));
        expect(find.byKey(Ios27CardKeys.footer), findsNothing);
        await pumpData(tester, sceneData('home-off', board: kIos27BoardWorst));
        final text = tester.widget<RichText>(
          find.descendant(
            of: find.byKey(Ios27CardKeys.footerText),
            matching: find.byType(RichText),
          ),
        );
        final link = _spans(text).firstWhere(
          (s) => s.style?.decoration == TextDecoration.underline,
        );
        // Подчёркнута и без обработчика: вид не зависит от того, куда ведёт нажатие.
        expect((link.recognizer as TapGestureRecognizer?)?.onTap, isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('IP нигде на карточке нет, на всех сценах', (tester) async {
      try {
        // IPv6 — три двоеточия и больше; таймер «ч:мм:сс» (два) под шаблон не попадает.
        final ip = RegExp(r'\d{1,3}(\.\d{1,3}){3}|([0-9a-f]{0,4}:){3,}');
        for (final scene in _scenes) {
          await pumpData(tester, sceneData(scene, since: DateTime(2026)));
          for (final t in tester.widgetList<RichText>(find.byType(RichText))) {
            expect(t.text.toPlainText(), isNot(matches(ip)), reason: scene);
          }
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets(
        'смена страны с длинной на короткую при мелком шрифте не переполняет строку',
        (tester) async {
      try {
        // Уходящее значение держит свою ширину, а не ширину нового «—».
        for (final scale in [0.8, 1.0, 2.0]) {
          await pumpData(tester, sceneData('error'), textScale: scale);
          await pumpData(tester, sceneData('offline'), textScale: scale);
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull, reason: '×$scale');
          await tester.pump(const Duration(seconds: 1));
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('крупный шрифт: статус уходит под страну, название не рвётся',
        (tester) async {
      try {
        await pumpData(
          tester,
          sceneData('error', board: kIos27BoardWorst),
          textScale: 2.0,
        );
        final country = tester.getRect(find.byKey(Ios27CardKeys.country));
        final state = tester.getRect(find.byKey(Ios27CardKeys.state));
        expect(state.top, greaterThanOrEqualTo(country.bottom));
        // «Россия» в одну строку: высота слова — одна строка, а не столбик из букв.
        expect(country.height, lessThan(80));
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
