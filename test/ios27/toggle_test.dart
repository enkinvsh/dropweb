// Переключатель iOS 27 (Ios27Toggle): тап, отключённое состояние, семантика, раздутие ручки под пальцем,
// Reduce Motion / Reduce Transparency, освобождение контроллеров, голдены prim_toggle_*.

import 'dart:ui' show Tristate;

import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/board_providers.dart';
import 'support/golden.dart';

/// Хозяин с состоянием: реальный экран хранит значение у себя.
class _Host extends StatefulWidget {
  const _Host({this.onChanged, this.identifier});

  final ValueChanged<bool>? onChanged;
  final String? identifier;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool _value = false;

  @override
  Widget build(BuildContext context) => Center(
        child: Ios27Toggle(
          value: _value,
          semanticLabel: 'Умный режим',
          semanticIdentifier: widget.identifier,
          onChanged: (v) {
            setState(() => _value = v);
            widget.onChanged?.call(v);
          },
        ),
      );
}

Ios27ProviderTheme _theme(int i) =>
    Ios27ProviderTheme.fromHeader(kBoardProviders[i].theme);

/// Окно доски со светлой темой по умолчанию.
Widget _app({
  required Widget child,
  Brightness brightness = Brightness.light,
  Ios27ProviderTheme theme = Ios27ProviderTheme.defaults,
  bool reduceTransparency = true,
  double textScale = 1.0,
  bool disableAnimations = false,
}) =>
    ios27BoardApp(
      child: child,
      brightness: brightness,
      theme: theme,
      reduceTransparency: reduceTransparency,
      textScale: textScale,
      disableAnimations: disableAnimations,
    );

BoxDecoration _knobDecoration(WidgetTester tester) {
  final box =
      tester.widget<DecoratedBox>(find.byKey(const ValueKey('toggle.knob')));
  return box.decoration as BoxDecoration;
}

Size _knobSize(WidgetTester tester) {
  final f = find.byKey(const ValueKey('toggle.knob'));
  return (tester.getBottomRight(f) - tester.getTopLeft(f)).toSize();
}

double _knobLeft(WidgetTester tester) {
  final track = tester.getTopLeft(find.byType(Ios27Toggle)).dx;
  return tester.getTopLeft(find.byKey(const ValueKey('toggle.knob'))).dx -
      track;
}

extension on Offset {
  Size toSize() => Size(dx, dy);
}

