// W3.3 — tolerant decode of unknown/future enum values.
//
// A single persisted enum value that no longer exists in the current binary
// (a future value written by a newer build, or a value removed across an
// upgrade) must NOT throw out of the generated `$enumDecode` and quarantine
// the WHOLE Config, wiping every unrelated setting. Instead each *safe*
// enum field decodes an unknown token to its own declared default while all
// sibling data survives.
//
// Strategy: start from a real `toJson()` of a Config/ClashConfig fixture with
// distinctive sentinel values, deep-clone it, poison exactly ONE enum field
// with `__unknown_future_value__`, decode via the app's real entry point
// (`Config.compatibleFromJson` / `ClashConfig.fromJson`), then assert
//   (a) the poisoned field fell back to its documented default, and
//   (b) unrelated sentinel fields survived intact.
//
// Semantic discriminators (OverrideRuleType, HotAction/KeyboardModifier,
// GroupType) are INTENTIONALLY excluded — silently remapping them would run
// the wrong behavior, so they are left to item-level recovery.
//
// Cross-links: lib/models/config.dart, lib/models/clash_config.dart,
// lib/enum/enum.dart, lib/common/preferences.dart (quarantine wrapper).

import 'dart:convert';
import 'dart:io';

import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter/material.dart' show ThemeMode, DynamicSchemeVariant;
import 'package:flutter_test/flutter_test.dart';

const _unknown = '__unknown_future_value__';

