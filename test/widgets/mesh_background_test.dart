import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/mesh_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts the mesh without a Navigator so `ModalRoute.of` is null and the only
/// thing gating the breathe is [TickerMode] — which is exactly what a hidden /
/// covered screen flips on macOS, and what has to make the app App Nap
/// eligible instead of waking the CPU forever.
Widget _host({required bool tickerEnabled}) => ProviderScope(
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: ThemeData(brightness: Brightness.dark),
            child: TickerMode(
              enabled: tickerEnabled,
              child: const MeshBackground(),
            ),
          ),
        ),
      ),
    );

/// The three orb alphas are the mesh's entire visible state, so a change here
/// is a repaint and no change is a frozen frame.
List<Color> _orbColors(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((box) =>
        ((box.decoration as BoxDecoration).gradient! as RadialGradient)
            .colors
            .first)
    .toList();

/// The breathe phase is wall-clock derived, so fake-async time alone never
/// advances it — let real time pass, then pump to sample the new phase.
Future<void> _letWallClockAdvance(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)),
  );
}

void main() {
  setUp(() {
    globalState.config = const Config(themeProps: defaultThemeProps);
  });

  testWidgets('breathe is driven by a vsync ticker while visible',
      (tester) async {
    await tester.pumpWidget(_host(tickerEnabled: true));
    await tester.pump();

    // A raw Timer registers no frame callback; a Ticker does.
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    final before = _orbColors(tester);
    await _letWallClockAdvance(tester);
    await tester.pump();
    expect(_orbColors(tester), isNot(before));
  });

  testWidgets('ticker stops under TickerMode(enabled: false)', (tester) async {
    await tester.pumpWidget(_host(tickerEnabled: false));
    await tester.pump();

    expect(tester.binding.transientCallbackCount, 0);

    final before = _orbColors(tester);
    await _letWallClockAdvance(tester);
    // Advance fake time well past the 80 ms step: a Timer-driven mesh repaints
    // here, a ticker-driven one stays frozen because the ticker is muted.
    await tester.pump(const Duration(milliseconds: 200));
    expect(_orbColors(tester), before);
  });
}