void main() {
  tearDown(Ios27A11y.debugReset);

  testWidgets('тап переключает значение, ручка едет на 22 px', (tester) async {
    final calls = <bool>[];
    await pumpIos27Board(
      tester,
      _app(child: _Host(onChanged: calls.add)),
    );
    expect(tester.getSize(find.byType(Ios27Toggle)), const Size(64, 28));
    expect(_knobLeft(tester), closeTo(2, 0.01));
    expect(_knobSize(tester), const Size(38, 24));

    await tester.tap(find.byType(Ios27Toggle));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(calls, [true]);
    expect(_knobLeft(tester), closeTo(24, 0.05));

    await tester.tap(find.byType(Ios27Toggle));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(calls, [true, false]);
    expect(_knobLeft(tester), closeTo(2, 0.05));
  });

  testWidgets(
      'onChanged == null: отключён, половинная яркость, тап ничего не делает',
      (tester) async {
    await pumpIos27Board(
      tester,
      _app(
        child: const Center(
          child: Ios27Toggle(value: true, onChanged: null, semanticLabel: 'X'),
        ),
      ),
    );
    expect(
      tester
          .widget<Opacity>(find.descendant(
            of: find.byType(Ios27Toggle),
            matching: find.byType(Opacity),
          ))
          .opacity,
      0.5,
    );
    await tester.tap(find.byType(Ios27Toggle));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_knobLeft(tester), closeTo(24, 0.01));
    final sem = tester.getSemantics(find.byType(Ios27Toggle));
    expect(sem.flagsCollection.isEnabled, Tristate.isFalse);
    expect(sem.flagsCollection.isToggled, Tristate.isTrue);
  });

  testWidgets('семантика: toggled, подпись, идентификатор', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpIos27Board(
        tester,
        _app(child: const _Host(identifier: 'dw_smart')),
      );
      expect(find.bySemanticsIdentifier('dw_smart'), findsOneWidget);
      var sem = tester.getSemantics(find.bySemanticsIdentifier('dw_smart'));
      expect(sem.label, 'Умный режим');
      expect(sem.flagsCollection.isToggled, Tristate.isFalse);
      expect(sem.flagsCollection.isEnabled, Tristate.isTrue);

      await tester.tap(find.bySemanticsIdentifier('dw_smart'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1200));
      sem = tester.getSemantics(find.bySemanticsIdentifier('dw_smart'));
      expect(sem.flagsCollection.isToggled, Tristate.isTrue);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('под пальцем ручка раздувается ×1,5 × 1,55 и возвращается',
      (tester) async {
    await pumpIos27Board(tester, _app(child: const _Host()));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Ios27Toggle)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    final pressed = _knobSize(tester);
    expect(pressed.width, closeTo(38 * 1.5, 1.5));
    expect(pressed.height, closeTo(24 * 1.55, 1.5));

    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_knobSize(tester).width, closeTo(38, 0.05));
    expect(_knobSize(tester).height, closeTo(24, 0.05));
  });

  testWidgets('линза под пальцем: полупрозрачная; Reduce Transparency — белая',
      (tester) async {
    for (final rt in [false, true]) {
      await pumpIos27Board(
        tester,
        _app(reduceTransparency: rt, child: const _Host()),
      );
      expect(Ios27A11y.reduceTransparency, rt);
      final rest = _knobDecoration(tester).color!;
      expect(rest.a, 1.0);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Ios27Toggle)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      final lens = _knobDecoration(tester).color!;
      if (rt) {
        expect(lens.a, 1.0,
            reason: 'при Reduce Transparency ручка остаётся белой');
      } else {
        expect(lens.a, lessThan(0.4), reason: 'линза прозрачная (#FFFFFF33)');
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1500));
    }
  });

  testWidgets('Reduce Motion: ручка прыгает, не раздувается, тикеры не бегут',
      (tester) async {
    await pumpIos27Board(
      tester,
      _app(disableAnimations: true, child: const _Host()),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Ios27Toggle)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_knobSize(tester), const Size(38, 24));
    await gesture.up();
    await tester.pump();
    // Значение поменялось: ручка встала на место сразу, без пружины.
    expect(_knobLeft(tester), closeTo(24, 0.01));
    // Остаётся лишь смена цвета трека (250 мс); после неё тикеров нет.
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('контроллеры освобождаются при удалении из дерева',
      (tester) async {
    await pumpIos27Board(tester, _app(child: const _Host()));
    await tester.tap(find.byType(Ios27Toggle));
    await tester.pump(const Duration(milliseconds: 50));
    // Пружина ещё бежит — удаляем виджет посреди движения.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('в строке списка при масштабе шрифта 2.0 нет переполнения',
      (tester) async {
    await pumpIos27Board(
      tester,
      _app(
        textScale: 2.0,
        child: const SingleChildScrollView(
          child: Ios27List(children: [
            Ios27ListRow(
              title: 'Умный режим: сам выбирает лучший узел для вашей сети',
              trailing: Ios27Toggle(value: true, onChanged: _noop),
            ),
          ]),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Ios27Toggle)), const Size(64, 28));
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    for (final p in [0, 5]) {
      if (p == 5 && dark) {
        continue;
      }
      testWidgets(
          'golden prim_toggle_${mode}_p$p: выкл / вкл / нажат / отключён',
          (tester) async {
        await pumpIos27Board(
          tester,
          _app(
            brightness: dark ? Brightness.dark : Brightness.light,
            theme: _theme(p),
            disableAnimations: true,
            child: Container(
              color: dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
              padding: const EdgeInsets.all(32),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 24,
                children: [
                  Ios27Toggle(value: false, onChanged: _noop),
                  Ios27Toggle(value: true, onChanged: _noop),
                  Ios27Toggle(value: true, onChanged: null),
                  Ios27Toggle(value: false, onChanged: null),
                ],
              ),
            ),
          ),
        );
        await expectIos27Golden(tester, 'prim_toggle_${mode}_p$p');
      });
    }
  }
}

void _noop(bool _) {}
