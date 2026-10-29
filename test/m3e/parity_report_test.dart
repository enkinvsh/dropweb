// Ворота 4: паритет раскладки с доской по всем экранам фазы A и итоговая таблица.
// Сверка отдельных экранов уже есть в своих файлах (home/empty/about/toast); здесь они
// сведены в одну таблицу `.omo/m3e-android/parity.md`. Таблица пишется только по
// запросу: `M3E_PARITY_TABLE=.omo/m3e-android/parity.md fvm flutter test
// test/m3e/parity_report_test.dart` (отдельное имя переменной, чтобы не пересекаться
// с `M3E_PARITY_REPORT` из home_test.dart, который пишет только главную).

import 'dart:convert';
import 'dart:io';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/m3e/color/theme_header.dart';
import 'package:dropweb/ui/m3e/screens/m3e_about.dart';
import 'package:dropweb/ui/m3e/screens/m3e_empty_home.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_hero_button.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sub_card.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gate_support.dart';
import 'home_scenes.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';

const double _tolerance = 4;

/// Строка сводки: наибольшее расхождение по варианту (тема × провайдер) для ключа.
class _Row {
  _Row(this.screen, this.scene, this.key, this.board, this.ours, this.delta);

  final String screen;
  final String scene;
  final String key;
  final Rect board;
  final Rect ours;
  final double delta;
}

final Map<String, _Row> _rows = {};

void _record(String screen, String scene, String key, Rect board, Rect ours) {
  final delta = [
    (board.left - ours.left).abs(),
    (board.top - ours.top).abs(),
    (board.width - ours.width).abs(),
    (board.height - ours.height).abs(),
  ].reduce((a, b) => a > b ? a : b);
  expect(delta, lessThanOrEqualTo(_tolerance),
      reason: '$screen / $scene / $key: board=$board ours=$ours');
  final id = '$screen|$scene|$key';
  final prev = _rows[id];
  if (prev == null || delta > prev.delta) {
    _rows[id] = _Row(screen, scene, key, board, ours, delta);
  }
}

final Map<String, dynamic> _layout =
    jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _elements(String variant) =>
    (_layout[variant] as Map<String, dynamic>)['elements']
        as Map<String, dynamic>;

Rect _rect(Object? raw, [int index = 0]) {
  final m = (raw is List ? raw[index] : raw) as Map<String, dynamic>;
  return Rect.fromLTWH(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['w'] as num).toDouble(),
    (m['h'] as num).toDouble(),
  );
}

const _variants = [
  (Brightness.light, 0),
  (Brightness.light, 5),
  (Brightness.dark, 0),
  (Brightness.dark, 5),
];

String _variantId(String scene, Brightness b, int p) => '$scene-${b.name}-p$p';

Future<void> _pump(WidgetTester tester, Widget app) async {
  await pumpM3eBoard(tester, app);
  await tester.pump(const Duration(seconds: 1));
}

Widget _screen(Widget child, {required Brightness brightness, required int p}) {
  final h = parseDropwebTheme(kBoardProviders[p].theme);
  return m3eBoardApp(
    seed: h.accent,
    filter: h.filter,
    brightness: brightness,
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child,
      ),
    ),
  );
}

