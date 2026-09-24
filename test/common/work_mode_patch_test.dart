import 'package:dropweb/common/country.dart';
import 'package:dropweb/common/work_mode_patch.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a fresh representative parsed-config map mirroring the shape that
/// `patchRawConfig` hands to [applyWorkModePatch]: a `proxies` list of node
/// maps (flag-prefixed names) plus a `proxy-groups` list and a `rules` list.
/// A new instance is returned on every call so mutation tests stay isolated.
Map<String, dynamic> buildConfig() => <String, dynamic>{
      'mixed-port': 7890,
      'proxies': <Map<String, dynamic>>[
        {'name': '🇩🇪 Frankfurt 01', 'type': 'vless', 'server': 'de1', 'port': 443},
        {'name': '🇩🇪 Frankfurt 02', 'type': 'vless', 'server': 'de2', 'port': 443},
        {'name': '🇸🇪 Stockholm 01', 'type': 'vless', 'server': 'se1', 'port': 443},
        {'name': '🇷🇺 Moscow 01', 'type': 'vless', 'server': 'ru1', 'port': 443},
      ],
      'proxy-groups': <Map<String, dynamic>>[
        {
          'name': '🌍 VPN',
          'type': 'select',
          'proxies': ['⚡ Fastest', '📶 First Available'],
        },
        {
          'name': '⚡ Fastest',
          'type': 'url-test',
          'proxies': ['🇩🇪 Frankfurt 01', '🇸🇪 Stockholm 01'],
        },
      ],
      'rules': <String>[
        'DOMAIN-SUFFIX,t.me,🌍 VPN',
        'MATCH,🌍 VPN',
      ],
    };

/// Builds a fixture mirroring the PRODUCTION subscription template shape:
///   * top-level `proxies` = the 3 leaf nodes the panel router routes through,
///     plus SOS-like emergency nodes that `patchSmartPool` appends at download
///     time (top-level proxies, but NOT members of any router);
///   * `⚡ Fastest` (url-test) is the primary router — most rule refs (~25) —
///     and its members are exactly the 3 leaf nodes (one of which, the
///     `🇪🇺 ✨ Умный режим` leaf, even carries the `✨`/`Умный` tokens the
///     `⚡ Fastest` exclude-filter targets, proving leaf selection is by
///     top-level membership, NOT by name regex);
///   * `🌍 VPN` (fallback) is the MATCH catch-all sibling.
/// A new instance is returned on every call so mutation tests stay isolated.
Map<String, dynamic> buildSmartTemplate() {
  final rules = <String>[
    for (var i = 0; i < 25; i++) 'DOMAIN-SUFFIX,site$i.com,⚡ Fastest',
    'MATCH,🌍 VPN',
  ];
  return <String, dynamic>{
    'mixed-port': 7890,
    'proxies': <Map<String, dynamic>>[
      {'name': '🇩🇪 Германия', 'type': 'vless', 'server': 'de', 'port': 443},
      {'name': '🇳🇱 Нидерланды', 'type': 'vless', 'server': 'nl', 'port': 443},
      {'name': '🇪🇺 ✨ Умный режим', 'type': 'vless', 'server': 'eu', 'port': 443},
      // SOS-like emergency nodes (disconeko pool) — top-level proxies that are
      // NOT members of the primary router. They must NEVER end up in «Умный».
      {'name': '🇩🇪 Germany', 'type': 'vless', 'server': 'sos1', 'port': 443},
      {'name': '🇫🇮 Finland', 'type': 'vless', 'server': 'sos2', 'port': 443},
    ],
    'proxy-groups': <Map<String, dynamic>>[
      {
        'name': '🌍 VPN',
        'type': 'fallback',
        'proxies': ['⚡ Fastest', '📶 First Available'],
      },
      {
        'name': '⚡ Fastest',
        'type': 'url-test',
        'exclude-filter': '🇪🇺|✨|cascade',
        'proxies': ['🇩🇪 Германия', '🇳🇱 Нидерланды', '🇪🇺 ✨ Умный режим'],
      },
      {
        'name': '📶 First Available',
        'type': 'fallback',
        'proxies': ['🧠 Smart'],
      },
    ],
    'rules': rules,
  };
}

/// The leaf nodes «Умный» must end up with for [buildSmartTemplate].
const _templateLeaves = <String>[
  '🇩🇪 Германия',
  '🇳🇱 Нидерланды',
  '🇪🇺 ✨ Умный режим',
];

/// Builds a fixture mirroring the FULL PRODUCTION subscription template so the
/// ИТЕРАЦИЯ-2 "intercept ALL rule-referenced groups" behavior can be asserted:
///   * `🌍 VPN` (fallback) — MATCH catch-all → [⚡ Fastest, 📶 First Available]
///   * `▶️ YouTube` / `💬 Discord` (fallback) → [🌀 Cascade, ⚡ Fastest]
///   * `⚡ Fastest` (url-test) — the leaf-node router [🇩🇪 A, 🇳🇱 B]
///   * `🌀 Cascade` (url-test) — its own leaf [🇸🇪 C] (NOT directly
///     rule-referenced; reachable only as a member of YouTube/Discord)
///   * `♻️ DIRECT` (select, hidden) → [DIRECT] (builtin-only → never qualifies)
///   * `📶 First Available` (fallback) → [🧠 Smart] (SOS surface — NOT
///     rule-referenced; hard-excluded)
///   * `🧠 Smart` (smart, include-all) — the SOS pool (hard-excluded)
/// `proxies` carries the 3 leaf nodes + 2 SOS-like emergency nodes.
/// Rules target VPN / Fastest / YouTube / Discord; MATCH → VPN.
/// A new instance is returned on every call so mutation tests stay isolated.
Map<String, dynamic> buildProdTemplate() {
  final rules = <String>[
    'DOMAIN-SUFFIX,youtube.com,▶️ YouTube',
    'DOMAIN-SUFFIX,discord.com,💬 Discord',
    for (var i = 0; i < 10; i++) 'DOMAIN-SUFFIX,site$i.com,⚡ Fastest',
    'DOMAIN-SUFFIX,corp.com,🌍 VPN',
    'MATCH,🌍 VPN',
  ];
  return <String, dynamic>{
    'mixed-port': 7890,
    'proxies': <Map<String, dynamic>>[
      {'name': '🇩🇪 A', 'type': 'vless', 'server': 'de', 'port': 443},
      {'name': '🇳🇱 B', 'type': 'vless', 'server': 'nl', 'port': 443},
      {'name': '🇸🇪 C', 'type': 'vless', 'server': 'se', 'port': 443},
      // SOS-like emergency nodes (disconeko pool) — top-level proxies NOT in
      // any rule-referenced group. They must NEVER end up in «Умный» NOR in a
      // «Страна <flag>» group. 🇷🇺/🇬🇧 are flags the panel sub never carries;
      // 🇩🇪 SOS Berlin deliberately COLLIDES with the curated 🇩🇪 A to prove
      // exclusion is structural (membership), not by flag/name regex.
      {'name': '🇫🇮 SOS1', 'type': 'vless', 'server': 'sos1', 'port': 443},
      {'name': '🇪🇪 SOS2', 'type': 'vless', 'server': 'sos2', 'port': 443},
      {'name': '🇷🇺 SOS Moscow', 'type': 'vless', 'server': 'sos3', 'port': 443},
      {'name': '🇬🇧 SOS London', 'type': 'vless', 'server': 'sos4', 'port': 443},
      {'name': '🇩🇪 SOS Berlin', 'type': 'vless', 'server': 'sos5', 'port': 443},
    ],
    'proxy-groups': <Map<String, dynamic>>[
      {
        'name': '🌍 VPN',
        'type': 'fallback',
        'proxies': ['⚡ Fastest', '📶 First Available'],
      },
      {
        'name': '▶️ YouTube',
        'type': 'fallback',
        'proxies': ['🌀 Cascade', '⚡ Fastest'],
      },
      {
        'name': '💬 Discord',
        'type': 'fallback',
        'proxies': ['🌀 Cascade', '⚡ Fastest'],
      },
      {
        'name': '⚡ Fastest',
        'type': 'url-test',
        'proxies': ['🇩🇪 A', '🇳🇱 B'],
      },
      {
        'name': '🌀 Cascade',
        'type': 'url-test',
        'proxies': ['🇸🇪 C'],
      },
      {
        'name': '♻️ DIRECT',
        'type': 'select',
        'proxies': ['DIRECT'],
      },
      {
        'name': '📶 First Available',
        'type': 'fallback',
        'proxies': ['🧠 Smart'],
      },
      {
        'name': '🧠 Smart',
        'type': 'smart',
        'include-all': true,
      },
    ],
    'rules': rules,
  };
}

