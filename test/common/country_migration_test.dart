import 'package:dropweb/common/work_mode_patch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fork-Б selectedMap migrates to a single router key', () {
    final migrated = reconcileCountrySelectedMap(
      current: {
        '🌍 VPN': 'Страна 🇩🇪',
        '⚡ Fastest': 'Страна 🇩🇪',
        '▶️ YouTube': 'Страна 🇩🇪',
        '💬 Discord': 'Страна 🇩🇪',
        'GLOBAL': 'Страна 🇩🇪',
        '🎮 Games': '🇳🇱 Amsterdam', // ручной выбор юзера — не трогаем
      },
      router: '🌍 VPN',
      target: '🇩🇪 Berlin',
    );
    expect(migrated, {
      '🌍 VPN': '🇩🇪 Berlin',
      '🎮 Games': '🇳🇱 Amsterdam',
    });
  });

  test('null target clears our keys and wires nothing', () {
    final migrated = reconcileCountrySelectedMap(
      current: {'🌍 VPN': 'Страна 🇩🇪', '🎮 Games': '🇳🇱 Amsterdam'},
      router: '🌍 VPN',
      target: null,
    );
    expect(migrated, {'🎮 Games': '🇳🇱 Amsterdam'});
  });
}
