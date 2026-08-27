import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app.dart';
import 'config.dart';

part 'generated/state.g.dart';

// CONFIG MIRROR — aggregation site (2 of 3).
// `configState` re-assembles the 13 config slice providers
// (lib/providers/config.dart) back into a single `Config`. It is the reverse
// of each slice's `build()` seed and must list EVERY `Config` field. A field
// added to `Config` (lib/models/config.dart) + its slice provider but forgotten
// HERE silently falls back to the default and is dropped — caught by
// test/common/config_roundtrip_test.dart. The flat ref-less mirror these slices
// shadow is owned by lib/common/config_repository.dart.
@riverpod
Config configState(Ref ref) {
  final themeProps = ref.watch(themeSettingProvider);
  final patchClashConfig = ref.watch(patchClashConfigProvider);
  final appSetting = ref.watch(appSettingProvider);
  final profiles = ref.watch(profilesProvider);
  final currentProfileId = ref.watch(currentProfileIdProvider);
  final overrideDns = ref.watch(overrideDnsProvider);
  final networkProps = ref.watch(networkSettingProvider);
  final vpnProps = ref.watch(vpnSettingProvider);
  final proxiesStyle = ref.watch(proxiesStyleSettingProvider);
  final scriptProps = ref.watch(scriptStateProvider);
  final hotKeyActions = ref.watch(hotKeyActionsProvider);
  final windowProps = ref.watch(windowSettingProvider);
  return Config(
    windowProps: windowProps,
    hotKeyActions: hotKeyActions,
    scriptProps: scriptProps,
    proxiesStyle: proxiesStyle,
    vpnProps: vpnProps,
    networkProps: networkProps,
    overrideDns: overrideDns,
    currentProfileId: currentProfileId,
    profiles: profiles,
    appSetting: appSetting,
    themeProps: themeProps,
    patchClashConfig: patchClashConfig,
  );
}

@riverpod
GroupsState currentGroupsState(Ref ref) {
  final mode =
      ref.watch(patchClashConfigProvider.select((state) => state.mode));
  final groups = ref.watch(groupsProvider);
  return GroupsState(
    value: switch (mode) {
      Mode.rule => groups
          .where((item) => item.hidden == false)
          .where((element) => element.name != GroupName.GLOBAL.name)
          .toList(),
      Mode.global => groups.toList(),
      _ => groups
          .where((item) => item.hidden == false)
          .where((element) => element.name != GroupName.GLOBAL.name)
          .toList(),
    },
  );
}

@riverpod
NavigationItemsState navigationsState(Ref ref) {
  final openLogs =
      ref.watch(appSettingProvider.select((state) => state.openLogs));
  final hasProxies = ref.watch(
      currentGroupsStateProvider.select((state) => state.value.isNotEmpty));
  return NavigationItemsState(
    value: navigation.getItems(
      openLogs: openLogs,
      hasProxies: hasProxies,
    ),
  );
}

@riverpod
NavigationItemsState currentNavigationsState(Ref ref) {
  final viewWidth = ref.watch(viewWidthProvider);
  final navigationItemsState = ref.watch(navigationsStateProvider);
  final hasProfiles = ref.watch(
    profilesProvider.select((profiles) => profiles.isNotEmpty),
  );
  final navigationItemMode = switch (viewWidth <= maxMobileWidth) {
    true => NavigationItemMode.mobile,
    false => NavigationItemMode.desktop,
  };
  final filtered = navigationItemsState.value
      .where(
        (element) => element.modes.contains(navigationItemMode),
      )
      .toList();
  // Without any profile/subscription there is nothing to navigate to —
  // collapse the tab menu and screen indicator to a single Dashboard entry
  // so the user only sees the connect / add-subscription affordance.
  return NavigationItemsState(
    value: hasProfiles
        ? filtered
        : filtered
            .where((element) => element.label == PageLabel.dashboard)
            .toList(),
  );
}

@riverpod
CoreState coreState(Ref ref) {
  final vpnProps = ref.watch(vpnSettingProvider);
  final currentProfile = ref.watch(currentProfileProvider);
  final onlyStatisticsProxy = ref
      .watch(appSettingProvider.select((state) => state.onlyStatisticsProxy));
  return CoreState(
    vpnProps: vpnProps,
    onlyStatisticsProxy: onlyStatisticsProxy,
    currentProfileName: currentProfile?.label ?? currentProfile?.id ?? "",
  );
}

