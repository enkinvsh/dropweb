import 'dart:convert';
import 'dart:io';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/screens/m3e_empty_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

/// Пустой экран как у эталонов: `disableAnimations` (эталон снят с reducedMotion).
Widget _view({
  VoidCallback? onSettings,
  VoidCallback? onPaste,
  VoidCallback? onScan,
  double textScale = 1,
}) =>
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: M3eEmptyView(
          onSettings: onSettings ?? () {},
          onPaste: onPaste ?? () {},
          onScan: onScan ?? () {},
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

Rect _ref(String scene, String key) {
  final all = jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
      as Map<String, dynamic>;
  final elements =
      (all[scene] as Map<String, dynamic>)['elements'] as Map<String, dynamic>;
  var e = elements[key];
  if (e is List) e = e.first;
  final m = e as Map<String, dynamic>;
  return Rect.fromLTWH(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['w'] as num).toDouble(),
    (m['h'] as num).toDouble(),
  );
}

void _expectRectNear(Rect actual, Rect expected, String what,
    {double tol = 4}) {
  expect((actual.left - expected.left).abs(), lessThanOrEqualTo(tol),
      reason: '$what left $actual vs $expected');
  expect((actual.top - expected.top).abs(), lessThanOrEqualTo(tol),
      reason: '$what top $actual vs $expected');
  expect((actual.width - expected.width).abs(), lessThanOrEqualTo(tol),
      reason: '$what width $actual vs $expected');
  expect((actual.height - expected.height).abs(), lessThanOrEqualTo(tol),
      reason: '$what height $actual vs $expected');
}

const _cases = [
  ('light', 0, Brightness.light),
  ('light', 5, Brightness.light),
  ('dark', 0, Brightness.dark),
  ('dark', 5, Brightness.dark),
];

void main() {
  group('golden', () {
    for (final (theme, p, brightness) in _cases) {
      testWidgets('empty_${theme}_p$p', (tester) async {
        await _pump(tester, _view(), provider: p, brightness: brightness);
        await expectM3eGolden(tester, 'empty_${theme}_p$p');
      });
    }
  });

  group('паритет с layout.json (±4 dp)', () {
    for (final (theme, p, brightness) in _cases) {
      testWidgets('empty-$theme-p$p', (tester) async {
        await _pump(tester, _view(), provider: p, brightness: brightness);
        final scene = 'empty-$theme-p$p';
        final keys = <String, Key>{
          'navBtn': kM3eNavButtonKey,
          'empty': kM3eEmptyKey,
          'empty.shape': kM3eEmptyShapeKey,
          'empty.title': kM3eEmptyTitleKey,
          'empty.actions': kM3eEmptyActionsKey,
        };
        for (final e in keys.entries) {
          _expectRectNear(
              tester.getRect(find.byKey(e.value)), _ref(scene, e.key), e.key);
        }
        // empty.btn в layout.json — список из двух кнопок, берём по индексу
        final all =
            jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
                as Map<String, dynamic>;
        final btns = ((all[scene] as Map<String, dynamic>)['elements']
            as Map<String, dynamic>)['empty.btn'] as List;
        for (var i = 0; i < 2; i++) {
          final m = btns[i] as Map<String, dynamic>;
          _expectRectNear(
            tester.getRect(
                find.byKey(i == 0 ? kM3eEmptyPasteKey : kM3eEmptyScanKey)),
            Rect.fromLTWH(
                (m['x'] as num).toDouble(),
                (m['y'] as num).toDouble(),
                (m['w'] as num).toDouble(),
                (m['h'] as num).toDouble()),
            'empty.btn.$i',
          );
        }
      });
    }
  });

  group('поведение', () {
    testWidgets('тапы зовут свои обработчики', (tester) async {
      var settings = 0, paste = 0, scan = 0;
      await _pump(
        tester,
        _view(
          onSettings: () => settings++,
          onPaste: () => paste++,
          onScan: () => scan++,
        ),
      );
      await tester.tap(find.byKey(kM3eNavButtonKey));
      await tester.pump(const Duration(milliseconds: 500));
      expect((settings, paste, scan), (1, 0, 0));
      await tester.tap(find.byKey(kM3eEmptyPasteKey));
      await tester.pump(const Duration(milliseconds: 500));
      expect((settings, paste, scan), (1, 1, 0));
      await tester.tap(find.byKey(kM3eEmptyScanKey));
      await tester.pump(const Duration(milliseconds: 500));
      expect((settings, paste, scan), (1, 1, 1));
    });

    testWidgets('семантика: подписи кнопок и кнопка настроек', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _view());
      final l10n = AppLocalizations.current;
      expect(tester.getSemantics(find.byKey(kM3eEmptyPasteKey)).label,
          contains(l10n.m3eEmptyPaste));
      expect(tester.getSemantics(find.byKey(kM3eEmptyScanKey)).label,
          contains(l10n.m3eEmptyScanQr));
      expect(tester.getSemantics(find.byKey(kM3eNavButtonKey)).label,
          contains(l10n.m3eA11ySettings));
      expect(find.text(l10n.m3eEmptyTitle), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('крупный шрифт 1,3 и 2,0 без переполнения', (tester) async {
      for (final scale in [1.3, 2.0]) {
        await _pump(tester, _view(textScale: scale));
        expect(tester.takeException(), isNull, reason: 'scale $scale');
      }
    });

    testWidgets(
        'низкое окно и крупный шрифт: блок прокручивается, без overflow',
        (tester) async {
      await _pump(tester, _view(textScale: 1.3));
      tester.view.physicalSize = const Size(411 * 2, 420 * 2);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('узкое окно 320 dp: кнопки не переполняют', (tester) async {
      await _pump(tester, _view(textScale: 1.3));
      tester.view.physicalSize = const Size(320 * 2, 914 * 2);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
