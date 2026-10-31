// Тон стекла кнопки питания идёт за ЦЕЛЕВЫМ состоянием, а не за долей пружины (W2b, P1).
//
// Баг, который тест закрывает: пружина тона садилась на 8.5e-5 вместо 0, а `tint` стекла
// выбирался как `t > 0`, поэтому после «включено → выключено» кнопка навсегда оставалась цвета
// акцента (диагностика: .omo/ios/g6/diag-bg-power.md, P1).

import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_power_button.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden.dart';

void main() {
  late Color accent;

  Widget app(Ios27PowerState state, {bool disableAnimations = false}) =>
      ios27BoardApp(
        brightness: Brightness.light,
        disableAnimations: disableAnimations,
        child: Builder(
          builder: (context) {
            accent = ios27ColorsFor(context).accentColor;
            return Center(
              child: Ios27PowerButton(state: state, semanticLabel: 'Питание'),
            );
          },
        ),
      );

  Color? tint(WidgetTester tester) =>
      tester.widget<Ios27Glass>(find.byType(Ios27Glass)).tint;

  /// Пружина идёт от первого тика: `pump()` запускает тикер, затем двух секунд хватает с запасом
  /// (smooth садится за 735 мс).
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('включили → выключили: тон снимается совсем и не залипает',
      (tester) async {
    await pumpIos27Board(tester, app(Ios27PowerState.off));
    expect(tint(tester), isNull);

    await tester.pumpWidget(app(Ios27PowerState.on));
    expect(
      tint(tester),
      accent,
      reason: 'стеклу сразу передаётся целевой тон: проявляет его сам материал',
    );
    await settle(tester);
    expect(tint(tester), accent);

    await tester.pumpWidget(app(Ios27PowerState.off));
    expect(tint(tester), isNull, reason: 'цель — без тона, в тот же кадр');
    await settle(tester);
    expect(
      tint(tester),
      isNull,
      reason: 'остаток пружины 8.5e-5 не должен оставлять кнопку цветной',
    );
    expect(tester.binding.transientCallbackCount, 0);

    // И обратно: цикл повторяется без накопления ошибки.
    await tester.pumpWidget(app(Ios27PowerState.on));
    await settle(tester);
    expect(tint(tester), accent);
    await tester.pumpWidget(app(Ios27PowerState.off));
    await settle(tester);
    expect(tint(tester), isNull);
  });

  testWidgets('выключили на полпути: цель важнее текущей доли пружины',
      (tester) async {
    await pumpIos27Board(tester, app(Ios27PowerState.off));
    await tester.pumpWidget(app(Ios27PowerState.on));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tint(tester), accent);

    await tester.pumpWidget(app(Ios27PowerState.off));
    expect(tint(tester), isNull);
    await settle(tester);
    expect(tint(tester), isNull);
  });

  testWidgets('все не-«включено» виды без тона, «включено» с тоном',
      (tester) async {
    for (final state in Ios27PowerState.values) {
      await pumpIos27Board(tester, app(state));
      await settle(tester);
      expect(
        tint(tester),
        state == Ios27PowerState.on ? accent : isNull,
        reason: '$state',
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Reduce Motion: тон меняется сразу в обе стороны',
      (tester) async {
    await pumpIos27Board(
      tester,
      app(Ios27PowerState.off, disableAnimations: true),
    );
    await tester.pumpWidget(app(Ios27PowerState.on, disableAnimations: true));
    expect(tint(tester), accent);
    await tester.pumpWidget(app(Ios27PowerState.off, disableAnimations: true));
    expect(tint(tester), isNull);
  });
}
