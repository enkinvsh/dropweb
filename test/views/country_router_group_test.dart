// Honesty-matrix lock for the «Страна» screen — REPLACES
// test/views/country_picker_state_test.dart.
//
// History. The «Страна» picker used to build its own parallel list of countries
// and filter it by its own liveness probe. When the core had not loaded the
// profile's nodes (VPN off / mid-reload) or the probe could not run, the filter
// removed EVERYTHING and the screen claimed «Страны не определены. Обновите
// подписку.» — a lie: the subscription HAS countries. Data/probe errors showed
// «No profile» — also a lie.
//
// The parallel probe is now GONE. The screen renders the membership of the
// primary router group (the `MATCH` target) through the same
// [ProxySelectorSheet] that draws «Серверы и группы», and delays come from
// `getDelayProvider` inside the row — exactly as on the group screen. All
// rendering is routed through the pure [resolveCountryScreenState], which is
// what this file pins.
//
// The four properties locked here, in the order the resolver checks them:
//   1. config unreadable            → configUnavailable (NOT «нет профиля», NOT «нет стран»)
//   2. no primary router in config  → noRouter           (NOT «нет стран»)
//   3. router known, core silent    → routerLoading      (NOT a ready-but-empty list)
//   4. router present               → ready, FULL membership in config order
// plus the one that killed the old design: resolution is DELAY-INDEPENDENT —
// a group whose members carry no liveness data whatsoever still resolves to a
// full `ready` list. Any reintroduced availability filter breaks this file.
//
// [detectPrimaryRouter] is driven for real (never stubbed): the whole point is
// that the screen and `applyWorkMode` cannot disagree about which group is
// «основная», so the test must exercise the same detection they share.
//
// Cross-links: lib/views/subscription/modes_content.dart
// (resolveCountryScreenState, CountryScreenStatus, CountryScreenState),
// lib/common/work_mode_patch.dart (detectPrimaryRouter, smartInterceptGroups).

import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/views/subscription/modes_content.dart';
import 'package:dropweb/views/subscription/proxy_selector_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

const _router = '🌍 VPN';
const _aggregate = '⚡ Авто';
const _de = '🇩🇪 Германия';
const _nl = '🇳🇱 Нидерланды';
const _youtube = '📺 YouTube';

/// Router membership in the order the panel template declares it — the
/// aggregate `⚡ Авто` first, then leaf countries. Mirrors the live
/// subscription (`🌍 VPN` → `[⚡ Авто, 🇩🇪 …, 🇳🇱 …]`).
const _routerMembers = <String>[_aggregate, _de, _nl];

/// A well-formed config whose catch-all `MATCH` targets [_router].
/// `detectPrimaryRouter` reads `proxy-groups` + rules only, but `proxies` is
/// included so the fixture is a realistic config rather than a shape trimmed to
/// the implementation.
Map<String, dynamic> _configWithRouter() => {
      'proxies': [
        {'name': _de, 'type': 'vless', 'server': 'de.example', 'port': 443},
        {'name': _nl, 'type': 'vless', 'server': 'nl.example', 'port': 443},
      ],
      'proxy-groups': [
        {'name': _router, 'type': 'select', 'proxies': _routerMembers},
        {
          'name': _aggregate,
          'type': 'url-test',
          'proxies': [_de, _nl],
        },
      ],
      'rules': ['MATCH,$_router'],
    };

/// A config with NO qualifying router: the only rule targets a mihomo builtin,
/// so no proxy-group is ever rule-referenced and `smartInterceptGroups` comes
/// back empty — `detectPrimaryRouter` returns null instead of falling through
/// to `qualifying.first`.
Map<String, dynamic> _configWithoutRouter() => {
      'proxies': [
        {'name': _de, 'type': 'vless', 'server': 'de.example', 'port': 443},
      ],
      'proxy-groups': [
        {
          'name': _router,
          'type': 'select',
          'proxies': [_de],
        },
      ],
      'rules': ['MATCH,DIRECT'],
    };

/// Rule-referenced, but of a type the work-mode engine never intercepts
/// (`load-balance` ∉ {select, url-test, fallback}). Second no-router shape:
/// proves the null comes from the qualification filter, not from an absent rule.
Map<String, dynamic> _configWithNonInterceptableRouter() => {
      'proxy-groups': [
        {
          'name': _router,
          'type': 'load-balance',
          'proxies': [_de, _nl],
        },
      ],
      'rules': ['MATCH,$_router'],
    };

