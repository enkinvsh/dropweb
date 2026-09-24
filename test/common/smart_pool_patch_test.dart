// patchSmartPool energy + naming regressions.
//
// Core defaults (core/Clash.Meta/adapter/outboundgroup/parser.go): a missing
// `interval` becomes 300 s for any non-select group, and the smart group's
// own background tasks touch it so `lazy` never idles — the injected group
// must therefore carry an explicit, slow interval.
import 'dart:convert';

import 'package:dropweb/common/smart_pool_patch.dart';
import 'package:dropweb/common/work_mode_patch.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _fleet = 12;
const _sos = 57;

String _uuid(int i) =>
    '1b3e${i.toString().padLeft(4, '0')}-1111-4222-8333-444455556666';

/// Panel template shape (dropweb-neya dropweb.universal.wl.yml) with Remnawave
/// having filled the host lists. [extraGroups] are appended verbatim.
String _panelYaml({List<String> extraGroups = const []}) {
  final b = StringBuffer()
    ..writeln('log-level: info')
    ..writeln('unified-delay: true')
    ..writeln('proxies:');
  final names = <String>[];
  for (var i = 0; i < _fleet; i++) {
    final n = '🇩🇪 Германия ${i + 1}';
    names.add(n);
    b.writeln('  - {name: "$n", type: vless, server: de$i.example.net, '
        'port: 443, uuid: ${_uuid(i)}}');
  }
  final list = names.map((n) => '"$n"').join(', ');
  b
    ..writeln('proxy-groups:')
    ..writeln('  - {name: "🌍 VPN", type: select, proxies: ["⚡ Авто", '
        '"📶 First Available"]}')
    ..writeln('  - {name: "⚡ Авто", type: fallback, url: '
        'https://cp.cloudflare.com/generate_204, interval: 300, lazy: false, '
        'proxies: ["⚡ Fastest", "📶 First Available"]}')
    ..writeln('  - {name: "⚡ Fastest", type: url-test, url: '
        'https://cp.cloudflare.com/generate_204, interval: 120, lazy: true, '
        'proxies: [$list]}')
    ..writeln('  - {name: "📶 First Available", type: fallback, url: '
        'https://cp.cloudflare.com/generate_204, interval: 180, lazy: true, '
        'proxies: [$list]}');
  for (final g in extraGroups) {
    b.writeln('  - $g');
  }
  b
    ..writeln('rules:')
    ..writeln('  - RULE-SET,youtube,🌍 VPN')
    ..writeln('  - MATCH,🌍 VPN');
  return b.toString();
}

List<Map<String, Object>> _sosPool({String country = '🇷🇺 Russia'}) => [
      for (var i = 0; i < _sos; i++)
        <String, Object>{
          'name': '${i.toString().padLeft(4, '0')} | $country | SNI-VK | VLESS',
          'type': 'vless',
          'server': 'sos$i.example.org',
          'port': 443,
          'uuid': _uuid(1000 + i),
        },
    ];

Map<String, dynamic> _plain(String yaml) =>
    json.decode(json.encode(loadYaml(yaml))) as Map<String, dynamic>;

List<Map> _groups(Map<String, dynamic> cfg) =>
    (cfg['proxy-groups'] as List).cast<Map>();

/// Health-check HEAD requests per hour for a group, assuming the probe is not
/// lazily skipped (the smart group self-touches) and unified-delay doubles
/// every probe.
int _headPerHour(Map g, int allProxies) {
  final interval = (g['interval'] as int?) ?? 300;
  final members = g['include-all'] == true
      ? allProxies
      : (g['proxies'] as List).length;
  return members * 2 * (3600 ~/ interval);
}

void main() {
  test('injected 🧠 Smart carries an explicit slow interval + lazy', () {
    final cfg = _plain(patchSmartPool(_panelYaml(), _sosPool()));
    final all = (cfg['proxies'] as List).length;
    final smart = _groups(cfg).firstWhere((g) => g['name'] == '🧠 Smart');
    final fa =
        _groups(cfg).firstWhere((g) => g['name'] == '📶 First Available');

    expect(smart['type'], 'smart');
    expect(smart['include-all'], isTrue);
    expect(smart['interval'], 1800);
    expect(smart['lazy'], isTrue);
    expect((fa['proxies'] as List).first, '🧠 Smart');

    final perHour = _headPerHour(smart, all);
    // ignore: avoid_print
    print('[smart-pool] members=$all HEAD/h=$perHour (was ${all * 2 * 12} '
        'at core-default 300 s)');
    expect(all, _fleet + _sos);
    expect(perHour, 276); // 69 × 2 × 2; was 1656 at the 300 s default.
  });

  test('WorkMode.smart «Умный» carries interval 600 + lazy', () {
    final cfg = _plain(patchSmartPool(_panelYaml(), _sosPool()));
    final out = applyWorkModePatch(cfg, workMode: WorkMode.smart);
    final umny =
        _groups(out).firstWhere((g) => g['name'] == workModeSmartGroupName);
    expect(umny['type'], 'smart');
    expect(umny['interval'], 600);
    expect(umny['lazy'], isTrue);
    expect(_headPerHour(umny, 0), 144); // 12 × 2 × 6; was 288 at 300 s.
  });

  test('derived SOS names never collide with an existing proxy-group name', () {
    // A white-label panel group literally named like a derived SOS display
    // name (flag + country word).
    final yaml = _panelYaml(extraGroups: [
      '{name: "🇩🇪 Germany", type: select, proxies: ["🇩🇪 Германия 1"]}',
    ]);
    final cfg = _plain(patchSmartPool(yaml, _sosPool(country: '🇩🇪 Germany')));

    final groupNames = _groups(cfg).map((g) => '${g['name']}').toSet();
    final proxyNames =
        (cfg['proxies'] as List).map((p) => '${(p as Map)['name']}').toList();

    // One flat namespace in mihomo: no proxy may reuse a group name, and no
    // two proxies may share a name.
    expect(proxyNames.toSet().intersection(groupNames), isEmpty);
    expect(proxyNames.toSet().length, proxyNames.length);
    expect(proxyNames, contains('🇩🇪 Germany 2'));
    expect(proxyNames, isNot(contains('🇩🇪 Germany')));
  });
}
