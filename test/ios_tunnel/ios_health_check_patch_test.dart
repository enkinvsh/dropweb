import 'dart:convert';

import 'package:dropweb/common/ios_config_patch.dart';
import 'package:flutter_test/flutter_test.dart';

/// Шаблон панели: авто-группы с пробами каждые 30 с и `lazy: false`.
Map<String, dynamic> _raw() => <String, dynamic>{
      'proxies': [
        {'name': 'de1', 'type': 'vless'},
        {'name': 'nl1', 'type': 'vless'},
      ],
      'proxy-groups': [
        {
          'name': 'VPN',
          'type': 'select',
          'proxies': ['YouTube', 'de1', 'nl1'],
        },
        {
          'name': 'YouTube',
          'type': 'url-test',
          'proxies': ['de1', 'nl1'],
          'url': 'https://cp.cloudflare.com/generate_204',
          'interval': 30,
          'lazy': false,
          'tolerance': 50,
        },
        {
          'name': 'Discord',
          'type': 'fallback',
          'proxies': ['de1', 'nl1'],
          'interval': 600,
        },
        {
          'name': 'LB',
          'type': 'load-balance',
          'proxies': ['de1', 'nl1'],
          'interval': '45',
        },
        {
          'name': 'Smart',
          'type': 'smart',
          'proxies': ['de1', 'nl1'],
        },
      ],
      'proxy-providers': {
        'on': {
          'type': 'file',
          'path': 'a.yaml',
          'health-check': {
            'enable': true,
            'interval': 30,
            'lazy': false,
            'url': 'https://x',
          },
        },
        'off': {
          'type': 'file',
          'path': 'b.yaml',
          'health-check': {'enable': false, 'interval': 30},
        },
        'none': {'type': 'file', 'path': 'c.yaml'},
      },
      'dns': {
        'nameserver': ['1.1.1.1', '8.8.8.8'],
      },
      'rules': ['MATCH,VPN'],
    };

Map _group(Map<String, dynamic> c, String name) => (c['proxy-groups'] as List)
    .cast<Map>()
    .firstWhere((g) => g['name'] == name);

void main() {
  group('applyIosHealthCheckPatch', () {
    test('авто-группа 30 с → 300 и lazy', () {
      final yt = _group(applyIosHealthCheckPatch(_raw()), 'YouTube');
      expect(yt['interval'], 300);
      expect(yt['lazy'], isTrue);
      expect(yt['type'], 'url-test');
      expect(yt['tolerance'], 50);
      expect(yt['url'], 'https://cp.cloudflare.com/generate_204');
    });

    test('интервал 600 остаётся 600, lazy включается', () {
      final d = _group(applyIosHealthCheckPatch(_raw()), 'Discord');
      expect(d['interval'], 600);
      expect(d['lazy'], isTrue);
    });

    test('строковый интервал и отсутствующий интервал', () {
      final out = applyIosHealthCheckPatch(_raw());
      expect(_group(out, 'LB')['interval'], 300);
      expect(_group(out, 'Smart')['interval'], 300);
      expect(_group(out, 'Smart')['lazy'], isTrue);
    });

    test('не авто-группы и остальной конфиг не трогает', () {
      final input = _raw();
      final out = applyIosHealthCheckPatch(input);
      expect(_group(out, 'VPN'), _group(input, 'VPN'));
      expect(out['proxies'], input['proxies']);
      expect(out['dns'], input['dns']);
      expect(out['rules'], input['rules']);
    });

    test('проверка провайдера: включена, интервал ≥ 300, lazy', () {
      final p = (applyIosHealthCheckPatch(_raw())['proxy-providers']
          as Map)['on'] as Map;
      expect(p['health-check'], {
        'enable': true,
        'interval': 300,
        'lazy': true,
        'url': 'https://x',
      });
    });

    test('выключенная проверка провайдера и провайдер без неё — как были', () {
      final input = _raw();
      final providers =
          applyIosHealthCheckPatch(input)['proxy-providers'] as Map;
      final before = input['proxy-providers'] as Map;
      expect(providers['off'], before['off']);
      expect(providers['none'], before['none']);
    });

    test('вход не меняется', () {
      final input = _raw();
      final snapshot = jsonEncode(input);
      applyIosHealthCheckPatch(input);
      expect(jsonEncode(input), snapshot);
    });

    test('идемпотентна: дважды = один раз (подпись туннеля не скачет)', () {
      final once = applyIosHealthCheckPatch(_raw());
      final twice = applyIosHealthCheckPatch(once);
      expect(jsonEncode(twice), jsonEncode(once));
    });

    test('поверх lite (iOS 13–14) результат lite не меняется', () {
      final lite = applyIosLitePatch(applyIosBasePatch(_raw()));
      final out = applyIosHealthCheckPatch(lite);
      expect(jsonEncode(out), jsonEncode(lite));
    });

    test('конфиг без групп и провайдеров', () {
      expect(applyIosHealthCheckPatch({'proxies': []}), {'proxies': []});
    });
  });
}