/// Two qualifying groups; the FIRST declared one is not the `MATCH` target.
/// Locks that detection follows `MATCH` rather than declaration order.
Map<String, dynamic> _configWithTwoQualifyingGroups() => {
      'proxy-groups': [
        {
          'name': _youtube,
          'type': 'select',
          'proxies': [_de],
        },
        {'name': _router, 'type': 'select', 'proxies': _routerMembers},
      ],
      'rules': [
        'DOMAIN-SUFFIX,youtube.com,$_youtube',
        'MATCH,$_router',
      ],
    };

Proxy _proxy(String name) => Proxy(name: name, type: 'Shadowsocks');

/// The router group as the core publishes it. [now] / [fixed] are left at
/// «nothing selected», and [Proxy] carries no latency at all — delays live in
/// the global delay state keyed by name, which the resolver never reads.
Group _routerGroup({List<String> members = _routerMembers}) => Group(
      type: GroupType.Selector,
      name: _router,
      all: [for (final m in members) _proxy(m)],
    );

/// The aggregate is also a group in its own right — that is precisely what
/// makes it an aggregate under the sponge rule (a router member whose name
/// matches another group's name), with no hardcoded names anywhere.
Group _aggregateGroup({bool hidden = false}) => Group(
      type: GroupType.URLTest,
      name: _aggregate,
      hidden: hidden,
      all: [_proxy(_de), _proxy(_nl)],
    );

