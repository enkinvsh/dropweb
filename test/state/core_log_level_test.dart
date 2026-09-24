// The core log-level is app-owned: logging off → `error` whatever the
// subscription asks (a provider `info` pushed a line per connection through
// FFI only for Dart to drop it); logging on («Журналирование») → `info`, or
// `debug` from the developer setting. Setup (patchRawConfig) and live updates
// (updateParamsProvider) must agree, or a mode switch would flip the level.
import 'dart:async';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/clash/interface.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

Future<String?> _patchedLogLevel({
  required bool openLogs,
  String? providerLevel,
  LogLevel devLevel = LogLevel.error,
}) async {
  SharedPreferences.setMockInitialValues({});
  final original = clashCore.clashInterface;
  clashCore.clashInterface = _FakeCore({
    if (providerLevel != null) 'log-level': providerLevel,
    'proxies': <dynamic>[],
  });
  addTearDown(() => clashCore.clashInterface = original);
  final profile = Profile.normal(label: 'log-level');
  globalState.config = Config(
    themeProps: defaultThemeProps,
    profiles: [profile],
    currentProfileId: profile.id,
    appSetting: AppSettingProps(openLogs: openLogs),
    patchClashConfig: ClashConfig(logLevel: devLevel),
  );
  final raw = await globalState.patchRawConfig(
    patchConfig: globalState.config.patchClashConfig,
  );
  return raw['log-level'] as String?;
}

void main() {
  useFakePathProvider();
  TestWidgetsFlutterBinding.ensureInitialized();

  group('coreLogLevel', () {
    test('logging off pins error for every developer setting', () {
      for (final level in LogLevel.values) {
        expect(coreLogLevel(openLogs: false, requested: level), LogLevel.error,
            reason: '$level');
      }
    });

    test('logging on gives info, debug only on request', () {
      for (final level in LogLevel.values) {
        expect(
          coreLogLevel(openLogs: true, requested: level),
          level == LogLevel.debug ? LogLevel.debug : LogLevel.info,
          reason: '$level',
        );
      }
    });
  });

  group('patchRawConfig log-level', () {
    test('provider info is capped to error while logging is off', () async {
      expect(await _patchedLogLevel(openLogs: false, providerLevel: 'info'),
          'error');
    });

    test('absent provider level (core default info) is capped too', () async {
      expect(await _patchedLogLevel(openLogs: false), 'error');
    });

    test('logging on runs the core at info', () async {
      expect(await _patchedLogLevel(openLogs: true, providerLevel: 'silent'),
          'info');
    });

    test('logging on + developer debug runs the core at debug', () async {
      expect(
        await _patchedLogLevel(
          openLogs: true,
          providerLevel: 'info',
          devLevel: LogLevel.debug,
        ),
        'debug',
      );
    });
  });

  test('live updates carry the same level and follow the logging toggle',
      () async {
    SharedPreferences.setMockInitialValues({});
    // Providers seed from globalState.config.
    globalState.config = const Config(
      themeProps: defaultThemeProps,
      appSetting: AppSettingProps(openLogs: false),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(updateParamsProvider).logLevel, LogLevel.error);

    container
        .read(appSettingProvider.notifier)
        .updateState((s) => s.copyWith(openLogs: true));
    expect(container.read(updateParamsProvider).logLevel, LogLevel.info);
  });
}
