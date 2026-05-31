import 'package:dropweb/common/share_link_profile.dart';
import 'package:dropweb/common/smart_pool_patch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Helper: extract a proxy-group map by name from a parsed mihomo YAML doc.
Map? _group(YamlMap doc, String name) {
  final groups = doc['proxy-groups'] as YamlList;
  for (final g in groups) {
    if (g['name'] == name) return g as Map;
  }
  return null;
}

List<String> _proxyNames(YamlMap doc) {
  final proxies = doc['proxies'];
  if (proxies == null) return <String>[];
  return [for (final p in proxies as YamlList) p['name'] as String];
}

void main() {
  group('patchSmartPool', () {
    // Compact representative fixture capturing the real dropweb panel shape:
    // - `🌍 VPN` is the primary router (most rules target it).
    // - `⚡ Fastest` (url-test) is its first member.
    // - `📶 First Available` (fallback) is an existing sibling, untouched.
    // - `♻️ DIRECT` is a hidden DIRECT-only select group (must NOT be primary).
    const template = '''
mixed-port: 7890
mode: rule
proxies: # LEAVE THIS LINE!

proxy-groups:
  - name: 🌍 VPN
    type: select
    proxies:
      - ⚡ Fastest
      - 📶 First Available

  - name: ▶️ YouTube
    type: select
    proxies:
      - 🌀 Cascade
      - 🌍 VPN

  - name: 🌀 Cascade
    type: url-test
    url: https://cp.cloudflare.com/generate_204
    interval: 180
    proxies:
      # LEAVE THIS LINE!

  - name: ⚡ Fastest
    type: url-test
    url: https://cp.cloudflare.com/generate_204
    interval: 180
    proxies:
      # LEAVE THIS LINE!

  - name: 📶 First Available
    type: fallback
    url: https://cp.cloudflare.com/generate_204
    interval: 180
    proxies:
      # LEAVE THIS LINE!

  - name: ♻️ DIRECT
    type: select
    hidden: true
    proxies:
      - DIRECT

rules:
  - IP-CIDR,17.0.0.0/8,♻️ DIRECT,no-resolve
  - DOMAIN-SUFFIX,t.me,🌍 VPN
  - DOMAIN-SUFFIX,telegram.org,🌍 VPN
  - RULE-SET,ai,🌍 VPN
  - RULE-SET,ru-app-list,♻️ DIRECT
  - RULE-SET,youtube,▶️ YouTube
  - RULE-SET,cloudflare,🌍 VPN
  - MATCH,DIRECT
''';

    final sosProxies = <Map<String, Object>>[
      {
        'name': '0099 | 🇷🇺 Russia | 🏳️ SNI-VK | VLESS | TG: @YoutubeUnBlockRu',
        'type': 'vless',
        'server': 'sos1.example.com',
        'port': 443,
        'uuid': 'sos-uuid-1',
        'network': 'tcp',
        'tls': true,
      },
      {
        'name': '0015 | 🇸🇪 Sweden | 🏳️ SNI-VK | VLESS | TG: @x',
        'type': 'vless',
        'server': 'sos2.example.com',
        'port': 443,
        'uuid': 'sos-uuid-2',
        'network': 'tcp',
        'tls': true,
      },
    ];

    test('dropweb template: builds 🧠 Smart group and rewires primary', () {
      final out = patchSmartPool(template, sosProxies);
      final doc = loadYaml(out) as YamlMap;

      // `🧠 Smart` group: type smart, uselightgbm:false, include-all:true.
      final smart = _group(doc, '🧠 Smart');
      expect(smart, isNotNull);
      expect(smart!['type'], 'smart');
      expect(smart['uselightgbm'], false);
      expect(smart['include-all'], true);

      // Primary router `🌍 VPN`: `🧠 Smart` prepended as default (index 0),
      // existing siblings preserved.
      final vpn = _group(doc, '🌍 VPN');
      expect(
        (vpn!['proxies'] as YamlList).toList(),
        ['🧠 Smart', '⚡ Fastest', '📶 First Available'],
      );

      // Emergency nodes appended with flag+country display names; the
      // provider / SNI / protocol / TG noise must NOT leak.
      final names = _proxyNames(doc);
      expect(names, contains('🇷🇺 Russia'));
      expect(names, contains('🇸🇪 Sweden'));
      expect(names, isNot(contains('SOS 1')));
      expect(names, isNot(contains('SOS 2')));
      expect(
        names,
        isNot(contains('0099 | 🇷🇺 Russia | 🏳️ SNI-VK | VLESS | TG: @YoutubeUnBlockRu')),
      );
      expect(out, isNot(contains('@YoutubeUnBlockRu')));
      expect(out, isNot(contains('SNI-VK')));

      // No legacy `🆘 SOS` group, and no `hidden: true` injected by the patch
      // (the only `hidden: true` is the pre-existing `♻️ DIRECT` group).
      expect(_group(doc, '🆘 SOS'), isNull);
      expect('hidden: true'.allMatches(out).length, 1);

      // `⚡ Fastest` and `📶 First Available` are otherwise unchanged.
      final fastest = _group(doc, '⚡ Fastest');
      expect(fastest!['type'], 'url-test');
      final firstAvail = _group(doc, '📶 First Available');
      expect(firstAvail!['type'], 'fallback');

      // `♻️ DIRECT` was NOT chosen as primary (only DIRECT member, untouched).
      final direct = _group(doc, '♻️ DIRECT');
      expect((direct!['proxies'] as YamlList).toList(), ['DIRECT']);

      // Original rules preserved verbatim: this patch only touches proxies
      // and proxy-groups, never rules.
      final originalRuleItems =
          template.substring(template.indexOf('  - IP-CIDR'));
      expect(out, contains(originalRuleItems.trimRight()));

      // No `🤖 AI` group — this patch does no AI routing.
      expect(_group(doc, '🤖 AI'), isNull);
    });

    test('etoneya raw case: convertShareLink output then patched', () {
      const blob = '''
vless://uuid-1@a.example.com:443?security=tls&sni=a.example.com#Etoneya%20A
vless://uuid-2@b.example.com:443?security=tls&sni=b.example.com#Etoneya%20B
''';
      final converted = convertShareLinkSubscriptionToMihomo(blob);
      expect(converted, isNotNull);

      final out = patchSmartPool(converted!, sosProxies);
      final doc = loadYaml(out) as YamlMap;

      final smart = _group(doc, '🧠 Smart');
      expect(smart, isNotNull);
      expect(smart!['type'], 'smart');

      final vpn = _group(doc, '🌍 VPN');
      expect((vpn!['proxies'] as YamlList).first, '🧠 Smart');
    });

    test('no qualifying router: returns input unchanged', () {
      const yaml = '''
mixed-port: 7890
proxies:
  - name: A
    type: vless
    server: a.com
    port: 443
    uuid: u
proxy-groups:
  - name: ♻️ DIRECT
    type: select
    proxies:
      - DIRECT
rules:
  - RULE-SET,ads,REJECT
  - MATCH,DIRECT
''';
      final out = patchSmartPool(yaml, sosProxies);
      expect(out, yaml);
    });

    test('flag+country collision: appends numeric suffix', () {
      const yaml = '''
mixed-port: 7890
proxies:
  - name: Base
    type: vless
    server: base.com
    port: 443
    uuid: base-uuid
proxy-groups:
  - name: 🌍 VPN
    type: select
    proxies:
      - Base
rules:
  - MATCH,🌍 VPN
''';
      final collide = <Map<String, Object>>[
        {
          'name': '0001 | 🇷🇺 Russia | VLESS',
          'type': 'vless',
          'server': 'x.com',
          'port': 443,
          'uuid': 'u1',
        },
        {
          'name': '0002 | 🇷🇺 Russia | TROJAN',
          'type': 'trojan',
          'server': 'y.com',
          'port': 443,
          'password': 'p',
        },
      ];
      final out = patchSmartPool(yaml, collide);
      final doc = loadYaml(out) as YamlMap;
      final names = _proxyNames(doc);
      expect(names, contains('🇷🇺 Russia'));
      expect(names, contains('🇷🇺 Russia 2'));
    });

    test('no-flag node: falls back to 🌐 Node N', () {
      const yaml = '''
mixed-port: 7890
proxies:
  - name: Base
    type: vless
    server: base.com
    port: 443
    uuid: base-uuid
proxy-groups:
  - name: 🌍 VPN
    type: select
    proxies:
      - Base
rules:
  - MATCH,🌍 VPN
''';
      final noFlag = <Map<String, Object>>[
        {
          'name': '0000 | TG: @x',
          'type': 'vless',
          'server': 'z.com',
          'port': 443,
          'uuid': 'u',
        },
      ];
      final out = patchSmartPool(yaml, noFlag);
      final doc = loadYaml(out) as YamlMap;
      final names = _proxyNames(doc);
      expect(names, contains('🌐 Node 1'));
      expect(out, isNot(contains('@x')));
    });

    test('existing 🧠 Smart group: gains include-all, stays default', () {
      const yaml = '''
mixed-port: 7890
proxies: # LEAVE THIS LINE!
proxy-groups:
  - name: 🌍 VPN
    type: select
    proxies:
      - 🧠 Smart
      - DIRECT
  - name: 🧠 Smart
    type: smart
    uselightgbm: false
    proxies:
      # LEAVE THIS LINE!
rules:
  - MATCH,🌍 VPN
''';
      final out = patchSmartPool(yaml, sosProxies);
      final doc = loadYaml(out) as YamlMap;

      // The pre-existing smart group must gain `include-all: true`.
      final smart = _group(doc, '🧠 Smart');
      expect(smart, isNotNull);
      expect(smart!['type'], 'smart');
      expect(smart['include-all'], true);

      // Exactly one `🧠 Smart` group — no duplicate appended.
      final smartCount = [
        for (final g in doc['proxy-groups'] as YamlList)
          if (g['name'] == '🧠 Smart') g,
      ].length;
      expect(smartCount, 1);

      // It stays the default (already index 0) of the primary router.
      final vpn = _group(doc, '🌍 VPN');
      expect((vpn!['proxies'] as YamlList).first, '🧠 Smart');

      // Emergency nodes still merged into top-level proxies.
      final names = _proxyNames(doc);
      expect(names, contains('🇷🇺 Russia'));
      expect(names, contains('🇸🇪 Sweden'));
    });

    test('null/empty proxies placeholder: creates list, no crash', () {
      const yaml = '''
mixed-port: 7890
proxies:
proxy-groups:
  - name: 🌍 VPN
    type: select
    proxies:
      - ⚡ Fastest
  - name: ⚡ Fastest
    type: url-test
    proxies:
      - DIRECT
rules:
  - MATCH,🌍 VPN
''';
      final out = patchSmartPool(yaml, sosProxies);
      final doc = loadYaml(out) as YamlMap;
      final names = _proxyNames(doc);
      expect(names, contains('🇷🇺 Russia'));
      expect(names, contains('🇸🇪 Sweden'));

      final vpn = _group(doc, '🌍 VPN');
      expect((vpn!['proxies'] as YamlList).first, '🧠 Smart');
    });
  });
}