Map<String, Object?> _clone(Map<String, Object?> json) =>
    (jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>();

/// Poison a nested JSON path (dot-separated) with an unknown enum token.
void _poison(Map<String, Object?> json, String path) {
  final parts = path.split('.');
  Map current = json;
  for (var i = 0; i < parts.length - 1; i++) {
    current = current[parts[i]] as Map;
  }
  current[parts.last] = _unknown;
}

void main() {
  // Config fixture: distinctive sentinels on fields that MUST survive when a
  // sibling enum is poisoned.
  final baseConfig = Config(
    themeProps: defaultThemeProps.copyWith(primaryColor: 0xFF123456),
    appSetting:
        defaultAppSettingProps.copyWith(testUrl: 'https://sentinel.example/'),
    networkProps: defaultNetworkProps.copyWith(autoSetSystemDns: false),
    vpnProps: defaultVpnProps.copyWith(
      accessControl: defaultAccessControl.copyWith(acceptList: ['sentinel.pkg']),
    ),
    proxiesStyle: defaultProxiesStyle.copyWith(iconMap: const {'k': 'v'}),
    patchClashConfig: defaultClashConfig.copyWith(
      mixedPort: 1234,
      tun: defaultTun.copyWith(device: 'sentinel-tun'),
      dns: defaultDns.copyWith(listen: '9.9.9.9:53'),
    ),
  );
  final baseConfigJson = baseConfig.toJson();

  // (json path, human label, assertion on decoded Config)
  final configCases = <(String, String, void Function(Config))>[
    (
      'vpnProps.accessControl.mode',
      'AccessControl.mode → rejectSelected',
      (c) => expect(
          c.vpnProps.accessControl.mode, AccessControlMode.rejectSelected),
    ),
    (
      'vpnProps.accessControl.sort',
      'AccessControl.sort → none',
      (c) => expect(c.vpnProps.accessControl.sort, AccessSortType.none),
    ),
    (
      'networkProps.routeMode',
      'NetworkProps.routeMode → config',
      (c) => expect(c.networkProps.routeMode, RouteMode.config),
    ),
    (
      'proxiesStyle.type',
      'ProxiesStyle.type → list',
      (c) => expect(c.proxiesStyle.type, ProxiesType.list),
    ),
    (
      'proxiesStyle.sortType',
      'ProxiesStyle.sortType → none',
      (c) => expect(c.proxiesStyle.sortType, ProxiesSortType.none),
    ),
    (
      'proxiesStyle.layout',
      'ProxiesStyle.layout → standard',
      (c) => expect(c.proxiesStyle.layout, ProxiesLayout.standard),
    ),
    (
      'proxiesStyle.cardType',
      'ProxiesStyle.cardType → expand',
      (c) => expect(c.proxiesStyle.cardType, ProxyCardType.expand),
    ),
    (
      'themeProps.themeMode',
      'ThemeProps.themeMode → dark',
      (c) => expect(c.themeProps.themeMode, ThemeMode.dark),
    ),
    (
      'themeProps.schemeVariant',
      'ThemeProps.schemeVariant → fidelity',
      (c) => expect(c.themeProps.schemeVariant, DynamicSchemeVariant.fidelity),
    ),
    (
      'patchClashConfig.mode',
      'ClashConfig.mode → rule',
      (c) => expect(c.patchClashConfig.mode, Mode.rule),
    ),
    (
      'patchClashConfig.log-level',
      'ClashConfig.logLevel → error',
      (c) => expect(c.patchClashConfig.logLevel, LogLevel.error),
    ),
    (
      'patchClashConfig.geodata-loader',
      'ClashConfig.geodataLoader → memconservative',
      (c) => expect(
          c.patchClashConfig.geodataLoader, GeodataLoader.memconservative),
    ),
    (
      'patchClashConfig.external-controller',
      'ClashConfig.externalController → close',
      (c) => expect(c.patchClashConfig.externalController,
          ExternalControllerStatus.close),
    ),
    (
      'patchClashConfig.tun.stack',
      'Tun.stack → mixed',
      (c) => expect(c.patchClashConfig.tun.stack, TunStack.mixed),
    ),
    (
      'patchClashConfig.dns.enhanced-mode',
      'Dns.enhancedMode → fakeIp',
      (c) => expect(c.patchClashConfig.dns.enhancedMode, DnsMode.fakeIp),
    ),
    // Already-hardened fields kept as regression coverage.
    (
      'proxiesStyle.iconStyle',
      'ProxiesStyle.iconStyle → icon (regression)',
      (c) => expect(c.proxiesStyle.iconStyle, ProxiesIconStyle.icon),
    ),
    (
      'patchClashConfig.find-process-mode',
      'ClashConfig.findProcessMode → always (regression)',
      (c) => expect(c.patchClashConfig.findProcessMode, FindProcessMode.always),
    ),
  ];

  group('Config.compatibleFromJson tolerates unknown enum values', () {
    for (final (path, label, assertField) in configCases) {
      test('$label — unknown at "$path" decodes + siblings survive', () {
        final poisoned = _clone(baseConfigJson);
        _poison(poisoned, path);

        final decoded = Config.compatibleFromJson(poisoned);

        // (a) poisoned field fell back to its documented default.
        assertField(decoded);

        // (b) unrelated data across the whole Config survived — proving the
        // single unknown enum did NOT quarantine/reset everything.
        expect(decoded.appSetting.testUrl, 'https://sentinel.example/');
        expect(decoded.patchClashConfig.mixedPort, 1234);
        expect(decoded.vpnProps.accessControl.acceptList, ['sentinel.pkg']);
        expect(decoded.themeProps.primaryColor, 0xFF123456);
        expect(decoded.networkProps.autoSetSystemDns, false);
        // Tun/Dns siblings survive even though those sub-objects carry a
        // best-effort catch wrapper (which would otherwise wipe them).
        expect(decoded.patchClashConfig.tun.device, 'sentinel-tun');
        expect(decoded.patchClashConfig.dns.listen, '9.9.9.9:53');
      });
    }
  });

  // Legacy standalone ClashConfig persistence (preferences.getClashConfig →
  // ClashConfig.fromJson). Same hardening must hold when the clash config is
  // decoded on its own, not just nested inside Config.
  final baseClash = defaultClashConfig.copyWith(
    mixedPort: 4321,
    tun: defaultTun.copyWith(device: 'legacy-tun'),
    dns: defaultDns.copyWith(listen: '4.4.4.4:53'),
  );
  final baseClashJson = baseClash.toJson();

  final clashCases = <(String, String, void Function(ClashConfig))>[
    (
      'mode',
      'ClashConfig.mode → rule',
      (c) => expect(c.mode, Mode.rule),
    ),
    (
      'log-level',
      'ClashConfig.logLevel → error',
      (c) => expect(c.logLevel, LogLevel.error),
    ),
    (
      'geodata-loader',
      'ClashConfig.geodataLoader → memconservative',
      (c) => expect(c.geodataLoader, GeodataLoader.memconservative),
    ),
    (
      'external-controller',
      'ClashConfig.externalController → close',
      (c) => expect(c.externalController, ExternalControllerStatus.close),
    ),
    (
      'tun.stack',
      'Tun.stack → mixed',
      (c) => expect(c.tun.stack, TunStack.mixed),
    ),
    (
      'dns.enhanced-mode',
      'Dns.enhancedMode → fakeIp',
      (c) => expect(c.dns.enhancedMode, DnsMode.fakeIp),
    ),
  ];

  group('legacy ClashConfig.fromJson tolerates unknown enum values', () {
    for (final (path, label, assertField) in clashCases) {
      test('$label — unknown at "$path" decodes + siblings survive', () {
        final poisoned = _clone(baseClashJson);
        _poison(poisoned, path);

        final decoded = ClashConfig.fromJson(poisoned);

        assertField(decoded);
        expect(decoded.mixedPort, 4321);
        expect(decoded.tun.device, 'legacy-tun');
        expect(decoded.dns.listen, '4.4.4.4:53');
      });
    }
  });

  test('ClashConfig does not persist server-owned TLS fragmentation', () {
    final decoded = ClashConfig.fromJson({
      'tls-fragment': true,
      'tls-fragment-size': 8,
      'tls-fragment-delay': 5,
    });

    final localJson = decoded.toJson();
    expect(localJson, isNot(contains('tls-fragment')));
    expect(localJson, isNot(contains('tls-fragment-size')));
    expect(localJson, isNot(contains('tls-fragment-delay')));
  });

  test('patchRawConfig preserves provider log-level', () {
    final source = File('lib/state.dart').readAsStringSync();

    expect(
      source,
      isNot(contains(
        'rawConfig["log-level"] = realPatchConfig.logLevel.name;',
      )),
    );
  });
}
