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

Map? _group(Map<String, dynamic> doc, String name) {
  final groups = doc['proxy-groups'] as List;
  for (final g in groups) {
    if (g is Map && g['name'] == name) return g;
  }
  return null;
}

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

    test('smart: injects "Умный" group once, idempotent on re-apply', () {
      final out = applyWorkModePatch(buildConfig(), workMode: WorkMode.smart);

      final smart = _group(out, 'Умный');
      expect(smart, isNotNull);
      expect(smart!['type'], 'smart');
      expect(smart['include-all'], true);
      expect(smart['collectdata'], false);

      // Exactly one such group.
      final count = (out['proxy-groups'] as List)
          .where((g) => g is Map && g['name'] == 'Умный')
          .length;
      expect(count, 1);

      // Re-apply must NOT duplicate.
      final out2 = applyWorkModePatch(out, workMode: WorkMode.smart);
      final count2 = (out2['proxy-groups'] as List)
          .where((g) => g is Map && g['name'] == 'Умный')
          .length;
      expect(count2, 1);
    });

    test('smart: does NOT modify existing groups or rules', () {
      final input = buildConfig();
      final originalGroups = buildConfig()['proxy-groups'];
      final originalRules = buildConfig()['rules'];

      final out = applyWorkModePatch(input, workMode: WorkMode.smart);

      // Every pre-existing group is preserved byte-for-byte (order + content).
      final outGroups = out['proxy-groups'] as List;
      expect(outGroups.length, (originalGroups as List).length + 1);
      for (var i = 0; i < originalGroups.length; i++) {
        expect(outGroups[i], originalGroups[i]);
      }
      // Rules untouched.
      expect(out['rules'], originalRules);
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
}
