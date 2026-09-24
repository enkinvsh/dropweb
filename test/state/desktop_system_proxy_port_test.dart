// Regression lock for A1-1: on desktop the OS system proxy must point at the
// port the core actually listens on.
//
// ProxyManager hands the OS `ProxyState.port` = patchClashConfig.mixedPort.
// The random credentials port is the MOBILE listener only (patchRawConfig
// writes it into mixed-port on Android/iOS); pointing the desktop OS proxy at
// it sent every browser to a port nothing listened on. This test runs the
// REAL sync + patch pipeline on the (desktop) test host and asserts the
// contract ProxyManager relies on: after _setupClashConfig's provider sync,
// the patch mixed-port equals the mixed-port the core is configured with.
import 'dart:async';
import 'dart:io';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/clash/interface.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_path_provider.dart';

class _FakeCore extends ClashHandlerInterface {
  _FakeCore(this.config);
  final Map<String, dynamic> config;

  @override
  Future<Result> getConfig(String path) async => Result.success(config);

  @override
  void sendMessage(String message) {}

  @override
  void reStart() {}

  @override
  FutureOr<bool> destroy() => true;

  @override
  Future<bool> preload() async => true;
}

Future<void> _useProfile(Map<String, dynamic> providerConfig,
    {bool override = false}) async {
  SharedPreferences.setMockInitialValues({});
  final original = clashCore.clashInterface;
  clashCore.clashInterface = _FakeCore(providerConfig);
  addTearDown(() => clashCore.clashInterface = original);
  final profile = Profile.normal(label: 'desktop');
  globalState.config = Config(
    themeProps: defaultThemeProps,
    profiles: [profile],
    currentProfileId: profile.id,
    appSetting: AppSettingProps(overrideNetworkSettings: override),
  );
}

Future<void> _expectOsProxyPortMatchesCore() async {
  var patch = globalState.config.patchClashConfig;
  patch = await globalState.syncNetworkSettingsFromProvider(patch);
  final raw = await globalState.patchRawConfig(patchConfig: patch);
  // patch.mixedPort is exactly what ProxyState.port (and so the OS proxy)
  // carries.
  expect(raw['mixed-port'], patch.mixedPort);
  expect(raw['mixed-port'], isNot(globalState.currentProxyCredentials.port));
}

void main() {
  useFakePathProvider();
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    expect(Platform.isAndroid || Platform.isIOS, isFalse,
        reason: 'exercises the desktop branch of patchRawConfig');
  });

  test('provider sets its own mixed-port', () async {
    await _useProfile({'mixed-port': 7891, 'proxies': <dynamic>[]});
    await _expectOsProxyPortMatchesCore();
    expect(globalState.config.patchClashConfig.mixedPort, isNot(7891),
        reason: 'fixture must differ from the default to be meaningful');
  });

  test('provider without mixed-port', () async {
    await _useProfile({'proxies': <dynamic>[]});
    await _expectOsProxyPortMatchesCore();
  });

  test('user overrides network settings', () async {
    await _useProfile({'mixed-port': 7891, 'proxies': <dynamic>[]},
        override: true);
    await _expectOsProxyPortMatchesCore();
  });
}