@riverpod
UpdateParams updateParams(Ref ref) {
  final routeMode = ref.watch(
    networkSettingProvider.select(
      (state) => state.routeMode,
    ),
  );
  return ref.watch(
    patchClashConfigProvider.select(
      (state) => UpdateParams(
        tun: state.tun.getRealTun(routeMode),
        allowLan: state.allowLan,
        findProcessMode: state.findProcessMode,
        mode: state.mode,
        logLevel: state.logLevel,
        ipv6: state.ipv6,
        tcpConcurrent: state.tcpConcurrent,
        externalController: state.externalController,
        unifiedDelay: state.unifiedDelay,
        mixedPort: state.mixedPort,
      ),
    ),
  );
}

@riverpod
ProxyState proxyState(Ref ref) {
  final isStart = ref.watch(runTimeProvider.select((state) => state != null));
  final vm2 = ref.watch(networkSettingProvider.select(
    (state) => VM2(
      a: state.systemProxy,
      b: state.bypassDomain,
    ),
  ));
  final mixedPort = ref.watch(
    patchClashConfigProvider.select((state) => state.mixedPort),
  );
  return ProxyState(
    isStart: isStart,
    systemProxy: vm2.a,
    bassDomain: vm2.b,
    port: mixedPort,
  );
}

@riverpod
TrayState trayState(Ref ref) {
  final isStart = ref.watch(runTimeProvider.select((state) => state != null));
  final systemProxy = ref.watch(
    networkSettingProvider.select((state) => state.systemProxy),
  );
  final mode = ref.watch(
    patchClashConfigProvider.select((state) => state.mode),
  );
  final mixedPort = ref.watch(
    patchClashConfigProvider.select((state) => state.mixedPort),
  );
  final tunEnable = ref.watch(
    patchClashConfigProvider.select((state) => state.tun.enable),
  );
  final autoLaunch = ref.watch(
    appSettingProvider.select((state) => state.autoLaunch),
  );
  final locale = ref.watch(
    appSettingProvider.select((state) => state.locale),
  );
  final groups = ref
      .watch(
        currentGroupsStateProvider,
      )
      .value;
  final brightness = ref.watch(
    appBrightnessProvider,
  );

  final selectedMap = ref.watch(selectedMapProvider);
  final globalModeEnabled = ref.watch(globalModeEnabledProvider);

  return TrayState(
    mode: mode,
    port: mixedPort,
    autoLaunch: autoLaunch,
    systemProxy: systemProxy,
    tunEnable: tunEnable,
    isStart: isStart,
    locale: locale,
    brightness: brightness,
    groups: groups,
    selectedMap: selectedMap,
    globalModeEnabled: globalModeEnabled,
  );
}

@riverpod
VpnState vpnState(Ref ref) {
  final vpnProps = ref.watch(vpnSettingProvider);
  final stack = ref.watch(
    patchClashConfigProvider.select((state) => state.tun.stack),
  );

  return VpnState(
    stack: stack,
    vpnProps: vpnProps,
  );
}

@riverpod
HomeState homeState(Ref ref) {
  final pageLabel = ref.watch(currentPageLabelProvider);
  final navigationItems = ref.watch(currentNavigationsStateProvider).value;
  final viewMode = ref.watch(viewModeProvider);
  final locale = ref.watch(appSettingProvider.select((state) => state.locale));
  return HomeState(
    pageLabel: pageLabel,
    navigationItems: navigationItems,
    viewMode: viewMode,
    locale: locale,
  );
}

@riverpod
DashboardState dashboardState(Ref ref) {
  final dashboardWidgets =
      ref.watch(appSettingProvider.select((state) => state.dashboardWidgets));
  final viewWidth = ref.watch(viewWidthProvider);
  return DashboardState(
    dashboardWidgets: dashboardWidgets,
    viewWidth: viewWidth,
  );
}

@riverpod
ProxiesActionsState proxiesActionsState(Ref ref) {
  final pageLabel = ref.watch(currentPageLabelProvider);
  final hasProviders = ref.watch(providersProvider.select(
    (state) => state.isNotEmpty,
  ));
  final type = ref.watch(proxiesStyleSettingProvider.select(
    (state) => state.type,
  ));
  return ProxiesActionsState(
    pageLabel: pageLabel,
    hasProviders: hasProviders,
    type: type,
  );
}