void main() {
  tearDown(() => debugDisableShadows = true);

  const homeKeys = <String, (String, Key)>{
    'card': ('Главная · карточка', M3eCardKeys.card),
    'card.head': ('Главная · карточка', M3eCardKeys.head),
    'card.plan': ('Главная · карточка', M3eCardKeys.plan),
    'card.line': ('Главная · карточка', M3eCardKeys.line),
    'card.meter': ('Главная · карточка', M3eCardKeys.meter),
    'card.stats': ('Главная · карточка', M3eCardKeys.stats),
    'card.sub': ('Главная · карточка', M3eCardKeys.sub),
    'card.site': ('Главная · карточка', M3eCardKeys.site),
    'card.refresh': ('Главная · карточка', M3eCardKeys.refresh),
    'card.name': ('Главная · карточка', M3eCardKeys.name),
    'card.state': ('Главная · карточка', M3eCardKeys.state),
    'card.dot': ('Главная · карточка', M3eCardKeys.dot),
    'card.timer': ('Главная · карточка', M3eCardKeys.timer),
    'card.why': ('Главная · карточка', M3eCardKeys.why),
    'hero': ('Главная · кнопки', kM3eHeroKey),
    'hero.shape': ('Главная · кнопки', kM3eHeroShapeKey),
    'joy': ('Главная · кнопки', kM3eJoyKey),
    'navBtn': ('Главная · кнопки', kM3eNavBtnKey),
    'subsBtn': ('Главная · кнопки', kM3eSubsBtnKey),
    'routeBtn': ('Главная · кнопки', kM3eRouteBtnKey),
  };

  group('главная: 10 сцен × 4 варианта', () {
    for (final scene in kHomeSceneIds) {
      testWidgets(scene, (tester) async {
        for (final (b, p) in _variants) {
          await _pump(tester, gateHomeApp(scene, provider: p, brightness: b));
          expect(tester.takeException(), isNull);
          final elements = _elements(_variantId(scene, b, p));
          for (final e in homeKeys.entries) {
            final (screen, key) = e.value;
            final ref = elements[e.key];
            final finder = find.byKey(key);
            if (ref == null) {
              expect(finder, findsNothing, reason: '$scene ${e.key}: лишний');
              continue;
            }
            expect(finder, findsOneWidget, reason: '$scene ${e.key}: нет');
            _record(screen, scene, e.key, _rect(ref), tester.getRect(finder));
          }
          for (final group in const ['stat', 'statValue']) {
            final refs = elements['card.$group'] as List<dynamic>;
            // Пинг убран с карточки по решению владельца 2026-10-29: колонок две
            // вместо трёх равных, поэтому x и w берём свои, а y и h сверяем с доской.
            for (var i = 0; i < 2; i++) {
              final key = group == 'stat'
                  ? M3eCardKeys.stat(i)
                  : M3eCardKeys.statValue(i);
              final ours = tester.getRect(find.byKey(key));
              final board = _rect(refs[i]);
              _record(
                'Главная · карточка',
                scene,
                'card.$group.$i',
                Rect.fromLTWH(ours.left, board.top, ours.width, board.height),
                ours,
              );
            }
          }
        }
      });
    }
  });

  group('пустой экран × 4 варианта', () {
    testWidgets('empty', (tester) async {
      final keys = <String, Key>{
        'navBtn': kM3eNavButtonKey,
        'empty': kM3eEmptyKey,
        'empty.shape': kM3eEmptyShapeKey,
        'empty.title': kM3eEmptyTitleKey,
        'empty.actions': kM3eEmptyActionsKey,
      };
      for (final (b, p) in _variants) {
        await _pump(
          tester,
          _screen(
            M3eEmptyView(onSettings: () {}, onPaste: () {}, onScan: () {}),
            brightness: b,
            p: p,
          ),
        );
        final elements = _elements(_variantId('empty', b, p));
        for (final e in keys.entries) {
          _record('Пустой экран', 'empty', e.key, _rect(elements[e.key]),
              tester.getRect(find.byKey(e.value)));
        }
        for (var i = 0; i < 2; i++) {
          _record(
            'Пустой экран',
            'empty',
            'empty.btn.$i',
            _rect(elements['empty.btn'], i),
            tester.getRect(
              find.byKey(i == 0 ? kM3eEmptyPasteKey : kM3eEmptyScanKey),
            ),
          );
        }
      }
    });
  });

  group('«О программе» × 4 варианта', () {
    testWidgets('about', (tester) async {
      Finder byId(String id) => find.byKey(ValueKey<String>('m3e.$id'));
      for (final (b, p) in _variants) {
        await _pump(
          tester,
          _screen(
            M3eAboutView(
              version: '0.10.3',
              core: '1.19.31',
              updateVersion: '0.10.4',
              onBack: () {},
              onUpdate: () {},
              onSite: () {},
              onPrivacy: () {},
            ),
            brightness: b,
            p: p,
          ),
        );
        final elements = _elements(_variantId('about', b, p));
        for (final k in const [
          'about',
          'about.logo',
          'about.title',
          'about.version',
        ]) {
          _record('О программе', 'about', k, _rect(elements[k]),
              tester.getRect(byId(k)));
        }
        // Под страницей «О программе» в layout.json лежит страница настроек: у `bar`,
        // `bar.back`, `page.title`, `list` по две записи (нужна вторая), у `list.item`
        // шесть (нужны 3..5).
        for (final k in const ['bar', 'bar.back', 'page.title', 'list']) {
          _record('О программе', 'about', k, _rect(elements[k], 1),
              tester.getRect(byId(k)));
        }
        for (var i = 0; i < 3; i++) {
          _record(
              'О программе',
              'about',
              'list.item.$i',
              _rect(elements['list.item'], 3 + i),
              tester.getRect(byId('list.item.$i')));
        }
      }
    });
  });

  group('уведомление × 4 варианта', () {
    testWidgets('support', (tester) async {
      for (final (b, p) in _variants) {
        final h = parseDropwebTheme(kBoardProviders[p].theme);
        await _pump(
          tester,
          m3eBoardApp(
            seed: h.accent,
            filter: h.filter,
            brightness: b,
            child: Builder(
              builder: (context) => Stack(
                children: [
                  Positioned.fill(
                    child: M3eToastPresenter(
                      message: M3eToastMessage(
                        // На доске support = ['out', …].
                        kind: M3eToastKind.out,
                        text: AppLocalizations.of(context).m3eToastSupport,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        // Вход плашки идёт пружиной: ждём, пока она сядет.
        await tester.pump(const Duration(milliseconds: 700));
        final elements = _elements(_variantId('support', b, p));
        for (final k in const ['toast', 'toast.text']) {
          // Решение владельца 2026-10-29: центр плашки на линии кнопки настроек, на
          // доске она ниже на 6 dp (y 52 против 46); сдвиг вычитается явно.
          _record(
              'Уведомление',
              'support',
              k,
              _rect(elements[k])
                  .shift(const Offset(0, -(52 - (44 + kM3eToastTopGap)))),
              tester.getRect(find.byKey(ValueKey<String>('m3e.$k'))));
        }
        // Презентер держит плашку 2200 мс и сам гасит; снимаем сообщение до конца теста.
        await tester.pump(const Duration(seconds: 4));
      }
    });
  });

  tearDownAll(() {
    final out = Platform.environment['M3E_PARITY_TABLE'];
    if (out == null || out.isEmpty) return;
    String fmt(Rect r) =>
        '${r.left.toStringAsFixed(1)},${r.top.toStringAsFixed(1)} '
        '${r.width.toStringAsFixed(1)}×${r.height.toStringAsFixed(1)}';
    final rows = _rows.values.toList();
    final buffer = StringBuffer()
      ..writeln('# Паритет раскладки с доской (фаза A, ворота 4)')
      ..writeln()
      ..writeln(
          'Источник: `test/m3e/parity_report_test.dart`, эталон `test/m3e/ref/layout.json` '
          '(dp, корень 411×914). Допуск ±$_tolerance dp на каждую из величин x, y, w, h. '
          'Δmax — наибольшее расхождение среди четырёх вариантов (light/dark × провайдер 0/5); '
          'колонки «Доска» и «Flutter» — вариант с наибольшим Δ. '
          'Все строки проверяются тестом: превышение допуска роняет тест.')
      ..writeln()
      ..writeln(
          'Строк: ${rows.length}, не в допуске: ${rows.where((r) => r.delta > _tolerance).length}, '
          'наибольшее Δ: ${rows.map((r) => r.delta).reduce((a, b) => a > b ? a : b).toStringAsFixed(2)} dp.')
      ..writeln()
      ..writeln(
          '| Экран | Сцена | Ключ | Доска x,y w×h | Flutter x,y w×h | Δmax dp | ок |')
      ..writeln('|---|---|---|---|---|---|---|');
    for (final r in rows) {
      buffer
          .writeln('| ${r.screen} | ${r.scene} | ${r.key} | ${fmt(r.board)} | '
              '${fmt(r.ours)} | ${r.delta.toStringAsFixed(2)} | '
              '${r.delta <= _tolerance ? 'да' : 'НЕТ'} |');
    }
    File(out).writeAsStringSync(buffer.toString());
  });
}
