// ignore_for_file: invalid_annotation_target

import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'models.dart';

part 'generated/config.freezed.dart';
part 'generated/config.g.dart';

const defaultBypassDomain = [
  "*zhihu.com",
  "*zhimg.com",
  "*jd.com",
  "100ime-iat-api.xfyun.cn",
  "*360buyimg.com",
  "localhost",
  "*.local",
  "127.*",
  "10.*",
  "172.16.*",
  "172.17.*",
  "172.18.*",
  "172.19.*",
  "172.2*",
  "172.30.*",
  "172.31.*",
  "192.168.*"
];

const defaultAppSettingProps = AppSettingProps();
const defaultVpnProps = VpnProps();
const defaultNetworkProps = NetworkProps();
const defaultProxiesStyle = ProxiesStyle();
const defaultWindowProps = WindowProps();
const defaultAccessControl = AccessControl();
const defaultThemeProps = ThemeProps(
  primaryColor: defaultPrimaryColor,
  orbColorPrimary: 0xFF009938,
  orbColorSecondary: 0xFF2BFF7A,
  orbBlur: 4.0,
);

const List<DashboardWidget> defaultDashboardWidgets = [
  DashboardWidget.metainfo,
  DashboardWidget.changeServerButton,
];

List<DashboardWidget> dashboardWidgetsSafeFormJson(
  List<dynamic>? dashboardWidgets,
) {
  if (dashboardWidgets == null) {
    return defaultDashboardWidgets;
  }
  try {
    // Degrade-to-skip: a persisted layout may reference a widget that no longer
    // exists (e.g. the removed rule/global `outboundMode`/`outboundModeV2`).
    // Drop unknown names instead of resetting the whole layout to defaults.
    final known = _$DashboardWidgetEnumMap.values.toSet();
    return dashboardWidgets
        .where(known.contains)
        .map((e) => $enumDecode(_$DashboardWidgetEnumMap, e))
        .toList();
  } catch (_) {
    return defaultDashboardWidgets;
  }
}

@freezed
class AppSettingProps with _$AppSettingProps {
  const factory AppSettingProps({
    String? locale,
    @Default(defaultDashboardWidgets)
    @JsonKey(fromJson: dashboardWidgetsSafeFormJson)
    List<DashboardWidget> dashboardWidgets,
    /// Set once meowzic has been seeded into [dashboardWidgets].
    ///
    /// A new [DashboardWidget] does not reach anyone who already uses the app:
    /// the grid renders the *saved* list, and unknown-to-it widgets only show
    /// up in the "add widget" pool. Defaults apply solely when the key is
    /// absent, and the whole settings blob is persisted on any change — so by
    /// the time meowzic ships, every existing layout is already frozen
    /// without it. Seeding once on first sight of `dropweb-music` fixes that;
    /// the flag makes it once, so removing the widget sticks.
    @Default(false) bool meowzicSeeded,
    @Default(false) bool onlyStatisticsProxy,
    @Default(false) bool autoLaunch,
    @Default(false) bool silentLaunch,
    @Default(false) bool autoRun,
    @Default(false) bool openLogs,
    @Default(true) bool closeConnections,
    @Default(defaultTestUrl) String testUrl,
    @Default(true) bool isAnimateToPage,
    // Sideloaded RU build self-updates from dropweb.org/update.json by default;
    // Play build ignores this (gated by kIsPlayBuild). Desktop just opens the
    // release page on a newer version. See docs/plans/2026-06-25-auto-update.md.
    @Default(true) bool autoCheckUpdate,
    /// Epoch-ms of the last in-app update check; drives the once/day cadence of
    /// the Android updater (see shouldRunScheduledCheck). 0 = never checked.
    @Default(0) int lastUpdateCheckMs,
    @Default(false) bool showLabel,
    @Default(false) bool disclaimerAccepted,
    @Default(true) bool minimizeOnExit,
    @Default(false) bool hidden,
    @Default(false) bool developerMode,
    @Default(false) bool overrideProviderSettings,
    @Default(true) bool applySubscriptionTheme,
    @Default(true) bool applySubscriptionLogo,
    @Default(false) bool overrideNetworkSettings,
  }) = _AppSettingProps;