@riverpod
StartButtonSelectorState startButtonSelectorState(Ref ref) {
  final isInit = ref.watch(initProvider);
  final hasProfile =
      ref.watch(profilesProvider.select((state) => state.isNotEmpty));
  final hasProxiesInit =
      ref.watch(groupsProvider.select((state) => state.isNotEmpty));
  return StartButtonSelectorState(
    isInit: isInit,
    hasProfile: hasProfile,
    hasProxiesInit: hasProxiesInit,
  );
}

@riverpod
ProfilesSelectorState profilesSelectorState(Ref ref) {
  final currentProfileId = ref.watch(currentProfileIdProvider);
  final profiles = ref.watch(profilesProvider);
  final columns = ref.watch(
    viewWidthProvider.select(
      utils.getProfilesColumns,
    ),
  );
  return ProfilesSelectorState(
    profiles: profiles,
    currentProfileId: currentProfileId,
    columns: columns,
  );
}

@riverpod
ProxiesListSelectorState proxiesListSelectorState(Ref ref) {
  final groupNames = ref.watch(currentGroupsStateProvider
      .select((state) => state.value.map((e) => e.name).toList()));
  final currentUnfoldSet = ref.watch(unfoldSetProvider);
  final proxiesStyle = ref.watch(proxiesStyleSettingProvider);
  final sortNum = ref.watch(sortNumProvider);
  final columns = ref.watch(getProxiesColumnsProvider);
  final query = ref.watch(
    proxiesQueryProvider.select(
      (state) => state.toLowerCase(),
    ),
  );
  return ProxiesListSelectorState(
    groupNames: groupNames,
    currentUnfoldSet: currentUnfoldSet,
    proxiesSortType: proxiesStyle.sortType,
    proxyCardType: proxiesStyle.cardType,
    sortNum: sortNum,
    columns: columns,
    query: query,
  );
}

@riverpod
ProxiesSelectorState proxiesSelectorState(Ref ref) {
  final groupNames = ref.watch(
    currentGroupsStateProvider.select(
      (state) => state.value.map((e) => e.name).toList(),
    ),
  );
  final currentGroupName = ref.watch(currentProfileProvider.select(
    (state) => state?.currentGroupName,
  ));
  return ProxiesSelectorState(
    groupNames: groupNames,
    currentGroupName: currentGroupName,
  );
}

@riverpod
GroupNamesState groupNamesState(Ref ref) => GroupNamesState(
      groupNames: ref.watch(
        currentGroupsStateProvider.select(
          (state) => state.value.map((e) => e.name).toList(),
        ),
      ),
    );

@riverpod
ProxyGroupSelectorState proxyGroupSelectorState(Ref ref, String groupName) {
  final proxiesStyle = ref.watch(
    proxiesStyleSettingProvider,
  );
  final group = ref.watch(
    currentGroupsStateProvider.select(
      (state) => state.value.getGroup(groupName),
    ),
  );
  final sortNum = ref.watch(sortNumProvider);
  final columns = ref.watch(getProxiesColumnsProvider);
  final query =
      ref.watch(proxiesQueryProvider.select((state) => state.toLowerCase()));
  final proxies = group?.all
          .where((item) => item.name.toLowerCase().contains(query))
          .toList() ??
      [];
  return ProxyGroupSelectorState(
    testUrl: group?.testUrl,
    proxiesSortType: proxiesStyle.sortType,
    proxyCardType: proxiesStyle.cardType,
    sortNum: sortNum,
    groupType: group?.type ?? GroupType.Selector,
    proxies: proxies,
    columns: columns,
  );
}

@riverpod
PackageListSelectorState packageListSelectorState(Ref ref) {
  final packages = ref.watch(packagesProvider);
  final accessControl =
      ref.watch(vpnSettingProvider.select((state) => state.accessControl));
  return PackageListSelectorState(
    packages: packages,
    accessControl: accessControl,
  );
}

