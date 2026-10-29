import 'dart:convert';
import 'dart:io';

import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/screens/m3e_about.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

/// Данные доски: `VERSION` в android.js и `UPDATE.version` в app.js.
const _version = '0.10.3';
const _core = '1.19.31';
const _update = '0.10.4';

/// Экран как у эталонов: `disableAnimations` (эталон снят с reducedMotion).
Widget _view({
  String version = _version,
  String core = _core,
  String? update = _update,
  VoidCallback? onBack,
  VoidCallback? onUpdate,
  VoidCallback? onSite,
  VoidCallback? onPrivacy,
  double textScale = 1,
}) =>
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: M3eAboutView(
          version: version,
          core: core,
          updateVersion: update,
          onBack: onBack ?? () {},
          onUpdate: onUpdate,
          onSite: onSite ?? () {},
          onPrivacy: onPrivacy ?? () {},
        ),
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  int provider = 0,
  Brightness brightness = Brightness.light,
}) async {
  final h = parseDropwebTheme(kBoardProviders[provider].theme);
  await pumpM3eBoard(
    tester,
    m3eBoardApp(
      seed: h.accent,
      filter: h.filter,
      brightness: brightness,
      child: child,
    ),
  );
}

Map<String, dynamic> _elements(String scene) {
  final all = jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
      as Map<String, dynamic>;
  return (all[scene] as Map<String, dynamic>)['elements']
      as Map<String, dynamic>;
}

/// Эталон: у элементов-повторов в layout.json список; [index] выбирает элемент.
Rect _ref(String scene, String key, [int index = 0]) {
  var e = _elements(scene)[key];
  if (e is List) e = e[index];
  final m = e as Map<String, dynamic>;
  return Rect.fromLTWH(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['w'] as num).toDouble(),
    (m['h'] as num).toDouble(),
  );
}

Rect _rect(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(ValueKey<String>(key)));

void _near(Rect actual, Rect expected, String what) {
  const tolerance = 4.0;
  expect(actual.left, closeTo(expected.left, tolerance), reason: '$what: x');
  expect(actual.top, closeTo(expected.top, tolerance), reason: '$what: y');
  expect(actual.width, closeTo(expected.width, tolerance), reason: '$what: w');
  expect(actual.height, closeTo(expected.height, tolerance), reason: '$what: h');
}

