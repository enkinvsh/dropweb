import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isHaulHeaderEnabled', () {
    test('включается по 1 и true без учёта регистра и пробелов', () {
      expect(isHaulHeaderEnabled({'dropweb-haul': '1'}), isTrue);
      expect(isHaulHeaderEnabled({'dropweb-haul': ' true '}), isTrue);
      expect(isHaulHeaderEnabled({'dropweb-haul': 'TRUE'}), isTrue);
    });

    test('выключен при отсутствии заголовка или значении 0/false', () {
      expect(isHaulHeaderEnabled(null), isFalse);
      expect(isHaulHeaderEnabled(const {}), isFalse);
      expect(isHaulHeaderEnabled({'dropweb-haul': '0'}), isFalse);
      expect(isHaulHeaderEnabled({'dropweb-haul': 'false'}), isFalse);
    });
  });

  group('applyHaulPatch', () {
    test('проставляет haul: true только в VLESS+Reality TCP узлы', () {
      final rawConfig = <String, dynamic>{
        'proxies': [
          <String, dynamic>{
            'name': '🇩🇪 Германия',
            'type': 'vless',
            'server': 'de-001.meybz.asia',
            'port': 443,
            'reality-opts': <String, dynamic>{
              'public-key': 'pubKey123',
              'short-id': '4f8a01',
            },
            'smux': <String, dynamic>{
              'enabled': true,
            },
          },
          <String, dynamic>{
            'name': '⚪ White',
            'type': 'vless',
            'network': 'xhttp',
            'server': 'white.meybz.asia',
            'port': 443,
            'reality-opts': <String, dynamic>{
              'public-key': 'pubKeyWhite',
              'short-id': '00',
            },
          },
          <String, dynamic>{
            'name': '🇵🇱 Hy2',
            'type': 'hysteria2',
            'server': 'pl.meybz.asia',
            'port': 443,
          },
        ],
      };

      applyHaulPatch(rawConfig, const {'dropweb-haul': '1'});

      final proxies = rawConfig['proxies'] as List;
      expect((proxies[0] as Map)['haul'], isTrue);
      expect(((proxies[0] as Map)['smux'] as Map)['enabled'], isTrue);
      expect((proxies[1] as Map).containsKey('haul'), isFalse);
      expect((proxies[2] as Map).containsKey('haul'), isFalse);
    });

    test('не меняет прокси без заголовка dropweb-haul', () {
      final rawConfig = <String, dynamic>{
        'proxies': [
          <String, dynamic>{
            'name': '🇩🇪 Германия',
            'type': 'vless',
            'server': 'de-001.meybz.asia',
            'port': 443,
            'reality-opts': <String, dynamic>{
              'public-key': 'pubKey123',
              'short-id': '4f8a01',
            },
          },
        ],
      };

      applyHaulPatch(rawConfig, const {});
      final proxies = rawConfig['proxies'] as List;
      expect((proxies[0] as Map).containsKey('haul'), isFalse);
    });

    test('сохраняется в storeSafeProviderHeaders для магазинных сборок', () {
      final filtered = storeSafeProviderHeaders(
        const {
          'dropweb-haul': '1',
          'dropweb-cabinet': 'https://cab.example.com',
        },
        isStoreBuild: true,
      );
      expect(filtered['dropweb-haul'], '1');
      expect(filtered.containsKey('dropweb-cabinet'), isFalse);
    });
  });
}
