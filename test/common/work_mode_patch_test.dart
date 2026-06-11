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

/// Builds a POOLED-shape fixture: exactly ONE leaf node per country whose
/// `server` is a pool DOMAIN (not an IP), mirroring the real panel template.
/// The 🇩🇪 leaf is a Reality VLESS node with NO explicit `servername`/`sni`
/// (so SNI-preservation must synthesize `servername` = the pool domain before
/// the IP override); the 🇳🇱 leaf carries an explicit steal-domain
/// `servername` (so SNI-preservation must NOT clobber it). A fresh instance is
/// returned each call so mutation tests stay isolated.
Map<String, dynamic> buildPooledTemplate() => <String, dynamic>{
      'mixed-port': 7890,
      'proxies': <Map<String, dynamic>>[
        {
          'name': '🇩🇪 Германия',
          'type': 'vless',
          'server': 'de.meybz.asia',
          'port': 443,
          'flow': 'xtls-rprx-vision',
          'tls': true,
          'reality-opts': <String, dynamic>{
            'public-key': 'PUBKEY_DE',
            'short-id': 'SHORTID_DE',
          },
        },
        {
          'name': '🇳🇱 Нидерланды',
          'type': 'vless',
          'server': 'nl.meybz.asia',
          'port': 443,
          'flow': 'xtls-rprx-vision',
          'tls': true,
          'servername': 'steal.example.com',
          'reality-opts': <String, dynamic>{
            'public-key': 'PUBKEY_NL',
            'short-id': 'SHORTID_NL',
          },
        },
      ],
      'proxy-groups': <Map<String, dynamic>>[
        {
          'name': '🌍 VPN',
          'type': 'fallback',
          'proxies': ['⚡ Fastest'],
        },
        {
          'name': '⚡ Fastest',
          'type': 'url-test',
          'proxies': ['🇩🇪 Германия', '🇳🇱 Нидерланды'],
        },
      ],
      'rules': <String>[
        'DOMAIN-SUFFIX,t.me,🌍 VPN',
        'MATCH,🌍 VPN',
      ],
    };

Map? _group(Map<String, dynamic> doc, String name) {
  final groups = doc['proxy-groups'] as List;
  for (final g in groups) {
    if (g is Map && g['name'] == name) return g;
  }
  return null;
}

/// Finds the top-level proxy map named [name], or null.
Map? _proxy(Map<String, dynamic> doc, String name) {
  final proxies = doc['proxies'] as List;
  for (final p in proxies) {
    if (p is Map && p['name'] == name) return p;
  }
  return null;
}

List<String> _members(Map? group) =>
    [for (final m in (group?['proxies'] as List? ?? const [])) m.toString()];

