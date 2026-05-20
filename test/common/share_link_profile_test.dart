import 'package:dropweb/common/share_link_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('convertShareLinkSubscriptionToMihomo', () {
    test('returns null for normal Mihomo YAML', () {
      const yaml = '''
mixed-port: 7890
mode: rule
proxies:
  - name: foo
    type: vless
    server: example.com
    port: 443
proxy-groups:
  - name: 🌍 VPN
    type: select
    proxies: [foo]
rules:
  - MATCH,🌍 VPN
''';
      expect(convertShareLinkSubscriptionToMihomo(yaml), isNull);
    });

    test('returns null for arbitrary plain text with no share links', () {
      expect(
        convertShareLinkSubscriptionToMihomo('hello\nworld\n# comment'),
        isNull,
      );
    });

    test('returns null when no valid nodes can be parsed', () {
      expect(
        convertShareLinkSubscriptionToMihomo('vless://not-a-uri\n'),
        isNull,
      );
    });

    test('converts single vless reality line', () {
      const link =
          'vless://11111111-2222-3333-4444-555555555555@1.2.3.4:443'
          '?type=tcp&security=reality&pbk=pubkey&sid=sid1&sni=example.com'
          '&flow=xtls-rprx-vision&fp=chrome#Node%201';
      final yaml = convertShareLinkSubscriptionToMihomo(link);
      expect(yaml, isNotNull);
      expect(yaml, contains('proxies:'));
      expect(yaml, contains('type: vless'));
      expect(yaml, contains('server: 1.2.3.4'));
      expect(yaml, contains('port: 443'));
      expect(yaml, contains('uuid: 11111111-2222-3333-4444-555555555555'));
      expect(yaml, contains('network: tcp'));
      expect(yaml, contains('tls: true'));
      expect(yaml, contains('servername: example.com'));
      expect(yaml, contains('flow: xtls-rprx-vision'));
      expect(yaml, contains('client-fingerprint: chrome'));
      expect(yaml, contains('reality-opts:'));
      expect(yaml, contains('public-key: pubkey'));
      expect(yaml, contains('short-id: sid1'));
      expect(yaml, contains('Node 1'));
      expect(yaml, contains('proxy-groups:'));
      expect(yaml, contains('🌍 VPN'));
      expect(yaml, contains('⚡ Fastest'));
      expect(yaml, contains('rules:'));
      expect(yaml, contains('MATCH,🌍 VPN'));
      expect(yaml!.contains('🌀 Cascade'), isFalse);
    });

    test('converts trojan line with sni', () {
      const link =
          'trojan://secretPass@trojan.example.com:8443'
          '?type=tcp&security=tls&sni=trojan.example.com&fp=firefox#Tro%201';
      final yaml = convertShareLinkSubscriptionToMihomo(link);
      expect(yaml, isNotNull);
      expect(yaml, contains('type: trojan'));
      expect(yaml, contains('password: secretPass'));
      expect(yaml, contains('server: trojan.example.com'));
      expect(yaml, contains('port: 8443'));
      expect(yaml, contains('sni: trojan.example.com'));
      expect(yaml, contains('client-fingerprint: firefox'));
    });

    test('treats Xray type=raw as network tcp', () {
      const link =
          'vless://aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee@host.example:443'
          '?type=raw&security=reality&pbk=pk&sid=sid&sni=host.example#R';
      final yaml = convertShareLinkSubscriptionToMihomo(link)!;
      expect(yaml, contains('network: tcp'));
    });

    test('skips blank lines and # comments, ignores malformed lines', () {
      const body = '''
# header comment

vless://uuid-1111@1.1.1.1:443?type=tcp&security=reality&pbk=pk&sid=s&sni=x#One

not a link
trojan://pw@2.2.2.2:443?type=tcp&security=tls&sni=y#Two
vless://garbage
''';
      final yaml = convertShareLinkSubscriptionToMihomo(body)!;
      expect(yaml, contains('One'));
      expect(yaml, contains('Two'));
      // Two valid nodes => names appear in 🌍 VPN group list at least once
      expect('One'.allMatches(yaml).length >= 1, isTrue);
    });

    test('deduplicates identical names with numeric suffix', () {
      const body = '''
vless://u1@a.example:443?type=tcp&security=reality&pbk=pk&sid=s&sni=a#Same
vless://u2@b.example:443?type=tcp&security=reality&pbk=pk&sid=s&sni=b#Same
''';
      final yaml = convertShareLinkSubscriptionToMihomo(body)!;
      expect(yaml, contains('Same'));
      expect(yaml, contains('Same #2'));
    });

    test('uses scheme host:port fallback when fragment empty', () {
      const link =
          'trojan://pw@1.2.3.4:443?type=tcp&security=tls&sni=x';
      final yaml = convertShareLinkSubscriptionToMihomo(link)!;
      expect(yaml, contains('trojan 1.2.3.4:443'));
    });

    test('groups list only 🌍 VPN, ⚡ Fastest, and DIRECT in VPN', () {
      const link =
          'vless://u@h.example:443?type=tcp&security=reality&pbk=pk&sid=s&sni=h#N';
      final yaml = convertShareLinkSubscriptionToMihomo(link)!;
      expect(yaml, contains('🌍 VPN'));
      expect(yaml, contains('⚡ Fastest'));
      expect(yaml, contains('DIRECT'));
      expect(yaml.contains('🌀 Cascade'), isFalse);
      expect(yaml.contains('📶 First Available'), isFalse);
      expect(yaml.contains('rule-providers'), isFalse);
    });
  });
}
