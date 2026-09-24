// Home lens (ConnectCircle) frame/rebuild budget.
//
// * While the aura spins (connecting handshake) the per-frame AnimatedBuilder
//   must NOT rebuild the StartButton glyph stack (ImageFiltered blur + HugeIcon
//   + optional ShaderMask) — it is passed through as the builder's `child`.
// * Disconnected / connected-and-settled lens requests no idle frames.
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/pages/home/connect_circle.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/dashboard/widgets/start_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

const _vsync120 = Duration(microseconds: 8333);

class _NullRunTime extends RunTime {
  @override
  int? build() => null;
}

class _RunningRunTime extends RunTime {
  @override
  int? build() => 1000;
}

Future<void> _pumpLens(WidgetTester tester, RunTime Function() rt) =>
    tester.pumpWidget(ProviderScope(
      overrides: [
        runTimeProvider.overrideWith(rt),
        startButtonSelectorStateProvider.overrideWithValue(
          const StartButtonSelectorState(
            isInit: true,
            hasProfile: true,
            hasProxiesInit: true,
          ),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const Scaffold(
          body: Center(child: ConnectCircle(buttonSize: 160)),
        ),
      ),
    ));

Future<int> _idleFramesRequested(WidgetTester tester) async {
  var requested = 0;
  for (var i = 0; i < 60; i++) {
    await tester.pump(_vsync120);
    if (SchedulerBinding.instance.hasScheduledFrame) requested++;
  }
  return requested;
}

void main() {
  setUp(() {
    globalState.config = const Config(themeProps: defaultThemeProps);
    globalState.isConnecting.value = false;
  });
  tearDown(() {
    globalState.isConnecting.value = false;
    widgets.debugOnRebuildDirtyWidget = null;
  });

  testWidgets('connecting: aura frames do not rebuild StartButton / HugeIcon',
      (tester) async {
    await _pumpLens(tester, _NullRunTime.new);
    await tester.pumpAndSettle();

    globalState.isConnecting.value = true; // handshake starts
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // iris ramp done

    var startButton = 0;
    var hugeIcon = 0;
    widgets.debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is StartButton) startButton++;
      if (element.widget is HugeIcon) hugeIcon++;
    };
    const frames = 120; // 1 s @ 120 Hz
    for (var i = 0; i < frames; i++) {
      await tester.pump(_vsync120);
    }
    widgets.debugOnRebuildDirtyWidget = null;
    // ignore: avoid_print
    print('[lens-connecting] frames=$frames StartButton.rebuilds=$startButton '
        'HugeIcon.rebuilds=$hugeIcon');
    // Before the fix: StartButton >= 119 rebuilds per second.
    expect(startButton, 0);
    expect(hugeIcon, 0);
  });

  testWidgets('disconnected: settles, no idle frames', (tester) async {
    await _pumpLens(tester, _NullRunTime.new);
    await tester.pumpAndSettle();
    expect(await _idleFramesRequested(tester), 0);
  });

  testWidgets('connected: one settle spin, then no idle frames',
      (tester) async {
    await _pumpLens(tester, _RunningRunTime.new);
    await tester.pumpAndSettle();
    expect(await _idleFramesRequested(tester), 0);
  });
}
