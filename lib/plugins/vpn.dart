import 'dart:async';
import 'dart:convert';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract mixin class VpnListener {
  void onDnsChanged(String dns) {}
}

/// Ordered core reset for a real bearer replacement. The order is mandatory:
/// the native side has already committed and applied the new underlying
/// network and dispatched the active bearer's DNS; here the resolver DNS
/// connection pools are reset BEFORE tracked flows close, so an immediate
/// re-dial cannot reuse an old bearer's pooled resolver connection. Delay
/// measurements from the previous bearer are invalidated last — they are
/// fiction on the new one.
@visibleForTesting
Future<void> handleUnderlyingNetworkChanged({
  required FutureOr<Object?> Function() resetConnections,
  required FutureOr<Object?> Function() closeConnections,
  required void Function() invalidateDelayData,
}) async {
  await Future.sync(resetConnections);
  await Future.sync(closeConnections);
  invalidateDelayData();
}

/// Normalizes the comma-separated system-DNS payload from the platform:
/// trims entries, drops empties, dedupes preserving encounter order. The
/// empty input remains "" — a meaningful clear-system-DNS command that must
/// travel through every layer down to the Go resolver.
@visibleForTesting
String normalizeSystemDnsPayload(String value) => value
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toSet()
    .join(',');

class Vpn {
  factory Vpn() {
    _instance ??= Vpn._internal();
    return _instance!;
  }

