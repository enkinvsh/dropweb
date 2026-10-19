// Brick-regression lock for the dashboard connect button.
//
// History: `StartButton.build()` used to early-return `SizedBox.shrink()`
// whenever `state.isInit` was false (lib/views/dashboard/widgets/start_button.dart).
// `isInit` only flips true at the very end of `AppController.init()`
// (lib/controller.dart) — behind the boot auto-start reconcile. If that boot
// path stalled or threw, `init()` never reached `initProvider = true`, so the
// glyph stayed hidden forever: only the parent glass painter remained (the
// "empty circle" bug) and the UI was bricked until force-kill.
//
// The fix keeps the glyph ALWAYS rendered, merely dimmed + non-tappable while
// `isConnecting || !isInit` (the existing "pending" affordance). This test
// pins that: with `isInit: false` the power glyph must still be in the tree.
//
// Cross-links: lib/views/dashboard/widgets/start_button.dart (_buildButton),
// lib/controller.dart (init() / initProvider), lib/models/selector.dart.

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/views/dashboard/widgets/start_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

/// Returns `runTime == null` without touching the `late` `globalState.appState`
/// (which is uninitialised in a unit-test context). The real `RunTime.build()`
/// reads `globalState.appState.runTime`, so it can't run here.
class _NullRunTime extends RunTime {
  @override
  int? build() => null;
}

void main() {
  // Подпись кнопки берётся из глобального appLocalizations.
  setUpAll(() => AppLocalizations.load(const Locale('en')));

  testWidgets(
    'connect glyph stays rendered while core init is pending (isInit=false)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Core NOT initialised — the exact state that used to brick the UI.
            startButtonSelectorStateProvider.overrideWithValue(
              const StartButtonSelectorState(
                isInit: false,
                hasProfile: true,
                hasProxiesInit: true,
              ),
            ),
            // Not running (runTime == null) and decoupled from the late appState.
            runTimeProvider.overrideWith(_NullRunTime.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: StartButton(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The power glyph must still be present — NOT collapsed to SizedBox.shrink.
      expect(find.byType(HugeIcon), findsWidgets);
    },
  );

  // Robo из Firebase Test Lab (и pre-launch report Google Play) нажимает в
  // центр узла семантики. Без собственного узла кнопка сливалась с текстом
  // подсказки пустого экрана в один узел на полэкрана, центр попадал в текст,
  // и робот считал, что на экране нечего нажимать (прогон 19.10.2026,
  // Galaxy S24 / A03s). Узел `dw_connect` должен совпадать с самой кнопкой.
  testWidgets(
    'dw_connect is its own tappable semantics node sized to the button',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startButtonSelectorStateProvider.overrideWithValue(
              const StartButtonSelectorState(
                isInit: true,
                hasProfile: false,
                hasProxiesInit: true,
              ),
            ),
            runTimeProvider.overrideWith(_NullRunTime.new),
          ],
          // Как на телефоне (lib/pages/home.dart): страница дашборда —
          // элемент PageView, а он делает каждую страницу одним узлом
          // семантики, куда сливается всё без собственной границы.
          child: MaterialApp(
            home: Scaffold(
              body: PageView.builder(
                itemCount: 1,
                itemBuilder: (_, __) => const Stack(
                  children: [
                    // Как MobileEmptyGuidanceOverlay: декоративный текст над
                    // кнопкой, без собственной границы семантики.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Text('guidance hint'),
                        ),
                      ),
                    ),
                    Center(
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: StartButton(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final node = tester.getSemantics(find.byType(StartButton));
      final data = node.getSemanticsData();
      expect(data.identifier, 'dw_connect');
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, 'Add a subscription');
      expect(node.rect.size, const Size(200, 200));
      semantics.dispose();
    },
  );
}