@riverpod
MoreToolsSelectorState moreToolsSelectorState(Ref ref) {
  final viewMode = ref.watch(viewModeProvider);
  final navigationItems = ref.watch(
      navigationsStateProvider.select((state) => state.value.where((element) {
            final isMore = element.modes.contains(NavigationItemMode.more);
            final isDesktop =
                element.modes.contains(NavigationItemMode.desktop);
            if (isMore && !isDesktop) return true;
            if (viewMode != ViewMode.mobile || !isMore) {
              return false;
            }
            return true;
          }).toList()));

  return MoreToolsSelectorState(navigationItems: navigationItems);
}

@riverpod
bool isCurrentPage(
  Ref ref,
  PageLabel pageLabel, {
  bool Function(PageLabel pageLabel, ViewMode viewMode)? handler,
}) {
  final currentPageLabel = ref.watch(currentPageLabelProvider);
  if (pageLabel == currentPageLabel) {
    return true;
  }
  if (handler != null) {
    final viewMode = ref.watch(viewModeProvider);
    return handler(currentPageLabel, viewMode);
  }
  return false;
}

@riverpod
String getRealTestUrl(Ref ref, [String? testUrl]) {
  final currentTestUrl =
      ref.watch(appSettingProvider.select((state) => state.testUrl));
  return testUrl.getSafeValue(currentTestUrl);
}

@riverpod
int? getDelay(
  Ref ref, {
  required String proxyName,
  String? testUrl,
}) {
  final currentTestUrl = ref.watch(getRealTestUrlProvider(testUrl));
  final proxyCardState = ref.watch(
    getProxyCardStateProvider(
      proxyName,
    ),
  );
  final delay = ref.watch(
    delayDataSourceProvider.select(
      (state) {
        final delayMap =
            state[proxyCardState.testUrl.getSafeValue(currentTestUrl)];
        return delayMap?[proxyCardState.proxyName];
      },
    ),
  );
  return delay;
}

@riverpod
SelectedMap selectedMap(Ref ref) {
  final selectedMap = ref.watch(
    currentProfileProvider.select((state) => state?.selectedMap ?? {}),
  );
  return selectedMap;
}

@riverpod
Set<String> unfoldSet(Ref ref) {
  final unfoldSet = ref.watch(
    currentProfileProvider.select((state) => state?.unfoldSet ?? {}),
  );
  return unfoldSet;
}

@riverpod
HotKeyAction getHotKeyAction(Ref ref, HotAction hotAction) => ref.watch(
      hotKeyActionsProvider.select(
        (state) {
          final index = state.indexWhere((item) => item.action == hotAction);
          return index != -1
              ? state[index]
              : HotKeyAction(
                  action: hotAction,
                );
        },
      ),
    );

@riverpod
Profile? currentProfile(Ref ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  return ref
      .watch(profilesProvider.select((state) => state.getProfile(profileId)));
}

const _cabinetTruthyValues = {'true', '1', 'yes', 'enabled', 'cabinet'};

bool _isCabinetHeaderTruthy(String? value) {
  if (value == null) return false;
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  if (_cabinetTruthyValues.contains(normalized)) return true;
  // Legacy fallback: accept any value containing the Cyrillic marker.
  return normalized.contains('кабинет');
}

bool profileHasCabinetMarker(Profile? profile) {
  final headers = profile?.providerHeaders;
  if (headers == null) return false;
  if (_isCabinetHeaderTruthy(headers['dropweb-cabinet'])) return true;
  // Legacy fallback: older profiles may carry the Cyrillic marker in any header.
  return headers.values.any(
    (value) => value.toLowerCase().contains('кабинет'),
  );
}

/// Default cabinet URL used as a fallback when the legacy marker value
/// `cabinet` (or its truthy aliases) is present without an explicit URL.
const String defaultCabinetUrl = 'https://cab.dropweb.org';

/// Returns `true` for loopback hostnames that may legitimately be served
/// over plain `http://` during local development.
bool _isLocalHttpCabinetHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1' ||
      // `Uri.host` lowercases IPv6 literals and strips the surrounding
      // brackets, but keep the bracketed form as a safety net.
      normalized == '[::1]';
}

