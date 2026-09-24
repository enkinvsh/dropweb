import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/mesh_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// One 120 Hz vsync (Pixel 10 display rate).
const _vsync120 = Duration(microseconds: 8333);

/// Hosts the mesh without a Navigator so `ModalRoute.of` is null and the only
/// gates are [TickerMode] and reduce-motion — [TickerMode] is exactly what a
/// hidden / covered screen flips on macOS, and what has to make the app App
/// Nap eligible instead of waking the CPU forever.
Widget _host({required bool tickerEnabled, bool reduceMotion = false}) =>
    ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
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

/// Frames actually drawn (the test binding only draws when a frame was
/// scheduled, exactly like the engine only renders on a requested vsync).
int _framesDrawn = 0;
bool _frameCounterInstalled = false;

void _installFrameCounter() {
  if (_frameCounterInstalled) return;
  _frameCounterInstalled = true;
  SchedulerBinding.instance.addPersistentFrameCallback((_) => _framesDrawn++);
}

/// Simulates one second of 120 Hz vsyncs. The breathe phase is wall-clock
/// derived, so real time is let through alongside the fake clock — otherwise
/// the phase could not move and every step would be a no-op. Returns the
/// number of frames drawn during that second.
Future<int> _framesInOneSecond(WidgetTester tester) async {
  _framesDrawn = 0;
  for (var i = 0; i < 120; i++) {
    await tester.runAsync(() => Future<void>.delayed(_vsync120));
    await tester.pump(_vsync120);
  }
  return _framesDrawn;
}

void main() {
  setUp(() {
    globalState.config = const Config(themeProps: defaultThemeProps);
  });

  testWidgets('visible: ~12.5 frames/s (80 ms wall-clock step), not per vsync',
      (tester) async {
    _installFrameCounter();
    await tester.pumpWidget(_host(tickerEnabled: true));
    await tester.pump();

    // No vsync ticker: a repeating controller would schedule every vsync.
    expect(tester.binding.transientCallbackCount, 0);

    final before = _orbColors(tester);
    final frames = await _framesInOneSecond(tester);
    // ignore: avoid_print
    print('[mesh] visible framesDrawn/1s@120Hz = $frames');
    expect(frames, inInclusiveRange(12, 13));
    expect(_orbColors(tester), isNot(before), reason: 'breathe still moves');
  });

  testWidgets('TickerMode disabled: 0 frames, frozen, resumes when re-enabled',
      (tester) async {
    _installFrameCounter();
    await tester.pumpWidget(_host(tickerEnabled: false));
    await tester.pump();

    final before = _orbColors(tester);
    final frames = await _framesInOneSecond(tester);
    // ignore: avoid_print
    print('[mesh] TickerMode(false) framesDrawn/1s = $frames');
    expect(frames, 0);
    expect(_orbColors(tester), before);

    await tester.pumpWidget(_host(tickerEnabled: true));
    await tester.pump();
    expect(await _framesInOneSecond(tester), inInclusiveRange(12, 13));
  });

  testWidgets('reduce-motion: 0 frames', (tester) async {
    _installFrameCounter();
    await tester.pumpWidget(_host(tickerEnabled: true, reduceMotion: true));
    await tester.pump();

    final frames = await _framesInOneSecond(tester);
    // ignore: avoid_print
    print('[mesh] reduceMotion framesDrawn/1s = $frames');
    expect(frames, 0);
  });

  testWidgets('app backgrounded: 0 frames', (tester) async {
    _installFrameCounter();
    await tester.pumpWidget(_host(tickerEnabled: true));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    // Background disables frames in the binding anyway; the point is that the
    // timer is gone, so nothing keeps waking the isolate.
    _framesDrawn = 0;
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(() => Future<void>.delayed(_vsync120));
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(_framesDrawn, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(await _framesInOneSecond(tester), inInclusiveRange(12, 13));
  });
}
