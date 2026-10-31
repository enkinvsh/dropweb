// Экран главной iOS: golden всех сцен доски × светлая/тёмная (против `ref/<сцена>-<тема>-rt-p0`),
// провайдер p5 для home-off и home-on, сцена `support` (главная под тостом).

import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass_away.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/layers/ios27_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/glass_away_probe.dart';
import 'support/golden.dart';
import 'support/home_harness.dart';

void main() {
  for (final scene in kIos27HomeScenes) {
    for (final brightness in Brightness.values) {
      final mode = brightness.name;
      testWidgets('golden: $scene / $mode / p0', (tester) async {
        try {
          await pumpHomeScene(tester, scene, brightness: brightness);
          expect(tester.takeException(), isNull);
          await expectIos27Golden(tester, 'home_${scene}_${mode}_p0');
        } finally {
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }

  // Провайдер p5 (серо-голубой) красит кнопку питания и фон; карточка от провайдера не зависит.
  for (final scene in ['home-off', 'home-on']) {
    for (final brightness in Brightness.values) {
      final mode = brightness.name;
      testWidgets('golden: $scene / $mode / p5', (tester) async {
        try {
          await pumpHomeScene(
            tester,
            scene,
            brightness: brightness,
            provider: 5,
          );
          expect(tester.takeException(), isNull);
          await expectIos27Golden(tester, 'home_${scene}_${mode}_p5');
        } finally {
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }

  // Сцена `support`: главная home-off под тостом «Открываем справочную» (app.js:199).
  for (final brightness in Brightness.values) {
    final mode = brightness.name;
    testWidgets('golden: support / $mode', (tester) async {
      try {
        await pumpHomeScene(
          tester,
          'home-off',
          brightness: brightness,
          overlay: const Positioned.fill(
            child: Ios27ToastPresenter(
              message: M3eToastMessage(
                kind: M3eToastKind.out,
                text: 'Открываем справочную',
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await expectIos27Golden(tester, 'home_support_${mode}_p0');
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    });
  }

  testWidgets('нижний ряд уходит под листом и возвращается', (tester) async {
    Widget app({required bool away}) => ios27BoardApp(
          brightness: Brightness.light,
          child: ios27HomeFrame(
            input: homeInputFor('home-off'),
            glassAway: away,
          ),
        );
    Finder dock() => find.byKey(const ValueKey<String>('dock'));
    bool ignoring() => tester
        .widget<IgnorePointer>(
          find.ancestor(of: dock(), matching: find.byType(IgnorePointer)).first,
        )
        .ignoring;
    bool semanticsExcluded() => tester
        .widget<ExcludeSemantics>(
          find
              .ancestor(of: dock(), matching: find.byType(ExcludeSemantics))
              .first,
        )
        .excluding;

    await pumpIos27Board(tester, app(away: false));
    expect(dockGlassFade(tester), 1);
    expect(ignoring(), isFalse);
    expect(semanticsExcluded(), isFalse);

    // `away` идёт в само стекло: три кнопки ряда, а не слой над ними.
    final glasses = tester.widgetList<Ios27Glass>(
        find.descendant(of: dock(), matching: find.byType(Ios27Glass)));
    expect(glasses, hasLength(3));
    expect(glasses.every((g) => !g.away), isTrue);

    await tester.pumpWidget(app(away: true));
    expect(ignoring(), isTrue, reason: 'невидимые кнопки не нажимаются');
    expect(semanticsExcluded(), isTrue, reason: 'и не читаются VoiceOver');
    expect(
      tester
          .widgetList<Ios27Glass>(
              find.descendant(of: dock(), matching: find.byType(Ios27Glass)))
          .every((g) => g.away),
      isTrue,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(dockGlassFade(tester), 0);

    await tester.pumpWidget(app(away: false));
    expect(ignoring(), isFalse);
    // Возврат с задержкой 150 мс и 300 мс хода (app.css:331).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(dockGlassFade(tester), 1);
  });

  // Значки гаснут вместе с материалом: они лежат внутри содержимого стекла, а не снаружи него.
  testWidgets('значки ряда лежат под прозрачностью содержимого стекла',
      (tester) async {
    await pumpIos27Board(
      tester,
      ios27BoardApp(
        brightness: Brightness.light,
        child: ios27HomeFrame(input: homeInputFor('home-off')),
      ),
    );
    for (final name in [
      Ios27IconName.stack,
      Ios27IconName.power,
      Ios27IconName.globe,
    ]) {
      expect(
        find.descendant(
          of: find.descendant(
            of: find.byKey(const ValueKey<String>('dock')),
            matching: find.byType(Ios27GlassAwayFade),
          ),
          matching:
              find.byWidgetPredicate((w) => w is Ios27Icon && w.name == name),
        ),
        findsOneWidget,
        reason: '$name',
      );
    }
  });
}
