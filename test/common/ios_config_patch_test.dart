import 'package:dropweb/common/ios_config_patch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iosNeedsLiteCore', () {
    test('iOS 13 and 14 need the lite core', () {
      expect(iosNeedsLiteCore('13.7'), isTrue);
      expect(iosNeedsLiteCore('14.8.1'), isTrue);
    });
    test('iOS 15 and later use the normal core', () {
      expect(iosNeedsLiteCore('15.0'), isFalse);
      expect(iosNeedsLiteCore('16.7.16'), isFalse);
      expect(iosNeedsLiteCore('27.0'), isFalse);
    });
    test('an unparsable version falls back to lite (fits every device)', () {
      expect(iosNeedsLiteCore(''), isTrue);
      expect(iosNeedsLiteCore('unknown'), isTrue);
    });
  });

  group('applyIosBasePatch', () {
    Map<String, dynamic> raw() => <String, dynamic>{
          'mixed-port': 41234,
          'port': 7890,
          'socks-port': 7891,
          'redir-port': 7892,
          'tproxy-port': 7893,
          'authentication': ['u:p'],
          'external-controller': '127.0.0.1:9090',
          'external-ui': 'ui',
          'find-process-mode': 'strict',
          'profile': {'store-selected': true, 'store-fake-ip': true},
          'proxy-groups': [
            {
              'name': 'G',
              'type': 'select',
              'proxies': ['A']
            }
          ],
        };

    test('turns off listeners, controller, process lookup and keep-alive', () {
      final out = applyIosBasePatch(raw());
      for (final key in [
        'mixed-port',
        'port',
        'socks-port',
        'redir-port',
        'tproxy-port'
      ]) {
        expect(out[key], 0, reason: key);
      }
      expect(out.containsKey('authentication'), isFalse);
      expect(out['external-controller'], '');
      expect(out.containsKey('external-ui'), isFalse);
      expect(out['find-process-mode'], 'off');
      expect(out['disable-keep-alive'], isTrue);
      expect(out['profile'], {'store-selected': false, 'store-fake-ip': false});
    });

    test('does not touch groups and does not mutate the input', () {
      final input = raw();
      final out = applyIosBasePatch(input);
      expect(out['proxy-groups'], input['proxy-groups']);
      expect(input['mixed-port'], 41234);
      expect(input['profile'], {'store-selected': true, 'store-fake-ip': true});
    });

    test('drops inbound servers the slim iOS core does not include', () {
      final input = raw()
        ..['listeners'] = [
          {'name': 'in', 'type': 'vless', 'port': 1}
        ]
        ..['tuic-server'] = {'enable': true}
        ..['ss-config'] = 'ss://x'
        ..['vmess-config'] = 'vmess://x'
        ..['tunnels'] = ['tcp,127.0.0.1:1,1.1.1.1:53,DIRECT'];
      final out = applyIosBasePatch(input);
      for (final key in [
        'listeners',
        'tuic-server',
        'ss-config',
        'vmess-config',
        'tunnels'
      ]) {
        expect(out.containsKey(key), isFalse, reason: key);
        expect(input.containsKey(key), isTrue, reason: key);
      }
    });

    test('forces the user-space mips TUN stack', () {
      final input = raw()
        ..['tun'] = <String, dynamic>{'enable': true, 'stack': 'mixed'};
      final out = applyIosBasePatch(input);
      expect(out['tun'], {'enable': true, 'stack': 'mips'});
      expect(input['tun']['stack'], 'mixed');
      expect(applyIosBasePatch(raw())['tun'], {'stack': 'mips'});
    });
  });

  group('applyIosLitePatch', () {
    Map<String, dynamic> raw() => <String, dynamic>{
          'proxies': [
            {
              'name': 'de1',
              'type': 'vless',
              'smux': {'enabled': true, 'protocol': 'smux'},
            },
            {'name': 'nl1', 'type': 'vless'},
          ],
          'proxy-groups': [
            {
              'name': 'VPN',
              'type': 'select',
              'proxies': ['Auto', 'Умный', 'de1', 'nl1'],
            },
            {
              'name': 'Auto',
              'type': 'fallback',
              'proxies': ['de1', 'nl1'],
              'url': 'https://cp.cloudflare.com',
              'interval': 30,
            },
            {
              'name': 'Умный',
              'type': 'url-test',
              'proxies': ['de1', 'nl1'],
              'interval': '600',
              'tolerance': 100,
            },
            {
              'name': 'YouTube',
              'type': 'url-test',
              'proxies': ['de1', 'nl1'],
              'url': 'https://www.youtube.com',
              'interval': 60,
              'tolerance': 50,
              'lazy': false,
              'timeout': 2000,
              'icon': 'yt.png',
            },
          ],
          'proxy-providers': {
            'p': {
              'type': 'http',
              'url': 'https://x',
              'health-check': {'enable': true, 'interval': 60},
            },
          },
          'rule': ['MATCH,VPN'],
        };

    List<Map> groups(Map<String, dynamic> c) =>
        (c['proxy-groups'] as List).cast<Map>();
    Map group(Map<String, dynamic> c, String name) =>
        groups(c).firstWhere((g) => g['name'] == name);

    test('auto groups inside the primary router stay auto, slowed and lazy',
        () {
      final out = applyIosLitePatch(raw());
      expect(group(out, 'Auto')['type'], 'fallback');
      expect(group(out, 'Auto')['interval'], 300);
      expect(group(out, 'Auto')['lazy'], isTrue);
      expect(group(out, 'Умный')['type'], 'url-test');
      expect(group(out, 'Умный')['interval'], 600);
    });

    test('other auto groups become select without health-check fields', () {
      final yt = group(applyIosLitePatch(raw()), 'YouTube');
      expect(yt['type'], 'select');
      for (final key in ['url', 'interval', 'tolerance', 'lazy', 'timeout']) {
        expect(yt.containsKey(key), isFalse, reason: key);
      }
      expect(yt['proxies'], ['de1', 'nl1']);
      expect(yt['icon'], 'yt.png');
    });

    test('provider health-check is off', () {
      final out = applyIosLitePatch(raw());
      expect(out['proxy-providers']['p']['health-check']['enable'], isFalse);
    });

    test('smux multiplexing is off', () {
      final input = raw();
      final proxies = (applyIosLitePatch(input)['proxies'] as List).cast<Map>();
      expect(proxies[0]['smux'], {'enabled': false, 'protocol': 'smux'});
      expect(proxies[1].containsKey('smux'), isFalse);
      expect((input['proxies'] as List).first['smux']['enabled'], isTrue);
    });

    test('DNS asks one server per list instead of all at once', () {
      final input = raw()
        ..['dns'] = <String, dynamic>{
          'enable': true,
          'nameserver': [
            'https://1.1.1.1/dns-query',
            'https://8.8.8.8/dns-query',
          ],
          'default-nameserver': ['tls://77.88.8.8', 'tls://77.88.8.1'],
          'proxy-server-nameserver': ['tls://77.88.8.8'],
          'nameserver-policy': {
            '+.yandex.ru': ['tls://77.88.8.8', 'https://77.88.8.8/dns-query'],
            'geosite:cn': 'https://223.5.5.5/dns-query',
          },
        };
      final dns = applyIosLitePatch(input)['dns'] as Map;
      expect(dns['enable'], isTrue);
      expect(dns['nameserver'], ['https://1.1.1.1/dns-query']);
      expect(dns['default-nameserver'], ['tls://77.88.8.8']);
      expect(dns['proxy-server-nameserver'], ['tls://77.88.8.8']);
      expect(dns.containsKey('fallback'), isFalse);
      expect(dns['nameserver-policy'], {
        '+.yandex.ru': ['tls://77.88.8.8'],
        'geosite:cn': 'https://223.5.5.5/dns-query',
      });
      expect((input['dns'] as Map)['nameserver'], hasLength(2));
    });

    test('rules untouched, input not mutated', () {
      final input = raw();
      final out = applyIosLitePatch(input);
      expect(out['rule'], ['MATCH,VPN']);
      expect(group(input, 'YouTube')['type'], 'url-test');
      expect(input['proxy-providers']['p']['health-check']['enable'], isTrue);
    });

    test('no router detected: first group is the router', () {
      final input = raw()..remove('rule');
      final out = applyIosLitePatch(input);
      expect(group(out, 'Auto')['type'], 'fallback');
      expect(group(out, 'YouTube')['type'], 'select');
    });

    test('config without groups passes through', () {
      expect(applyIosLitePatch({'proxies': []}), {'proxies': []});
    });
  });

  group('toIosExtensionConfig', () {
    Map<String, dynamic> raw() => <String, dynamic>{
          'proxy-providers': {
            'nodes': {
              'type': 'http',
              'url': 'https://sub',
              'interval': 3600,
              'path': '/g/providers/nodes.yaml',
              'health-check': {'enable': false},
            },
          },
          'rule-providers': {
            'ru': {
              'type': 'http',
              'behavior': 'domain',
              'format': 'mrs',
              'url': 'https://r/ru.mrs',
              'interval': 86400,
              'path': '/g/providers/ru.mrs',
            },
            'missing': {
              'type': 'http',
              'behavior': 'domain',
              'url': 'https://r/m.mrs',
              'path': '/g/providers/m.mrs',
            },
            'inline': {
              'type': 'inline',
              'payload': ['DOMAIN,a.com']
            },
          },
        };
    bool exists(String p) => p != '/g/providers/m.mrs';

    test('downloaded http providers become file providers', () {
      final out = toIosExtensionConfig(raw(), fileExists: exists);
      expect(out.config['proxy-providers']['nodes'], {
        'type': 'file',
        'path': '/g/providers/nodes.yaml',
        'health-check': {'enable': false},
      });
      expect(out.config['rule-providers']['ru'], {
        'type': 'file',
        'behavior': 'domain',
        'format': 'mrs',
        'path': '/g/providers/ru.mrs',
      });
    });

    test('missing files stay http and are reported', () {
      final out = toIosExtensionConfig(raw(), fileExists: exists);
      expect(out.config['rule-providers']['missing']['type'], 'http');
      expect(out.stillRemote, ['missing']);
    });

    test('non-http providers untouched', () {
      final out = toIosExtensionConfig(raw(), fileExists: exists);
      expect(out.config['rule-providers']['inline'], {
        'type': 'inline',
        'payload': ['DOMAIN,a.com']
      });
    });
  });
}