/// Resolves the cabinet URL declared by the panel via
/// `dropweb-cabinet: <url>` response header.
///
/// Accepts:
///   * any absolute `https://` URI with a non-empty host;
///   * `http://` URIs only when the host is a loopback address
///     (`localhost`, `127.0.0.1`, `::1`) — strictly for local dev.
/// Returns the default cabinet URL when the header carries a legacy
/// truthy marker (e.g. `cabinet`, `true`).
/// Returns `null` for missing, invalid, or unsupported values
/// (relative paths, hostless URIs, plain `http://` on public hosts,
/// `tg://`, `intent://`, `javascript:` etc.).
Uri? profileCabinetUri(Profile? profile) {
  final raw = profile?.providerHeaders['dropweb-cabinet'];
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final parsed = Uri.tryParse(trimmed);
  if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
    if (parsed.scheme == 'https') {
      return parsed;
    }
    if (parsed.scheme == 'http' && _isLocalHttpCabinetHost(parsed.host)) {
      return parsed;
    }
  }

  // Legacy truthy marker → fall back to the well-known cabinet URL.
  if (_isCabinetHeaderTruthy(trimmed)) {
    return Uri.parse(defaultCabinetUrl);
  }

  return null;
}

@riverpod
bool globalModeEnabled(Ref ref) {
  final profile = ref.watch(currentProfileProvider);
  final value = profile?.providerHeaders['dropweb-globalmode'];
  return value?.toLowerCase() != 'false';
}

@riverpod
bool hasAnnounceData(Ref ref) {
  final profile = ref.watch(currentProfileProvider);
  final value = profile?.providerHeaders['announce'];
  return value != null && value.isNotEmpty;
}

@riverpod
bool hasServiceInfoData(Ref ref) {
  final profile = ref.watch(currentProfileProvider);
  final value = profile?.providerHeaders['dropweb-servicename'];
  return value != null && value.isNotEmpty;
}

@riverpod
bool hasServerInfoData(Ref ref) {
  final profile = ref.watch(currentProfileProvider);
  final value = profile?.providerHeaders['dropweb-serverinfo'];
  return value != null && value.isNotEmpty;
}

/// The vocabulary `dropweb-music` used before it carried a token.
///
/// A panel still sending `dropweb-music: on` is describing a switch, not a
/// credential — forwarding it to the bridge would spend every request on a
/// 403. Treating the old words as "configured, but not with a token" keeps
/// music off until the operator pastes the real value, which is the visible
/// failure rather than the silent one.
const _musicSwitchWords = {
  'on',
  'true',
  '1',
  'yes',
  'enabled',
  'off',
  'false',
  '0',
  'no',
  'disabled',
};

/// Where the bridge lives when a provider names a token but no address.
const _defaultMeowzicBaseUrl = 'http://meow.dropweb.org:8090';

/// The music bridge a provider advertises: a token and the address to spend
/// it on.
@immutable
class MeowzicBridge {
  const MeowzicBridge({required this.token, required this.baseUrl});

  final String token;
  final Uri baseUrl;

  /// How many tracks a search asks for.
  ///
  /// Sent explicitly, because the bridge's own default is ten — barely a
  /// screen and a half, and short enough that a search reads as having found
  /// almost nothing. Twenty is also the bridge's ceiling
  /// (`min(int(request.query.get("n", 10)), 20)` in its search handler), so
  /// this is as deep as one call goes; asking for more would simply be
  /// clamped back to it, silently.
  static const searchLimit = 20;

  Uri searchUri(String query) => baseUrl.replace(
        path: '${baseUrl.path}/s',
        queryParameters: {'q': query, 'n': '$searchLimit'},
      );

  Uri audioUri(String videoId) =>
      baseUrl.replace(path: '${baseUrl.path}/a/$videoId');

  /// The credential, as a request header — never a query parameter.
  ///
  /// The audio URL ends up inside a `MediaItem`, and Android publishes that
  /// to the system media session, where any app holding notification access
  /// can read it. A token in the query string would leak to every scrobbler
  /// on the phone.
  Map<String, String> get headers => {'X-Bridge-Token': token};

  @override
  bool operator ==(Object other) =>
      other is MeowzicBridge &&
      other.token == token &&
      other.baseUrl == baseUrl;

  @override
  int get hashCode => Object.hash(token, baseUrl);
}

