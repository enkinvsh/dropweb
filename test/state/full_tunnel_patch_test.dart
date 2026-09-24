// Full tunnel is wired into the real config build: the profile flag decides
// whether patchRawConfig hands the core the provider's catch-all or the VPN.
import 'dart:async';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/clash/interface.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_path_provider.dart';

class _FakeCore extends ClashHandlerInterface {
  @override
  Future<Result> getConfig(String path) async => Result.success(<String, dynamic>{
        'proxies': [
          {'name': '🇩🇪 Германия', 'type': 'vless'},
        ],
        'proxy-groups': [
          {
            'name': '🌍 VPN',
            'type': 'select',
            'proxies': ['🇩🇪 Германия'],
          },
          {
            'name': '♻️ DIRECT',
            'type': 'select',
            'proxies': ['DIRECT'],
          },
        ],
        // The core hands the rules back under `rule`.
        'rule': [
          'DOMAIN-SUFFIX,youtube.com,🌍 VPN',
          'IP-CIDR,17.0.0.0/8,♻️ DIRECT',
          'MATCH,♻️ DIRECT',
        ],
      });

  @override
  void sendMessage(String message) {}

  @override
  void reStart() {}

  @override
  FutureOr<bool> destroy() => true;

  @override
  Future<bool> preload() async => true;
}

Future<List<dynamic>> _patchedRules({required bool fullTunnel}) async {
  SharedPreferences.setMockInitialValues({});
  final original = clashCore.clashInterface;
  clashCore.clashInterface = _FakeCore();
  addTearDown(() => clashCore.clashInterface = original);
  final profile =
      Profile.normal(label: 'full-tunnel').copyWith(fullTunnel: fullTunnel);
  globalState.config = Config(
    themeProps: defaultThemeProps,
    profiles: [profile],
    currentProfileId: profile.id,
  );
  final raw = await globalState.patchRawConfig(
    patchConfig: globalState.config.patchClashConfig,
  );
  return raw['rule'] as List<dynamic>;
}

void main() {
  useFakePathProvider();
  TestWidgetsFlutterBinding.ensureInitialized();

  test('off: the provider catch-all reaches the core untouched', () async {
    expect(await _patchedRules(fullTunnel: false), [
      'DOMAIN-SUFFIX,youtube.com,🌍 VPN',
      'IP-CIDR,17.0.0.0/8,♻️ DIRECT',
      'MATCH,♻️ DIRECT',
    ]);
  });

  test('on: only the catch-all moves to the VPN', () async {
    expect(await _patchedRules(fullTunnel: true), [
      'DOMAIN-SUFFIX,youtube.com,🌍 VPN',
      'IP-CIDR,17.0.0.0/8,♻️ DIRECT',
      'MATCH,🌍 VPN',
    ]);
  });
}
