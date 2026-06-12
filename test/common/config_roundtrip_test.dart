// Field-coverage round-trip / drift-lock for the config mirror.
//
// The app keeps a dual source of truth for `Config`: 13 Riverpod slice
// providers (lib/providers/config.dart) each seed themselves from
// `globalState.config` in their `build()`, and `configState`
// (lib/providers/state.dart) re-aggregates those 13 slices back into a
// single `Config`. The mirror is owned by `ConfigRepository`
// (lib/common/config_repository.dart) behind the `globalState.config`
// getter/setter.
//
// This test locks the field list across BOTH halves of that mirror:
//
//   1. Coverage guard — build a Config whose EVERY top-level field differs
//      from the default Config, enumerated via `toJson().keys`. Adding a new
//      field to `Config` without giving it a non-default value here FAILS the
//      guard, forcing the author to acknowledge the new field.
//
//   2. Round-trip — seed `globalState.config` with that non-default Config
//      (the same field the 13 providers read in `build()`), then read
//      `configStateProvider` (the same aggregation the app uses) and assert
//      deep equality. A field added to `Config` but forgotten in a slice
//      provider OR in `configState` aggregation FAILS this — the round-tripped
//      value falls back to the default and no longer matches the seed.
//
// Cross-links: lib/common/config_repository.dart, lib/providers/config.dart,
// lib/providers/state.dart (configState), lib/common/mixin.dart.

import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A Config with a NON-DEFAULT value for every one of its 13 top-level
  // fields. Each nested prop flips a single field away from its default so the
  // top-level field serialises differently from the default Config.
  final nonDefaultConfig = Config(
    appSetting: defaultAppSettingProps.copyWith(openLogs: true, locale: 'ru'),
    profiles: const [
      Profile(
        id: 'rt-profile-id',
        label: 'roundtrip',
        url: 'https://example.test/sub',
        autoUpdateDuration: Duration(hours: 12),
      ),
    ],
    hotKeyActions: const [
      HotKeyAction(action: HotAction.start, key: 42),
    ],
    currentProfileId: 'rt-profile-id',
    overrideDns: true,
    networkProps: defaultNetworkProps.copyWith(systemProxy: true),
    vpnProps: defaultVpnProps.copyWith(enable: false),
    themeProps: defaultThemeProps.copyWith(pureBlack: false),
    proxiesStyle: defaultProxiesStyle.copyWith(type: ProxiesType.tab),
    windowProps: defaultWindowProps.copyWith(width: 999),
    patchClashConfig: defaultClashConfig.copyWith(allowLan: true),
    scriptProps: const ScriptProps(currentId: 'rt-script'),
  );

  // The app's default Config (matches the fallback in GlobalState.init()).
  const defaultConfig = Config(themeProps: defaultThemeProps);

  group('config mirror field-coverage', () {
    test('fixture sets a non-default value for EVERY Config field', () {
      final fixtureJson = nonDefaultConfig.toJson();
      final defaultJson = defaultConfig.toJson();

      // Every top-level field present in the default Config must be covered
      // (and differ) by the fixture. If a new field is added to Config, this
      // fails until the fixture above sets a distinct value for it.
      for (final key in defaultJson.keys) {
        expect(
          fixtureJson.containsKey(key),
          isTrue,
          reason: 'fixture is missing Config field "$key" — add a '
              'non-default value for it in nonDefaultConfig',
        );
        expect(
          fixtureJson[key],
          isNot(equals(defaultJson[key])),
          reason: 'Config field "$key" still holds its default value in the '
              'fixture — pick a non-default value so the round-trip can '
              'actually detect drift for this field',
        );
      }
    });

    test('non-default config survives the live provider seed + aggregation',
        () {
      // Seed the single mirror the 13 slice providers read in build().
      globalState.config = nonDefaultConfig;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Aggregate back through the exact provider the app uses.
      final roundTripped = container.read(configStateProvider);

      // Per-field comparison first for a precise failure message...
      final inputJson = nonDefaultConfig.toJson();
      final outputJson = roundTripped.toJson();
      for (final key in inputJson.keys) {
        expect(
          outputJson[key],
          equals(inputJson[key]),
          reason: 'Config field "$key" did not survive the round-trip — it is '
              'missing from a slice provider build() or from configState '
              'aggregation in lib/providers/state.dart',
        );
      }

      // ...then full freezed deep-equality as the authoritative lock.
      expect(roundTripped, equals(nonDefaultConfig));
    });
  });
}
