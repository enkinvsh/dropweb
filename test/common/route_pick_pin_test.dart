import 'package:dropweb/common/proxy_pin.dart';
import 'package:dropweb/common/work_mode_patch.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

// Шаблон как у «SPACE VPN» (TestFlight 2050000031): роутер собран через
// include-all, первым членом стоит «Авто». Явных `proxies:` у роутера нет,
// поэтому interceptLeafNodes не видит ни одного узла и цели «Страны» нет.
Map<String, dynamic> includeAllConfig() => {
      'proxies': [
        {
          'name': '🇪🇪 Эстония',
          'type': 'vless',
          'server': 'ee.example.com',
          'port': 443
        },
        {
          'name': '🇵🇱 Польша',
          'type': 'vless',
          'server': 'pl.example.com',
          'port': 443
        },
      ],
      'proxy-groups': [
        {
          'name': '🌍 VPN',
          'type': 'select',
          'proxies': ['⚡ Авто'],
          'include-all': true,
        },
        {
          'name': '⚡ Авто',
          'type': 'url-test',
          'include-all': true,
        },
      ],
      'rules': ['MATCH,🌍 VPN'],
    };

void main() {
  const router = '🌍 VPN';
  const pick = '🇵🇱 Польша';

  test('include-all роутер: цели «Страны» нет — исходное условие бага', () {
    final cfg = includeAllConfig();
    expect(detectPrimaryRouter(cfg), router);
    expect(countryTargetName(cfg, pick), isNull);
  });

  test('тап узла без цели страны применяется как Standard с пином', () {
    final cfg = includeAllConfig();
    final target = countryTargetName(cfg, pick);
    final effective = effectiveWorkModeForPick(
      mode: WorkMode.country,
      staticCountry: pick,
      countryTarget: target,
      routerPin: pick,
    );
    expect(effective.mode, WorkMode.standard);
    expect(effective.staticCountry, isNull);

    final selectedMap = resolveWorkModeSelectedMap(
      current: const {router: '⚡ Авто'},
      mode: effective.mode,
      ownedRouter: router,
      countryTarget: target,
      smartGroups: const [router],
      smartAvailable: false,
      routerPin: pick,
    );
    // Именно эту карту увидит setup.json расширения на iOS.
    expect(selectedMap[router], pick);
  });

  test('Country без цели не теряет пин юзера', () {
    final selectedMap = resolveWorkModeSelectedMap(
      current: const {router: '⚡ Авто', '🎮 Games': '🇪🇪 Эстония'},
      mode: WorkMode.country,
      ownedRouter: router,
      countryTarget: null,
      smartGroups: const [router],
      smartAvailable: false,
      routerPin: pick,
    );
    expect(selectedMap, {router: pick, '🎮 Games': '🇪🇪 Эстония'});
  });

  test('reconcile перед setup не снимает ручной пин роутера без цели', () {
    final reconciled = reconcileCountrySelectedMap(
      current: const {router: pick},
      router: router,
      target: null,
    );
    expect(reconciled, {router: pick});
  });

  test('при найденной цели страна остаётся Country', () {
    final effective = effectiveWorkModeForPick(
      mode: WorkMode.country,
      staticCountry: pick,
      countryTarget: pick,
      routerPin: pick,
    );
    expect(effective.mode, WorkMode.country);
    expect(effective.staticCountry, pick);
  });
}
