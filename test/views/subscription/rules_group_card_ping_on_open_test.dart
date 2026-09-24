// Regression: opening a group from «Серверы и группы» must delay-test EVERY
// member of that group under the group's own testUrl. The view's on-open ping
// only re-tests each group's SELECTED member, so after a network change wiped
// the delay map, the other members of a url-test group with a non-default
// testUrl showed blank latency until used.
import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/theme.dart';
import 'package:dropweb/controller.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/subscription/proxy_selector_sheet.dart';
import 'package:dropweb/views/subscription/rules_proxies_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_path_provider.dart';

const _customUrl = 'https://example.com/generate_204';

class _FakeController implements AppController {
  /// Every member name delay-tested, and every testUrl it was tested under.
  final tested = <String>[];
  final testUrls = <String?>[];

  @override
  String getRealTestUrl(String? url) {
    testUrls.add(url);
    return url ?? 'default';
  }

  // Empty resolved name → delayTest records the request and skips the core
  // call (no FFI in a widget test).
  @override
  ProxyCardState getProxyCardState(dynamic proxyName) {
    tested.add(proxyName as String);
    return const ProxyCardState(proxyName: '');
  }

  @override
  void addSortNum() {}

  @override
  void addLog(Log log) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  useFakePathProvider();
  testWidgets('opening a url-test group pings all its members on its testUrl',
      (tester) async {
    await AppLocalizations.load(const Locale('en'));
    final fake = _FakeController();
    globalState.appController = fake;
    globalState.config = const Config(themeProps: defaultThemeProps);

    const group = Group(
      type: GroupType.URLTest,
      name: 'Auto',
      testUrl: _customUrl,
      all: [
        Proxy(name: 'node-a', type: 'Vless'),
        Proxy(name: 'node-b', type: 'Vless'),
        Proxy(name: 'node-c', type: 'Vless'),
      ],
    );
    globalState.appState = AppState(
      version: 0,
      viewSize: const Size(400, 800),
      requests: FixedList(10),
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      groups: const [group],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentGroupsStateProvider
              .overrideWith((ref) => const GroupsState(value: [group])),
          selectedMapProvider.overrideWith((ref) => const {}),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              globalState.theme = CommonTheme.of(context, 1.0);
              return const RulesProxiesView();
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Ignore the view's own selected-member ping.
    fake.tested.clear();
    fake.testUrls.clear();

    await tester.tap(find.text('Auto', findRichText: true));
    await tester.pumpAndSettle();

    final sheet =
        tester.widget<ProxySelectorSheet>(find.byType(ProxySelectorSheet));
    expect(sheet.pingOnOpen, isTrue);
    expect(fake.tested.toSet(), {'node-a', 'node-b', 'node-c'},
        reason: 'every member must be delay-tested, not only the selected');
    expect(fake.testUrls, isNotEmpty);
    expect(fake.testUrls.every((u) => u == _customUrl), isTrue,
        reason: 'members must be tested under the group testUrl');
  });
}
