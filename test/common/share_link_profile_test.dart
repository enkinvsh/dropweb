import 'package:dropweb/common/share_link_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('convertShareLinkSubscriptionToMihomo', () {
    test('returns null for normal Mihomo YAML', () {
      const yaml = '''
mixed-port: 7890
proxies:
  - name: test
    type: vless
''';
      expect(convertShareLinkSubscriptionToMihomo(yaml), isNull);
    });

    test('parses a single vless share link', () {
      const link =
          'vless://uuid-1@example.com:443?type=tcp&security=tls&sni=example.com#My%20Server';
      final result = convertShareLinkSubscriptionToMihomo(link);
      expect(result, isNotNull);
      expect(result, contains('name: My Server'));
      expect(result, contains('type: vless'));
      expect(result, contains('uuid: uuid-1'));
      expect(result, contains('server: example.com'));
      expect(result, contains('🌍 VPN'));
    });

    test('parses multiple links and builds groups', () {
      const blob = '''
vless://uuid-1@a.com:443?security=tls#Server%20A
trojan://pass-1@b.com:8443?sni=b.com#Server%20B
''';
      final result = convertShareLinkSubscriptionToMihomo(blob);
      expect(result, isNotNull);
      expect(result, contains('Server A'));
      expect(result, contains('Server B'));
      expect(result, contains('proxy-groups:'));
      expect(result, contains('url-test'));
    });

    test('deduplicates identical proxy names', () {
      const blob = '''
vless://uuid-1@a.com:443#Same
vless://uuid-2@b.com:443#Same
''';
      final result = convertShareLinkSubscriptionToMihomo(blob);
      expect(result, isNotNull);
      expect(result, contains('Same'));
      expect(result, contains('Same #2'));
    });
  });

  group('parseSubscriptionToProxies', () {
    test('vless/trojan share-link blob → proxy maps with names', () {
      const blob = '''
vless://uuid-1@a.com:443?security=tls&sni=a.com#Server%20A
trojan://pass-1@b.com:8443?sni=b.com#Server%20B
''';
      final proxies = parseSubscriptionToProxies(blob);
      expect(proxies, hasLength(2));
      expect(proxies[0]['name'], 'Server A');
      expect(proxies[0]['type'], 'vless');
      expect(proxies[0]['server'], 'a.com');
      expect(proxies[0]['uuid'], 'uuid-1');
      expect(proxies[1]['name'], 'Server B');
      expect(proxies[1]['type'], 'trojan');
      expect(proxies[1]['password'], 'pass-1');
    });

    test('vless/trojan blob dedups identical names', () {
      const blob = '''
vless://uuid-1@a.com:443#Same
vless://uuid-2@b.com:443#Same
''';
      final proxies = parseSubscriptionToProxies(blob);
      expect(proxies, hasLength(2));
      final names = proxies.map((p) => p['name']).toList();
      expect(names, contains('Same'));
      expect(names, contains('Same #2'));
    });

    test('mihomo YAML with proxies: returns those proxies', () {
      const yaml = '''
proxies:
  - name: Node 1
    type: vless
    server: c.com
    port: 443
    uuid: u1
  - name: Node 2
    type: trojan
    server: d.com
    port: 8443
    password: p2
''';
      final proxies = parseSubscriptionToProxies(yaml);
      expect(proxies, hasLength(2));
      expect(proxies[0]['name'], 'Node 1');
      expect(proxies[0]['server'], 'c.com');
      expect(proxies[1]['name'], 'Node 2');
      expect(proxies[1]['password'], 'p2');
    });

    test('garbage/empty → []', () {
      expect(parseSubscriptionToProxies(''), isEmpty);
      expect(parseSubscriptionToProxies('not a config\njust text'), isEmpty);
      expect(parseSubscriptionToProxies('key: value\nfoo: bar'), isEmpty);
    });
  });
}
