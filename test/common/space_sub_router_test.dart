import 'package:dropweb/common/proxy_pin.dart';
import 'package:dropweb/common/work_mode_patch.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

// Форма подписки «SPACE VPN» без include-all: `MATCH` ведёт в «Остальные сайты»
// (первый член — узел `type: direct`, трафик по умолчанию идёт напрямую), а
// выбор выхода живёт в «Недоступные сайты». Домены IP-проверок, YouTube и
// «заблокированные» наборы правил ведут именно туда. Секреты (uuid, адреса,
// reality-ключи) заменены, имена, типы, порядок членов и фильтры сохранены.
const _poland = '🇵🇱 Польша | Poland';
const _nodes = <String>[
  'estonia-most',
  '🇳🇱 Нидерланды TEST',
  '🇳🇱 Нидерланды | Netherlands',
  '🇩🇪 Германия | Germany',
  '🇪🇪 Эстония | Estonia',
  _poland,
  '🇫🇮 Финляндия | Finland',
  '🇭🇺 Венгрия | Hungary',
  '🇺🇸 Америка | USA',
  '🇷🇺 Россия | Russia',
  'OVH TEST',
];

Map<String, dynamic> _spaceConfig() => {
      'proxies': [
        {'name': 'Без VPN', 'type': 'direct', 'udp': true},
        {'name': 'DNS-OUT', 'type': 'dns'},
        for (final name in _nodes)
          {
            'name': name,
            'type': 'vless',
            'server': 'node.example.invalid',
            'port': 443,
            'uuid': '11111111-1111-4111-8111-111111111111',
          },
      ],
      'proxy-groups': [
        {
          'name': 'Недоступные сайты',
          'type': 'select',
          'proxies': ['Любой доступный сервер', 'Без VPN', ..._nodes],
        },
        {
          'name': 'YouTube',
          'type': 'select',
          'proxies': ['Недоступные сайты', ..._nodes],
        },
        {
          'name': 'RU сайты',
          'type': 'select',
          'proxies': ['Без VPN'],
        },
        {
          'name': 'Остальные сайты',
          'type': 'select',
          'proxies': ['Без VPN', 'Недоступные сайты', ..._nodes],
        },
        {
          'name': 'Любой доступный сервер',
          'type': 'fallback',
          'exclude-filter': 'Россия|Russia|Америка|USA|Whitelist',
          'url': 'https://www.gstatic.com/generate_204',
          'interval': 300,
          'hidden': true,
          'lazy': true,
          'proxies': [
            '🇺🇸 Америка | USA',
            '🇫🇮 Финляндия | Finland',
            _poland,
            '🇪🇪 Эстония | Estonia',
          ],
        },
      ],
      'rules': [
        'DST-PORT,53,DNS-OUT',
        'DOMAIN,ipwho.is,Недоступные сайты',
        'DOMAIN,api.ip.sb,Недоступные сайты',
        'RULE-SET,youtube,YouTube',
        'RULE-SET,ru-apps,RU сайты',
        'MATCH,Остальные сайты',
      ],
    };

/// Куда в итоге уходит трафик на [host]: правило `DOMAIN` (иначе `MATCH`), затем
/// пины `select`-групп, а без пина — первый член. Ядро делает то же для `select`.
String _exitOf(
  Map<String, dynamic> cfg,
  Map<String, String> selectedMap,
  String host,
) {
  final rules = (cfg['rules'] as List).cast<String>();
  final rule = rules.firstWhere(
    (r) => r.startsWith('DOMAIN,$host,') || r.startsWith('MATCH,'),
  );
  var name = rule.split(',').last;
  final groups = {
    for (final g in cfg['proxy-groups'] as List) g['name'] as String: g as Map,
  };
  while (groups.containsKey(name)) {
    final members = (groups[name]!['proxies'] as List).cast<String>();
    name = selectedMap[name] ?? members.first;
  }
  return name;
}

void main() {
  const hub = 'Недоступные сайты';

  test('роутер — группа за «рубильником обхода», а не цель MATCH', () {
    final cfg = _spaceConfig();
    expect(detectPrimaryRouter(cfg), hub);
    // MATCH ведёт мимо роутера, поэтому «Весь трафик через VPN» осмыслен.
    expect(fullTunnelAvailable(cfg), isTrue);
  });

  test(
      'выбор страны меняет выход IP-проверки, остальной трафик остаётся прямым',
      () {
    final cfg = _spaceConfig();
    final router = detectPrimaryRouter(cfg);
    final target = countryTargetName(cfg, _poland);
    final selectedMap = resolveWorkModeSelectedMap(
      current: const {},
      mode: WorkMode.country,
      ownedRouter: router,
      countryTarget: target,
      smartGroups: const [],
      smartAvailable: false,
      routerPin: _poland,
    );

    expect(_exitOf(cfg, selectedMap, 'ipwho.is'), _poland);
    expect(_exitOf(cfg, selectedMap, 'api.ip.sb'), _poland);
    expect(_exitOf(cfg, selectedMap, 'example.com'), 'Без VPN');
  });

  test('«Весь трафик» отдаёт MATCH группе с выбором страны', () {
    final full = applyFullTunnel(_spaceConfig());
    expect((full['rules'] as List).last, 'MATCH,$hub');
  });

  test('MATCH-группа с прямым первым членом без узлов в хабе остаётся роутером',
      () {
    final cfg = _spaceConfig();
    // «Недоступные сайты» без узлов не даёт VPN-выхода: роутер — сама MATCH-цель.
    (cfg['proxy-groups'] as List)[0]['proxies'] = ['Без VPN'];
    expect(detectPrimaryRouter(cfg), 'Остальные сайты');
  });
}