void main() {
  group('golden', () {
    for (final p in [0, 5]) {
      for (final theme in ['light', 'dark']) {
        testWidgets('about_${theme}_p$p', (tester) async {
          await _pump(
            tester,
            _view(),
            provider: p,
            brightness: theme == 'dark' ? Brightness.dark : Brightness.light,
          );
          await expectM3eGolden(tester, 'about_${theme}_p$p');
        });
      }
    }
  });

  group('паритет с layout.json (±4 dp)', () {
    for (final p in [0, 5]) {
      for (final theme in ['light', 'dark']) {
        final scene = 'about-$theme-p$p';
        testWidgets(scene, (tester) async {
          await _pump(
            tester,
            _view(),
            provider: p,
            brightness: theme == 'dark' ? Brightness.dark : Brightness.light,
          );
          // Элементы с одним значением в layout.json.
          for (final key in ['about', 'about.logo', 'about.title', 'about.version']) {
            _near(_rect(tester, 'm3e.$key'), _ref(scene, key), key);
          }
          // Под страницей «О программе» лежит страница настроек: в layout.json у `bar`,
          // `bar.back`, `page.title` по две записи, у `list` и `list.item` собраны обе
          // страницы подряд. Список «О программе» — второй `list` и пункты 3..5.
          _near(_rect(tester, 'm3e.bar'), _ref(scene, 'bar', 1), 'bar');
          _near(_rect(tester, 'm3e.bar.back'), _ref(scene, 'bar.back', 1),
              'bar.back');
          _near(_rect(tester, 'm3e.page.title'),
              _ref(scene, 'page.title', 1), 'page.title');
          _near(_rect(tester, 'm3e.list'), _ref(scene, 'list', 1), 'list');
          for (var i = 0; i < 3; i++) {
            _near(_rect(tester, 'm3e.list.item.$i'),
                _ref(scene, 'list.item', 3 + i), 'list.item.$i');
          }
        });
      }
    }
  });

  group('без обновления', () {
    testWidgets('пункта нет, раскладка без дыр', (tester) async {
      await _pump(tester, _view(update: null));
      expect(find.byKey(const ValueKey<String>('m3e.list.item.2')), findsNothing);
      // Остались «Сайт» (72) и «Политика» (56) подряд через 2 dp от начала списка.
      final list = _rect(tester, 'm3e.list');
      final site = _rect(tester, 'm3e.list.item.0');
      final privacy = _rect(tester, 'm3e.list.item.1');
      expect(site.top, list.top);
      expect(site.height, 72);
      expect(privacy.top, site.bottom + 2);
      expect(privacy.height, 56);
      expect(list.bottom, privacy.bottom);
      expect(find.text('Обновление'), findsNothing);
      expect(find.textContaining('Доступна версия'), findsNothing);
    });

    testWidgets('golden-раскладка не зависит от обновления выше списка',
        (tester) async {
      await _pump(tester, _view(update: null));
      _near(_rect(tester, 'm3e.about'), _ref('about-light-p0', 'about'), 'about');
    });
  });

  group('поведение', () {
    testWidgets('тапы зовут колбэки', (tester) async {
      var back = 0, update = 0, site = 0, privacy = 0;
      await _pump(
        tester,
        _view(
          onBack: () => back++,
          onUpdate: () => update++,
          onSite: () => site++,
          onPrivacy: () => privacy++,
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('m3e.bar.back')));
      await tester.tap(find.byKey(const ValueKey<String>('m3e.list.item.0')));
      await tester.tap(find.byKey(const ValueKey<String>('m3e.list.item.1')));
      await tester.tap(find.byKey(const ValueKey<String>('m3e.list.item.2')));
      expect((back, update, site, privacy), (1, 1, 1, 1));
    });

    testWidgets('строки и версия из l10n', (tester) async {
      await _pump(tester, _view());
      expect(find.text('О программе'), findsOneWidget);
      expect(find.text('dropweb'), findsOneWidget);
      expect(find.text('Версия 0.10.3, ядро 1.19.31'), findsOneWidget);
      expect(find.text('Доступна версия 0.10.4'), findsOneWidget);
      expect(find.text('Сайт проекта'), findsOneWidget);
      expect(find.text('Политика конфиденциальности'), findsOneWidget);
    });

    testWidgets('семантика: «Назад», пункты списка — кнопки', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _view(onUpdate: () {}));
      final back = tester.getSemantics(
        find.byKey(const ValueKey<String>('m3e.bar.back')),
      );
      expect(back.label, 'Назад');
      expect(back.flagsCollection.isButton, isTrue);
      expect(find.bySemanticsLabel('Назад'), findsOneWidget);
      for (final entry in {
        0: ['Обновление', 'Доступна версия 0.10.4'],
        1: ['Сайт проекта', 'dropweb.org'],
        2: ['Политика конфиденциальности'],
      }.entries) {
        final node = tester.getSemantics(
          find.byKey(ValueKey<String>('m3e.list.item.${entry.key}')),
        );
        expect(node.flagsCollection.isButton, isTrue, reason: 'item ${entry.key}');
        for (final part in entry.value) {
          expect(node.label, contains(part), reason: 'item ${entry.key}');
        }
      }
      // Значок приложения декоративный: ни одного узла «image» с подписью.
      expect(find.bySemanticsLabel('dropweb'), findsOneWidget);
      handle.dispose();
    });
  });

  group('WORST', () {
    testWidgets('длинная версия и ядро без overflow', (tester) async {
      await _pump(
        tester,
        _view(
          version: '10.123.456-beta.7+2050000023-very-long-build-suffix',
          core: 'v1.19.31-alpha-20261029-commit-abcdef0123456789abcdef',
          update: '10.123.457-beta.8+2050000024-very-long-build-suffix',
        ),
      );
      expect(tester.takeException(), isNull);
      final about = _rect(tester, 'm3e.about');
      expect(about.width, 379);
      final version = _rect(tester, 'm3e.about.version');
      expect(version.width, lessThanOrEqualTo(379));
      expect(version.height, greaterThan(20), reason: 'длинная строка переносится');
    });

    testWidgets('textScaler 1.3 без overflow', (tester) async {
      await _pump(tester, _view(textScale: 1.3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('textScaler 1.3 + длинные строки', (tester) async {
      await _pump(
        tester,
        _view(
          version: '10.123.456-beta.7+2050000023-very-long-build-suffix',
          core: 'v1.19.31-alpha-20261029-commit-abcdef0123456789abcdef',
          update: '10.123.457-beta.8+2050000024-very-long-build-suffix',
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