/// The intercept-group set «Умный» must bind, in proxy-groups declaration order.
const _prodInterceptGroups = <String>[
  '🌍 VPN',
  '▶️ YouTube',
  '💬 Discord',
  '⚡ Fastest',
];

/// The union of leaf nodes «Умный» must rotate over for [buildProdTemplate],
/// first-seen order across the intercept groups: VPN→Fastest's leaves, then
/// YouTube/Discord→Cascade's leaf, then Fastest's leaves.
const _prodUnionLeaves = <String>['🇩🇪 A', '🇳🇱 B', '🇸🇪 C'];

/// Leaf nodes «Умный» rotates over for [buildProdTemplate] now that Smart binds
/// ONLY the primary router: 🌍 VPN → ⚡ Fastest [🇩🇪 A, 🇳🇱 B]; the
/// 📶 First Available → 🧠 Smart member is a group (not a top-level proxy) and is
/// dropped. 🇸🇪 C is reachable only via Cascade (YouTube/Discord), not the VPN
/// router, so it is excluded.
const _prodRouterLeaves = <String>['🇩🇪 A', '🇳🇱 B'];

Map? _group(Map<String, dynamic> doc, String name) {
  final groups = doc['proxy-groups'] as List;
  for (final g in groups) {
    if (g is Map && g['name'] == name) return g;
  }
  return null;
}

List<String> _members(Map? group) =>
    [for (final m in (group?['proxies'] as List? ?? const [])) m.toString()];

/// The three user nodes the panel renders into the subscription. The 🇪🇺 node is
/// the cascade exit — `🌀 Cascade` selects it via `filter`, `⚡ Fastest` drops it
/// via `exclude-filter`. Both keys are core-side, so the app (which does NOT
/// resolve `include-all`/`filter` — deliberately out of scope) sees the node in
/// whatever `proxies` list the panel wrote it into.
const _prodCountryNodes = <String>[
  '🇩🇪 Германия',
  '🇳🇱 Нидерланды',
  '🇪🇺 Каскад',
];

/// Builds a fixture mirroring the REAL CURRENT production subscription template
/// (`dropweb-mihomo/mihomo.ultimate.yml`) AFTER Remnawave has RENDERED it — i.e.
/// what the app actually parses on a live subscription, not the hand-written
/// source YAML.
///
/// The rendering rule that shapes this fixture (backend
/// `mihomo.generator.service.ts`, commit `78098f5`): Remnawave APPENDS every
/// user node name to the `proxies` of EVERY group that does NOT carry
/// `remnawave: include-proxies: false`. So:
///   * `🌍 VPN` / `⚡ Fastest` / `📶 First Available` — NO opt-out ⇒ they carry
///     their hand-written members PLUS all three nodes;
///   * `⚡ Авто` / `▶️ YouTube` / `💬 Discord` / `🌀 Cascade` / `♻️ DIRECT` —
///     opt-out ⇒ exactly the members the template author wrote.
///
/// `▶️ YouTube` / `💬 Discord` are `fallback` with `interval: 30, lazy: false`
/// (they probe relentlessly) — that is precisely why variant А must never pin
/// into them: `fallback.go:113-119` DESTROYS a pin on a failed health check
/// (bug P0). Group declaration order matches the template.
///
/// A new instance is returned on every call so mutation tests stay isolated.
Map<String, dynamic> buildProdCountryTemplate() => <String, dynamic>{
      'mixed-port': 7890,
      'proxies': <Map<String, dynamic>>[
        {
          'name': '🇩🇪 Германия',
          'type': 'vless',
          'server': 'de1.example.com',
          'port': 443
        },
        {
          'name': '🇳🇱 Нидерланды',
          'type': 'vless',
          'server': 'nl1.example.com',
          'port': 443
        },
        {
          'name': '🇪🇺 Каскад',
          'type': 'vless',
          'server': 'eu1.example.com',
          'port': 443
        },
      ],
      'proxy-groups': <Map<String, dynamic>>[
        // NO opt-out → the panel appended all three nodes after «⚡ Авто».
        {
          'name': '🌍 VPN',
          'type': 'select',
          'proxies': <String>['⚡ Авто', ..._prodCountryNodes],
        },
        // include-proxies: false → hand-written members only.
        {
          'name': '⚡ Авто',
          'type': 'fallback',
          'proxies': <String>['⚡ Fastest', '📶 First Available'],
        },
        {
          'name': '▶️ YouTube',
          'type': 'fallback',
          'interval': 30,
          'lazy': false,
          'proxies': <String>['🌀 Cascade', '⚡ Fastest'],
        },
        {
          'name': '💬 Discord',
          'type': 'fallback',
          'interval': 30,
          'lazy': false,
          'proxies': <String>['🌀 Cascade', '⚡ Fastest'],
        },
        {
          'name': '🌀 Cascade',
          'type': 'url-test',
          'include-all': true,
          'filter': '🇪🇺',
          'proxies': <String>[],
        },
        // NO opt-out → all three nodes; the 🇪🇺 one is dropped CORE-SIDE by
        // exclude-filter, which the app deliberately does not resolve.
        {
          'name': '⚡ Fastest',
          'type': 'url-test',
          'exclude-filter': '🇪🇺',
          'proxies': <String>[..._prodCountryNodes],
        },
        {
          'name': '📶 First Available',
          'type': 'fallback',
          'proxies': <String>[..._prodCountryNodes],
        },
        {
          'name': '♻️ DIRECT',
          'type': 'select',
          'proxies': <String>['DIRECT'],
        },
      ],
      'rules': <String>[
        'OR,((RULE-SET,telegram_ips),(RULE-SET,telegram_domains)),⚡ Fastest',
        'RULE-SET,additional-telegram-domains,⚡ Fastest',
        'RULE-SET,youtube,▶️ YouTube',
        'OR,((RULE-SET,discord_domains),(PROCESS-NAME,Discord)),💬 Discord',
        'DOMAIN-SUFFIX,gosuslugi.ru,DIRECT',
        'MATCH,🌍 VPN',
      ],
    };

