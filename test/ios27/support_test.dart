// Каркас G3/G4 (`test/ios27/support/`): шрифты, окно доски, корень образца, раскладка эталонов,
// таблица сверки и данные доски. Без него golden и parity молча рисовали бы Ahem или не тот размер.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/board_providers.dart';
import 'support/board_fixtures.dart';
import 'support/fonts.dart';
import 'support/golden.dart';
import 'support/layout.dart';
import 'support/surface.dart';

double _width(String text, TextStyle style) {
  final p = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final w = p.width;
  p.dispose();
  return w;
}

void main() {
  group('окна', () {
    test('доска: 411×914 dp при dpr 2 даёт кадр 822×1828', () {
      expect(kIos27BoardDevice.size, const Size(411, 914));
      expect(kIos27BoardDevice.dpr, 2);
      expect(kIos27BoardDevice.pixelWidth, 822);
      expect(kIos27BoardDevice.pixelHeight, 1828);
      // Отступы доски: контент ложится от 48 сверху и до 52 снизу (app.css:132, 153, 448).
      expect(kIos27BoardDevice.padding,
          const EdgeInsets.only(top: 48, bottom: 52));
    });

    test('отступы доски сходятся с маской и корнем в layout.json', () {
      final l = Ios27RefLayout.load('home-off-light-norm-p0');
      expect(l.root, const Rect.fromLTWH(0, 0, 411, 914));
      expect(l.mask.statusBar, const Rect.fromLTWH(0, 0, 411, 40));
      expect(l.mask.homeIndicator, const Rect.fromLTWH(151.5, 902, 108, 4));
      // Низ дока лежит ровно на нижнем отступе доски: 914 − 52 = 862.
      final dock = l.element('dock')!;
      expect(dock.bottom, 914 - kIos27BoardDevice.padding.bottom);
      // Верх строки настроек начинается с верхнего отступа.
      expect(l.element('settings')!.top, kIos27BoardDevice.padding.top);
    });

    test('Apple-устройства для G3', () {
      expect(
        kIos27Iphones.map((d) =>
            (d.size.width, d.size.height, d.padding.top, d.padding.bottom)),
        [
          (375.0, 667.0, 20.0, 0.0),
          (390.0, 844.0, 47.0, 34.0),
          (440.0, 956.0, 62.0, 34.0)
        ],
      );
      expect(kIos27IphoneSmall.dpr, 2);
      expect(kIos27IphoneMedium.dpr, 3);
      expect(kIos27IphoneLarge.dpr, 3);
      expect(kIos27IphoneLarge.pixelWidth, 1320);
      expect(kIos27IphoneLarge.pixelHeight, 2868);
    });

    testWidgets(
        'setIos27Surface выставляет размер, плотность и отступы, tearDown их снимает',
        (tester) async {
      setIos27Surface(tester, kIos27IphoneMedium);
      expect(tester.view.devicePixelRatio, 3);
      expect(tester.view.physicalSize, const Size(1170, 2532));
      expect(tester.view.padding.top, 47 * 3);
      expect(tester.view.padding.bottom, 34 * 3);
      expect(tester.view.viewPadding.top, 47 * 3);
      expect(tester.view.viewInsets.bottom, 0);
    });
  });

  group('шрифты', () {
    testWidgets(
        'Onest и Twemoji загружены: ширина не равна Ahem, веса различаются',
        (tester) async {
      await tester.runAsync(loadIos27Fonts);
      const text = 'Подключено 0,23 ГБ';
      final ahem =
          _width(text, const TextStyle(fontFamily: 'Ahem', fontSize: 17));
      final onest =
          _width(text, const TextStyle(fontFamily: 'Onest', fontSize: 17));
      final semibold = _width(
        text,
        const TextStyle(
            fontFamily: 'Onest', fontSize: 17, fontWeight: FontWeight.w600),
      );
      // Ahem: каждый символ ровно в кегль, 18 знаков × 17.
      expect(ahem, text.length * 17.0);
      expect(onest, isNot(closeTo(ahem, 1)));
      // Разные веса — разные файлы шрифта: полужирный шире обычного.
      expect(semibold, greaterThan(onest));
    });

    testWidgets('роль body из токенов рисуется Onest, а не запасным шрифтом',
        (tester) async {
      await tester.runAsync(loadIos27Fonts);
      final onest = _width('Подключено', Ios27Text.style(Ios27Text.body));
      final ahem = _width(
        'Подключено',
        Ios27Text.style(Ios27Text.body).copyWith(fontFamily: 'Ahem'),
      );
      expect(onest, isNot(closeTo(ahem, 1)));
    });

    testWidgets('загрузка идёт один раз на файл', (tester) async {
      final first = loadIos27Fonts();
      final second = loadIos27Fonts();
      expect(identical(first, second), isTrue);
      await tester.runAsync(() => first);
    });
  });

  group('корень образца', () {
    // Предыдущий тест уже должен был вернуть подмену прозрачности в исходное состояние.
    setUp(() => expect(Ios27A11y.debugOverride, isNull,
        reason: 'подмена прозрачности пережила тест'));

    testWidgets('кадр 822×1828 и системные настройки доходят до home',
        (tester) async {
      late MediaQueryData seen;
      late Ios27Colors colors;
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.dark,
          highContrast: true,
          boldText: true,
          textScale: 1.3,
          disableAnimations: true,
          theme: Ios27ProviderTheme.fromHeader(kBoardProviders[1].theme),
          child: Builder(
            builder: (context) {
              seen = MediaQuery.of(context);
              colors = Ios27Colors.of(context);
              return const SizedBox.expand();
            },
          ),
        ),
      );
      expect(seen.size, const Size(411, 914));
      expect(seen.padding, const EdgeInsets.only(top: 48, bottom: 52));
      expect(seen.viewPadding, const EdgeInsets.only(top: 48, bottom: 52));
      expect(seen.platformBrightness, Brightness.dark);
      expect(seen.highContrast, isTrue);
      expect(seen.boldText, isTrue);
      expect(seen.textScaler, const TextScaler.linear(1.3));
      expect(seen.disableAnimations, isTrue);
      expect(colors.dark, isTrue);
      expect(colors.highContrast, isTrue);
      expect(colors.theme.accent, '#38BDF8');

      final box = tester.element(find.byKey(kIos27BoardRootKey)).renderObject!
          as RenderRepaintBoundary;
      final image = (await tester.runAsync<ui.Image>(
        () => box.toImage(pixelRatio: tester.view.devicePixelRatio),
      ))!;
      expect((image.width, image.height), (822, 1828));
      image.dispose();
    });

    testWidgets('по умолчанию «Уменьшить прозрачность» включена',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
            brightness: Brightness.light, child: const SizedBox.expand()),
      );
      expect(Ios27A11y.debugOverride, isTrue);
      expect(Ios27A11y.reduceTransparency, isTrue);
    });

    testWidgets('reduceTransparency: false включает обычное стекло',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          reduceTransparency: false,
          child: const SizedBox.expand(),
        ),
      );
      expect(Ios27A11y.debugOverride, isFalse);
    });

    testWidgets(
        'значения по умолчанию: светлая, без контраста и жирного, масштаб 1',
        (tester) async {
      late MediaQueryData seen;
      late Ios27Colors colors;
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          child: Builder(
            builder: (context) {
              seen = MediaQuery.of(context);
              colors = Ios27Colors.of(context);
              return const SizedBox.expand();
            },
          ),
        ),
      );
      expect(seen.highContrast, isFalse);
      expect(seen.boldText, isFalse);
      expect(seen.textScaler, TextScaler.noScaling);
      expect(seen.disableAnimations, isFalse);
      expect(colors.theme, Ios27ProviderTheme.defaults);
      expect(colors.brightness, Brightness.light);
    });

    testWidgets('локаль ru: строки l10n загружены и текст рисуется Onest',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          child: const Center(child: Text('Подключено', key: Key('t'))),
        ),
      );
      final style = tester.widget<Text>(find.byKey(const Key('t')));
      expect(style.style, isNull);
      final rendered =
          tester.renderObject<RenderBox>(find.byKey(const Key('t')));
      final ahem = _width(
          'Подключено', const TextStyle(fontFamily: 'Ahem', fontSize: 17));
      expect(rendered.size.width, isNot(closeTo(ahem, 1)));
    });

    testWidgets('другое устройство: пикселей ровно по его размеру',
        (tester) async {
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          device: kIos27IphoneSmall,
          child: const SizedBox.expand(),
        ),
        device: kIos27IphoneSmall,
      );
      final box = tester.element(find.byKey(kIos27BoardRootKey)).renderObject!
          as RenderRepaintBoundary;
      final image = (await tester.runAsync<ui.Image>(
        () => box.toImage(pixelRatio: tester.view.devicePixelRatio),
      ))!;
      expect((image.width, image.height), (750, 1334));
      image.dispose();
    });
  });

  group('раскладка эталонов', () {
    test('читает запись и элементы-списки', () {
      final l = Ios27RefLayout.load('home-off-light-norm-p0');
      expect(l.key, 'home-off-light-norm-p0');
      expect(l.rects, isNotEmpty);
      // `card.stat` — список из двух рамок (IP и трафик).
      expect(l.all('card.stat').length, greaterThanOrEqualTo(2));
      expect(l.element('card.stat'), l.all('card.stat').first);
      expect(l.elements.keys, l.rects.keys);
      expect(l.all('нет-такого-элемента'), isEmpty);
      expect(l.element('нет-такого-элемента'), isNull);
    });

    test('ключ без записи падает с подсказкой', () {
      expect(
        () => Ios27RefLayout.load('нет-такой-записи'),
        throwsA(isA<TestFailure>()
            .having((e) => e.message, 'message', contains('layout.json'))),
      );
    });

    test('в эталоне есть обе темы, оба режима и провайдеры 0 и 5', () {
      for (final theme in ['light', 'dark']) {
        for (final mode in ['norm', 'rt']) {
          for (final p in [0, 5]) {
            expect(Ios27RefLayout.load('home-on-$theme-$mode-p$p').root.size,
                const Size(411, 914));
          }
        }
      }
    });
  });

  group('таблица сверки', () {
    const ref = Rect.fromLTWH(16, 108, 379, 189);

    test('строка в допуске и вне его', () {
      const ok = Ios27ParityRow(
          name: 'card',
          ref: ref,
          app: Rect.fromLTWH(18, 107, 381, 189),
          tol: 4);
      expect((ok.dx, ok.dy, ok.dw, ok.dh), (2, -1, 2, 0));
      expect(ok.worst, 2);
      expect(ok.ok, isTrue);
      const bad = Ios27ParityRow(
          name: 'card',
          ref: ref,
          app: Rect.fromLTWH(16, 120, 379, 189),
          tol: 4);
      expect(bad.ok, isFalse);
    });

    test('нет рамки с одной стороны — расхождение, с обеих — норма', () {
      expect(const Ios27ParityRow(name: 'x', ref: null, app: null, tol: 4).ok,
          isTrue);
      expect(const Ios27ParityRow(name: 'x', ref: ref, app: null, tol: 4).ok,
          isFalse);
      expect(const Ios27ParityRow(name: 'x', ref: null, app: ref, tol: 4).ok,
          isFalse);
    });

    test('markdown: формат строки и заголовка', () {
      const row = Ios27ParityRow(
          name: 'card',
          ref: ref,
          app: Rect.fromLTWH(18, 107, 381, 189),
          tol: 4);
      expect(
        row.toMarkdown(),
        '| card | 16.0, 108.0, 379.0×189.0 | 18.0, 107.0, 381.0×189.0 | 2.0 | -1.0 | 2.0 | 0.0 | да |',
      );
      final table = ios27ParityMarkdown('home-off-light-norm-p0', [row]);
      expect(table, startsWith('### home-off-light-norm-p0\n'));
      expect(table, contains('| элемент | доска x, y, w×h |'));
      expect(table, contains(row.toMarkdown()));
    });

    test('запись в файл дописывает, а не затирает', () {
      final dir = Directory.systemTemp.createTempSync('ios27_parity');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/table.md');
      const row = Ios27ParityRow(name: 'card', ref: ref, app: ref, tol: 4);
      ios27AppendParityTable(file.path, 'a', [row]);
      ios27AppendParityTable(file.path, 'b', [row]);
      final text = file.readAsStringSync();
      expect(text, contains('### a'));
      expect(text, contains('### b'));
      expect('| card |'.allMatches(text).length, 2);
    });

    testWidgets('ios27Parity сверяет рамки с эталоном и возвращает строки',
        (tester) async {
      // Если путь к таблице задан снаружи, запись идёт в этот файл (ветка записи проверена выше
      // через ios27AppendParityTable); без переменной ios27Parity на диск ничего не пишет.
      final env = Platform.environment['IOS27_PARITY_TABLE'];
      final before = (env != null && env.isNotEmpty && File(env).existsSync())
          ? File(env).lengthSync()
          : 0;

      final l = Ios27RefLayout.load('home-off-light-norm-p0');
      final card = l.element('card')!;
      await pumpIos27Board(
        tester,
        ios27BoardApp(
          brightness: Brightness.light,
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: card.shift(const Offset(2, -1)),
                child: const SizedBox.expand(key: Key('card')),
              ),
            ],
          ),
        ),
      );
      final rows = ios27Parity(tester, 'home-off-light-norm-p0', {
        'card': find.byKey(const Key('card')),
        'нет-на-доске': find.byKey(const Key('absent')),
      });
      expect(rows, hasLength(2));
      expect(rows.first.name, 'card');
      expect((rows.first.dx, rows.first.dy), (2, -1));
      expect(rows.first.ok, isTrue);
      expect(rows.last.ok, isTrue);
      expectIos27Parity(rows);

      if (env != null && env.isNotEmpty) {
        expect(File(env).lengthSync(), greaterThan(before));
      }
    });

    testWidgets('expectIos27Parity падает с таблицей отклонений',
        (tester) async {
      const bad = Ios27ParityRow(
        name: 'card',
        ref: Rect.fromLTWH(0, 0, 10, 10),
        app: Rect.fromLTWH(0, 20, 10, 10),
        tol: 4,
      );
      expect(
        () => expectIos27Parity([bad]),
        throwsA(isA<TestFailure>()
            .having((e) => e.message, 'message', contains('card'))),
      );
    });
  });

  group('данные доски', () {
    test('NORMAL и WORST: профили, страницы и логотипы идут параллельно', () {
      for (final d in [kIos27BoardNormal, kIos27BoardWorst]) {
        expect(d.profiles.length, d.pages.length);
        expect(d.profiles.length, d.logos.length);
        expect(d.countries, isNotEmpty);
        expect(d.groups, isNotEmpty);
      }
      expect(kIos27BoardNormal.profiles, ['DROPWEB', 'Дом']);
      expect(kIos27BoardWorst.profiles, hasLength(6));
    });

    test('WORST: анонс в 200 знаков, трафик почти исчерпан', () {
      expect(kIos27BoardWorst.announce.length, 200);
      expect(kIos27BoardWorst.traffic!.pct, 98.4);
      expect(kIos27BoardNormal.traffic, isNull);
    });

    test('вспомогательные: текст трафика, строка тарифа, статусы', () {
      expect(ios27BoardGbText(0.23), '0,23\u00a0ГБ');
      expect(ios27BoardGbText(49.2), '49,2\u00a0ГБ');
      expect(ios27BoardPlanLine(kIos27BoardNormal), 'Безлимит · бессрочно');
      expect(kIos27BoardIpOff, '95.24.118.7');
      expect(kIos27BoardLangs, hasLength(5));
      expect(kIos27BoardToasts, hasLength(5));
    });
  });
}