  factory AppSettingProps.fromJson(Map<String, Object?> json) =>
      _$AppSettingPropsFromJson(json);

  factory AppSettingProps.safeFromJson(Map<String, Object?>? json) =>
      json == null ? defaultAppSettingProps : AppSettingProps.fromJson(json);
}

@freezed
class AccessControl with _$AccessControl {
  const factory AccessControl({
    @Default(false) bool enable,
    @JsonKey(unknownEnumValue: AccessControlMode.rejectSelected)
    @Default(AccessControlMode.rejectSelected)
    AccessControlMode mode,
    @Default([]) List<String> acceptList,
    @Default([]) List<String> rejectList,
    @JsonKey(unknownEnumValue: AccessSortType.none)
    @Default(AccessSortType.none)
    AccessSortType sort,
    @Default(true) bool isFilterSystemApp,
    @Default(true) bool isFilterNonInternetApp,
  }) = _AccessControl;

  factory AccessControl.fromJson(Map<String, Object?> json) =>
      _$AccessControlFromJson(json);
}

extension AccessControlExt on AccessControl {
  List<String> get currentList => switch (mode) {
        AccessControlMode.acceptSelected => acceptList,
        AccessControlMode.rejectSelected => rejectList,
      };
}

@freezed
class WindowProps with _$WindowProps {
  const factory WindowProps({
    @Default(450) double width,
    @Default(650) double height,
    double? top,
    double? left,
  }) = _WindowProps;

  factory WindowProps.fromJson(Map<String, Object?>? json) =>
      json == null ? const WindowProps() : _$WindowPropsFromJson(json);
}

@freezed
class VpnProps with _$VpnProps {
  const factory VpnProps({
    @Default(true) bool enable,
    @Default(true) bool systemProxy,
    @Default(true) bool ipv6,
    @Default(true) bool allowBypass,
    @Default(defaultAccessControl) AccessControl accessControl,
  }) = _VpnProps;

  factory VpnProps.fromJson(Map<String, Object?> json) =>
      _$VpnPropsFromJson(json);
}

@freezed
class NetworkProps with _$NetworkProps {
  const factory NetworkProps({
    @Default(false) bool systemProxy,
    @Default(defaultBypassDomain) List<String> bypassDomain,
    @JsonKey(unknownEnumValue: RouteMode.config)
    @Default(RouteMode.config)
    RouteMode routeMode,
    @Default(true) bool autoSetSystemDns,
  }) = _NetworkProps;

  factory NetworkProps.fromJson(Map<String, Object?>? json) =>
      json == null ? const NetworkProps() : _$NetworkPropsFromJson(json);
}

@freezed
class ProxiesStyle with _$ProxiesStyle {
  const factory ProxiesStyle({
    @JsonKey(unknownEnumValue: ProxiesType.list)
    @Default(ProxiesType.list)
    ProxiesType type,
    @JsonKey(unknownEnumValue: ProxiesSortType.none)
    @Default(ProxiesSortType.none)
    ProxiesSortType sortType,
    @JsonKey(unknownEnumValue: ProxiesLayout.standard)
    @Default(ProxiesLayout.standard)
    ProxiesLayout layout,
    @JsonKey(unknownEnumValue: ProxiesIconStyle.icon)
    @Default(ProxiesIconStyle.icon)
    ProxiesIconStyle iconStyle,
    @JsonKey(unknownEnumValue: ProxyCardType.expand)
    @Default(ProxyCardType.expand)
    ProxyCardType cardType,
    @Default({}) Map<String, String> iconMap,
  }) = _ProxiesStyle;

  factory ProxiesStyle.fromJson(Map<String, Object?>? json) =>
      json == null ? defaultProxiesStyle : _$ProxiesStyleFromJson(json);
}