void main() {
  group('applyWorkModePatch', () {
    test('standard: no-op (deep-equal to input)', () {
      final input = buildConfig();
      final out = applyWorkModePatch(input, workMode: WorkMode.standard);
      expect(out, buildConfig());
    });

    test('smart: «Умный».proxies == exactly the router leaf nodes; SOS absent; '
        'no include-all', () {
      final out =
          applyWorkModePatch(buildSmartTemplate(), workMode: WorkMode.smart);

      final smart = _group(out, 'Умный');
      expect(smart, isNotNull);
      expect(smart!['type'], 'smart');
      expect(smart['collectdata'], false);
      // D1 fix: explicit leaf membership, NEVER include-all.
      expect(smart.containsKey('include-all'), isFalse);
      expect(_members(smart), _templateLeaves);

      // SOS / emergency-pool node names never leak into «Умный».
      expect(_members(smart), isNot(contains('🇩🇪 Germany')));
      expect(_members(smart), isNot(contains('🇫🇮 Finland')));
    });

    test('smart: appends "Умный" ONLY to the primary router (MATCH target) '
        'once, idempotent', () {
      final out =
          applyWorkModePatch(buildSmartTemplate(), workMode: WorkMode.smart);

      // buildSmartTemplate is rule-referenced on BOTH ⚡ Fastest (×25) and
      // 🌍 VPN (MATCH). «Умный» is appended at the END of each, existing
      // members preserved in order; 📶 First Available (SOS) is untouched.
      // ⚡ Fastest is rule-referenced (×25) but NOT the MATCH target → it must
      // NOT gain «Умный» (only the primary router is bound now).
      expect(_members(_group(out, '⚡ Fastest')), _templateLeaves);

      final vpn = _group(out, '🌍 VPN');
      expect(_members(vpn), ['⚡ Fastest', '📶 First Available', 'Умный']);
      expect(_members(vpn).where((m) => m == 'Умный').length, 1);

      // SOS surface must NOT gain «Умный».
      expect(_members(_group(out, '📶 First Available')), ['🧠 Smart']);

      // Re-apply must NOT duplicate the group nor any appended member.
      final out2 = applyWorkModePatch(out, workMode: WorkMode.smart);
      final groupCount = (out2['proxy-groups'] as List)
          .where((g) => g is Map && g['name'] == 'Умный')
          .length;
      expect(groupCount, 1);
      expect(_members(_group(out2, '🌍 VPN')),
          ['⚡ Fastest', '📶 First Available', 'Умный']);
      expect(_members(_group(out2, '⚡ Fastest')), _templateLeaves);
      // Injected group membership stays exactly the leaves on re-apply.
      expect(_members(_group(out2, 'Умный')), _templateLeaves);
    });

    test('smart: only the primary router gains "Умный"; every other group '
        'byte-for-byte; rules untouched', () {
      final input = buildSmartTemplate();
      final original = buildSmartTemplate();
      final originalGroups = original['proxy-groups'] as List;
      const referenced = {'🌍 VPN'};

      final out = applyWorkModePatch(input, workMode: WorkMode.smart);
      final outGroups = out['proxy-groups'] as List;

      // One new group appended (Умный); originals retained in order.
      expect(outGroups.length, originalGroups.length + 1);
      for (var i = 0; i < originalGroups.length; i++) {
        final origGroup = originalGroups[i] as Map;
        if (referenced.contains(origGroup['name'])) {
          // The sole permitted change: 'Умный' appended to the router members.
          final expected = Map<String, dynamic>.from(
              origGroup.cast<String, dynamic>())
            ..['proxies'] = [
              ...(origGroup['proxies'] as List).map((e) => e.toString()),
              'Умный',
            ];
          expect(outGroups[i], expected);
        } else {
          expect(outGroups[i], origGroup);
        }
      }
      // Rules untouched (deep-equal to a fresh build).
      expect(out['rules'], original['rules']);
    });

    test('smart: router whose members are groups → one-level leaf resolution',
        () {
      // buildConfig: primary 🌍 VPN → members [⚡ Fastest, 📶 First Available].
      // ⚡ Fastest resolves one level deep to its top-level proxy members;
      // 📶 First Available is a dangling name (no such group, not a proxy) → dropped.
      final out = applyWorkModePatch(buildConfig(), workMode: WorkMode.smart);
      final smart = _group(out, 'Умный');
      expect(smart, isNotNull);
      expect(_members(smart), ['🇩🇪 Frankfurt 01', '🇸🇪 Stockholm 01']);

      // 'Умный' appended to the router (🌍 VPN) members.
      expect(_members(_group(out, '🌍 VPN')),
          ['⚡ Fastest', '📶 First Available', 'Умный']);
      // ⚡ Fastest is NOT directly rule-referenced in buildConfig (only reached
      // as a member of 🌍 VPN) → it must NOT gain «Умный».
      expect(_members(_group(out, '⚡ Fastest')),
          ['🇩🇪 Frankfurt 01', '🇸🇪 Stockholm 01']);
    });

    test('smart: no primary router → NO «Умный» group and NO append', () {
      final input = <String, dynamic>{
        'proxies': <Map<String, dynamic>>[
          {'name': '🇩🇪 A', 'type': 'vless', 'server': 'a', 'port': 443},
        ],
        'proxy-groups': <Map<String, dynamic>>[
          {
            'name': '🌍 VPN',
            'type': 'select',
            'proxies': ['🇩🇪 A'],
          },
        ],
        // No rule targets any group → detectPrimaryRouter returns null.
        'rules': <String>['MATCH,DIRECT'],
      };
      final out = applyWorkModePatch(input, workMode: WorkMode.smart);
      expect(_group(out, 'Умный'), isNull);
      // Existing router untouched (no 'Умный' member).
      expect(_members(_group(out, '🌍 VPN')), ['🇩🇪 A']);
      expect((out['proxy-groups'] as List).length, 1);
    });

    test('smart: router members resolve to empty leaf list → NO injection', () {
      // Router exists and is rule-targeted, but its only member is a nested
      // group whose members are all builtins → zero resolvable leaf nodes.
      final input = <String, dynamic>{
        'proxies': <Map<String, dynamic>>[],
        'proxy-groups': <Map<String, dynamic>>[
          {
            'name': 'Router',
            'type': 'select',
            'proxies': ['Inner'],
          },
          {
            'name': 'Inner',
            'type': 'select',
            'proxies': ['DIRECT', 'REJECT'],
          },
        ],
        'rules': <String>['MATCH,Router'],
      };
      final out = applyWorkModePatch(input, workMode: WorkMode.smart);
      expect(_group(out, 'Умный'), isNull);
      expect(_members(_group(out, 'Router')), ['Inner']);
    });

    test('standard/country: «Умный» is NEVER injected outside smart mode', () {
      // Country DOES bind its own «Страна <flag>» group into intercept groups
      // (fork Б) — but «Умный» (the smart group) belongs to smart mode alone.
      for (final out in [
        applyWorkModePatch(buildSmartTemplate(), workMode: WorkMode.standard),
        applyWorkModePatch(buildSmartTemplate(),
            workMode: WorkMode.country, staticCountry: '🇩🇪'),
      ]) {
        expect(_group(out, 'Умный'), isNull);
        for (final g in smartInterceptGroups(buildSmartTemplate())) {
          expect(_members(_group(out, g)), isNot(contains('Умный')),
              reason: '«Умный» must only appear in smart mode');
        }
      }
      // Standard is a pure no-op: the router stays byte-identical (country,
      // by contrast, appends «Страна 🇩🇪» — asserted in the country-binding group).
      final std =
          applyWorkModePatch(buildSmartTemplate(), workMode: WorkMode.standard);
      expect(_members(_group(std, '⚡ Fastest')), _templateLeaves);
    });

    test('country: unknown flag with no nodes injects no group', () {
      final out = applyWorkModePatch(
        buildConfig(),
        workMode: WorkMode.country,
        staticCountry: '🇫🇷', // no French nodes in fixture
      );
      expect(_group(out, 'Страна 🇫🇷'), isNull);
      // proxy-groups length unchanged.
      expect((out['proxy-groups'] as List).length,
          (buildConfig()['proxy-groups'] as List).length);
    });

    test('country: null staticCountry injects no group', () {
      final out = applyWorkModePatch(
        buildConfig(),
        workMode: WorkMode.country,
      );
      expect((out['proxy-groups'] as List).length,
          (buildConfig()['proxy-groups'] as List).length);
    });

    test('country: single node → target is the NODE itself, no «Страна» group',
        () {
      final cfg = {
        'proxies': [
          {'name': '🇩🇪 Berlin', 'type': 'ss', 'server': '1.2.3.4', 'port': 443},
          {
            'name': '🇳🇱 Amsterdam',
            'type': 'ss',
            'server': '1.2.3.5',
            'port': 443
          },
        ],
        'proxy-groups': [
          {
            'name': '🌍 VPN',
            'type': 'select',
            'proxies': ['🇩🇪 Berlin', '🇳🇱 Amsterdam']
          },
        ],
        'rules': ['MATCH,🌍 VPN'],
      };
      final out = applyWorkModePatch(cfg,
          workMode: WorkMode.country, staticCountry: '🇩🇪 Berlin');
      final groups = out['proxy-groups'] as List;
      expect(groups.map((g) => g['name']), isNot(contains('Страна 🇩🇪 Berlin')));
      expect(groups.length, 1, reason: 'никакой группы-обёртки при одном узле');
      expect((groups.single as Map)['proxies'], ['🇩🇪 Berlin', '🇳🇱 Amsterdam'],
          reason: 'узел уже член роутера — append это no-op');
    });

    test('country: multi-node key → «Страна» group injected AND appended to router',
        () {
      final cfg = {
        'proxies': [
          {'name': '🇩🇪 Berlin', 'type': 'ss', 'server': '1.2.3.4', 'port': 443},
          {'name': '🇩🇪 Munich', 'type': 'ss', 'server': '1.2.3.5', 'port': 443},
        ],
        'proxy-groups': [
          {'name': '🌍 VPN', 'type': 'select', 'proxies': ['🇩🇪 Berlin', '🇩🇪 Munich']},
        ],
        'rules': ['MATCH,🌍 VPN'],
      };
      final out = applyWorkModePatch(cfg,
          workMode: WorkMode.country, staticCountry: '🇩🇪');
      final groups = out['proxy-groups'] as List;
      final injected = groups.firstWhere((g) => g['name'] == 'Страна 🇩🇪') as Map;
      expect(injected['type'], 'fallback');
      expect(injected['proxies'], ['🇩🇪 Berlin', '🇩🇪 Munich']);
      final router = groups.firstWhere((g) => g['name'] == '🌍 VPN') as Map;
      expect((router['proxies'] as List).last, 'Страна 🇩🇪');
    });

    test('country: non-select router → membership collapsed, auto-keys stripped',
        () {
      final cfg = {
        'proxies': [
          {'name': '🇩🇪 Berlin', 'type': 'ss', 'server': '1.2.3.4', 'port': 443},
          {'name': '🇳🇱 Amsterdam', 'type': 'ss', 'server': '1.2.3.5', 'port': 443},
        ],
        'proxy-groups': [
          {'name': 'AUTO', 'type': 'url-test', 'include-all': true,
           'exclude-filter': '🇷🇺',
           'proxies': ['🇩🇪 Berlin', '🇳🇱 Amsterdam']},
        ],
        'rules': ['MATCH,AUTO'],
      };
      final out = applyWorkModePatch(cfg,
          workMode: WorkMode.country, staticCountry: '🇩🇪 Berlin');
      final router = (out['proxy-groups'] as List).single as Map;
      expect(router['proxies'], ['🇩🇪 Berlin']);
      expect(router.containsKey('include-all'), isFalse);
      expect(router.containsKey('exclude-filter'), isFalse);
      expect(router['type'], 'url-test', reason: 'тип группы не меняем');
    });

    test('country: per-service groups are left EXACTLY as the provider wrote them',
        () {
      final cfg = {
        'proxies': [
          {'name': '🇩🇪 Berlin', 'type': 'ss', 'server': '1.2.3.4', 'port': 443},
        ],
        'proxy-groups': [
          {'name': '🌍 VPN', 'type': 'select', 'proxies': ['🇩🇪 Berlin']},
          {'name': '▶️ YouTube', 'type': 'fallback', 'proxies': ['🇩🇪 Berlin']},
          {'name': '⚡ Fastest', 'type': 'url-test', 'proxies': ['🇩🇪 Berlin']},
        ],
        'rules': ['RULE-SET,youtube,▶️ YouTube', 'RULE-SET,tg,⚡ Fastest',
                  'MATCH,🌍 VPN'],
      };
      final before = cfg['proxy-groups'] as List;
      final out = applyWorkModePatch(cfg,
          workMode: WorkMode.country, staticCountry: '🇩🇪 Berlin');
      final after = out['proxy-groups'] as List;
      expect(after[1], same(before[1]), reason: 'YouTube сохранён по ссылке');
      expect(after[2], same(before[2]), reason: 'Fastest сохранён по ссылке');
    });

    test('country: idempotent on re-apply (variant A)', () {
      final cfg = {
        'proxies': [
          {'name': '🇩🇪 Berlin', 'type': 'ss', 'server': '1.2.3.4', 'port': 443},
          {'name': '🇩🇪 Munich', 'type': 'ss', 'server': '1.2.3.5', 'port': 443},
        ],
        'proxy-groups': [
          {'name': '🌍 VPN', 'type': 'select', 'proxies': ['🇩🇪 Berlin', '🇩🇪 Munich']},
        ],
        'rules': ['MATCH,🌍 VPN'],
      };
      final once = applyWorkModePatch(cfg,
          workMode: WorkMode.country, staticCountry: '🇩🇪');
      final twice = applyWorkModePatch(once,
          workMode: WorkMode.country, staticCountry: '🇩🇪');
      expect(twice['proxy-groups'], once['proxy-groups']);
    });

    // Salvaged verbatim from the deleted fork-Б binding group: both are
    // orthogonal to the cancelled "bind every intercept group" design (they
    // assert no-op-ness and purity), pass unchanged under variant А, and are the
    // only purity coverage the patch has.
    test('country: degenerate — no country nodes at all → patch is a no-op', () {
      final input = buildProdTemplate();
      final snapshot = buildProdTemplate();
      final out = applyWorkModePatch(input,
          workMode: WorkMode.country, staticCountry: '🇫🇷'); // no French nodes
      expect(_group(out, 'Страна 🇫🇷'), isNull);
      expect(out['proxy-groups'], snapshot['proxy-groups']);
      for (final g in _prodInterceptGroups) {
        expect(_members(_group(out, g)), isNot(contains('Страна 🇫🇷')));
      }
    });

    test('country: PURE — input never mutated; non-intercept groups + rules + '
        'proxies deep-equal the input', () {
      final input = buildProdTemplate();
      final snapshot = buildProdTemplate();
      applyWorkModePatch(input,
          workMode: WorkMode.country, staticCountry: '🇩🇪');
      expect(input, snapshot, reason: 'input rawConfig must not be mutated');

      final out = applyWorkModePatch(buildProdTemplate(),
          workMode: WorkMode.country, staticCountry: '🇩🇪');
      // Groups NOT in the intercept set stay deep-equal to the fresh fixture.
      for (final g in ['🌀 Cascade', '♻️ DIRECT', '🧠 Smart', '📶 First Available']) {
        expect(_group(out, g), _group(snapshot, g), reason: '$g must be untouched');
      }
      expect(out['rules'], snapshot['rules']);
      expect(out['proxies'], snapshot['proxies']);
    });
  });

  group('smartGroupWillInject', () {
    test('real template with resolvable leaves → true', () {
      expect(smartGroupWillInject(buildSmartTemplate()), isTrue);
    });

    test('router whose members resolve one level deep → true', () {
      expect(smartGroupWillInject(buildConfig()), isTrue);
    });

    test('no primary router → false', () {
      final input = <String, dynamic>{
        'proxies': <Map<String, dynamic>>[
          {'name': '🇩🇪 A', 'type': 'vless', 'server': 'a', 'port': 443},
        ],
        'proxy-groups': <Map<String, dynamic>>[
          {
            'name': '🌍 VPN',
            'type': 'select',
            'proxies': ['🇩🇪 A'],
          },
        ],
        'rules': <String>['MATCH,DIRECT'],
      };
      expect(smartGroupWillInject(input), isFalse);
    });

    test('router resolves to empty leaf list → false', () {
      final input = <String, dynamic>{
        'proxies': <Map<String, dynamic>>[],
        'proxy-groups': <Map<String, dynamic>>[
          {
            'name': 'Router',
            'type': 'select',
            'proxies': ['Inner'],
          },
          {
            'name': 'Inner',
            'type': 'select',
            'proxies': ['DIRECT', 'REJECT'],
          },
        ],
        'rules': <String>['MATCH,Router'],
      };
      expect(smartGroupWillInject(input), isFalse);
    });

    test('group already present → true even if leaves would be empty', () {
      final input = <String, dynamic>{
        'proxies': <Map<String, dynamic>>[],
        'proxy-groups': <Map<String, dynamic>>[
          {
            'name': 'Умный',
            'type': 'smart',
            'proxies': <String>[],
          },
        ],
        'rules': <String>['MATCH,DIRECT'],
      };
      expect(smartGroupWillInject(input), isTrue);
    });

    test('agrees with applyWorkModePatch output presence', () {
      final cases = <Map<String, dynamic>>[
        buildSmartTemplate(),
        buildConfig(),
      ];
      for (final cfg in cases) {
        final willInject = smartGroupWillInject(cfg);
        final out = applyWorkModePatch(cfg, workMode: WorkMode.smart);
        final present = _group(out, 'Умный') != null;
        expect(willInject, present);
      }
    });
  });

  group('detectPrimaryRouter', () {
    test('returns the MATCH catch-all target', () {
      expect(detectPrimaryRouter(buildProdTemplate()), '🌍 VPN');
      expect(detectPrimaryRouter(buildSmartTemplate()), '🌍 VPN');
      expect(detectPrimaryRouter(buildConfig()), '🌍 VPN');
    });

    test('falls back to first qualifying group when MATCH targets a builtin', () {
      final cfg = <String, dynamic>{
        'proxies': <Map<String, dynamic>>[
          {'name': '🇩🇪 A', 'type': 'vless', 'server': 'a', 'port': 443},
        ],
        'proxy-groups': <Map<String, dynamic>>[
          {'name': 'Main', 'type': 'select', 'proxies': ['🇩🇪 A']},
        ],
        'rules': <String>['DOMAIN-SUFFIX,x.com,Main', 'MATCH,DIRECT'],
      };
      expect(detectPrimaryRouter(cfg), 'Main');
    });

    test('MATCH target that is not a qualifying group falls back to first', () {
      final cfg = <String, dynamic>{
        'proxies': <Map<String, dynamic>>[
          {'name': '🇩🇪 A', 'type': 'vless', 'server': 'a', 'port': 443},
        ],
        'proxy-groups': <Map<String, dynamic>>[
          {'name': 'Routable', 'type': 'select', 'proxies': ['🇩🇪 A']},
          {'name': 'Dead', 'type': 'select', 'proxies': ['DIRECT']},
        ],
        'rules': <String>['DOMAIN-SUFFIX,x.com,Routable', 'MATCH,Dead'],
      };
      expect(detectPrimaryRouter(cfg), 'Routable');
    });

    test('returns null when no group qualifies', () {
      final cfg = <String, dynamic>{
        'proxies': <Map<String, dynamic>>[],
        'proxy-groups': <Map<String, dynamic>>[
          {'name': 'Main', 'type': 'select', 'proxies': ['DIRECT']},
        ],
        'rules': <String>['MATCH,DIRECT'],
      };
      expect(detectPrimaryRouter(cfg), isNull);
    });
  });

  group('smartInterceptGroups (ИТЕРАЦИЯ 2)', () {
    test('returns ALL qualifying rule-referenced groups in declaration order',
        () {
      expect(smartInterceptGroups(buildProdTemplate()), _prodInterceptGroups);
    });

    test('excludes the SOS chain (🧠 Smart / 📶 First Available)', () {
      final got = smartInterceptGroups(buildProdTemplate());
      expect(got, isNot(contains('🧠 Smart')));
      expect(got, isNot(contains('📶 First Available')));
    });

    test('excludes a builtin-only group (♻️ DIRECT)', () {
      expect(smartInterceptGroups(buildProdTemplate()),
          isNot(contains('♻️ DIRECT')));
    });

    test('excludes a group reachable only via membership (🌀 Cascade), not '
        'directly rule-referenced', () {
      expect(smartInterceptGroups(buildProdTemplate()),
          isNot(contains('🌀 Cascade')));
    });

    test('resolves rules from the build-path "rule" key as well as "rules"', () {
      final cfg = buildProdTemplate();
      cfg['rule'] = cfg.remove('rules');
      expect(smartInterceptGroups(cfg), _prodInterceptGroups);
    });

    test('no rules / malformed config → empty', () {
      expect(smartInterceptGroups(<String, dynamic>{}), isEmpty);
      expect(
        smartInterceptGroups(<String, dynamic>{
          'proxy-groups': <dynamic>[],
          'rules': <dynamic>[],
        }),
        isEmpty,
      );
    });

    test('only the primary router (detectPrimaryRouter) is patched with «Умный»',
        () {
      final cfg = buildProdTemplate();
      final primary = detectPrimaryRouter(cfg);
      expect(primary, '🌍 VPN'); // the MATCH catch-all target
      final out = applyWorkModePatch(cfg, workMode: WorkMode.smart);
      for (final g in smartInterceptGroups(cfg)) {
        expect(_members(_group(out, g)).contains('Умный'), g == primary,
            reason: '$g: only the primary router should be bound');
      }
    });
  });

  group('applyWorkModePatch — production template (primary-router only)', () {
    test('appends «Умный» ONLY to 🌍 VPN (primary); YouTube/Discord/Fastest/'
        'Cascade/SOS/DIRECT untouched', () {
      final out =
          applyWorkModePatch(buildProdTemplate(), workMode: WorkMode.smart);

      expect(_members(_group(out, '🌍 VPN')),
          ['⚡ Fastest', '📶 First Available', 'Умный']);
      // Per-service groups keep the template's own routing (no «Умный»).
      expect(_members(_group(out, '▶️ YouTube')), ['🌀 Cascade', '⚡ Fastest']);
      expect(_members(_group(out, '💬 Discord')), ['🌀 Cascade', '⚡ Fastest']);
      expect(_members(_group(out, '⚡ Fastest')), ['🇩🇪 A', '🇳🇱 B']);

      // Non-intercepted groups stay byte-for-byte.
      expect(_members(_group(out, '🌀 Cascade')), ['🇸🇪 C']);
      expect(_members(_group(out, '♻️ DIRECT')), ['DIRECT']);
      expect(_members(_group(out, '📶 First Available')), ['🧠 Smart']);
      expect(_group(out, '🧠 Smart')!['include-all'], true);
    });

    test('«Умный» group rotates over the PRIMARY router leaves only; '
        'SOS nodes absent', () {
      final out =
          applyWorkModePatch(buildProdTemplate(), workMode: WorkMode.smart);
      final smart = _group(out, 'Умный');
      expect(smart, isNotNull);
      expect(smart!['type'], 'smart');
      expect(smart['collectdata'], false);
      expect(smart.containsKey('include-all'), isFalse);
      expect(_members(smart), _prodRouterLeaves);
      // 🇸🇪 C is reachable only via Cascade (YouTube/Discord), not the VPN
      // router, so Smart never rotates over it.
      expect(_members(smart), isNot(contains('🇸🇪 C')));
      // SOS pool never leaks into «Умный».
      expect(_members(smart), isNot(contains('🇫🇮 SOS1')));
      expect(_members(smart), isNot(contains('🇪🇪 SOS2')));
    });

    test('build-path "rule" key still drives primary-router interception', () {
      final cfg = buildProdTemplate();
      cfg['rule'] = cfg.remove('rules');
      final out = applyWorkModePatch(cfg, workMode: WorkMode.smart);
      expect(_members(_group(out, '🌍 VPN')), contains('Умный'));
      expect(_members(_group(out, '▶️ YouTube')), isNot(contains('Умный')));
      expect(_members(_group(out, '💬 Discord')), isNot(contains('Умный')));
      expect(_members(_group(out, '⚡ Fastest')), isNot(contains('Умный')));
      expect(_members(_group(out, 'Умный')), _prodRouterLeaves);
    });

    test('idempotent on re-apply over production template', () {
      final out =
          applyWorkModePatch(buildProdTemplate(), workMode: WorkMode.smart);
      final out2 = applyWorkModePatch(out, workMode: WorkMode.smart);
      expect(
        (out2['proxy-groups'] as List)
            .where((g) => g is Map && g['name'] == 'Умный')
            .length,
        1,
      );
      expect(
          _members(_group(out2, '🌍 VPN')).where((m) => m == 'Умный').length, 1);
      expect(_members(_group(out2, 'Умный')), _prodRouterLeaves);
    });

    test('standard/country: no group gains «Умный» on prod template', () {
      for (final out in [
        applyWorkModePatch(buildProdTemplate(), workMode: WorkMode.standard),
        applyWorkModePatch(buildProdTemplate(),
            workMode: WorkMode.country, staticCountry: '🇩🇪'),
      ]) {
        for (final g in _prodInterceptGroups) {
          expect(_members(_group(out, g)), isNot(contains('Умный')));
        }
        expect(_group(out, 'Умный'), isNull);
      }
    });

    test('smartGroupWillInject agrees on production template', () {
      expect(smartGroupWillInject(buildProdTemplate()), isTrue);
    });
  });

  group('interceptLeafNodes / country — disconeko leak (D1 in country branch)',
      () {
    test('interceptLeafNodes == the union of rule-group leaves; ALL SOS nodes '
        'structurally excluded', () {
      final leaves = interceptLeafNodes(buildProdTemplate());
      expect(leaves, _prodUnionLeaves);
      // disconeko emergency nodes never appear — they are not members of any
      // rule-referenced group.
      for (final sos in [
        '🇫🇮 SOS1',
        '🇪🇪 SOS2',
        '🇷🇺 SOS Moscow',
        '🇬🇧 SOS London',
        '🇩🇪 SOS Berlin',
      ]) {
        expect(leaves, isNot(contains(sos)), reason: '$sos leaked into leaves');
      }
    });

    test('country «Страна» candidates come ONLY from rule-group leaves '
        '(groupNodesByCountry over interceptLeafNodes)', () {
      final byCountry = groupNodesByCountry(interceptLeafNodes(buildProdTemplate()));
      // Panel-curated flags present; SOS-only flags absent entirely.
      expect(byCountry.keys, containsAll(<String>['🇩🇪', '🇳🇱', '🇸🇪']));
      expect(byCountry.containsKey('🇷🇺'), isFalse);
      expect(byCountry.containsKey('🇬🇧'), isFalse);
      expect(byCountry.containsKey('🇫🇮'), isFalse);
      // Same-flag collision: 🇩🇪 resolves to the curated leaf, NOT the SOS node.
      expect(byCountry['🇩🇪'], ['🇩🇪 A']);
      expect(byCountry['🇩🇪'], isNot(contains('🇩🇪 SOS Berlin')));
    });

    test('applyWorkModePatch country 🇷🇺 (SOS-only flag) → injects NOTHING', () {
      final input = buildProdTemplate();
      final before = (input['proxy-groups'] as List).length;
      final out = applyWorkModePatch(input,
          workMode: WorkMode.country, staticCountry: '🇷🇺');
      expect(_group(out, 'Страна 🇷🇺'), isNull);
      expect((out['proxy-groups'] as List).length, before);
    });

    test('applyWorkModePatch country 🇩🇪 → target is the curated leaf '
        '(SOS 🇩🇪 Berlin excluded)', () {
      final cfg = buildProdTemplate();
      // Variant А: 🇩🇪 resolves to ONE curated node, so no «Страна» wrapper is
      // built — the router is pointed straight at that node.
      expect(_group(applyWorkModePatch(cfg,
              workMode: WorkMode.country, staticCountry: '🇩🇪'),
          'Страна 🇩🇪'),
          isNull);
      final target = countryTargetName(cfg, '🇩🇪');
      expect(target, '🇩🇪 A');
      expect(target, isNot('🇩🇪 SOS Berlin'),
          reason: 'the SOS node with the same flag must never be the target');
      // And it is the router's binding: nothing else changed.
      final out = applyWorkModePatch(cfg,
          workMode: WorkMode.country, staticCountry: '🇩🇪');
      expect(_members(_group(out, '🌍 VPN')), contains('🇩🇪 A'));
      expect(_members(_group(out, '🌍 VPN')), isNot(contains('🇩🇪 SOS Berlin')));
    });

    test('countryTargetName: SOS-only flags null, curated flags resolve', () {
      Map<String, dynamic> cfg() => buildProdTemplate();
      for (final sos in ['🇷🇺', '🇬🇧', '🇫🇮']) {
        expect(
          countryTargetName(cfg(), sos),
          isNull,
          reason: '$sos is SOS-only → must resolve to no target',
        );
      }
      for (final ok in ['🇩🇪', '🇳🇱', '🇸🇪']) {
        expect(
          countryTargetName(cfg(), ok),
          isNotNull,
          reason: '$ok is panel-curated → must resolve to a target',
        );
      }
    });

    test('multi-node country preserves order AND excludes same-flag SOS nodes',
        () {
      // Curated router routes through TWO 🇷🇺 panel nodes (in order); the SOS
      // pool also carries 🇷🇺 nodes as bare top-level proxies. Country 🇷🇺 must
      // pick exactly the two curated nodes, in order, never the SOS ones.
      final input = <String, dynamic>{
        'proxies': <Map<String, dynamic>>[
          {'name': '🇷🇺 Panel 1', 'type': 'vless', 'server': 'p1', 'port': 443},
          {'name': '🇷🇺 Panel 2', 'type': 'vless', 'server': 'p2', 'port': 443},
          {'name': '🇷🇺 SOS X', 'type': 'vless', 'server': 'x', 'port': 443},
          {'name': '🇷🇺 SOS Y', 'type': 'vless', 'server': 'y', 'port': 443},
        ],
        'proxy-groups': <Map<String, dynamic>>[
          {
            'name': '🌍 VPN',
            'type': 'select',
            'proxies': ['🇷🇺 Panel 1', '🇷🇺 Panel 2'],
          },
        ],
        'rules': <String>['MATCH,🌍 VPN'],
      };
      final out = applyWorkModePatch(input,
          workMode: WorkMode.country, staticCountry: '🇷🇺');
      expect(_members(_group(out, 'Страна 🇷🇺')), ['🇷🇺 Panel 1', '🇷🇺 Panel 2']);
    });

    test('build-path "rule" key still filters country candidates', () {
      final cfg = buildProdTemplate();
      cfg['rule'] = cfg.remove('rules');
      // Curated 🇩🇪 resolves to its single curated leaf; SOS-only 🇷🇺 resolves to
      // nothing — even via the renamed key.
      expect(countryTargetName(cfg, '🇩🇪'), '🇩🇪 A');
      final outDe = applyWorkModePatch(cfg,
          workMode: WorkMode.country, staticCountry: '🇩🇪');
      expect(_members(_group(outDe, '🌍 VPN')), contains('🇩🇪 A'));
      final cfg2 = buildProdTemplate();
      cfg2['rule'] = cfg2.remove('rules');
      expect(countryTargetName(cfg2, '🇷🇺'), isNull);
      final outRu = applyWorkModePatch(cfg2,
          workMode: WorkMode.country, staticCountry: '🇷🇺');
      expect(_group(outRu, 'Страна 🇷🇺'), isNull);
      expect(_members(_group(outRu, '🌍 VPN')),
          isNot(contains('🇷🇺 SOS Moscow')),
          reason: 'SOS node must never become the router target');
    });
  });

  group('structural sentinel filter (isRoutableProxy via interceptLeafNodes)',
      () {
    /// Mirrors a Remnawave/xray sub returned on a hit device/HWID limit: the
    /// rule-referenced `select` group routes ONLY through non-routable sentinel
    /// placeholders (server 0.0.0.0, port 1, all-zero uuid). One carries a SO
    /// sentinel flag (VLES expiry placeholder), one is flagless (ATA device
    /// placeholder), plus one REAL node to prove the filter is surgical.
    Map<String, dynamic> buildSentinelSub() => <String, dynamic>{
          'proxies': <Map<String, dynamic>>[
            {
              'name': '\u{1F1F8}\u{1F1F4} expired',
              'type': 'vless',
              'server': '0.0.0.0',
              'port': 1,
              'uuid': '00000000-0000-0000-0000-000000000000',
            },
            {
              'name': 'buy more devices',
              'type': 'vless',
              'server': '0.0.0.0',
              'port': 1,
              'uuid': '00000000-0000-0000-0000-000000000000',
            },
            {
              'name': '\u{1F1E9}\u{1F1EA} Frankfurt 01',
              'type': 'vless',
              'server': 'de1',
              'port': 443,
              'uuid': 'f88ea5c7-e386-45ee-92a5-bd231a889526',
            },
          ],
          'proxy-groups': <Map<String, dynamic>>[
            {
              'name': 'Remnawave',
              'type': 'select',
              'proxies': [
                '\u{1F1F8}\u{1F1F4} expired',
                'buy more devices',
                '\u{1F1E9}\u{1F1EA} Frankfurt 01',
              ],
            },
          ],
          'rules': <String>['MATCH,Remnawave'],
        };

    test('interceptLeafNodes drops 0.0.0.0/port-1/zero-uuid sentinels', () {
      final leaves = interceptLeafNodes(buildSentinelSub());
      expect(leaves, ['\u{1F1E9}\u{1F1EA} Frankfurt 01']);
      expect(leaves, isNot(contains('\u{1F1F8}\u{1F1F4} expired')));
      expect(leaves, isNot(contains('buy more devices')));
    });

    test('groupNodesByCountry over interceptLeafNodes invents no SO country',
        () {
      final byCountry =
          groupNodesByCountry(interceptLeafNodes(buildSentinelSub()));
      expect(byCountry.keys, ['\u{1F1E9}\u{1F1EA}']);
      expect(byCountry.containsKey('\u{1F1F8}\u{1F1F4}'), isFalse);
    });

    test('country mode on the sentinel flag SO injects nothing', () {
      final input = buildSentinelSub();
      final before = (input['proxy-groups'] as List).length;
      final out = applyWorkModePatch(input,
          workMode: WorkMode.country, staticCountry: '\u{1F1F8}\u{1F1F4}');
      expect(_group(out, workModeCountryGroupName('\u{1F1F8}\u{1F1F4}')), isNull);
      expect((out['proxy-groups'] as List).length, before);
    });

    test('country mode on the real flag DE still resolves (filter is surgical)',
        () {
      // Variant А: the single surviving real node IS the target — no wrapper.
      final cfg = buildSentinelSub();
      expect(countryTargetName(cfg, '\u{1F1E9}\u{1F1EA}'),
          '\u{1F1E9}\u{1F1EA} Frankfurt 01');
      final out = applyWorkModePatch(cfg,
          workMode: WorkMode.country, staticCountry: '\u{1F1E9}\u{1F1EA}');
      expect(_group(out, workModeCountryGroupName('\u{1F1E9}\u{1F1EA}')), isNull);
      // The sentinels stay out of the resolved candidate set.
      expect(countryTargetName(cfg, '\u{1F1F8}\u{1F1F4}'), isNull);
    });

    test('smart excludes sentinels from the injected smart group', () {
      final out =
          applyWorkModePatch(buildSentinelSub(), workMode: WorkMode.smart);
      final smart = _group(out, workModeSmartGroupName);
      expect(smart, isNotNull);
      expect(_members(smart), ['\u{1F1E9}\u{1F1EA} Frankfurt 01']);
    });

    test('a node with a real server but port "1" is dropped (string coercion)',
        () {
      final cfg = <String, dynamic>{
        'proxies': <Map<String, dynamic>>[
          {
            'name': '\u{1F1EB}\u{1F1F7} Paris',
            'type': 'vless',
            'server': 'fr1',
            'port': '1',
            'uuid': 'f88ea5c7-e386-45ee-92a5-bd231a889526',
          },
          {
            'name': '\u{1F1E9}\u{1F1EA} Berlin',
            'type': 'vless',
            'server': 'de1',
            'port': 443
          },
        ],
        'proxy-groups': <Map<String, dynamic>>[
          {
            'name': 'R',
            'type': 'select',
            'proxies': ['\u{1F1EB}\u{1F1F7} Paris', '\u{1F1E9}\u{1F1EA} Berlin'],
          },
        ],
        'rules': <String>['MATCH,R'],
      };
      expect(interceptLeafNodes(cfg), ['\u{1F1E9}\u{1F1EA} Berlin']);
    });
  });

  group('REGRESSION LOCK — smart output byte-identical after _injectBoundGroup '
      'refactor', () {
    test('prod template smart output deep-equals the known additive deltas', () {
      final out =
          applyWorkModePatch(buildProdTemplate(), workMode: WorkMode.smart);

      // Expected = fresh fixture + exactly two additive deltas:
      //   (1) «Умный» appended as the LAST member of the primary router 🌍 VPN;
      //   (2) the «Умный» smart group appended last (leaves = router leaves).
      final expected = buildProdTemplate();
      for (final g in expected['proxy-groups'] as List) {
        if (g is Map && g['name'] == '🌍 VPN') {
          g['proxies'] = [...(g['proxies'] as List), 'Умный'];
        }
      }
      (expected['proxy-groups'] as List).add(<String, dynamic>{
        'name': 'Умный',
        'type': 'smart',
        'collectdata': false,
        'interval': 600,
        'lazy': true,
        'proxies': ['🇩🇪 A', '🇳🇱 B'],
      });

      expect(out, expected);
    });

    test('smart template smart output deep-equals the known additive deltas', () {
      final out =
          applyWorkModePatch(buildSmartTemplate(), workMode: WorkMode.smart);

      final expected = buildSmartTemplate();
      for (final g in expected['proxy-groups'] as List) {
        if (g is Map && g['name'] == '🌍 VPN') {
          g['proxies'] = [...(g['proxies'] as List), 'Умный'];
        }
      }
      (expected['proxy-groups'] as List).add(<String, dynamic>{
        'name': 'Умный',
        'type': 'smart',
        'collectdata': false,
        'interval': 600,
        'lazy': true,
        'proxies': List<String>.from(_templateLeaves),
      });

      expect(out, expected);
    });
  });

  // Offline regression lock against the REAL rendered production template — the
  // strongest proof available without a device. Each test names the on-device
  // step it substitutes for.
  group('country variant А — REAL production template (regression lock)', () {
    test('detectPrimaryRouter picks 🌍 VPN (the MATCH target)', () {
      // The whole variant-А design pivots on this: exactly ONE group follows the
      // country, and it is the catch-all MATCH target. If detection ever drifts
      // to a per-service group, the pin lands in a `fallback` and P0 returns.
      expect(detectPrimaryRouter(buildProdCountryTemplate()), '🌍 VPN');
    });

    test('single-node country: target is the node, NO wrapper group, router '
        'membership unchanged', () {
      final cfg = buildProdCountryTemplate();
      final routerMembersBefore = _members(_group(cfg, '🌍 VPN'));

      expect(countryTargetName(cfg, '🇩🇪 Германия'), '🇩🇪 Германия',
          reason: 'пул из одного узла ⇒ цель = сам узел, обёртка не нужна');

      final out = applyWorkModePatch(cfg,
          workMode: WorkMode.country, staticCountry: '🇩🇪 Германия');
      final groups = out['proxy-groups'] as List;

      expect(
          groups.where(
              (g) => (g as Map)['name'].toString().startsWith('Страна ')),
          isEmpty,
          reason: 'никакой группы «Страна *» при пуле из одного узла');

      // The node is ALREADY a member of the router (Remnawave appended it), so
      // the append is a no-op. This is the offline proof that the pin will be
      // EXACT: `Selector.selectedProxy` (selector.go:103-112) resolves a pin
      // only among the group's OWN members — an absent name silently yields
      // proxies[0].
      expect(_members(_group(out, '🌍 VPN')), routerMembersBefore,
          reason: 'узел уже член роутера — append это no-op');
      expect(_members(_group(out, '🌍 VPN')), contains('🇩🇪 Германия'),
          reason: 'цель пина ОБЯЗАНА быть прямым членом роутера');
    });

    test('per-service groups survive BY REFERENCE (variant А core promise)', () {
      // Offline equivalent of device step 2 («YouTube/Discord/Fastest keep the
      // provider's choice») AND of device step 5 (nothing is pinned into a
      // `fallback`, so fallback.go:117 — which destroys a pin on a failed
      // health check, bug P0 — can never fire).
      final cfg = buildProdCountryTemplate();
      final before = cfg['proxy-groups'] as List;
      final byNameBefore = <String, Object?>{
        for (final g in before) (g as Map)['name'].toString(): g,
      };

      final out = applyWorkModePatch(cfg,
          workMode: WorkMode.country, staticCountry: '🇩🇪 Германия');
      final after = out['proxy-groups'] as List;

      expect(after.length, before.length,
          reason: 'вариант А ничего не инжектит на пуле из одного узла');

      for (final name in const <String>[
        '⚡ Авто',
        '▶️ YouTube',
        '💬 Discord',
        '🌀 Cascade',
        '⚡ Fastest',
        '📶 First Available',
        '♻️ DIRECT',
      ]) {
        expect(_group(out, name), same(byNameBefore[name]),
            reason: '$name сохранён ПО ССЫЛКЕ, а не по значению');
      }

      // Only 🌍 VPN is even allowed to differ — and per the test above it does
      // not, because the target is already one of its members.
      expect(_group(out, '🌍 VPN'), same(byNameBefore['🌍 VPN']),
          reason: 'append оказался no-op ⇒ и роутер уцелел по ссылке');
    });

    test('🇪🇺 cascade node IS a legitimate country target (it is a router '
        'member); the 🌀 Cascade GROUP never is', () {
      // HONEST value, derived from the code BEFORE asserting, then measured:
      //   smartInterceptGroups → [🌍 VPN, ▶️ YouTube, 💬 Discord, ⚡ Fastest]
      //     (🌀 Cascade is NOT rule-referenced ⇒ not an intercept group;
      //      📶 First Available is hard-excluded);
      //   interceptLeafNodes → all three nodes, because 🌍 VPN (and ⚡ Fastest)
      //     carry 🇪🇺 Каскад in their `proxies` — Remnawave appended it and the
      //     app does not resolve `exclude-filter`.
      // ⇒ 🇪🇺 Каскад resolves as a normal single-node country. This is NOT an
      // SOS/disconeko leak: SOS nodes are never members of a rule-referenced
      // group, whereas the cascade exit genuinely is one of the user's servers.
      final cfg = buildProdCountryTemplate();

      expect(smartInterceptGroups(cfg),
          const <String>['🌍 VPN', '▶️ YouTube', '💬 Discord', '⚡ Fastest']);
      expect(smartInterceptGroups(cfg), isNot(contains('🌀 Cascade')),
          reason: '🌀 Cascade не таргет ни одного правила ⇒ не перехватывается');

      expect(countryTargetName(cfg, '🇪🇺'), '🇪🇺 Каскад',
          reason: '🇪🇺 Каскад — член роутера, значит легальная цель');

      // A GROUP name can never become the target: leaves are top-level proxies
      // only, so no group name is ever a country candidate.
      final leaves = interceptLeafNodes(cfg);
      for (final g in cfg['proxy-groups'] as List) {
        expect(leaves, isNot(contains((g as Map)['name'].toString())),
            reason: 'имя группы не может быть узлом-кандидатом');
      }
      expect(countryTargetName(cfg, '🌀 Cascade'), isNull,
          reason: 'имя группы — не ключ страны');
    });
  });
}
