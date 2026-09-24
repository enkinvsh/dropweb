// Regression (A1-4): a failed profile read must be FAIL-CLOSED on the start
// path. The core answers "" when it cannot read/parse the profile;
// ClashLibHandler.getConfig (service isolate / tile quickStart) now frees the
// native strings and throws on "" exactly like ClashCore.getConfig (main
// isolate) throws on an error Result. getSetupParams must then propagate the
// error (lib/main.dart tile onStart catches it: logs, tips "Start error",
// vpn.stop(), exit(0)) instead of building a rule-less config that routes
// every flow DIRECT.
//
// ClashLibHandler itself needs libclash.so (DynamicLibrary.open), which the
// host VM cannot load, so this drives the shared contract through the
// main-isolate ClashCore with a core that reports the read failure.
import 'dart:async';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/clash/interface.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_path_provider.dart';

class _FailedReadCore extends ClashHandlerInterface {
  @override
  Future<Result> getConfig(String path) async =>
      Result.error('Failed to read profile config: $path');

  @override
  void sendMessage(String message) {}

  @override
  void reStart() {}

  @override
  FutureOr<bool> destroy() => true;

  @override
  Future<bool> preload() async => true;
}

void main() {
  useFakePathProvider();
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed profile read aborts setup instead of a rule-less config',
      () async {
    SharedPreferences.setMockInitialValues({});
    final original = clashCore.clashInterface;
    clashCore.clashInterface = _FailedReadCore();
    addTearDown(() => clashCore.clashInterface = original);

    final profile = Profile.normal(label: 'probe');
    globalState.config = Config(
      themeProps: defaultThemeProps,
      profiles: [profile],
      currentProfileId: profile.id,
    );

    // Same call the tile path makes (tun disabled, as in main.dart onStart).
    await expectLater(
      globalState.getSetupParams(
        pathConfig: globalState.config.patchClashConfig.copyWith.tun(
          enable: false,
        ),
      ),
      throwsA(contains('Failed to read profile config')),
    );
  });
}