/// Reads `dropweb-music: <token>[,<baseUrl>]`, or null when music stays off.
///
/// Fail-closed at every step. Anything unparseable leaves music disabled
/// rather than shipping an entry point that cannot reach a bridge.
MeowzicBridge? parseMeowzicBridge(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;

  final fields = value.split(',');
  final token = fields.first.trim();
  if (token.isEmpty) return null;
  if (_musicSwitchWords.contains(token.toLowerCase())) return null;
  // Sent as an HTTP header, and dart:io rejects non-ASCII header values
  // outright. Refusing here turns a mangled panel value into a quiet "music
  // off" instead of an exception on the first search.
  if (!_isHeaderSafe(token)) return null;

  final address = fields.length > 1 ? fields[1].trim() : '';
  final base = Uri.tryParse(address.isEmpty ? _defaultMeowzicBaseUrl : address);
  if (base == null || !base.hasAuthority) return null;
  // Anything but http/https would not survive the platform HTTP client, and
  // cleartext http only reaches the one host listed in
  // `network_security_config.xml` — a third-party bridge has to serve TLS.
  if (base.scheme != 'http' && base.scheme != 'https') return null;

  return MeowzicBridge(
    token: token,
    baseUrl: base.replace(path: base.path.replaceAll(RegExp(r'/+$'), '')),
  );
}

bool _isHeaderSafe(String value) =>
    value.codeUnits.every((unit) => unit > 0x20 && unit < 0x7f);

/// The bridge this provider advertises, or null while music is off.
///
/// Gates the whole music feature per provider: dropweb ships it, other panels
/// running the same client send no header and never see the entry point.
/// `navigation.dart` and the dashboard grid are shared across those builds,
/// so without this gate the feature would reach everyone.
///
/// The token doubles as the switch. A separate on/off field would allow
/// "enabled, but with nothing to connect to" — a state that can only render
/// as a broken screen, so the contract does not have it.
@riverpod
MeowzicBridge? meowzicBridge(Ref ref) {
  final profile = ref.watch(currentProfileProvider);
  return parseMeowzicBridge(profile?.providerHeaders['dropweb-music']);
}

@riverpod
String? backgroundUrl(Ref ref) {
  final profile = ref.watch(currentProfileProvider);
  return profile?.providerHeaders['dropweb-background'];
}

@riverpod
int getProxiesColumns(Ref ref) {
  final viewWidth = ref.watch(viewWidthProvider);
  final proxiesLayout =
      ref.watch(proxiesStyleSettingProvider.select((state) => state.layout));
  return utils.getProxiesColumns(viewWidth, proxiesLayout);
}

ProxyCardState _getProxyCardState(
  List<Group> groups,
  SelectedMap selectedMap,
  ProxyCardState proxyDelayState,
) {
  if (proxyDelayState.proxyName.isEmpty) return proxyDelayState;
  final index =
      groups.indexWhere((element) => element.name == proxyDelayState.proxyName);
  if (index == -1) return proxyDelayState;
  final group = groups[index];
  // resolveSelectedName (NOT getCurrentSelectedName): an unpinned smart group
  // yields "" here, terminating resolution at the group itself so delay tests
  // and badge lookups target a name the core can actually URLTest. The
  // display label "Auto" must never leak into this chain.
  final currentSelectedName =
      group.resolveSelectedName(selectedMap[proxyDelayState.proxyName] ?? '');
  if (currentSelectedName.isEmpty) {
    return proxyDelayState;
  }
  return _getProxyCardState(
    groups,
    selectedMap,
    proxyDelayState.copyWith(
      proxyName: currentSelectedName,
      testUrl: group.testUrl,
    ),
  );
}

@riverpod
ProxyCardState getProxyCardState(Ref ref, String proxyName) {
  final groups = ref.watch(groupsProvider);
  final selectedMap = ref.watch(selectedMapProvider);
  return _getProxyCardState(
      groups, selectedMap, ProxyCardState(proxyName: proxyName));
}

@riverpod
String? getProxyName(Ref ref, String groupName) {
  final proxyName =
      ref.watch(selectedMapProvider.select((state) => state[groupName]));
  return proxyName;
}

@riverpod
String? getSelectedProxyName(Ref ref, String groupName) {
  final proxyName = ref.watch(getProxyNameProvider(groupName));
  final group = ref.watch(
    groupsProvider.select(
      (state) => state.getGroup(groupName),
    ),
  );
  return group?.getCurrentSelectedName(proxyName ?? '');
}

