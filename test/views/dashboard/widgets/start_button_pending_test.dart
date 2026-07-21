import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/dashboard/widgets/start_button.dart';
import 'package:dropweb/views/profiles/add_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

class _NullRunTime extends RunTime {
  @override
  int? build() => null;
}

void main() {
  tearDown(() => globalState.isConnecting.value = false);

  testWidgets('pending keeps the glyph, blocks taps, then enables taps again',
      (tester) async {
    globalState.isConnecting.value = true;
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
        child: MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: const Scaffold(
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

    expect(find.byType(HugeIcon), findsWidgets);
    final gesture = find.descendant(
      of: find.byType(StartButton),
      matching: find.byType(GestureDetector),
    );
    expect(tester.widget<GestureDetector>(gesture).onTap, isNull);

    await tester.tap(gesture, warnIfMissed: false);
    await tester.pump();
    expect(find.byType(AddProfileView), findsNothing);

    globalState.isConnecting.value = false;
    await tester.pump();

    expect(tester.widget<GestureDetector>(gesture).onTap, isNotNull);
    await tester.tap(gesture);
    await tester.pump();
    expect(find.byType(AddProfileView), findsOneWidget);
    Navigator.of(tester.element(find.byType(AddProfileView))).pop();
    await tester.pump();
  });
}