@freezed
class TextScale with _$TextScale {
  const factory TextScale({
    @Default(false) enable,
    @Default(1.0) scale,
  }) = _TextScale;

  factory TextScale.fromJson(Map<String, Object?> json) =>
      _$TextScaleFromJson(json);
}

@freezed
class ThemeProps with _$ThemeProps {
  const factory ThemeProps({
    int? primaryColor,
    int? orbColorPrimary,
    int? orbColorSecondary,
    @Default(5.0) double orbBlur,
    @Default(defaultPrimaryColors) List<int> primaryColors,
    @JsonKey(unknownEnumValue: ThemeMode.dark)
    @Default(ThemeMode.dark)
    ThemeMode themeMode,
    @JsonKey(unknownEnumValue: DynamicSchemeVariant.fidelity)
    @Default(DynamicSchemeVariant.fidelity)
    DynamicSchemeVariant schemeVariant,
    @Default(true) bool pureBlack,
    @Default(TextScale()) TextScale textScale,
  }) = _ThemeProps;

  factory ThemeProps.fromJson(Map<String, Object?> json) =>
      _$ThemePropsFromJson(json);

  factory ThemeProps.safeFromJson(Map<String, Object?>? json) {
    if (json == null) {
      return defaultThemeProps;
    }
    try {
      return ThemeProps.fromJson(json);
    } catch (_) {
      return defaultThemeProps;
    }
  }
}

@freezed
class ScriptProps with _$ScriptProps {
  const factory ScriptProps({
    String? currentId,
    @Default([]) List<Script> scripts,
  }) = _ScriptProps;

  factory ScriptProps.fromJson(Map<String, Object?> json) =>
      _$ScriptPropsFromJson(json);
}

extension ScriptPropsExt on ScriptProps {
  String? get realId {
    final index = scripts.indexWhere((script) => script.id == currentId);
    if (index != -1) {
      return currentId;
    }
    return null;
  }

  Script? get currentScript {
    final index = scripts.indexWhere((script) => script.id == currentId);
    if (index != -1) {
      return scripts[index];
    }
    return null;
  }
}

@freezed
class Config with _$Config {
  const factory Config({
    @JsonKey(fromJson: AppSettingProps.safeFromJson)
    @Default(defaultAppSettingProps)
    AppSettingProps appSetting,
    @Default([]) List<Profile> profiles,
    @Default([]) List<HotKeyAction> hotKeyActions,
    String? currentProfileId,
    @Default(false) bool overrideDns,
    @Default(defaultNetworkProps) NetworkProps networkProps,
    @Default(defaultVpnProps) VpnProps vpnProps,
    @JsonKey(fromJson: ThemeProps.safeFromJson) required ThemeProps themeProps,
    @Default(defaultProxiesStyle) ProxiesStyle proxiesStyle,
    @Default(defaultWindowProps) WindowProps windowProps,
    @Default(defaultClashConfig) ClashConfig patchClashConfig,
    @Default(ScriptProps()) ScriptProps scriptProps,
  }) = _Config;

  factory Config.fromJson(Map<String, Object?> json) => _$ConfigFromJson(json);

  factory Config.compatibleFromJson(Map<String, Object?> json) {
    try {
      final accessControlMap = json["accessControl"];
      final isAccessControl = json["isAccessControl"];
      if (accessControlMap != null) {
        (accessControlMap as Map)["enable"] = isAccessControl;
        if (json["vpnProps"] != null) {
          (json["vpnProps"]! as Map)["accessControl"] = accessControlMap;
        }
      }

      // Migration: Replace deprecated "standard" iconStyle with "icon"
      final proxiesStyle = json["proxiesStyle"];
      if (proxiesStyle is Map) {
        if (proxiesStyle["iconStyle"] == "standard") {
          proxiesStyle["iconStyle"] = "icon";
        }
      }
    } catch (e) {
      commonPrint.log('[config] swallowed config migration error: $e');
    }
    return Config.fromJson(json);
  }
}

extension ConfigExt on Config {
  Profile? get currentProfile => profiles.getProfile(currentProfileId);
}
