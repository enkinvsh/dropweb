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

Map? _group(Map<String, dynamic> doc, String name) {
  final groups = doc['proxy-groups'] as List;
  for (final g in groups) {
    if (g is Map && g['name'] == name) return g;
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

    test('smart: appends "Умный" to the primary router members once, idempotent',
        () {
      final out =
          applyWorkModePatch(buildSmartTemplate(), workMode: WorkMode.smart);

      // D2 fix: «Умный» is now a MEMBER of the primary router (⚡ Fastest),
      // appended at the END, with existing members preserved in order.
      final router = _group(out, '⚡ Fastest');
      expect(_members(router), [..._templateLeaves, 'Умный']);
      expect(_members(router).where((m) => m == 'Умный').length, 1);

      // Re-apply must NOT duplicate the group nor the appended member.
      final out2 = applyWorkModePatch(out, workMode: WorkMode.smart);
      final groupCount = (out2['proxy-groups'] as List)
          .where((g) => g is Map && g['name'] == 'Умный')
          .length;
      expect(groupCount, 1);
      final router2 = _group(out2, '⚡ Fastest');
      expect(_members(router2), [..._templateLeaves, 'Умный']);
      expect(_members(router2).where((m) => m == 'Умный').length, 1);
      // Injected group membership stays exactly the leaves on re-apply.
      expect(_members(_group(out2, 'Умный')), _templateLeaves);
    });

    test('smart: leaves every group except the primary router byte-for-byte; '
        'rules untouched', () {
      final input = buildSmartTemplate();
      final original = buildSmartTemplate();
      final originalGroups = original['proxy-groups'] as List;

      final out = applyWorkModePatch(input, workMode: WorkMode.smart);
      final outGroups = out['proxy-groups'] as List;

      // One new group appended (Умный); originals retained in order.
      expect(outGroups.length, originalGroups.length + 1);
      for (var i = 0; i < originalGroups.length; i++) {
        final origGroup = originalGroups[i] as Map;
        if (origGroup['name'] == '⚡ Fastest') {
          // The sole permitted change: 'Умный' appended to the router members.
          final expected = Map<String, dynamic>.from(
              origGroup.cast<String, dynamic>())
            ..['proxies'] = [..._templateLeaves, 'Умный'];
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

    test('country: injects fallback group with only that country nodes, order preserved', () {
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
      expect(
        (country['proxies'] as List).toList(),
        ['🇩🇪 Frankfurt 01', '🇩🇪 Frankfurt 02'],
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
}
