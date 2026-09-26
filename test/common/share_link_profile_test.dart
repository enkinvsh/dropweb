// Regression: share-link converter keeps transport options (audit A4-7),
// subscription-userinfo parsing tolerates malformed segments (A4-4) and the
// remote-body guard rejects configs without proxies (A4-1).
import 'package:dropweb/common/share_link_profile.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../support/fake_path_provider.dart';

const _uuid = 'b831381d-6324-4d53-ad4f-8cda48b30811';
const _pbk = 'jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0';

Map<String, Map> _proxiesByName(String body) {
  final yaml = convertShareLinkSubscriptionToMihomo(body)!;
  final doc = loadYaml(yaml) as Map;
  return {
    for (final p in (doc['proxies'] as List).cast<Map>())
      p['name'] as String: p,
  };
}

void main() {
  // Skipped-scheme logging goes through commonPrint → fileLogger → appPath.
  useFakePathProvider();
  TestWidgetsFlutterBinding.ensureInitialized();

  group('share-link transport options', () {
    test('vless ws → ws-opts {path, headers.Host}', () {
      final ws = _proxiesByName(
        'vless://$_uuid@ws.example.com:443?type=ws&path=%2Fsecret-ws'
        '&host=cdn.example.com&security=tls&sni=cdn.example.com#ws',
      )['ws']!;
      expect(ws['network'], 'ws');
      expect(ws['ws-opts'], {
        'path': '/secret-ws',
        'headers': {'Host': 'cdn.example.com'},
      });
      expect(ws['tls'], isTrue);
      expect(ws['servername'], 'cdn.example.com');
    });

    test('vless grpc → grpc-opts {grpc-service-name}', () {
      final grpc = _proxiesByName(
        'vless://$_uuid@grpc.example.com:443?type=grpc&serviceName=hidden-svc'
        '&mode=gun&security=tls#grpc',
      )['grpc']!;
      expect(grpc['network'], 'grpc');
      expect(grpc['grpc-opts'], {'grpc-service-name': 'hidden-svc'});
    });

    test('vless xhttp → xhttp-opts {path, host, mode}', () {
      final xh = _proxiesByName(
        'vless://$_uuid@xh.example.com:443?type=xhttp&path=%2Fxh'
        '&host=h.example.com&mode=packet-up&security=reality&pbk=$_pbk&sid=01'
        '#xhttp',
      )['xhttp']!;
      expect(xh['network'], 'xhttp');
      expect(xh['xhttp-opts'], {
        'path': '/xh',
        'host': 'h.example.com',
        'mode': 'packet-up',
      });
      expect(xh['reality-opts'], {'public-key': _pbk, 'short-id': '01'});
    });

    test('trojan ws/grpc carry their options', () {
      final byName = _proxiesByName([
        'trojan://pw@t.example.com:443?type=ws&path=%2Ftw&host=t.cdn#tws',
        'trojan://pw@t.example.com:443?type=grpc&serviceName=tsvc#tgrpc',
      ].join('\n'));
      expect(byName['tws']!['ws-opts'], {
        'path': '/tw',
        'headers': {'Host': 't.cdn'},
      });
      expect(byName['tgrpc']!['grpc-opts'], {'grpc-service-name': 'tsvc'});
    });

    test('tcp / reality output is unchanged (no transport opts)', () {
      final byName = _proxiesByName([
        'vless://$_uuid@r.example.com:443?type=tcp&security=reality&pbk=$_pbk'
                '&sid=0123abcd&sni=www.microsoft.com&fp=chrome'
                '&flow=xtls-rprx-vision#r'
            .toString(),
        'vless://$_uuid@p.example.com:443?security=tls#plain',
      ].join('\n'));
      expect(Map<String, Object?>.from(byName['r']!), {
        'name': 'r',
        'type': 'vless',
        'server': 'r.example.com',
        'port': 443,
        'uuid': _uuid,
        'network': 'tcp',
        'flow': 'xtls-rprx-vision',
        'tls': true,
        'servername': 'www.microsoft.com',
        'client-fingerprint': 'chrome',
        'reality-opts': {'public-key': _pbk, 'short-id': '0123abcd'},
      });
      expect(byName['plain']!['network'], 'tcp');
      expect(byName['plain']!.keys.where((k) => '$k'.endsWith('-opts')),
          isEmpty);
    });

    test('unsupported schemes are skipped without breaking supported ones',
        () {
      final names = _proxiesByName([
        'vless://$_uuid@a.example.com:443?security=tls#keep',
        'hysteria2://pass@h.example.com:443?sni=h.example.com#hy2-node',
        'ss://YWVzLTI1Ni1nY206cGFzcw@s.example.com:8388#ss-node',
      ].join('\n'))
          .keys;
      expect(names, ['keep']);
    });

    test('no 🧠 Smart / smart group; ⚡ Fastest leads 🌍 VPN', () {
      final yaml = convertShareLinkSubscriptionToMihomo(
        'vless://$_uuid@a.example.com:443?security=tls#keep',
      )!;
      expect(yaml, isNot(contains('🧠 Smart')));
      expect(yaml, isNot(contains('type: smart')));
      final vpn = ((loadYaml(yaml) as Map)['proxy-groups'] as List)
          .cast<Map>()
          .firstWhere((g) => g['name'] == '🌍 VPN');
      expect(vpn['proxies'], ['⚡ Fastest', 'keep', 'DIRECT']);
    });
  });

  group('SubscriptionInfo.formHString', () {
    test('trailing semicolon', () {
      expect(
        SubscriptionInfo.formHString('upload=1; download=2; total=3; expire=4;'),
        const SubscriptionInfo(upload: 1, download: 2, total: 3, expire: 4),
      );
    });
    test('empty header', () {
      expect(SubscriptionInfo.formHString(''), const SubscriptionInfo());
    });
    test('malformed segments are skipped', () {
      expect(
        SubscriptionInfo.formHString(';;upload; =5; total=7 ;download=x'),
        const SubscriptionInfo(total: 7),
      );
    });
  });

  group('subscriptionBodyRejectReason', () {
    test('rejects blank / non-map / empty proxy sources', () {
      expect(subscriptionBodyRejectReason(''), isNotNull);
      expect(subscriptionBodyRejectReason(' \n\t'), isNotNull);
      expect(
        subscriptionBodyRejectReason('{"message":"Not Found","statusCode":404}'),
        isNotNull,
      );
      expect(subscriptionBodyRejectReason('<html>expired</html>'), isNotNull);
      expect(subscriptionBodyRejectReason('proxies: []\n'), isNotNull);
      expect(subscriptionBodyRejectReason('proxy-providers: {}\n'), isNotNull);
      expect(subscriptionBodyRejectReason('rules:\n  - MATCH,DIRECT\n'),
          isNotNull);
    });
    test('accepts non-empty proxies or proxy-providers', () {
      expect(
        subscriptionBodyRejectReason('proxies:\n  - {name: a, type: direct}\n'),
        isNull,
      );
      expect(
        subscriptionBodyRejectReason(
            'proxy-providers:\n  p: {type: http, url: "https://x"}\n'),
        isNull,
      );
    });
    test('defers to the core when the Dart YAML parser fails', () {
      expect(subscriptionBodyRejectReason('a: [unclosed'), isNull);
    });
  });

  // A node the core's RealityOptions.Parse rejects fails the WHOLE config, so
  // one malformed share link must not reach the saved profile.
  group('REALITY keys the core would reject are dropped', () {
    String link(String name, {String pbk = _pbk, String? sid}) =>
        'vless://$_uuid@$name.example.net:443?security=reality&pbk=$pbk'
        '${sid == null ? '' : '&sid=$sid'}#$name';

    test('share links: odd/overlong/non-hex short id and bad key dropped', () {
      final names = parseSubscriptionToProxies([
        link('ok', sid: '0123abcd'),
        link('nosid'),
        link('upper', sid: 'ABCDEF01'),
        link('odd', sid: 'abc'),
        link('long', sid: '0123456789abcdef01'),
        link('nonhex', sid: 'zz'),
        link('shortkey', pbk: _pbk.substring(1)),
        link('padded', pbk: '${_pbk.substring(1)}='),
      ].join('\n'))
          .map((p) => p['name'])
          .toList();
      expect(names, ['ok', 'nosid', 'upper']);
    });

    test('YAML pool: invalid REALITY node dropped, others kept', () {
      const pool = '''
proxies:
  - {name: good, type: vless, server: a.example, port: 443, uuid: $_uuid, reality-opts: {public-key: $_pbk, short-id: "01"}}
  - {name: bad, type: vless, server: b.example, port: 443, uuid: $_uuid, reality-opts: {public-key: $_pbk, short-id: abc}}
  - {name: plain, type: trojan, server: c.example, port: 443, password: x}
''';
      final names =
          parseSubscriptionToProxies(pool).map((p) => p['name']).toList();
      expect(names, ['good', 'plain']);
    });
  });
}