  Vpn._internal() {
    methodChannel = const MethodChannel("vpn");
    methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case "gc":
          clashCore.requestGc();
        case "getStartForegroundParams":
          if (handleGetStartForegroundParams != null) {
            return await handleGetStartForegroundParams!();
          }
          // Default handler for UI mode - get current proxy name from core
          return await _getDefaultForegroundParams();
        case "status":
          return clashLibHandler?.getRunTime() != null;
        case "networkChanged":
          // The native bearer tracker committed a real physical-bearer
          // replacement beneath the live tunnel (WiFi<->cell, dual-SIM,
          // offline->replacement). Stale upstream proxy sessions (mux,
          // Hy2/QUIC) would otherwise be reused until their own long timeouts
          // — the "minutes-long reconnect". Reset DNS pools, drop the flows,
          // then wipe delay data: measurements from the previous bearer are
          // FICTION on the new one — badges flip to «не замерено» instead of
          // showing stale green numbers; URLTest cycles repopulate honest
          // values. Safe here: networkChanged only fires under a LIVE tunnel,
          // so appController is already initialized — no null-init window.
          final details = call.arguments;
          commonPrint.log(
            "[VPN] BEARER_CHANGE $details — resetting DNS pools and core connections",
          );
          await handleUnderlyingNetworkChanged(
            resetConnections: clashCore.resetConnections,
            closeConnections: clashCore.closeConnections,
            invalidateDelayData:
                globalState.appController.invalidateDelayData,
          );
        case "dnsChanged":
          handleDnsChangedPayload(call.arguments);
      }
    });
  }
  static Vpn? _instance;
  late MethodChannel methodChannel;
  FutureOr<String> Function()? handleGetStartForegroundParams;

  /// Cached server name for foreground notification (updated via updateServerName)
  String _cachedServerName = "";

  /// Cached profile info for foreground notification
  String _cachedProfileName = "dropweb";
  String _cachedServiceName = "";

  /// Update cached server name (called from UI when proxy changes)
  void updateServerName(String serverName) {
    _cachedServerName = serverName;
  }

  /// Update cached profile info (called when profile changes or on init)
  void updateProfileInfo({
    required String profileName,
    required String serviceName,
  }) {
    _cachedProfileName = profileName;
    _cachedServiceName = serviceName;
  }

  /// Get cached server name
  String get cachedServerName => _cachedServerName;

  /// Get cached profile name
  String get cachedProfileName => _cachedProfileName;

  /// Get cached service name
  String get cachedServiceName => _cachedServiceName;

  /// Default foreground params when running in UI mode.
  /// Shows: title = panel profile title (else selected server, else cached
  /// service name, else cached profile name), content = traffic speed,
  /// server (subText) = empty.
  Future<String> _getDefaultForegroundParams() async {
    try {
      // UI-mode traffic read goes through the bridge invoke and is async —
      // it MUST be awaited, else the notification renders a Future instance.
      final traffic = await clashCore.getTraffic();
      final profile = globalState.config.currentProfile;

      // Current proxy/server name
      String? proxyName;
      try {
        final header = profile?.providerHeaders['dropweb-serverinfo'];
        final serverInfoGroupName =
            header == null ? null : decodeMaybeBase64(header);
        if (serverInfoGroupName != null && serverInfoGroupName.isNotEmpty) {
          proxyName = globalState.appController
              .getSelectedProxyName(serverInfoGroupName);
        }
      } catch (e) {
        commonPrint.log('[vpn] failed to resolve selected proxy name: $e');
      }

      // Title: panel profile title (Remnawave `profile-title`, the big
      // dashboard subscription-card title — may be `base64:`-prefixed), else
      // selected server name, else cached service name, else cached profile
      // name. Same preference order as the _service-mode handler in main.dart.
      final rawProfileTitle = profile?.providerHeaders['profile-title'];
      final profileTitle =
          (rawProfileTitle == null || rawProfileTitle.isEmpty)
              ? ""
              : decodeMaybeBase64(rawProfileTitle).trim();
      final serverDisplay = (proxyName ?? "").trim();
      final title = profileTitle.isNotEmpty
          ? profileTitle
          : (serverDisplay.isNotEmpty
              ? serverDisplay
              : (_cachedServiceName.isNotEmpty
                  ? _cachedServiceName
                  : _cachedProfileName));

      return json.encode({
        "title": title,
        "server": "",
        "content":
            "\u2191 ${traffic.up.show}/s  \u2193 ${traffic.down.show}/s",
      });
    } catch (e) {
      return json.encode({
        "title": "dropweb",
        "server": "",
        "content": "",
      });
    }
  }

  final ObserverList<VpnListener> _listeners = ObserverList<VpnListener>();

  /// Extracted dnsChanged dispatch: validates the MethodChannel payload type
  /// but never discards an empty string — empty is a meaningful command
  /// (clear system DNS state after the active bearer was lost).
  @visibleForTesting
  void handleDnsChangedPayload(Object? raw) {
    if (raw is! String) {
      commonPrint.log(
        "[VPN] ignoring malformed dnsChanged payload: ${raw.runtimeType}",
      );
      return;
    }
    final dns = normalizeSystemDnsPayload(raw);
    for (final listener in _listeners) {
      listener.onDnsChanged(dns);
    }
  }

  Future<bool?> start(AndroidVpnOptions options) async =>
      methodChannel.invokeMethod<bool>("start", {
        'data': json.encode(options),
      });

  Future<bool?> stop() async => methodChannel.invokeMethod<bool>("stop");

  /// Show subscription expiration notification
  Future<bool?> showSubscriptionNotification({
    required String title,
    required String message,
    required String actionLabel,
    required String actionUrl,
  }) async =>
      methodChannel.invokeMethod<bool>("showSubscriptionNotification", {
        'title': title,
        'message': message,
        'actionLabel': actionLabel,
        'actionUrl': actionUrl,
      });

  void addListener(VpnListener listener) {
    _listeners.add(listener);
  }

  void removeListener(VpnListener listener) {
    _listeners.remove(listener);
  }
}

Vpn? get vpn {
  // On Android, we always need Vpn instance to handle method channel calls
  // from the VPN service (e.g., getStartForegroundParams)
  if (defaultTargetPlatform == TargetPlatform.android) {
    return Vpn();
  }
  // On other platforms, only create in service mode
  return globalState.isService ? Vpn() : null;
}