@riverpod
String getProxyDesc(Ref ref, Proxy proxy) {
  final groupTypeNamesList = GroupType.values.map((e) => e.name).toList();
  if (!groupTypeNamesList.contains(proxy.type)) {
    return proxy.serverDescription ?? proxy.type;
  } else {
    final groups = ref.watch(groupsProvider);
    final index = groups.indexWhere((element) => element.name == proxy.name);
    if (index == -1) return proxy.serverDescription ?? proxy.type;
    final state = ref.watch(getProxyCardStateProvider(proxy.name));
    return "${proxy.serverDescription ?? proxy.type}(${state.proxyName.isNotEmpty ? state.proxyName : '*'})";
  }
}

@riverpod
class ProfileOverrideState extends _$ProfileOverrideState {
  @override
  ProfileOverrideStateModel build() => const ProfileOverrideStateModel(
        selectedRules: {},
      );

  void updateState(
    ProfileOverrideStateModel? Function(ProfileOverrideStateModel state)
        builder,
  ) {
    final value = builder(state);
    if (value == null) {
      return;
    }
    state = value;
  }
}

@riverpod
OverrideData? getProfileOverrideData(Ref ref, String profileId) => ref.watch(
      profilesProvider.select(
        (state) => state.getProfile(profileId)?.overrideData,
      ),
    );

@riverpod
VM2? layoutChange(Ref ref) {
  final viewWidth = ref.watch(viewWidthProvider);
  final textScale =
      ref.watch(themeSettingProvider.select((state) => state.textScale));
  return VM2(
    a: viewWidth,
    b: textScale,
  );
}

@riverpod
VM2<int, bool> checkIp(Ref ref) {
  final checkIpNum = ref.watch(checkIpNumProvider);
  final containsDetection = ref.watch(
    dashboardStateProvider.select(
      (state) =>
          state.dashboardWidgets.contains(DashboardWidget.networkDetection),
    ),
  );
  return VM2(
    a: checkIpNum,
    b: containsDetection,
  );
}

@riverpod
ColorScheme genColorScheme(
  Ref ref,
  Brightness brightness, {
  Color? color,
  bool ignoreConfig = false,
}) {
  final vm2 = ref.watch(
    themeSettingProvider.select(
      (state) => VM2(
        a: state.primaryColor,
        b: state.schemeVariant,
      ),
    ),
  );
  if (color == null && (ignoreConfig == true || vm2.a == null)) {
    return ColorScheme.fromSeed(
      seedColor: globalState.corePalette
              ?.toColorScheme(brightness: brightness)
              .primary ??
          globalState.accentColor,
      brightness: brightness,
      dynamicSchemeVariant: vm2.b,
    );
  }
  // Override fromSeed's tone-mapped primary with the HSL-filtered seed so the
  // accent stays exact (fromSeed lightens/desaturates for contrast).
  final seed = color ?? Color(vm2.a!);
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: vm2.b,
  );
  final filtered = applyColorFilter(seed, vm2.b);
  final onAccent =
      ThemeData.estimateBrightnessForColor(filtered) == Brightness.dark
          ? Colors.white
          : Colors.black;
  return scheme.copyWith(primary: filtered, onPrimary: onAccent);
}

@riverpod
VM3<String?, String?, Dns?> needSetup(Ref ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  final content = ref.watch(
      scriptStateProvider.select((state) => state.currentScript?.content));
  final overrideDns = ref.watch(overrideDnsProvider);
  final dns = overrideDns == true
      ? ref.watch(patchClashConfigProvider.select(
          (state) => state.dns,
        ))
      : null;
  return VM3(
    a: profileId,
    b: content,
    c: dns,
  );
}

@riverpod
VM2<bool, bool> autoSetSystemDnsState(Ref ref) {
  final isStart = ref.watch(runTimeProvider.select((state) => state != null));
  final realTunEnable = ref.watch(realTunEnableProvider);
  final autoSetSystemDns = ref.watch(
    networkSettingProvider.select(
      (state) => state.autoSetSystemDns,
    ),
  );
  return VM2(
    a: isStart ? realTunEnable : false,
    b: autoSetSystemDns,
  );
}
