import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Pointer;
import 'dart:io' show Platform;
import 'dart:math';

import 'package:animations/animations.dart';
import 'package:dio/dio.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/common/connect_trace.dart';
import 'package:dropweb/common/error_mapper.dart';
import 'package:dropweb/common/theme.dart';
import 'package:dropweb/common/work_mode_patch.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/plugins/service.dart';
import 'package:dropweb/widgets/dialog.dart';
import 'package:dropweb/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_js/extensions/fetch.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:material_color_utilities/palettes/core_palette.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common/common.dart';
import 'common/proxy_credentials.dart';
import 'controller.dart';
import 'models/models.dart';

typedef UpdateTasks = List<FutureOr Function()>;

/// Per-session random secret for mihomo external-controller API auth.
/// Regenerated on each app start — prevents localhost API exploitation.
final String _apiSecret = List.generate(
  32,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

class GlobalState {
  factory GlobalState() {
    _instance ??= GlobalState._internal();
    return _instance!;
  }

  GlobalState._internal();
  static GlobalState? _instance;
  Map<CacheTag, double> cacheScrollPosition = {};
  Map<CacheTag, FixedMap<String, double>> cacheHeightMap = {};
  bool isService = false;
  Timer? timer;
  Timer? groupsUpdateTimer;
  late Config config;
  late AppState appState;
  bool isPre = true;
  String? coreSHA256;
  String? coreVersion;
  late PackageInfo packageInfo;
  Function? updateCurrentDelayDebounce;

  /// Pause/resume hooks for the 20s proxy-group poll timer owned by
  /// `ApplicationState`. Wired in its initState and cleared in dispose so the
  /// lifecycle observer (`AppStateManager`) can stop the poll while the app is
  /// backgrounded — the Android VPN foreground service keeps the UI isolate
  /// (and otherwise this timer) alive indefinitely with the screen off, which
  /// would poll the Go core over FFI for the full groups JSON every 20s.
  VoidCallback? pauseGroupsPolling;
  VoidCallback? resumeGroupsPolling;

  late Measure measure;
  late CommonTheme theme;
  late Color accentColor;
  CorePalette? corePalette;
  DateTime? startTime;
  UpdateTasks tasks = [];

  /// Pending TUN-listener readiness ack for the in-flight Android VPN start.
  /// Completed with `null` on ready, a non-null error string on failure.
  /// Only created when [handleStart] needs to wait for the native TUN ack.
  Completer<String?>? _tunAck;

  /// True while [handleStart] is waiting on the native TUN readiness ack.
  /// Drives the start button's connecting affordance. Plain [ValueNotifier]
  /// so [handleStart] (which has no Riverpod ref) can flip it directly and the
  /// dashboard listens via [ValueListenableBuilder].
  final ValueNotifier<bool> isConnecting = ValueNotifier<bool>(false);

  /// Completes the pending TUN ack (no-op if none is in flight, e.g. a late
  /// TUN status arriving outside a start transition).
  void completeTunAck(String? error) {
    final ack = _tunAck;
    if (ack == null || ack.isCompleted) return;
    ack.complete(error);
  }
  final navigatorKey = GlobalKey<NavigatorState>();
  AppController? _appController;
  GlobalKey<CommonScaffoldState> homeScaffoldKey = GlobalKey();
  bool isInit = false;

  /// Persisted SOCKS port (loaded from SharedPreferences on init)
  /// Survives app restarts to avoid VPN detection via port scanning
  int? _persistedSocksPort;

  /// Current session's proxy credentials (auth regenerated per connect, port persisted)
  ProxyCredentials? _currentProxyCredentials;

  /// Get or generate proxy credentials for current session.
  /// Port is persisted across app restarts; username/password regenerate per session.
  ProxyCredentials get currentProxyCredentials {
    if (_currentProxyCredentials == null) {
      _currentProxyCredentials = ProxyCredentialsGenerator.generate(
        persistedPort: _persistedSocksPort,
      );
      // If we generated a new port, persist it
      if (_persistedSocksPort == null) {
        _persistedSocksPort = _currentProxyCredentials!.port;
        preferences.saveSocksPort(_persistedSocksPort!);
        commonPrint.log(
            '[SOCKS Port] Generated and saved new port: $_persistedSocksPort');
      }
    }
    return _currentProxyCredentials!;
  }

  /// Clear credentials (call on disconnect). Port remains persisted.
  void clearProxyCredentials() {
    _currentProxyCredentials = null;
  }

  /// Force regenerate credentials (call on connect).
  /// Reuses persisted port; only regenerates username/password.
  void regenerateProxyCredentials() {
    _currentProxyCredentials = ProxyCredentialsGenerator.generate(
      persistedPort: _persistedSocksPort,
    );
  }

  bool get isStart => startTime != null && startTime!.isBeforeNow;

  AppController get appController => _appController!;

  set appController(AppController appController) {
    _appController = appController;
    isInit = true;
  }

  Future<void> initApp(int version) async {
    coreSHA256 = const String.fromEnvironment("CORE_SHA256");
    coreVersion = const String.fromEnvironment("CORE_VERSION");
    isPre = const String.fromEnvironment("APP_ENV") != 'stable';
    appState = AppState(
      version: version,
      viewSize: Size.zero,
      requests: FixedList(maxLength),
      logs: FixedList(maxLength),
      traffics: FixedList(30),
      totalTraffic: Traffic(),
    );
    await _initDynamicColor();
    await init();
  }

  Future<void> _initDynamicColor() async {
    try {
      corePalette = await DynamicColorPlugin.getCorePalette();
      accentColor = await DynamicColorPlugin.getAccentColor() ??
          const Color(defaultPrimaryColor);
    } catch (_) {}
  }

  Future<void> init() async {
    packageInfo = await PackageInfo.fromPlatform();
    config = await preferences.getConfig() ??
        const Config(
          themeProps: defaultThemeProps,
        );
    await globalState.migrateOldData(config);
    await AppLocalizations.load(
      utils.getLocaleForString(config.appSetting.locale) ??
          WidgetsBinding.instance.platformDispatcher.locale,
    );
    // Load persisted SOCKS port for VPN detection protection
    _persistedSocksPort = await preferences.getSocksPort();
    if (_persistedSocksPort != null) {
      commonPrint
          .log('[SOCKS Port] Loaded persisted port: $_persistedSocksPort');
    }
  }

  String get ua => config.patchClashConfig.globalUa ?? packageInfo.ua;

  Future<void> startUpdateTasks([UpdateTasks? tasks]) async {
    if (timer != null && timer!.isActive == true) return;
    if (tasks != null) {
      this.tasks = tasks;
    }
    await executorUpdateTask();
    // Throttled from 1s → 2s to halve the background rebuild cascade
    // (traffic + runtime + proxy state all tick through this loop).
    // Speedometer/graph feel slightly less live but whole-UI work halves.
    timer = Timer(const Duration(seconds: 2), () async {
      startUpdateTasks();
    });
  }

  Future<void> executorUpdateTask() async {
    for (final task in tasks) {
      await task();
    }
    timer = null;
  }

  void stopUpdateTasks() {
    if (timer == null || timer?.isActive == false) return;
    timer?.cancel();
    timer = null;
  }

  /// Serialises VPN start/stop so a double-tap can't spawn duplicate listeners.
  bool _vpnTransitionInFlight = false;

  Future<bool> handleStart([UpdateTasks? tasks]) async {
    if (_vpnTransitionInFlight) {
      commonPrint.log('handleStart ignored: transition already in flight');
      return startTime != null;
    }
    _vpnTransitionInFlight = true;
    // Wait for the native TUN listener readiness ack only on Android when the
    // VPN(TUN) *service mode* is selected — `config.vpnProps.enable`, which is
    // what VpnPlugin.kt uses to choose handleStartVpn() (real TUN fd) over the
    // proxy-only service. This is NOT the clash-config `tun.enable` flag: in
    // proxy-only mode Kotlin still calls startTun(fd=0) and Go emits
    // {"status":"error","message":"invalid fd 0"}, so gating on the config flag
    // would wrongly roll back a valid proxy-only start. Desktop and Android
    // proxy-only starts never block on the ack and behave exactly as before.
    final needsTunAck = Platform.isAndroid && config.vpnProps.enable;
    if (needsTunAck) {
      _tunAck = Completer<String?>();
      isConnecting.value = true;
    }
    try {
      // For the non-ack path keep the original semantics: startTime is set
      // before startVpn so runTime/UI flips to connected immediately. For the
      // ack path startTime is deliberately deferred until the ack succeeds so
      // the UI never shows "connected" before the TUN listener is up.
      if (!needsTunAck) {
        startTime ??= DateTime.now();
      }
      await clashCore.startListener();
      ConnectTrace.mark('startListener.done');
      final started = await service?.startVpn();
      ConnectTrace.mark('startVpn.done');
      if (started == false) {
        startTime = null;
        await clashCore.stopListener();
        return false;
      }
      if (needsTunAck) {
        final ackError = await _tunAck!.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => 'tun start timeout',
        );
        if (ackError != null) {
          // TUN failed to come up — roll back exactly like the started==false
          // branch, plus tear down the native VPN service (5s cap, mirroring
          // handleStop) so we don't leave a half-up tunnel behind.
          startTime = null;
          await clashCore.stopListener();
          try {
            await service?.stopVpn().timeout(const Duration(seconds: 5));
          } on TimeoutException {
            commonPrint
                .log('service.stopVpn() timed out during TUN-ack rollback');
          } catch (e) {
            commonPrint.log('service.stopVpn() failed during TUN-ack rollback: $e');
          }
          showNotifier(ackError);
          return false;
        }
        // Ack succeeded: now it's honest to mark the connection as started.
        startTime ??= DateTime.now();
        ConnectTrace.end('tunReady');
      }
      startUpdateTasks(tasks);
      return true;
    } finally {
      _tunAck = null;
      isConnecting.value = false;
      _vpnTransitionInFlight = false;
    }
  }

  Future updateStartTime() async {
    startTime = await clashLib?.getRunTime();
  }

  Future<void> handleStop() async {
    if (_vpnTransitionInFlight) {
      commonPrint.log('handleStop ignored: transition already in flight');
      return;
    }
    _vpnTransitionInFlight = true;
    try {
      startTime = null;
      await clashCore.stopListener();
      try {
        // 5s cap — a hung native service mustn't freeze the UI.
        await service?.stopVpn().timeout(const Duration(seconds: 5));
      } on TimeoutException {
        commonPrint.log('service.stopVpn() timed out — forcing local stop');
      } catch (e) {
        commonPrint.log('service.stopVpn() failed: $e');
      }
      stopUpdateTasks();
    } finally {
      _vpnTransitionInFlight = false;
    }
  }

  Future<bool?> showMessage({
    String? title,
    required InlineSpan message,
    String? confirmText,
    bool cancelable = true,
  }) async =>
      showCommonDialog<bool>(
        child: Builder(
          builder: (context) => CommonDialog(
            title: title ?? appLocalizations.tip,
            actions: [
              if (cancelable)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(appLocalizations.cancel),
                ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text(confirmText ?? appLocalizations.confirm),
              )
            ],
            child: Container(
              width: 300,
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: SelectableText.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.labelLarge,
                    children: [message],
                  ),
                  style: const TextStyle(
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Future<T?> showCommonDialog<T>({
    required Widget child,
    bool dismissible = true,
  }) async =>
      showModal<T>(
        context: navigatorKey.currentState!.context,
        configuration: FadeScaleTransitionConfiguration(
          barrierColor: Colors.black38,
          barrierDismissible: dismissible,
        ),
        builder: (_) => child,
        filter: commonFilter,
      );

  Future<T?> safeRun<T>(
    FutureOr<T> Function() futureFunction, {
    String? title,
    bool silence = true,
  }) async {
    try {
      final res = await futureFunction();
      return res;
    } catch (e) {
      commonPrint.log("$e");
      final message =
          ErrorMapper.mapError(e.toString()) ?? appLocalizations.genericErrorMessage;
      if (silence) {
        showNotifier(message);
      } else {
        showMessage(
          title: title ?? appLocalizations.tip,
          message: TextSpan(
            text: message,
          ),
        );
      }
      return null;
    }
  }

  void showNotifier(String text) {
    if (text.isEmpty) {
      return;
    }
    navigatorKey.currentContext?.showNotifier(text);
  }

  Future<void> openUrl(String url) async {
    final res = await showMessage(
      message: TextSpan(text: url),
      title: appLocalizations.externalLink,
      confirmText: appLocalizations.go,
    );
    if (res != true) {
      return;
    }
    launchUrl(Uri.parse(url));
  }

  Future<void> migrateOldData(Config config) async {
    final clashConfig = await preferences.getClashConfig();
    if (clashConfig != null) {
      config = config.copyWith(
        patchClashConfig: clashConfig,
      );
      preferences.clearClashConfig();
      preferences.saveConfig(config);
    }
  }

  CoreState getCoreState() {
    final currentProfile = config.currentProfile;
    return CoreState(
      vpnProps: config.vpnProps,
      onlyStatisticsProxy: config.appSetting.onlyStatisticsProxy,
      currentProfileName: currentProfile?.label ?? currentProfile?.id ?? "",
      bypassDomain: config.networkProps.bypassDomain,
    );
  }

  Future<SetupParams> getSetupParams({
    required ClashConfig pathConfig,
  }) async {
    final clashConfig = await patchRawConfig(
      patchConfig: pathConfig,
    );
    final params = SetupParams(
      config: clashConfig,
      selectedMap: config.currentProfile?.selectedMap ?? {},
      testUrl: config.appSetting.testUrl,
    );
    return params;
  }

  Future<ClashConfig> syncNetworkSettingsFromProvider(
      ClashConfig patchConfig) async {
    if (config.appSetting.overrideNetworkSettings) {
      return patchConfig; // User wants to override, keep current settings
    }

    final profile = config.currentProfile;
    if (profile == null) {
      return patchConfig;
    }

    try {
      final profileId = profile.id;
      final configMap = await getProfileConfig(profileId);
      final rawConfig = await handleEvaluate(configMap);

      final providerIpv6 = rawConfig['ipv6'] as bool? ?? patchConfig.ipv6;
      final providerAllowLan =
          rawConfig['allow-lan'] as bool? ?? patchConfig.allowLan;
      final providerMixedPort =
          rawConfig['mixed-port'] as int? ?? patchConfig.mixedPort;
      final providerFindProcessModeStr =
          rawConfig['find-process-mode'] as String?;
      final providerFindProcessMode = providerFindProcessModeStr != null
          ? FindProcessMode.values.firstWhere(
              (e) =>
                  e.name.toLowerCase() ==
                  providerFindProcessModeStr.toLowerCase(),
              orElse: () => patchConfig.findProcessMode,
            )
          : patchConfig.findProcessMode;

      final providerTunStackStr = rawConfig['tun']?['stack'] as String?;
      final providerTunStack = providerTunStackStr != null
          ? TunStack.values.firstWhere(
              (e) => e.name.toLowerCase() == providerTunStackStr.toLowerCase(),
              orElse: () => patchConfig.tun.stack,
            )
          : patchConfig.tun.stack;

      return patchConfig
          .copyWith(
            ipv6: providerIpv6,
            allowLan: providerAllowLan,
            mixedPort: providerMixedPort,
            findProcessMode: providerFindProcessMode,
          )
          .copyWith
          .tun(stack: providerTunStack);
    } catch (e) {
      commonPrint.log("Error syncing network settings from provider: $e");
      return patchConfig;
    }
  }

  Future<Map<String, dynamic>> patchRawConfig({
    required ClashConfig patchConfig,
  }) async {
    final profile = config.currentProfile;
    if (profile == null) {
      return {};
    }
    final profileId = profile.id;
    final configMap = await getProfileConfig(profileId);
    final rawConfig = await handleEvaluate(configMap);

    final realPatchConfig = patchConfig.copyWith(
      tun: patchConfig.tun.getRealTun(config.networkProps.routeMode),
    );
    rawConfig["external-controller"] = realPatchConfig.externalController.value;
    // Security: always set a random secret on external-controller API
    // Prevents unauthorized access from other apps via localhost scanning
    rawConfig["secret"] = _apiSecret;
    if (rawConfig["external-ui"] == null || rawConfig["external-ui"] == "") {
      rawConfig["external-ui"] = "";
    }
    rawConfig["interface-name"] = "";
    if (rawConfig["external-ui-url"] == null ||
        rawConfig["external-ui-url"] == "") {
      rawConfig["external-ui-url"] = "";
    }
    rawConfig["tcp-concurrent"] = realPatchConfig.tcpConcurrent;
    rawConfig["unified-delay"] = realPatchConfig.unifiedDelay;
    rawConfig["log-level"] = realPatchConfig.logLevel.name;
    rawConfig["port"] = 0;
    rawConfig["socks-port"] = 0;
    rawConfig["keep-alive-interval"] = realPatchConfig.keepAliveInterval;
    rawConfig["port"] = realPatchConfig.port;
    rawConfig["socks-port"] = realPatchConfig.socksPort;
    rawConfig["redir-port"] = realPatchConfig.redirPort;
    rawConfig["tproxy-port"] = realPatchConfig.tproxyPort;
    // Original three modes — direct passthrough to mihomo:
    // Mode.rule → "rule", Mode.direct → "direct", Mode.global → "global".
    rawConfig["mode"] = realPatchConfig.mode.name;

    // Set network settings: use patchConfig if overriding, otherwise keep provider values
    if (config.appSetting.overrideNetworkSettings) {
      // User wants to override - use values from UI (always write)
      rawConfig["find-process-mode"] = realPatchConfig.findProcessMode.name;
      rawConfig["allow-lan"] = realPatchConfig.allowLan;
      rawConfig["ipv6"] = realPatchConfig.ipv6;
      rawConfig["mixed-port"] = realPatchConfig.mixedPort;
    } else {
      // Use provider values - only set if not already in rawConfig, use patchConfig values (which are synced from provider)
      if (rawConfig["find-process-mode"] == null) {
        rawConfig["find-process-mode"] = realPatchConfig.findProcessMode.name;
      }
      if (rawConfig["allow-lan"] == null) {
        rawConfig["allow-lan"] = realPatchConfig.allowLan;
      }
      if (rawConfig["ipv6"] == null) {
        rawConfig["ipv6"] = realPatchConfig.ipv6;
      }
      if (rawConfig["mixed-port"] == null) {
        rawConfig["mixed-port"] = realPatchConfig.mixedPort;
      }
    }

    // === SOCKS PORT PROTECTION ===
    // Reference: https://habr.com/ru/articles/1022422/
    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile: random port + auth (защита от VPN детекторов типа YourVPNDead)
      final proxyCredentials = currentProxyCredentials;
      commonPrint.log(
          '[SOCKS Protection] Mobile: port=${proxyCredentials.port} with auth');
      rawConfig["mixed-port"] = proxyCredentials.port;
      rawConfig["port"] = 0;
      rawConfig["socks-port"] = 0;
      rawConfig["authentication"] =
          ProxyCredentialsGenerator.toMihomoAuth(proxyCredentials);
    } else {
      // Desktop: фиксированный порт из конфига + skip-auth для localhost
      // Браузеры используют system proxy (127.0.0.1:7890)
      commonPrint.log(
          '[SOCKS Protection] Desktop: using configured port, localhost allowed');
      rawConfig["skip-auth-prefixes"] = ["127.0.0.1/8", "::1/128"];
    }

    if (rawConfig["tun"] == null) {
      rawConfig["tun"] = {};
    }
    rawConfig["tun"]["enable"] = realPatchConfig.tun.enable;
    rawConfig["tun"]["device"] = realPatchConfig.tun.device;
    rawConfig["tun"]["dns-hijack"] = realPatchConfig.tun.dnsHijack;

    // Set TUN stack
    if (config.appSetting.overrideNetworkSettings) {
      // User wants to override - use value from UI (always write)
      rawConfig["tun"]["stack"] = realPatchConfig.tun.stack.name;
    } else {
      // Use provider value - only set if not already in rawConfig, use patchConfig value (which is synced from provider)
      final currentStack = rawConfig["tun"]["stack"];
      if (currentStack == null) {
        rawConfig["tun"]["stack"] = realPatchConfig.tun.stack.name;
      }
    }

    rawConfig["tun"]["route-address"] = realPatchConfig.tun.routeAddress;
    rawConfig["tun"]["auto-route"] = realPatchConfig.tun.autoRoute;
    rawConfig["geodata-loader"] = realPatchConfig.geodataLoader.name;
    if (rawConfig["sniffer"]?["sniff"] != null) {
      for (final value in (rawConfig["sniffer"]?["sniff"] as Map).values) {
        if (value["ports"] != null && value["ports"] is List) {
          value["ports"] =
              value["ports"]?.map((item) => item.toString()).toList() ?? [];
        }
      }
    }
    if (rawConfig["profile"] == null) {
      rawConfig["profile"] = {};
    }
    if (rawConfig["proxy-providers"] != null) {
      final proxyProviders = rawConfig["proxy-providers"] as Map;
      for (final key in proxyProviders.keys) {
        final proxyProvider = proxyProviders[key];
        if (proxyProvider["type"] != "http") {
          continue;
        }
        if (proxyProvider["url"] != null) {
          proxyProvider["path"] = await appPath.getProvidersFilePath(
            profile.id,
            "proxies",
            proxyProvider["url"],
          );
        }
      }
    }

    if (rawConfig["rule-providers"] != null) {
      final ruleProviders = rawConfig["rule-providers"] as Map;
      for (final key in ruleProviders.keys) {
        final ruleProvider = ruleProviders[key];
        if (ruleProvider["type"] != "http") {
          continue;
        }
        if (ruleProvider["url"] != null) {
          ruleProvider["path"] = await appPath.getProvidersFilePath(
            profile.id,
            "rules",
            ruleProvider["url"],
          );
        }
      }
    }

    rawConfig["profile"]["store-selected"] = false;

    final mergedGeoXUrl = <String, dynamic>{};
    final patchGeoX = realPatchConfig.geoXUrl.toJson();
    final profileGeoX = rawConfig["geox-url"];

    mergedGeoXUrl['geoip'] = patchGeoX['geoip'];
    mergedGeoXUrl['mmdb'] = patchGeoX['mmdb'];
    mergedGeoXUrl['asn'] = patchGeoX['asn'];
    mergedGeoXUrl['geosite'] = patchGeoX['geosite'];

    if (profileGeoX != null && profileGeoX is Map) {
      if (profileGeoX['geoip'] != null)
        mergedGeoXUrl['geoip'] = profileGeoX['geoip'];
      if (profileGeoX['mmdb'] != null)
        mergedGeoXUrl['mmdb'] = profileGeoX['mmdb'];
      if (profileGeoX['asn'] != null) mergedGeoXUrl['asn'] = profileGeoX['asn'];
      if (profileGeoX['geosite'] != null)
        mergedGeoXUrl['geosite'] = profileGeoX['geosite'];
    }

    rawConfig["geox-url"] = mergedGeoXUrl;
    rawConfig["global-ua"] = realPatchConfig.globalUa;
    if (rawConfig["hosts"] == null) {
      rawConfig["hosts"] = {};
    }
    for (final host in realPatchConfig.hosts.entries) {
      rawConfig["hosts"][host.key] = host.value.splitByMultipleSeparators;
    }
    if (rawConfig["dns"] == null) {
      rawConfig["dns"] = {};
    }
    final isEnableDns = rawConfig["dns"]["enable"] == true;
    final overrideDns = globalState.config.overrideDns;
    if (overrideDns || !isEnableDns) {
      final dns = switch (!isEnableDns) {
        true => realPatchConfig.dns.copyWith(
            nameserver: [...realPatchConfig.dns.nameserver, "system://"]),
        false => realPatchConfig.dns,
      };
      rawConfig["dns"] = dns.toJson();
      rawConfig["dns"]["nameserver-policy"] = {};
      for (final entry in dns.nameserverPolicy.entries) {
        rawConfig["dns"]["nameserver-policy"][entry.key] =
            entry.value.splitByMultipleSeparators;
      }
    }
    var rules = [];
    if (rawConfig["rules"] != null) {
      rules = rawConfig["rules"];
    }
    rawConfig.remove("rules");

    final overrideData = profile.overrideData;
    if (overrideData.enable && config.scriptProps.currentScript == null) {
      if (overrideData.rule.type == OverrideRuleType.override) {
        rules = overrideData.runningRule;
      } else {
        rules = [...overrideData.runningRule, ...rules];
      }
    }
    rawConfig["rule"] = rules;

    // Additive work-mode group injection. Runs on EVERY setup over the parsed
    // config (the download-time `patchSmartPool` output is already baked into
    // the profile file, so its groups are present here). NEVER reshapes the
    // panel's existing groups/rules — only appends our `Умный` / `Страна <flag>`
    // group. Mode + selectedMap wiring lives in the controller, not here.
    //
    // Defensive backstop (B-3): a Country profile whose country lost all its
    // nodes (e.g. a LOCAL file edit between revalidation chokepoints) injects no
    // group, yet selectedMap[GLOBAL] may still point at it. That does NOT break
    // core startup — the GLOBAL selector silently falls back to its first proxy
    // — but log it so the dangle is visible. The revalidation chokepoints are
    // the primary fix; this is only a cheap last-line warning.
    if (profile.workMode == WorkMode.country &&
        !countryGroupWillInject(
          rawConfig,
          workMode: profile.workMode,
          staticCountry: profile.staticCountry,
        )) {
      commonPrint.log('[workmode] country group missing, config falls back');
    }
    return applyWorkModePatch(
      rawConfig,
      workMode: profile.workMode,
      staticCountry: profile.staticCountry,
    );
  }

  Future<Map<String, dynamic>> getProfileConfig(String profileId) async {
    final configMap = await switch (clashLibHandler != null) {
      true => clashLibHandler!.getConfig(profileId),
      false => clashCore.getConfig(profileId),
    };
    configMap["rules"] = configMap["rule"];
    configMap.remove("rule");
    return configMap;
  }

  Future<Map<String, dynamic>> handleEvaluate(
    Map<String, dynamic> config,
  ) async {
    final currentScript = globalState.config.scriptProps.currentScript;
    if (currentScript == null) {
      return config;
    }
    if (config["proxy-providers"] == null) {
      config["proxy-providers"] = {};
    }
    final configJs = json.encode(config);
    const evalTimeout = Duration(seconds: 10);
    // A user/backup-supplied proxy script runs `main(config)` to rewrite the
    // resolved config. A runaway script (e.g. `while (true) {}`) must not hang
    // the config-apply pipeline forever. There are TWO guards because
    // `evaluateAsync` is, on every engine here, `Future.value(evaluate(...))`
    // — the JS runs SYNCHRONOUSLY on this isolate, so a Dart `.timeout()` Timer
    // can never fire while a tight loop blocks the event loop:
    //   1. QuickJS (Android/Windows/Linux): construct the runtime with a native
    //      interrupt deadline (ms) so the C engine aborts the script itself —
    //      the only thing that stops a synchronous infinite loop.
    //   2. A Dart-side `guardWithTimeout` as belt-and-suspenders for engines
    //      whose eval yields to the event loop (promises/async) and to surface
    //      a readable error; it disposes the (possibly wedged) runtime on expiry.
    final isQuickJs =
        Platform.isAndroid || Platform.isWindows || Platform.isLinux;
    final JavascriptRuntime runtime;
    if (isQuickJs) {
      final quickJs = QuickJsRuntime2(timeout: evalTimeout.inMilliseconds);
      // Mirror getJavascriptRuntime's setup (fetch is fire-and-forget there).
      unawaited(quickJs.enableFetch());
      quickJs.enableHandlePromises();
      runtime = quickJs;
    } else {
      runtime = getJavascriptRuntime();
    }
    final res = await runtime
        .evaluateAsync("""
      ${currentScript.content}
      main($configJs)
    """)
        .guardWithTimeout(
          timeout: evalTimeout,
          message: 'script evaluation timed out (${evalTimeout.inSeconds}s)',
          onTimeout: runtime.dispose,
        );
    if (res.isError) {
      final error = res.stringResult;
      // A native QuickJS interrupt surfaces as an "interrupted" exception —
      // translate it to the same readable timeout error as the Dart path.
      if (error.toLowerCase().contains('interrupt')) {
        throw 'script evaluation timed out (${evalTimeout.inSeconds}s)';
      }
      throw error;
    }
    final value = switch (res.rawResult is Pointer) {
      true => runtime.convertValue<Map<String, dynamic>>(res),
      false => Map<String, dynamic>.from(res.rawResult),
    };
    return value ?? config;
  }
}

final globalState = GlobalState();

class DetectionState {
  factory DetectionState() {
    _instance ??= DetectionState._internal();
    return _instance!;
  }

  DetectionState._internal();
  static DetectionState? _instance;
  bool? _preIsStart;
  Timer? _setTimeoutTimer;
  CancelToken? cancelToken;
  DateTime? _lastManualCheck;

  final state = ValueNotifier<NetworkDetectionState>(
    const NetworkDetectionState(
      isTesting: false,
      isLoading: true,
      ipInfo: null,
    ),
  );

  void startCheck() {
    debouncer.call(
      FunctionTag.checkIp,
      _checkIp,
      duration: const Duration(
        milliseconds: 1200,
      ),
    );
  }

  bool forceCheck() {
    if (_lastManualCheck != null) {
      final timeSinceLastCheck = DateTime.now().difference(_lastManualCheck!);
      if (timeSinceLastCheck.inSeconds < 15) {
        return false;
      }
    }
    _lastManualCheck = DateTime.now();
    _checkIp();
    return true;
  }

  Future<void> _checkIp() async {
    final appState = globalState.appState;
    final isInit = appState.isInit;
    if (!isInit) return;
    final isStart = appState.runTime != null;
    if (_preIsStart == false &&
        _preIsStart == isStart &&
        state.value.ipInfo != null) {
      return;
    }
    _clearSetTimeoutTimer();
    state.value = state.value.copyWith(
      isLoading: true,
      ipInfo: null,
    );
    _preIsStart = isStart;
    if (cancelToken != null) {
      cancelToken!.cancel();
      cancelToken = null;
    }
    cancelToken = CancelToken();
    state.value = state.value.copyWith(
      isTesting: true,
    );
    final res = await request.checkIp(cancelToken: cancelToken);
    if (res.isError) {
      state.value = state.value.copyWith(
        isLoading: true,
        ipInfo: null,
      );
      return;
    }
    final ipInfo = res.data;
    state.value = state.value.copyWith(
      isTesting: false,
    );
    if (ipInfo != null) {
      state.value = state.value.copyWith(
        isLoading: false,
        ipInfo: ipInfo,
      );
      return;
    }
    _clearSetTimeoutTimer();
    _setTimeoutTimer = Timer(const Duration(milliseconds: 300), () {
      state.value = state.value.copyWith(
        isLoading: false,
        ipInfo: null,
      );
    });
  }

  void _clearSetTimeoutTimer() {
    if (_setTimeoutTimer != null) {
      _setTimeoutTimer?.cancel();
      _setTimeoutTimer = null;
    }
  }
}

final detectionState = DetectionState();
