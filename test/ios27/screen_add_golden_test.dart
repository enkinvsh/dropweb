// Экран «Добавить подписку» iOS: golden против эталонов доски (G3) и рамки против layout.json (G4).
//
// Сцены: `add` (шаг листа «Подписка», поле пустое), `add-empty` (отдельный лист с пустой
// главной, ссылка подставлена), `add-error` (ошибка поля; на доске эталона нет, golden для глаза).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_add_support.dart';
import 'support/golden.dart';
import 'support/layout.dart';

const String _board = 'https://dropweb.site/s/7f3a9c2e';

Finder _k(String key) => find.byKey(ValueKey<String>(key));

Map<String, Finder> _elements() => {
      'sheet': _k('ios27.sheet.frame'),
      'sheet.title': _k('ios27.sheet.title'),
      'sheet.back': _k('ios27.sheet.back'),
      'sheet.close': _k('ios27.sheet.close'),
      'sheet.foot': _k('sheet.foot'),
      'sheet.submit': _k('sheet.submit'),
      'sheet.group': _k('sheet.group'),
      'sheet.row': _k('sheet.row'),
      'sheet.rowTitle': _k('sheet.rowTitle'),
      'sheet.rowIcon': _k('sheet.rowIcon'),
      'sheet.field': _k('sheet.field'),
      'sheet.fieldInput': _k('sheet.fieldInput'),
      'sheet.fieldPaste': _k('sheet.fieldPaste'),
      'sheet.fieldError': _k('sheet.fieldError'),
      'sheet.addBtn': _k('sheet.addBtn'),
    };

Future<void> _scene(
  WidgetTester tester,
  String scene,
  Brightness brightness, {
  bool backdrop = true,
}) async {
  switch (scene) {
    case 'add':
      await pumpAdd(tester, AddEntry.step,
          brightness: brightness, backdrop: backdrop);
    case 'add-empty':
      await pumpAdd(tester, AddEntry.sheet,
          brightness: brightness, initialUrl: _board, backdrop: backdrop);
    case 'add-error':
      await pumpAdd(tester, AddEntry.sheet,
          brightness: brightness,
          initialUrl: 'dropweb.site/s/7f3a9c2e',
          backdrop: backdrop);
      await tester.tap(find.byKey(addButton));
      await settleAdd(tester);
    default:
      fail('нет сцены $scene');
  }
}

void main() {
  for (final scene in ['add', 'add-empty', 'add-error']) {
    for (final brightness in Brightness.values) {
      final mode = brightness.name;
      testWidgets('golden: $scene / $mode', (tester) async {
        try {
          await _scene(tester, scene, brightness);
          expect(tester.takeException(), isNull);
          await expectIos27Golden(tester, '${scene}_${mode}_p0');
        } finally {
          await tester.pumpWidget(const SizedBox());
        }
      });

      // У ошибки эталона нет: рамки сверяются по сцене, из которой она получена.
      final ref = scene == 'add-error' ? 'add-empty' : scene;
      testWidgets('рамки: $scene / $mode', (tester) async {
        try {
          await _scene(tester, scene, brightness, backdrop: false);
          expect(tester.takeException(), isNull);
          final elements = _elements();
          if (scene == 'add-error') {
            // С ошибкой всё ниже поля уезжает на высоту строки ошибки: сверяем верх.
            elements
              ..remove('sheet.group')
              ..remove('sheet.row')
              ..remove('sheet.rowTitle')
              ..remove('sheet.rowIcon')
              ..remove('sheet.fieldError');
          }
          final rows = ios27Parity(tester, '$ref-$mode-rt-p0', elements);
          // Заголовок группы: ключ стоит на всей полосе `.group-head` (363×26), как на доске.
          final head = Ios27RefLayout.load('$ref-$mode-rt-p0')
              .element('sheet.groupHead')!;
          rows.add(
            Ios27ParityRow(
              name: 'sheet.groupHead',
              ref: head,
              app: rectOf(tester, _k('sheet.groupHead')),
              tol: 4,
            ),
          );
          expectIos27Parity(rows);
        } finally {
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }
}