void main() {
  group('applyWorkModePatch', () {
    test('standard: no-op (deep-equal to input)', () {
      final input = buildConfig();
      final out = applyWorkModePatch(input, workMode: WorkMode.standard);
      expect(out, buildConfig());
    });

    test('gaming: no-op (deep-equal to input)', () {
      final input = buildConfig();
      final out = applyWorkModePatch(input, workMode: WorkMode.gaming);
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

    test('smart: appends "Умный" to EVERY rule-referenced router once, '
        'idempotent (ИТЕРАЦИЯ 2)', () {
      final out =
          applyWorkModePatch(buildSmartTemplate(), workMode: WorkMode.smart);

      // buildSmartTemplate is rule-referenced on BOTH ⚡ Fastest (×25) and
      // 🌍 VPN (MATCH). «Умный» is appended at the END of each, existing
      // members preserved in order; 📶 First Available (SOS) is untouched.
      final fastest = _group(out, '⚡ Fastest');
      expect(_members(fastest), [..._templateLeaves, 'Умный']);
      expect(_members(fastest).where((m) => m == 'Умный').length, 1);

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
      expect(_members(_group(out2, '⚡ Fastest')), [..._templateLeaves, 'Умный']);
      expect(_members(_group(out2, '🌍 VPN')),
          ['⚡ Fastest', '📶 First Available', 'Умный']);
      // Injected group membership stays exactly the leaves on re-apply.
      expect(_members(_group(out2, 'Умный')), _templateLeaves);
    });

    test('smart: only rule-referenced routers gain "Умный"; every other group '
        'byte-for-byte; rules untouched', () {
      final input = buildSmartTemplate();
      final original = buildSmartTemplate();
      final originalGroups = original['proxy-groups'] as List;
      const referenced = {'⚡ Fastest', '🌍 VPN'};

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

    test('standard/gaming/country: primary router members never gain "Умный"',
        () {
      for (final out in [
        applyWorkModePatch(buildSmartTemplate(), workMode: WorkMode.standard),
        applyWorkModePatch(buildSmartTemplate(), workMode: WorkMode.gaming),
        applyWorkModePatch(buildSmartTemplate(),
            workMode: WorkMode.country, staticCountry: '🇩🇪'),
      ]) {
        expect(_members(_group(out, '⚡ Fastest')), _templateLeaves,
            reason: 'router members must not be touched outside smart mode');
        expect(_group(out, 'Умный'), isNull);
      }
    });

    test('country: injects fallback group with only that country RULE-GROUP '
        'LEAF nodes (🇩🇪 Frankfurt 02 is not a router member → excluded)', () {
      final out = applyWorkModePatch(
        buildConfig(),
        workMode: WorkMode.country,
        staticCountry: '🇩🇪',
      );

      final country = _group(out, 'Страна 🇩🇪');
      expect(country, isNotNull);
      expect(country!['type'], 'fallback');
      expect(country['url'], 'https://cp.cloudflare.com/generate_204');
      expect(country['interval'], 180);
      // Only 🇩🇪 Frankfurt 01 is routed through the rule-referenced 🌍 VPN
      // (via ⚡ Fastest). 🇩🇪 Frankfurt 02 is a bare top-level proxy → excluded.
      expect(
        (country['proxies'] as List).toList(),
        ['🇩🇪 Frankfurt 01'],
      );

      // Existing groups untouched.
      final vpn = _group(out, '🌍 VPN');
      expect((vpn!['proxies'] as List).toList(),
          ['⚡ Fastest', '📶 First Available']);
    });

    test('country: idempotent on re-apply', () {
      final out = applyWorkModePatch(
        buildConfig(),
        workMode: WorkMode.country,
        staticCountry: '🇩🇪',
      );
      final out2 = applyWorkModePatch(
        out,
        workMode: WorkMode.country,
        staticCountry: '🇩🇪',
      );
      final count = (out2['proxy-groups'] as List)
          .where((g) => g is Map && g['name'] == 'Страна 🇩🇪')
          .length;
      expect(count, 1);
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
  });

  group('countryGroupWillInject', () {
    test('country with matching nodes → true', () {
      expect(
        countryGroupWillInject(
          buildConfig(),
          workMode: WorkMode.country,
          staticCountry: '🇩🇪',
        ),
        isTrue,
      );
    });

    test('country with no matching nodes → false', () {
      expect(
        countryGroupWillInject(
          buildConfig(),
          workMode: WorkMode.country,
          staticCountry: '🇫🇷',
        ),
        isFalse,
      );
    });

    test('non-country mode → false', () {
      expect(
        countryGroupWillInject(
          buildConfig(),
          workMode: WorkMode.smart,
          staticCountry: '🇩🇪',
        ),
        isFalse,
      );
    });

    test('null staticCountry → false', () {
      expect(
        countryGroupWillInject(
          buildConfig(),
          workMode: WorkMode.country,
        ),
        isFalse,
      );
    });

    test('group already present (no nodes) → true', () {
      // A country whose nodes vanished but whose group is already defined in the
      // config still counts as present — the core has a valid target.
      final config = buildConfig();
      (config['proxy-groups'] as List).add(<String, dynamic>{
        'name': 'Страна 🇫🇷',
        'type': 'fallback',
        'proxies': <String>[],
      });
      expect(
        countryGroupWillInject(
          config,
          workMode: WorkMode.country,
          staticCountry: '🇫🇷', // no French nodes in fixture
        ),
        isTrue,
      );
    });

    test('agrees with applyWorkModePatch output presence', () {
      for (final flag in ['🇩🇪', '🇸🇪', '🇷🇺', '🇫🇷']) {
        final willInject = countryGroupWillInject(
          buildConfig(),
          workMode: WorkMode.country,
          staticCountry: flag,
        );
        final out = applyWorkModePatch(
          buildConfig(),
          workMode: WorkMode.country,
          staticCountry: flag,
        );
        final present = _group(out, 'Страна $flag') != null;
        expect(willInject, present, reason: 'mismatch for $flag');
      }
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

    test('never names a group applyWorkModePatch did not actually patch', () {
      final out = applyWorkModePatch(buildProdTemplate(), workMode: WorkMode.smart);
      for (final g in smartInterceptGroups(buildProdTemplate())) {
        expect(_members(_group(out, g)), contains('Умный'),
            reason: '$g claimed as intercept target but not patched');
      }
    });
  });

  group('applyWorkModePatch — production template multi-interception', () {
    test('appends «Умный» to VPN, YouTube, Discord, Fastest; SOS/DIRECT/Cascade '
        'untouched', () {
      final out =
          applyWorkModePatch(buildProdTemplate(), workMode: WorkMode.smart);

      expect(_members(_group(out, '🌍 VPN')),
          ['⚡ Fastest', '📶 First Available', 'Умный']);
      expect(_members(_group(out, '▶️ YouTube')),
          ['🌀 Cascade', '⚡ Fastest', 'Умный']);
      expect(_members(_group(out, '💬 Discord')),
          ['🌀 Cascade', '⚡ Fastest', 'Умный']);
      expect(_members(_group(out, '⚡ Fastest')), ['🇩🇪 A', '🇳🇱 B', 'Умный']);

      // Non-intercepted groups stay byte-for-byte.
      expect(_members(_group(out, '🌀 Cascade')), ['🇸🇪 C']);
      expect(_members(_group(out, '♻️ DIRECT')), ['DIRECT']);
      expect(_members(_group(out, '📶 First Available')), ['🧠 Smart']);
      expect(_group(out, '🧠 Smart')!['include-all'], true);
    });

    test('«Умный» group rotates over the UNION of all intercept-group leaves; '
        'SOS nodes absent', () {
      final out =
          applyWorkModePatch(buildProdTemplate(), workMode: WorkMode.smart);
      final smart = _group(out, 'Умный');
      expect(smart, isNotNull);
      expect(smart!['type'], 'smart');
      expect(smart['collectdata'], false);
      expect(smart.containsKey('include-all'), isFalse);
      expect(_members(smart), _prodUnionLeaves);
      // SOS pool never leaks into «Умный».
      expect(_members(smart), isNot(contains('🇫🇮 SOS1')));
      expect(_members(smart), isNot(contains('🇪🇪 SOS2')));
    });

    test('build-path "rule" key still drives full interception', () {
      final cfg = buildProdTemplate();
      cfg['rule'] = cfg.remove('rules');
      final out = applyWorkModePatch(cfg, workMode: WorkMode.smart);
      expect(_members(_group(out, '🌍 VPN')), contains('Умный'));
      expect(_members(_group(out, '▶️ YouTube')), contains('Умный'));
      expect(_members(_group(out, '💬 Discord')), contains('Умный'));
      expect(_members(_group(out, '⚡ Fastest')), contains('Умный'));
      expect(_members(_group(out, 'Умный')), _prodUnionLeaves);
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
      for (final g in _prodInterceptGroups) {
        expect(_members(_group(out2, g)).where((m) => m == 'Умный').length, 1);
      }
      expect(_members(_group(out2, 'Умный')), _prodUnionLeaves);
    });

    test('standard/gaming/country: no group gains «Умный» on prod template', () {
      for (final out in [
        applyWorkModePatch(buildProdTemplate(), workMode: WorkMode.standard),
        applyWorkModePatch(buildProdTemplate(), workMode: WorkMode.gaming),
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

    test('applyWorkModePatch country 🇩🇪 → «Страна 🇩🇪» holds the curated leaf '
        'only (SOS 🇩🇪 Berlin excluded)', () {
      final out = applyWorkModePatch(buildProdTemplate(),
          workMode: WorkMode.country, staticCountry: '🇩🇪');
      final country = _group(out, 'Страна 🇩🇪');
      expect(country, isNotNull);
      expect(country!['type'], 'fallback');
      expect(_members(country), ['🇩🇪 A']);
      expect(_members(country), isNot(contains('🇩🇪 SOS Berlin')));
    });

    test('countryGroupWillInject: SOS-only flags false, curated flags true', () {
      Map<String, dynamic> cfg() => buildProdTemplate();
      for (final sos in ['🇷🇺', '🇬🇧', '🇫🇮']) {
        expect(
          countryGroupWillInject(cfg(),
              workMode: WorkMode.country, staticCountry: sos),
          isFalse,
          reason: '$sos is SOS-only → must not inject',
        );
      }
      for (final ok in ['🇩🇪', '🇳🇱', '🇸🇪']) {
        expect(
          countryGroupWillInject(cfg(),
              workMode: WorkMode.country, staticCountry: ok),
          isTrue,
          reason: '$ok is panel-curated → must inject',
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
      // Curated 🇩🇪 injects; SOS-only 🇷🇺 does not — even via the renamed key.
      final outDe = applyWorkModePatch(cfg,
          workMode: WorkMode.country, staticCountry: '🇩🇪');
      expect(_members(_group(outDe, 'Страна 🇩🇪')), ['🇩🇪 A']);
      final cfg2 = buildProdTemplate();
      cfg2['rule'] = cfg2.remove('rules');
      final outRu = applyWorkModePatch(cfg2,
          workMode: WorkMode.country, staticCountry: '🇷🇺');
      expect(_group(outRu, 'Страна 🇷🇺'), isNull);
    });
  });

  group('countryStrictProxyName', () {
    test('formats as «Страна <flag> <ip>» and is country-prefixed', () {
      final name = countryStrictProxyName('🇩🇪', '152.53.155.182');
      expect(name, 'Страна 🇩🇪 152.53.155.182');
      // MUST start with the «Страна » prefix so value-ownership selectedMap
      // cleanup recognizes the variant as ours.
      expect(name.startsWith('$workModeCountryGroupPrefix '), isTrue);
    });
  });

  group('applyWorkModePatch — DNS-pool unrolling (strict IP pin)', () {
    const ip = '152.53.155.182';
    final variantName = countryStrictProxyName('🇩🇪', ip);

    test('injects a variant proxy with server=IP and synthesized SNI', () {
      final out = applyWorkModePatch(
        buildPooledTemplate(),
        workMode: WorkMode.country,
        staticCountry: '🇩🇪',
        staticStrictNode: ip,
      );

      final variant = _proxy(out, variantName);
      expect(variant, isNotNull, reason: 'variant proxy must be appended');
      expect(variant!['server'], ip, reason: 'server pinned to the IP');
      expect(variant['name'], variantName);
      // SNI PRESERVATION: base had NO servername → synthesize it to the pool
      // domain BEFORE overriding server, else Reality SNI breaks.
      expect(variant['servername'], 'de.meybz.asia');
      // Reality opts + flow/tls cloned verbatim.
      expect(variant['type'], 'vless');
      expect(variant['flow'], 'xtls-rprx-vision');
      expect(variant['tls'], true);
      expect((variant['reality-opts'] as Map)['public-key'], 'PUBKEY_DE');
      expect((variant['reality-opts'] as Map)['short-id'], 'SHORTID_DE');
    });

    test('does NOT clobber an existing servername on the base node', () {
      final out = applyWorkModePatch(
        buildPooledTemplate(),
        workMode: WorkMode.country,
        staticCountry: '🇳🇱',
        staticStrictNode: '193.233.126.126',
      );
      final variant = _proxy(out, countryStrictProxyName('🇳🇱', '193.233.126.126'));
      expect(variant, isNotNull);
      expect(variant!['server'], '193.233.126.126');
      // Steal-domain servername preserved verbatim (NOT set to the pool domain).
      expect(variant['servername'], 'steal.example.com');
    });

    test('leaves base proxies & groups untouched (additive only)', () {
      final base = buildPooledTemplate();
      final out = applyWorkModePatch(
        base,
        workMode: WorkMode.country,
        staticCountry: '🇩🇪',
        staticStrictNode: ip,
      );
      // Base 🇩🇪 leaf unchanged: still the pool domain, no server override.
      final baseLeaf = _proxy(out, '🇩🇪 Германия');
      expect(baseLeaf!['server'], 'de.meybz.asia');
      expect(baseLeaf.containsKey('servername'), isFalse);
      // Country fallback group still injected (failover safety net).
      expect(_group(out, 'Страна 🇩🇪'), isNotNull);
      // Existing routers untouched.
      expect(_members(_group(out, '⚡ Fastest')),
          ['🇩🇪 Германия', '🇳🇱 Нидерланды']);
      // Exactly one variant appended (orig 2 proxies → 3).
      expect((out['proxies'] as List).length, 3);
    });

    test('idempotent: re-apply does not duplicate the variant', () {
      final out = applyWorkModePatch(
        buildPooledTemplate(),
        workMode: WorkMode.country,
        staticCountry: '🇩🇪',
        staticStrictNode: ip,
      );
      final out2 = applyWorkModePatch(
        out,
        workMode: WorkMode.country,
        staticCountry: '🇩🇪',
        staticStrictNode: ip,
      );
      final count = (out2['proxies'] as List)
          .where((p) => p is Map && p['name'] == variantName)
          .length;
      expect(count, 1);
    });

    test('staticStrictNode = a real node NAME pins by name, no variant', () {
      final out = applyWorkModePatch(
        buildConfig(),
        workMode: WorkMode.country,
        staticCountry: '🇩🇪',
        staticStrictNode: '🇩🇪 Frankfurt 01',
      );
      // No IP variant created; proxies list length unchanged.
      expect((out['proxies'] as List).length,
          (buildConfig()['proxies'] as List).length);
      // Country fallback group still present.
      expect(_group(out, 'Страна 🇩🇪'), isNotNull);
    });

    test('IP pin but no matching country leaf → no variant', () {
      final out = applyWorkModePatch(
        buildPooledTemplate(),
        workMode: WorkMode.country,
        staticCountry: '🇫🇷', // no French leaf
        staticStrictNode: ip,
      );
      expect(_proxy(out, countryStrictProxyName('🇫🇷', ip)), isNull);
      expect((out['proxies'] as List).length,
          (buildPooledTemplate()['proxies'] as List).length);
    });

    test('IP that already names a proxy → no duplicate variant built', () {
      // Edge: staticStrictNode equals an existing proxy name that is an IP.
      final cfg = buildPooledTemplate();
      (cfg['proxies'] as List).add(<String, dynamic>{
        'name': ip,
        'type': 'vless',
        'server': ip,
        'port': 443,
      });
      final out = applyWorkModePatch(
        cfg,
        workMode: WorkMode.country,
        staticCountry: '🇩🇪',
        staticStrictNode: ip,
      );
      // It is already a proxy name → treated as a name pin, no «Страна» variant.
      expect(_proxy(out, variantName), isNull);
    });
  });
}