void main() {
  group('resolveCountryScreenState honesty matrix', () {
    test(
        'row 1: config unreadable → configUnavailable, never «нет профиля» / «нет стран»',
        () {
      final state = resolveCountryScreenState(null, [_routerGroup()]);

      expect(state.status, CountryScreenStatus.configUnavailable);
      expect(state.group, isNull);
      // A config READ failure must not be reported as a routing problem or as
      // an empty subscription — those are different lies the old picker told.
      expect(state.status, isNot(CountryScreenStatus.noRouter));
      expect(state.status, isNot(CountryScreenStatus.ready));
    });

    test('row 2: no MATCH-targeted qualifying group → noRouter, group null', () {
      final state = resolveCountryScreenState(
        _configWithoutRouter(),
        [_routerGroup()],
      );

      expect(state.status, CountryScreenStatus.noRouter);
      expect(state.group, isNull);
    });

    test(
        'row 2b: MATCH targets a non-interceptable group type → still noRouter '
        '(no fall-through to «first qualifying»)', () {
      final state = resolveCountryScreenState(
        _configWithNonInterceptableRouter(),
        [_routerGroup()],
      );

      expect(state.status, CountryScreenStatus.noRouter);
      expect(state.group, isNull);
    });

    test(
        'row 3: router resolvable but absent from the core groups → routerLoading, '
        'NOT a ready-but-empty list', () {
      final state = resolveCountryScreenState(_configWithRouter(), const []);

      expect(state.status, CountryScreenStatus.routerLoading);
      expect(state.group, isNull);
      // The anti-«пустой список» lock: cold start is LOADING, never a ready
      // screen with zero countries.
      expect(state.status, isNot(CountryScreenStatus.ready));
    });

    test(
        'row 4: router present → ready with its FULL membership in config order, '
        'aggregate included', () {
      final state = resolveCountryScreenState(
        _configWithRouter(),
        [_routerGroup(), _aggregateGroup()],
      );

      expect(state.status, CountryScreenStatus.ready);
      expect(state.group, isNotNull);
      expect(state.group!.name, _router);
      expect(
        state.group!.all.map((p) => p.name).toList(),
        // Exact order, aggregate first — nothing reordered, nothing dropped.
        [_aggregate, _de, _nl],
      );
    });

    test(
        'the aggregate member survives resolution and is recognisable by the '
        'REAL shared sponge rule (its name matches another group)', () {
      // Этот тест раньше переопределял правило ЛОКАЛЬНО и потому зеленел, пока
      // прод падал. Теперь он зовёт ровно ту функцию, которую зовёт виджет, —
      // разъехаться они больше не могут.
      final groups = [_routerGroup(), _aggregateGroup()];
      final state = resolveCountryScreenState(_configWithRouter(), groups);

      expect(state.status, CountryScreenStatus.ready);
      final names = state.group!.all.map((p) => p.name).toList();
      expect(names, contains(_aggregate));

      final groupNames = aggregateGroupNames(groups);
      bool isAggregate(String proxyName) => isAggregateMember(
            proxyName: proxyName,
            routerName: state.group!.name,
            allGroupNames: groupNames,
          );
      expect(isAggregate(_aggregate), isTrue);
      expect(isAggregate(_de), isFalse);
      expect(isAggregate(_nl), isFalse);
    });

    test(
        'DELAY-INDEPENDENCE: a router whose members carry no liveness data still '
        'resolves to ready with every member', () {
      // Nothing selected, nothing pinned, no latency anywhere — the exact state
      // the deleted probe used to read as «all servers dead» and filter to an
      // empty list. Resolution must not depend on liveness at all.
      final coldGroup = Group(
        type: GroupType.Selector,
        name: _router,
        now: null,
        all: [for (final m in _routerMembers) _proxy(m)],
      );

      final state = resolveCountryScreenState(_configWithRouter(), [coldGroup]);

      expect(state.status, CountryScreenStatus.ready);
      expect(state.group!.all, hasLength(_routerMembers.length));
      expect(state.group!.all.map((p) => p.name).toList(), _routerMembers);
      expect(state.group!.realNow, isEmpty);
    });

    test(
        'the router is chosen by MATCH, not by declaration order — the screen '
        'cannot diverge from applyWorkMode', () {
      final state = resolveCountryScreenState(
        _configWithTwoQualifyingGroups(),
        [
          Group(
            type: GroupType.Selector,
            name: _youtube,
            all: [_proxy(_de)],
          ),
          _routerGroup(),
          _aggregateGroup(),
        ],
      );

      expect(state.status, CountryScreenStatus.ready);
      expect(state.group!.name, _router);
      expect(state.group!.name, isNot(_youtube));
    });
  });

  // ── Sponge rule: aggregate vs country ───────────────────────────────────
  //
  // REGRESSION 2026-08-09 (найдена на Pixel 10). Тап по `⚡ Авто` на экране
  // «Страна» обязан переключить профиль в WorkMode.standard. Вместо этого
  // писалось `workMode: country` + `staticCountry: ⚡ Авто`, потому что
  // `isAggregate` оказывался false.
  //
  // Причина: множество имён бралось из ФИЛЬТРОВАННОГО `currentGroupsState`,
  // который выкидывает `hidden == true`. Живая подписка объявляет агрегатор
  // скрытым:
  //     - name: ⚡ Авто   type: fallback   hidden: true
  // ⇒ скрытый агрегатор НИКОГДА не попадал в множество и всегда
  // классифицировался как страна.
  //
  // Правило остаётся структурным («имя совпало с именем другой группы»), без
  // единого захардкоженного имени и без нюха по типу группы. Чинилось ровно
  // одно: КАКОЕ множество имён подаётся на вход.
  group('sponge rule: isAggregateMember / aggregateGroupNames', () {
    test(
        'REGRESSION LOCK: a HIDDEN aggregate group is still an aggregate, '
        'never a country', () {
      final groups = [_routerGroup(), _aggregateGroup(hidden: true)];

      expect(
        isAggregateMember(
          proxyName: _aggregate,
          routerName: _router,
          allGroupNames: aggregateGroupNames(groups),
        ),
        isTrue,
        reason: 'скрытая группа обязана попадать в множество имён',
      );
    });

    test('a VISIBLE aggregate group is an aggregate', () {
      final groups = [_routerGroup(), _aggregateGroup()];

      expect(
        isAggregateMember(
          proxyName: _aggregate,
          routerName: _router,
          allGroupNames: aggregateGroupNames(groups),
        ),
        isTrue,
      );
    });

    test('a leaf node whose name matches no group is a country', () {
      final groups = [_routerGroup(), _aggregateGroup(hidden: true)];
      final names = aggregateGroupNames(groups);

      for (final leaf in [_de, _nl]) {
        expect(
          isAggregateMember(
            proxyName: leaf,
            routerName: _router,
            allGroupNames: names,
          ),
          isFalse,
          reason: '$leaf — листовая нода, а не группа',
        );
      }
    });

    test('the router group is never its own aggregate', () {
      // Роутер сам присутствует в множестве имён — гвардия `!= routerName`
      // обязана его отсечь.
      final groups = [_routerGroup(), _aggregateGroup(hidden: true)];
      final names = aggregateGroupNames(groups);

      expect(names, contains(_router));
      expect(
        isAggregateMember(
          proxyName: _router,
          routerName: _router,
          allGroupNames: names,
        ),
        isFalse,
      );
    });

    test(
        'aggregateGroupNames keeps EVERY group — hidden ones included — so the '
        'filtered currentGroupsState can never be the classification input',
        () {
      final groups = [
        _routerGroup(),
        _aggregateGroup(hidden: true),
        Group(
          type: GroupType.Fallback,
          name: _youtube,
          hidden: true,
          all: [_proxy(_de)],
        ),
      ];

      expect(
        aggregateGroupNames(groups),
        {_router, _aggregate, _youtube},
      );
    });
  });
}
