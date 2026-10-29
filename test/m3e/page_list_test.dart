import 'dart:convert';
import 'dart:io';
import 'dart:ui' show CheckedState, Tristate;

import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/symbols.g.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_source.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_list.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

/// Ключ образца: прямоугольник пункта и его семантический узел.
Key _k(String name) => ValueKey<String>('t.$name');

Widget _noMotion(Widget child) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child,
      ),
    );

/// Фон страницы и списки на поверхности страницы, без полосы со стрелкой: образец
/// пунктов должен поместиться в кадр целиком.
Widget _sheetOf(List<Widget> groups) => Builder(
      builder: (context) {
        final scheme = M3eColors.of(context).scheme;
        final media = MediaQuery.of(context);
        return ColoredBox(
          color: scheme.surface,
          child: M3eListSurfaceScope(
            surface: M3eListSurface.page,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  16, media.padding.top + 8, 16, media.padding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: groups,
              ),
            ),
          ),
        );
      },
    );

/// Образец A: ведущие значки и радио, хвосты (значок, бейдж, задержка), выбор и тоны.
Widget _sampleA() => _noMotion(
      _sheetOf([
        const M3eListHeader('Пункты'),
        M3eList(children: [
          M3eListItem(
            key: _k('icon'),
            lead: M3eListLead.icon(M3eSymbol.translate),
            label: 'Язык',
            onTap: () {},
          ),
          M3eListItem(
            key: _k('sup-icon'),
            lead: M3eListLead.icon(M3eSymbol.systemUpdate),
            label: 'Обновление',
            sup: 'Доступна версия 0.10.4',
            trail: M3eListTrail.badge(),
            onTap: () {},
          ),
          M3eListItem(
            key: _k('slow'),
            lead: M3eListLead.icon(M3eSymbol.dns),
            label: 'Медленный узел',
            sup: 'vless · reality',
            trail: M3eListTrail.text('640 мс', tone: M3eTrailTone.slow),
            onTap: () {},
          ),
          M3eListItem(
            key: _k('dead'),
            lead: M3eListLead.icon(M3eSymbol.dns),
            label: 'Недоступный узел',
            trail: M3eListTrail.text('нет ответа', tone: M3eTrailTone.dead),
            onTap: () {},
          ),
          M3eListItem(
            key: _k('static'),
            lead: M3eListLead.icon(M3eSymbol.info),
            label: 'Статичный пункт без нажатия',
            trail: M3eListTrail.icon(M3eSymbol.openInNew),
          ),
        ]),
        const SizedBox(height: 16),
        const M3eListHeader('Радио'),
        M3eList(semanticLabel: 'Язык', children: [
          M3eListItem(
            key: _k('radio-off'),
            lead: M3eListLead.radio(false),
            label: 'Русский',
            sup: 'Russian',
            radioChecked: false,
            onTap: () {},
          ),
          M3eListItem(
            key: _k('radio-on'),
            lead: M3eListLead.radio(true),
            label: 'English',
            radioChecked: true,
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 16),
        M3eList(children: [
          M3eListItem(
            key: _k('accent'),
            lead: M3eListLead.avatar(icon: M3eSymbol.add, accent: true),
            label: 'Добавить подписку',
            tone: M3eListItemTone.accent,
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 16),
        M3eList(children: [
          M3eListItem(
            key: _k('danger'),
            lead: M3eListLead.icon(M3eSymbol.delete),
            label: 'Удалить подписку',
            tone: M3eListItemTone.danger,
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 16),
        M3eList(children: [
          M3eListItem(
            key: _k('toggle-on'),
            label: 'Весь трафик через VPN',
            trail: M3eListTrail.toggle(true),
            toggled: true,
            onTap: () {},
          ),
          M3eListItem(
            key: _k('toggle-off'),
            label: 'Режим экономии',
            trail: M3eListTrail.toggle(false),
            toggled: false,
            onTap: () {},
          ),
        ]),
      ]),
    );

/// Образец B: аватары (инициалы, логотип, флаг, эмодзи, значок), выбранный пункт без радио,
/// точки цвета и составной хвост.
Widget _sampleB(String logoSvg) => _noMotion(
      _sheetOf([
        const M3eListHeader('Все подписки'),
        M3eList(semanticLabel: 'Подписки', children: [
          M3eListItem(
            key: _k('av-text'),
            lead: M3eListLead.avatar(text: 'db'),
            label: 'DROPWEB',
            sup: 'dropweb.org',
            radioChecked: true,
            trail: M3eListTrail.icon(M3eSymbol.check),
            onTap: () {},
          ),
          M3eListItem(
            key: _k('av-logo'),
            lead: M3eListLead.avatar(logoSvg: logoSvg),
            label: 'С логотипом',
            sup: 'example.org',
            radioChecked: false,
            onTap: () {},
          ),
          M3eListItem(
            key: _k('av-small'),
            lead: M3eListLead.avatar(text: 'ГС', small: true),
            label: 'Малый аватар 32',
            radioChecked: false,
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 16),
        const M3eListHeader('Страна'),
        M3eList(semanticLabel: 'Страна', children: [
          M3eListItem(
            key: _k('flag'),
            lead: M3eListLead.avatar(flag: '🇫🇮'),
            label: 'Финляндия',
            radioChecked: true,
            trail: M3eListTrail.row([
              M3eListTrail.text('43 мс'),
              M3eListTrail.icon(M3eSymbol.check),
            ]),
            onTap: () {},
          ),
          M3eListItem(
            key: _k('flag-us'),
            lead: M3eListLead.avatar(flag: '🇺🇸'),
            label: 'США',
            radioChecked: false,
            trail: M3eListTrail.text('118 мс'),
            onTap: () {},
          ),
          M3eListItem(
            key: _k('emoji'),
            lead: M3eListLead.avatar(emoji: '🚀'),
            label: 'Быстрая группа',
            sup: 'hysteria2',
            trail: M3eListTrail.text('37 мс'),
            onTap: () {},
          ),
          M3eListItem(
            key: _k('bolt'),
            lead: M3eListLead.avatar(icon: M3eSymbol.bolt),
            label: 'Авто',
            sup: 'Финляндия',
            radioChecked: false,
            trail: M3eListTrail.text('43 мс'),
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 16),
        M3eList(children: [
          M3eListItem(
            key: _k('dot'),
            lead: M3eListLead.radio(true),
            label: 'Цвет провайдера',
            sup: 'Как в подписке',
            radioChecked: true,
            trail: M3eListTrail.colorDot(const Color(0xFF29FF76)),
            onTap: () {},
          ),
          M3eListItem(
            key: _k('swatch'),
            lead: M3eListLead.radio(false),
            label: 'Свой цвет',
            sup: 'Выбрать из палитры',
            radioChecked: false,
            trail: M3eListTrail.swatch(
              primary: const Color(0xFF29FF76),
              secondary: const Color(0xFFB3D5B2),
              tertiary: const Color(0xFF9CCBFF),
            ),
            onTap: () {},
          ),
        ]),
      ]),
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  List<Override> overrides = const [],
}) async {
  final h = parseDropwebTheme(kBoardProviders[0].theme);
  await pumpM3eBoard(
    tester,
    m3eBoardApp(
      seed: h.accent,
      filter: h.filter,
      brightness: brightness,
      overrides: overrides,
      child: child,
    ),
  );
}

Rect _rectOf(WidgetTester tester, String name) =>
    tester.getRect(find.byKey(_k(name)));

Rect _ref(String scene, String key, [int index = 0]) {
  final all = jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
      as Map<String, dynamic>;
  final elements =
      (all[scene] as Map<String, dynamic>)['elements'] as Map<String, dynamic>;
  var e = elements[key];
  if (e is List) e = e[index];
  final m = e as Map<String, dynamic>;
  return Rect.fromLTWH(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['w'] as num).toDouble(),
    (m['h'] as num).toDouble(),
  );
}

void _near(Rect actual, Rect expected, String what) {
  const tolerance = 4.0;
  expect(actual.left, closeTo(expected.left, tolerance), reason: '$what: x');
  expect(actual.top, closeTo(expected.top, tolerance), reason: '$what: y');
  expect(actual.width, closeTo(expected.width, tolerance), reason: '$what: w');
  expect(actual.height, closeTo(expected.height, tolerance),
      reason: '$what: h');
}

/// Форма пункта: скругления углов Material под ключом.
BorderRadius _corners(WidgetTester tester, String name) {
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.byKey(_k(name)),
          matching: find.byType(Material),
        )
        .first,
  );
  return ((material.shape! as RoundedRectangleBorder).borderRadius)
      .resolve(TextDirection.ltr);
}

Color _fill(WidgetTester tester, String name) => tester
    .widget<Material>(
      find
          .descendant(
            of: find.byKey(_k(name)),
            matching: find.byType(Material),
          )
          .first,
    )
    .color!;

void main() {
  final logoSvg = File('test/m3e/fixtures/board_logo.svg').readAsStringSync();

  group('golden: образцы пунктов', () {
    for (final theme in ['light', 'dark']) {
      final brightness = theme == 'dark' ? Brightness.dark : Brightness.light;
      testWidgets('page_list_a_${theme}_p0', (tester) async {
        await _pump(tester, _sampleA(), brightness: brightness);
        await expectM3eGolden(tester, 'page_list_a_${theme}_p0');
      });
      testWidgets('page_list_b_${theme}_p0', (tester) async {
        await _pump(tester, _sampleB(logoSvg), brightness: brightness);
        await expectM3eGolden(tester, 'page_list_b_${theme}_p0');
      });
    }
  });

  group('страница', () {
    Widget page({int rows = 3}) => _noMotion(
          M3ePage(
            title: 'Настройки',
            body: M3eList(children: [
              for (var i = 0; i < rows; i++)
                M3eListItem(
                  key: _k('row$i'),
                  lead: M3eListLead.icon(M3eSymbol.settings),
                  label: 'Пункт $i',
                  sup: 'Подпись',
                  onTap: () {},
                ),
            ]),
          ),
        );

    testWidgets('геометрия панели и заголовка как в about-light-p0',
        (tester) async {
      await _pump(tester, page());
      const scene = 'about-light-p0';
      _near(tester.getRect(find.byKey(kM3ePageBarKey)), _ref(scene, 'bar', 1),
          'bar');
      _near(tester.getRect(find.byKey(kM3ePageBackKey)),
          _ref(scene, 'bar.back', 1), 'bar.back');
      _near(tester.getRect(find.byKey(kM3ePageTitleKey)),
          _ref(scene, 'page.title', 1), 'page.title');
      // Первый пункт сразу под заголовком (y 176).
      expect(_rectOf(tester, 'row0').top, closeTo(176, 0.5));
    });

    testWidgets('малый заголовок появляется только после прокрутки',
        (tester) async {
      await _pump(tester, page(rows: 14));
      expect(find.byKey(const ValueKey<String>('m3e.bar.title')), findsNothing);
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
          find.byKey(const ValueKey<String>('m3e.bar.title')), findsOneWidget);
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey<String>('m3e.bar.title')), findsNothing);
    });

    testWidgets('golden: прокрученная страница', (tester) async {
      await _pump(tester, page(rows: 14));
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await expectM3eGolden(tester, 'page_list_scrolled_light_p0');
    });

    testWidgets('«Назад» по умолчанию закрывает маршрут, onBack перехватывает',
        (tester) async {
      var back = 0;
      await _pump(
        tester,
        _noMotion(M3ePage(
            title: 'Тест', body: const SizedBox(), onBack: () => back++)),
      );
      await tester.tap(find.byKey(kM3ePageBackKey));
      expect(back, 1);
    });

    testWidgets('pushM3ePage открывает страницу с темой и закрывается стрелкой',
        (tester) async {
      final h = parseDropwebTheme(kBoardProviders[0].theme);
      await _pump(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              key: _k('open'),
              onPressed: () => pushM3ePage<void>(
                context,
                (_) => const M3ePage(title: 'Вторая', body: SizedBox()),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
        overrides: [
          m3eThemeSourceProvider.overrideWithValue(
            M3eThemeSource(seed: h.accent, filter: h.filter),
          ),
        ],
      );
      await tester.tap(find.byKey(_k('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Вторая'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(kM3ePageBackKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Вторая'), findsNothing);
    });
  });

  group('пункты', () {
    testWidgets('высоты 56 и 72 по наличию подписи', (tester) async {
      await _pump(tester, _sampleA());
      expect(_rectOf(tester, 'icon').height, 56);
      expect(_rectOf(tester, 'sup-icon').height, 72);
      expect(_rectOf(tester, 'dead').height, 56);
      expect(_rectOf(tester, 'icon').width, 379);
    });

    testWidgets('скругления: внешние 16, внутренние 4, одиночный пункт 16',
        (tester) async {
      await _pump(tester, _sampleA());
      final first = _corners(tester, 'icon');
      expect((first.topLeft.x, first.bottomLeft.x), (16, 4));
      final middle = _corners(tester, 'slow');
      expect((middle.topLeft.x, middle.bottomRight.x), (4, 4));
      final last = _corners(tester, 'static');
      expect((last.topLeft.x, last.bottomLeft.x), (4, 16));
      final alone = _corners(tester, 'accent');
      expect((alone.topLeft.x, alone.bottomRight.x), (16, 16));
      // Между пунктами 2 dp.
      expect(
          _rectOf(tester, 'sup-icon').top, _rectOf(tester, 'icon').bottom + 2);
    });

    testWidgets('выбранный пункт без радио заливается secondary-container',
        (tester) async {
      await _pump(tester, _sampleB(logoSvg));
      final scheme =
          M3eColors.of(tester.element(find.byKey(_k('av-text')))).scheme;
      expect(_fill(tester, 'av-text'), scheme.secondaryContainer);
      expect(_fill(tester, 'av-logo'), scheme.surfaceContainerHigh);
      // С радиокнопкой в lead заливки нет: выбор виден по самой кнопке.
      expect(_fill(tester, 'dot'), scheme.surfaceContainerHigh);
    });

    testWidgets('семантика: радио, переключатель, кнопка, статичный пункт',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, Column(children: [Expanded(child: _sampleA())]));
      SemanticsNode node(String name) =>
          tester.getSemantics(find.byKey(_k(name)));

      final on = node('radio-on').flagsCollection;
      expect(on.isInMutuallyExclusiveGroup, isTrue);
      expect(on.isChecked, CheckedState.isTrue);
      final off = node('radio-off').flagsCollection;
      expect(off.isInMutuallyExclusiveGroup, isTrue);
      expect(off.isChecked, CheckedState.isFalse);
      expect(node('radio-on').getSemanticsData().label, contains('English'));
      expect(node('radio-off').getSemanticsData().label, contains('Русский'));
      expect(node('radio-off').getSemanticsData().label, contains('Russian'));

      expect(node('toggle-on').flagsCollection.isToggled, Tristate.isTrue);
      expect(node('toggle-off').flagsCollection.isToggled, Tristate.isFalse);

      expect(node('icon').flagsCollection.isButton, isTrue);
      expect(node('static').flagsCollection.isButton, isFalse);
      // Бейдж и значки декоративные: в подписи только текст.
      expect(node('sup-icon').getSemanticsData().label,
          'Обновление\nДоступна версия 0.10.4');
      handle.dispose();
    });

    testWidgets('нажатие зовёт onTap, статичный пункт молчит', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        _noMotion(
          M3eList(children: [
            M3eListItem(key: _k('a'), label: 'A', onTap: () => taps++),
            M3eListItem(key: _k('b'), label: 'B'),
          ]),
        ),
      );
      await tester.tap(find.byKey(_k('a')));
      await tester.tap(find.byKey(_k('b')));
      expect(taps, 1);
    });
  });

  group('WORST', () {
    testWidgets('длинные подписи и textScaler 1.3 без overflow',
        (tester) async {
      const long =
          'Очень-очень-длинное-название-без-пробелов-которое-не-помещается-в-строку-пункта';
      await _pump(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(1.3),
            ),
            child: M3ePage(
              title: long,
              body: M3eList(children: [
                M3eListItem(
                  lead: M3eListLead.avatar(text: 'ДЛ'),
                  label: long,
                  sup: long,
                  trail: M3eListTrail.row([
                    M3eListTrail.text('нет ответа', tone: M3eTrailTone.dead),
                    M3eListTrail.icon(M3eSymbol.check),
                  ]),
                  radioChecked: true,
                  onTap: () {},
                ),
                M3eListItem(
                  lead: M3eListLead.avatar(flag: '🇫🇮'),
                  label: long,
                  trail: M3eListTrail.toggle(true),
                  toggled: true,
                  onTap: () {},
                ),
              ]),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
