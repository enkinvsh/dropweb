// Regression: the dashboard «Сменить сервер» card used to call
// `toPage(PageLabel.proxies)`, but the navigation has only dashboard + tools,
// so the tap did nothing on screen while leaving `currentPageLabel` stuck at
// `proxies` (which gates dashboard pollers). The card must open the same
// «Серверы и группы» sheet as the modes screen and never navigate.
import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/theme.dart';
import 'package:dropweb/controller.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/dashboard/widgets/change_server_button.dart';
import 'package:dropweb/views/subscription/rules_proxies_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeController implements AppController {
  final pages = <PageLabel>[];

  @override
  void toPage(PageLabel pageLabel) => pages.add(pageLabel);

  @override
  void addLog(Log log) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('ChangeServerButton opens the servers sheet, never navigates',
      (tester) async {
    await AppLocalizations.load(const Locale('en'));
    final fake = _FakeController();
    globalState.appController = fake;
    // showSheet picks bottom-sheet vs side-sheet from appState.viewMode.
    globalState.appState = AppState(
      version: 0,
      viewSize: const Size(400, 800),
      requests: FixedList(10),
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
    );

    const profile = Profile(
      id: 'p1',
      label: 'sub',
      autoUpdateDuration: Duration(hours: 12),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((ref) => profile),
          currentGroupsStateProvider
              .overrideWith((ref) => const GroupsState(value: [])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              globalState.theme = CommonTheme.of(context, 1.0);
              return const ChangeServerButton();
            }),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RulesProxiesView), findsNothing);

    await tester.tap(find.byType(ChangeServerButton));
    await tester.pumpAndSettle();

    expect(fake.pages, isEmpty,
        reason: 'no navigable proxies page exists; toPage would be a dead tap');
    expect(find.byType(RulesProxiesView), findsOneWidget);
    expect(find.text(appLocalizations.serversAndGroups), findsOneWidget);
  });
}
