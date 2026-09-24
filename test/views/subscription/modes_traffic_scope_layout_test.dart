// Layout: the «Трафик» selector sits UNDER the mode cards, and disappears
// entirely when the provider's catch-all already goes through the VPN.
import 'package:dropweb/common/theme.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/subscription/common.dart';
import 'package:dropweb/views/subscription/modes_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_path_provider.dart';

Future<void> _pump(WidgetTester tester, {required bool available}) async {
  final profile = Profile.normal(label: 'p');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) => profile),
        modeProfileDataProvider(profile.id)
            .overrideWith((ref) async => (fullTunnelAvailable: available)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            globalState.theme = CommonTheme.of(context, 1.0);
            return const ModesContent();
          }),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  useFakePathProvider();
  setUp(() async {
    await AppLocalizations.load(const Locale('en'));
    globalState.config = const Config(themeProps: defaultThemeProps);
  });

  testWidgets('traffic selector is below the mode cards', (tester) async {
    await _pump(tester, available: true);

    final country = tester.getBottomLeft(find.text('Country')).dy;
    final header = tester.getTopLeft(find.text('Traffic')).dy;
    final segment = tester.getTopLeft(find.text('Selective')).dy;
    expect(tester.getTopLeft(find.text('Standard')).dy, lessThan(country));
    expect(header, greaterThan(country));
    expect(segment, greaterThan(header));
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('no selector when the catch-all already uses the VPN',
      (tester) async {
    await _pump(tester, available: false);

    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    expect(find.text('Traffic'), findsNothing);
    expect(find.text('Selective'), findsNothing);
  });
}
