import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/common/archive.dart';
import 'package:dropweb/common/connect_trace.dart';
import 'package:dropweb/common/error_mapper.dart';
import 'package:dropweb/common/work_mode_patch.dart';
import 'package:dropweb/services/subscription_notification_service.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' hide windows;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common/common.dart';
import 'models/models.dart';
import 'plugins/vpn.dart';
import 'views/profiles/override_profile.dart';

/// Decides whether a profile is eligible for automatic subscription update.
///
/// The original [AppController.autoUpdateProfiles] skipped profiles based on
/// `profile.type == ProfileType.file`, which is derived from
/// `profile.url.isEmpty`. After URL migration to `SecureProfileUrlStore` the
/// plaintext `Profile.url` is intentionally empty for URL profiles, so the
/// type-based check misclassifies migrated URL profiles as file profiles and
/// silently disables auto-update for them. This helper instead takes the
/// already-resolved URL (via `preferences.getProfileUrl(profile)`), so the
/// "is there anything to fetch?" decision matches what `Profile.update()`
/// actually uses.
///
/// Skips:
/// * `autoUpdate == false`
/// * no resolved URL (real file profile)
/// * `lastUpdateDate + autoUpdateDuration` still in the future
@visibleForTesting
bool shouldAutoUpdateProfile({
  required Profile profile,
  required DateTime now,
  required String? resolvedUrl,
}) {
  if (!profile.autoUpdate) return false;
  if (resolvedUrl == null || resolvedUrl.isEmpty) return false;
  final nextUpdate = profile.lastUpdateDate?.add(profile.autoUpdateDuration);
  // Preserve original `isBeforeNow` semantics: only update once the next
  // update timestamp is strictly before `now`. `null` lastUpdateDate means
  // "never updated", so it falls through and is treated as due.
  if (nextUpdate != null && !nextUpdate.isBefore(now)) return false;
  return true;
}

/// Decides whether [AppController.checkUpdateResultHandle] should react to a
/// finished update check.
///
/// Pre-release builds (`globalState.isPre == true`) suppress *automatic*
/// startup prompts to avoid noisy prerelease dialogs, but a *manual* check
/// initiated from About → "Проверить обновления" must still produce
/// feedback (either the update dialog or the "latest version" message).
/// Stable builds always proceed.
///
/// [handleError] mirrors the existing `checkUpdateResultHandle` flag:
/// `true` = manual/explicit check (show "latest version" when there is no
/// update), `false` = silent automatic check.
@visibleForTesting
bool shouldHandleUpdateResult({
  required bool isPre,
  required bool handleError,
}) {
  if (!isPre) return true;
  return handleError;
}

/// Whether [AppController.autoCheckUpdate] is allowed to hit the GitHub
/// releases API on startup.
///
/// Android is the Google Play target: Play policy forbids in-app update
/// checks against an external source, so Android always skips the auto
/// check regardless of the persisted `autoCheckUpdate` preference (which
/// can still be flipped on via a subscription `dropweb-settings:
/// autoupdate` header). Non-Android builds keep honouring the user's
/// preference.
@visibleForTesting
bool shouldRunAutoUpdateCheck({
  required bool isAndroid,
  required bool autoCheckUpdate,
}) {
  if (isAndroid) return false;
  return autoCheckUpdate;
}

class AppController {
  AppController(this.context, WidgetRef ref) : _ref = ref;
  int? lastProfileModified;

  /// In-memory hash of the last *effective* config that was successfully pushed
  /// to the core via [_setupClashConfig]. When the freshly computed hash matches
  /// this value we skip the expensive full setup (Go YAML read → JSON → Dart map
  /// patch → JSON → Go ParseRawConfig/ApplyConfig). Never persisted: a fresh app
  /// start always re-runs the full setup. Invalidated on profile switch and on
  /// any setup error.
  String? _lastSetupHash;

  Timer? _profileUpdateTimer;
  final BuildContext context;
  final WidgetRef _ref;

  void setupClashConfigDebounce() {
    debouncer.call(FunctionTag.setupClashConfig, () async {
      await setupClashConfig();
    });
  }

  void updateClashConfigDebounce() {
    debouncer.call(FunctionTag.updateClashConfig, () async {
      await updateClashConfig();
    });
  }

  void updateGroupsDebounce() {
    debouncer.call(FunctionTag.updateGroups, updateGroups);
  }

  void addCheckIpNumDebounce() {
    debouncer.call(FunctionTag.addCheckIpNum, () {
      _ref.read(checkIpNumProvider.notifier).add();
    });
  }

  void applyProfileDebounce({
    bool silence = false,
  }) {
    debouncer.call(FunctionTag.applyProfile, (silence) {
      applyProfile(silence: silence);
    }, args: [silence]);
  }

  void savePreferencesDebounce() {
    debouncer.call(FunctionTag.savePreferences, savePreferences);
  }

  void changeProxyDebounce(String groupName, String proxyName) {
    debouncer.call(FunctionTag.changeProxy,
        (String groupName, String proxyName) async {
      await changeProxy(
        groupName: groupName,
        proxyName: proxyName,
      );
      await updateGroups();
      // Update cached server name for foreground notification
      _updateForegroundServerName(groupName, proxyName);
    }, args: [groupName, proxyName]);
  }

  /// Update cached server name in VPN plugin for foreground notification
  /// Also sends IPC message to service isolate to update selectedMap
  void _updateForegroundServerName(String groupName, String serverName) {
    vpn?.updateServerName(serverName);
    // Send IPC message to service isolate (Android only)
    clashLib?.sendIpcMessage({
      'action': 'updateForegroundServer',
      'groupName': groupName,
      'serverName': serverName,
    });
  }

  /// Initialize foreground notification cache with current profile and server
  void initForegroundCache() {
    final profile = globalState.config.currentProfile;
    if (profile == null) return;

    final profileName = profile.label ?? profile.id;

    // Decode service name from header
    String serviceName = "";
    final svc = profile.providerHeaders['dropweb-servicename'];
    if (svc != null && svc.isNotEmpty) {
      try {
        final normalized = base64.normalize(svc);
        serviceName = utf8.decode(base64.decode(normalized)).trim();
      } catch (_) {
        serviceName = svc.trim();
      }
    }

    vpn?.updateProfileInfo(
      profileName: profileName,
      serviceName: serviceName,
    );

    // Get current server name from selectedMap
    String? groupName = profile.providerHeaders['dropweb-serverinfo'];
    if (groupName != null && groupName.isNotEmpty) {
      String decodedGroupName;
      try {
        final normalized = base64.normalize(groupName);
        decodedGroupName = utf8.decode(base64.decode(normalized)).trim();
      } catch (_) {
        decodedGroupName = groupName.trim();
      }
      final serverName = profile.selectedMap[decodedGroupName] ?? "";
      vpn?.updateServerName(serverName);
    }
  }

  Future<void> restartCore() async {
    commonPrint.log("restart core");
    await clashService?.reStart();
    await _initCore();
    if (_ref.read(runTimeProvider.notifier).isStart) {
      await globalState.handleStart();
    }
  }

  /// Read-only reconcile of Dart VPN state with native runtime. Never toggles VPN.
  Future<void> syncRunStateFromNative() async {
    if (!Platform.isAndroid) return;
    final prevStartTime = globalState.startTime;
    await globalState.updateStartTime();
    final nativeIsRunning = globalState.startTime != null;
    final uiIsRunning = _ref.read(runTimeProvider.notifier).isStart;
    if (nativeIsRunning == uiIsRunning) return;

    commonPrint.log(
      'syncRunStateFromNative: native=$nativeIsRunning ui=$uiIsRunning '
      '(prev startTime=$prevStartTime, new=${globalState.startTime})',
    );

    if (nativeIsRunning) {
      updateRunTime();
    } else {
      // Native already stopped — tear down Dart bookkeeping without re-calling handleStop.
      clashCore.resetTraffic();
      _ref.read(trafficsProvider.notifier).clear();
      _ref.read(totalTrafficProvider.notifier).value = Traffic();
      _ref.read(runTimeProvider.notifier).value = null;
      globalState.stopUpdateTasks();
      await StatusBarManager.updateIcon(isConnected: false);
      addCheckIpNumDebounce();
    }
  }

  Future<void> updateStatus(bool isStart) async {
    if (isStart) {
      ConnectTrace.mark('updateStatus');
      // Central safety gate: every code path that turns the VPN on must
      // pass through here, so first-run disclosure consent is enforced
      // even for non-UI entry points (Quick Settings tile, desktop tray,
      // hotkey, hidden auto-run). Disconnect is intentionally never gated.
      // UI is NOT shown from the controller — the dashboard StartButton is
      // responsible for surfacing the dialog and persisting consent before
      // it calls back into this method. If consent is missing we simply
      // refuse the start so external triggers can't bypass the disclosure.
      if (!await vpnConsent.isAccepted()) {
        commonPrint.log(
          'updateStatus(true) refused: VPN disclosure consent not granted',
        );
        return;
      }
    }
    await StatusBarManager.updateIcon(isConnected: isStart);

    if (isStart) {
      // Regenerate proxy credentials for this session (SOCKS port protection)
      globalState.regenerateProxyCredentials();
      // Initialize foreground notification cache before starting
      initForegroundCache();
      final started = await globalState.handleStart([
        updateRunTime,
        updateTraffic,
      ]);
      if (!started) {
        globalState.showNotifier(ErrorMapper.vpnStartFailed);
        return;
      }
      final currentLastModified =
          await _ref.read(currentProfileProvider)?.profileLastModified;
      if (currentLastModified == null || lastProfileModified == null) {
        addCheckIpNumDebounce();
        return;
      }
      if (currentLastModified <= (lastProfileModified ?? 0)) {
        addCheckIpNumDebounce();
        return;
      }
      applyProfileDebounce();
    } else {
      await globalState.handleStop();
      // Clear credentials on disconnect
      globalState.clearProxyCredentials();
      clashCore.resetTraffic();
      _ref.read(trafficsProvider.notifier).clear();
      _ref.read(totalTrafficProvider.notifier).value = Traffic();
      _ref.read(runTimeProvider.notifier).value = null;
      addCheckIpNumDebounce();
    }
  }

  void updateRunTime() {
    final startTime = globalState.startTime;
    if (startTime != null) {
      final startTimeStamp = startTime.millisecondsSinceEpoch;
      final nowTimeStamp = DateTime.now().millisecondsSinceEpoch;
      _ref.read(runTimeProvider.notifier).value = nowTimeStamp - startTimeStamp;
    } else {
      _ref.read(runTimeProvider.notifier).value = null;
    }
  }

  Future<void> updateTraffic() async {
    final traffic = await clashCore.getTraffic();
    _ref.read(trafficsProvider.notifier).addTraffic(traffic);
    _ref.read(totalTrafficProvider.notifier).value =
        await clashCore.getTotalTraffic();
  }

  Future<void> addProfile(Profile profile) async {
    _ref.read(profilesProvider.notifier).setProfile(profile);
    // Always select the freshly added profile so importing a config switches
    // to it (previously it only auto-selected when no profile existed yet).
    _ref.read(currentProfileIdProvider.notifier).value = profile.id;
    applyProfileDebounce(silence: true);
  }

  Future<void> deleteProfile(String id) async {
    _ref.read(profilesProvider.notifier).deleteProfileById(id);
    clearEffect(id);
    if (globalState.config.currentProfileId == id) {
      final profiles = globalState.config.profiles;
      final currentProfileId = _ref.read(currentProfileIdProvider.notifier);
      if (profiles.isNotEmpty) {
        final updateId = profiles.first.id;
        currentProfileId.value = updateId;
      } else {
        currentProfileId.value = null;
        updateStatus(false);
      }
    }
  }

  Future<void> updateProviders() async {
    _ref.read(providersProvider.notifier).value =
        await clashCore.getExternalProviders();
  }

  Future<void> updateLocalIp() async {
    _ref.read(localIpProvider.notifier).value = null;
    await Future.delayed(commonDuration);
    _ref.read(localIpProvider.notifier).value = await utils.getLocalIpAddress();
  }

  void applySubscriptionSettings(Set<String>? settings) {
    try {
      final currentSettings = _ref.read(appSettingProvider);
      if (currentSettings.overrideProviderSettings) {
        commonPrint.log(
            "Override provider settings enabled - ignoring subscription settings");
        return;
      }

      // If settings is null (header removed), reset to defaults (false)
      final effectiveSettings = settings ?? {};

      _ref
          .read(appSettingProvider.notifier)
          .updateState((state) => state.copyWith(
                minimizeOnExit: effectiveSettings.contains('minimize'),
                autoLaunch: effectiveSettings.contains('autorun'),
                silentLaunch: effectiveSettings.contains('shadowstart'),
                autoRun: effectiveSettings.contains('autostart'),
                autoCheckUpdate: effectiveSettings.contains('autoupdate'),
              ));
    } catch (e) {
      // Silently ignore subscription settings errors
    }
  }

  void _applyAllHeaderSettings(Profile profile, {required bool isNewProfile}) {
    final headers = profile.providerHeaders;
    if (headers.isEmpty) return;

    final customBehavior = headers['dropweb-custom'];

    final shouldApply = switch (customBehavior) {
      'add' => isNewProfile,
      'update' => true,
      _ => false,
    };

    if (!shouldApply) return;

    _applyProviderSettings(headers);
    _applyThemeColor(headers);
    _applyCustomViewSettings(profile);
  }

  void applyActiveProfileHeaders() {
    final id = _ref.read(currentProfileIdProvider);
    if (id == null) return;
    final profiles = _ref.read(profilesProvider);
    final profile = profiles.where((p) => p.id == id).firstOrNull;
    if (profile == null || profile.providerHeaders.isEmpty) return;
    _applyAllHeaderSettings(profile, isNewProfile: false);
  }

  void _applyProviderSettings(Map<String, String> headers) {
    try {
      final currentSettings = _ref.read(appSettingProvider);
      if (currentSettings.overrideProviderSettings) {
        commonPrint.log(
            "Override provider settings enabled - ignoring provider settings");
        return;
      }

      final settingsHeader = headers['dropweb-settings'];
      if (settingsHeader != null) {
        final settings = settingsHeader
            .split(',')
            .map((s) => s.trim().toLowerCase())
            .where((s) => s.isNotEmpty)
            .toSet();
        applySubscriptionSettings(settings);
      }
    } catch (e) {
      commonPrint.log("Failed to apply provider settings: $e");
    }
  }

  void _applyThemeColor(Map<String, String> headers) {
    try {
      final applyTheme = _ref.read(appSettingProvider).applySubscriptionTheme;
      if (!applyTheme) {
        commonPrint.log(
            "Apply subscription theme disabled - ignoring operator theme");
        return;
      }
      final themeHeader = headers['dropweb-theme'];
      if (themeHeader != null && themeHeader.isNotEmpty) {
        _applyDropwebTheme(themeHeader);
      }
    } catch (e) {
      commonPrint.log("Failed to apply theme color: $e");
    }
  }

  /// Resets operator-applied (subscription) theme accents back to the dropweb
  /// defaults. Called when switching profiles so a profile WITHOUT a
  /// `dropweb-theme` header doesn't keep the previously selected operator's
  /// colors. Only the subscription-controlled fields are reset; the user's
  /// palette, text scale, pure-black and theme mode are preserved.
  void _resetSubscriptionTheme() {
    _ref.read(themeSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            primaryColor: defaultPrimaryColor,
            orbColorPrimary: 0xFF009938,
            orbColorSecondary: 0xFF2BFF7A,
            schemeVariant: DynamicSchemeVariant.fidelity,
            orbBlur: 4.0,
          ),
        );
  }

  /// Parses `<filter>,<accentHex>,<orb1Hex>,<orb2Hex>,<blur>` (all optional).
  void _applyDropwebTheme(String header) {
    try {
      final parts = header.split(',').map((s) => s.trim()).toList();

      DynamicSchemeVariant? variant;
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        final name = parts[0].toLowerCase();
        for (final v in DynamicSchemeVariant.values) {
          if (v.name.toLowerCase() == name) {
            variant = v;
            break;
          }
        }
      }

      final accent = parts.length > 1 && parts[1].isNotEmpty
          ? _parseHexColorValue(parts[1].replaceAll('#', ''))
          : null;
      final orb1 = parts.length > 2 && parts[2].isNotEmpty
          ? _parseHexColorValue(parts[2].replaceAll('#', ''))
          : null;
      final orb2 = parts.length > 3 && parts[3].isNotEmpty
          ? _parseHexColorValue(parts[3].replaceAll('#', ''))
          : null;
      final blur = parts.length > 4 && parts[4].isNotEmpty
          ? double.tryParse(parts[4])?.clamp(1.0, 5.0)
          : null;

      commonPrint.log('Applying dropweb-theme: filter=${variant?.name}, '
          'accent=$accent, orb1=$orb1, orb2=$orb2, blur=$blur');

      _ref.read(themeSettingProvider.notifier).updateState((state) {
        final colors = [...state.primaryColors];
        if (accent != null && !colors.contains(accent)) colors.add(accent);
        return state.copyWith(
          primaryColor: accent ?? state.primaryColor,
          primaryColors: colors,
          orbColorPrimary: orb1 ?? state.orbColorPrimary,
          orbColorSecondary: orb2 ?? state.orbColorSecondary,
          schemeVariant: variant ?? state.schemeVariant,
          orbBlur: blur ?? state.orbBlur,
        );
      });

      savePreferencesDebounce();
    } catch (e) {
      commonPrint.log('Failed to parse dropweb-theme: $header - $e');
    }
  }

  /// 6/8-digit hex (no '#') to ARGB int, or null if invalid.
  int? _parseHexColorValue(String hexString) {
    if (hexString.length != 6 && hexString.length != 8) {
      return null;
    }
    try {
      return int.parse(
        hexString.length == 6 ? 'FF$hexString' : hexString,
        radix: 16,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> updateProfile(Profile profile) async {
    // Re-read the latest profile state by id rather than trusting the passed
    // snapshot. Callers (auto-update timer loop, dashboard pull-to-refresh,
    // card/subscription/profiles/edit menus) capture a Profile possibly long
    // before this runs; a concurrent applyWorkMode / selectedMap edit may have
    // landed in between. Using the stale snapshot here would overwrite those
    // fresh workMode/staticCountry/staticStrictNode/selectedMap values and
    // silently revert the user's choice. `profile.id` is only an identity key.
    // (A tiny residual window also exists inside applyWorkMode between its
    // currentProfileProvider read and setProfile; user-initiated + sub-second,
    // accepted for now without locking.)
    final latest =
        _ref.read(profilesProvider).getProfile(profile.id) ?? profile;
    final prefs = await SharedPreferences.getInstance();
    final shouldSend = prefs.getBool('sendDeviceHeaders') ?? true;
    final newProfile = await latest.update(
      shouldSendHeaders: shouldSend,
    );

    final headers = newProfile.providerHeaders;
    if (headers.isNotEmpty) {
      _applyAllHeaderSettings(newProfile, isNewProfile: false);
    }

    final showHwidLimit = headers['x-hwid-limit']?.toLowerCase() == 'true';
    final announceText = headers['announce'];
    if (showHwidLimit && announceText != null && announceText.isNotEmpty) {
      _showHwidLimitNotice(announceText, headers['support-url']);
    }

    final finalProfile =
        await _revalidateWorkMode(newProfile.copyWith(isUpdating: false));
    _ref.read(profilesProvider.notifier).setProfile(finalProfile);

    if (profile.id == _ref.read(currentProfileIdProvider)) {
      applyProfileDebounce(silence: true);
      unawaited(_updateGeoFilesAfterProfileUpdate().catchError((e) {
        commonPrint.log("Error updating geo files: $e");
      }));
    }

    // Check subscription expiration and show notification if needed
    unawaited(SubscriptionNotificationService.checkAndNotify(newProfile)
        .catchError((e) {
      commonPrint.log("Error checking subscription: $e");
    }));
  }

  void _showHwidLimitNotice(String encodedText, String? supportUrl) {
    String? announceText;
    var textToDecode = encodedText;

    if (encodedText.startsWith('base64:')) {
      textToDecode = encodedText.substring(7);
    }

    try {
      final normalized = base64.normalize(textToDecode);
      announceText = utf8.decode(base64.decode(normalized));
    } catch (e) {
      announceText = encodedText;
    }

    if (announceText.isNotEmpty) {
      final actions = <Widget>[];

      if (supportUrl != null && supportUrl.isNotEmpty) {
        actions.add(
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              globalState.openUrl(supportUrl);
            },
            child: Text(appLocalizations.support),
          ),
        );
      }

      actions.add(
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.confirm),
        ),
      );

      globalState.showCommonDialog(
        child: CommonDialog(
          title: appLocalizations.tip,
          actions: actions,
          child: Container(
            width: 300,
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: SelectableText(
                announceText,
                style: const TextStyle(
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<Map<String, String>?> _getRemoteFileMetadata(String url) async {
    try {
      final response = await http.head(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) {
        return null;
      }

      final metadata = <String, String>{};

      final etag = response.headers['etag'];
      if (etag != null && etag.isNotEmpty) {
        metadata['etag'] = etag;
      }

      final lastModified = response.headers['last-modified'];
      if (lastModified != null && lastModified.isNotEmpty) {
        metadata['last-modified'] = lastModified;
      }

      final contentLength = response.headers['content-length'];
      if (contentLength != null && contentLength.isNotEmpty) {
        metadata['content-length'] = contentLength;
      }

      return metadata.isEmpty ? null : metadata;
    } catch (e) {
      commonPrint.log("Failed to get remote file metadata for $url: $e");
      return null;
    }
  }

  String _getMetadataKey(String profileId, String key) =>
      'geo_metadata_${profileId}_$key';

  Future<Map<String, String>?> _getSavedMetadata(
      String profileId, String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = _getMetadataKey(profileId, key);
      final jsonString = prefs.getString(storageKey);
      if (jsonString == null) return null;
      return Map<String, String>.from(json.decode(jsonString));
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveMetadata(
      String profileId, String key, Map<String, String> metadata) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = _getMetadataKey(profileId, key);
      await prefs.setString(storageKey, json.encode(metadata));
    } catch (e) {
      commonPrint.log("Failed to save metadata for $key: $e");
    }
  }

  bool _hasMetadataChanged(
      Map<String, String>? oldMeta, Map<String, String>? newMeta) {
    if (oldMeta == null || newMeta == null) return true;

    if (newMeta['etag'] != null && oldMeta['etag'] != null) {
      return newMeta['etag'] != oldMeta['etag'];
    }

    if (newMeta['last-modified'] != null && oldMeta['last-modified'] != null) {
      return newMeta['last-modified'] != oldMeta['last-modified'];
    }

    if (newMeta['content-length'] != null &&
        oldMeta['content-length'] != null) {
      return newMeta['content-length'] != oldMeta['content-length'];
    }

    return true;
  }

  Future<void> _updateGeoFilesAfterProfileUpdate(
      {bool forceUpdate = false}) async {
    try {
      final currentProfileId = _ref.read(currentProfileIdProvider);
      if (currentProfileId == null) return;

      final profileConfig =
          await globalState.getProfileConfig(currentProfileId);

      final geodataMode = profileConfig["geodata-mode"];
      if (geodataMode != true) {
        commonPrint.log(
            "Geodata updates are disabled by profile (geodata-mode != true)");
        return;
      }

      final geoXUrl = profileConfig["geox-url"];

      if (geoXUrl == null || geoXUrl is! Map) {
        commonPrint.log("No geox-url found in profile config");
        return;
      }

      final geoFiles = [
        {'type': 'GeoIp', 'name': geoIpFileName, 'key': 'geoip'},
        {'type': 'MMDB', 'name': mmdbFileName, 'key': 'mmdb'},
        {'type': 'GeoSite', 'name': geoSiteFileName, 'key': 'geosite'},
        {'type': 'ASN', 'name': asnFileName, 'key': 'asn'},
      ];

      // Counters for logging purposes (values used in log messages via increment)
      // ignore: unused_local_variable
      var updatedCount = 0;
      // ignore: unused_local_variable
      var skippedCount = 0;

      for (final geoFile in geoFiles) {
        final geoType = geoFile['type']!;
        final fileName = geoFile['name']!;
        final key = geoFile['key']!;

        final url = geoXUrl[key];
        if (url == null || url is! String || url.isEmpty) {
          commonPrint.log("No URL for $fileName, skipping");
          continue;
        }

        try {
          final remoteMetadata = await _getRemoteFileMetadata(url);
          if (remoteMetadata == null) {
            commonPrint.log("Failed to get metadata for $fileName from $url");
            continue;
          }

          final savedMetadata = await _getSavedMetadata(currentProfileId, key);

          if (!forceUpdate &&
              !_hasMetadataChanged(savedMetadata, remoteMetadata)) {
            commonPrint.log(
                "$fileName is up to date for profile $currentProfileId, skipping download");
            skippedCount++;
            continue;
          }

          final reason = forceUpdate ? "force update" : "metadata changed";
          commonPrint.log(
              "$fileName needs update for profile $currentProfileId ($reason), downloading from $url...");
          final result = await clashCore.updateGeoData(
            UpdateGeoDataParams(geoType: geoType, geoName: fileName),
          );

          if (result.isNotEmpty) {
            commonPrint.log("Failed to update $fileName: $result");
            continue;
          }

          await _saveMetadata(currentProfileId, key, remoteMetadata);
          commonPrint.log(
              "$fileName was successfully updated for profile $currentProfileId from $url");
          updatedCount++;
        } catch (e) {
          commonPrint.log("Failed to update $fileName: $e");
        }
      }
    } catch (e) {
      commonPrint.log("Failed to update geo files after profile update: $e");
    }
  }

  void setProfile(Profile profile) {
    _ref.read(profilesProvider.notifier).setProfile(profile);
  }

  void setProfileAndAutoApply(Profile profile) {
    _ref.read(profilesProvider.notifier).setProfile(profile);
    if (profile.id == _ref.read(currentProfileIdProvider)) {
      applyProfileDebounce(silence: true);
    }
  }

  /// Like [setProfileAndAutoApply] but first re-validates the profile's work
  /// mode against the FRESH on-disk config. Use this on the LOCAL profile-edit
  /// save path (file edit / upload) — a country whose nodes vanished, or a strict
  /// node that disappeared, would otherwise dangle (revalidation only runs on the
  /// subscription-update path). Mirrors [updateProfile]'s revalidate-then-persist
  /// order. The revalidation reads the config via `getProfileConfig`, so it must
  /// run AFTER the new file bytes are written (i.e. after `profile.saveFile`).
  Future<void> setProfileWithRevalidationAndAutoApply(Profile profile) async {
    final revalidated = await _revalidateWorkMode(profile);
    setProfileAndAutoApply(revalidated);
  }

  void setProfiles(List<Profile> profiles) {
    _ref.read(profilesProvider.notifier).value = profiles;
  }

  void addLog(Log log) {
    _ref.read(logsProvider).add(log);
  }

  void updateOrAddHotKeyAction(HotKeyAction hotKeyAction) {
    final hotKeyActions = _ref.read(hotKeyActionsProvider);
    final index =
        hotKeyActions.indexWhere((item) => item.action == hotKeyAction.action);
    if (index == -1) {
      _ref.read(hotKeyActionsProvider.notifier).value = List.from(hotKeyActions)
        ..add(hotKeyAction);
    } else {
      _ref.read(hotKeyActionsProvider.notifier).value = List.from(hotKeyActions)
        ..[index] = hotKeyAction;
    }

    _ref.read(hotKeyActionsProvider.notifier).value = index == -1
        ? (List.from(hotKeyActions)..add(hotKeyAction))
        : (List.from(hotKeyActions)..[index] = hotKeyAction);
  }

  List<Group> getCurrentGroups() =>
      _ref.read(currentGroupsStateProvider.select((state) => state.value));

  String getRealTestUrl(String? url) => _ref.read(getRealTestUrlProvider(url));

  int getProxiesColumns() => _ref.read(getProxiesColumnsProvider);

  dynamic addSortNum() => _ref.read(sortNumProvider.notifier).add();

  String? getCurrentGroupName() {
    final currentGroupName = _ref.read(currentProfileProvider.select(
      (state) => state?.currentGroupName,
    ));
    return currentGroupName;
  }

  ProxyCardState getProxyCardState(proxyName) =>
      _ref.read(getProxyCardStateProvider(proxyName));

  String? getSelectedProxyName(groupName) =>
      _ref.read(getSelectedProxyNameProvider(groupName));

  void updateCurrentGroupName(String groupName) {
    final profile = _ref.read(currentProfileProvider);
    if (profile == null || profile.currentGroupName == groupName) {
      return;
    }
    setProfile(
      profile.copyWith(currentGroupName: groupName),
    );
  }

  Future<void> updateClashConfig() async {
    final commonScaffoldState = globalState.homeScaffoldKey.currentState;
    if (commonScaffoldState?.mounted != true) return;
    await commonScaffoldState?.loadingRun(() async {
      await _updateClashConfig();
    });
  }

  Future<void> _updateClashConfig() async {
    final updateParams = _ref.read(updateParamsProvider);
    final res = await _requestAdmin(updateParams.tun.enable);
    if (res.isError) {
      return;
    }
    final realTunEnable = _ref.read(realTunEnableProvider);
    final message = await clashCore.updateConfig(
      updateParams.copyWith.tun(
        enable: realTunEnable,
      ),
    );
    if (message.isNotEmpty) throw message;
  }

  Future<Result<bool>> _requestAdmin(bool enableTun) async {
    final realTunEnable = _ref.read(realTunEnableProvider);
    if (enableTun != realTunEnable && realTunEnable == false) {
      final code = await system.authorizeCore();
      switch (code) {
        case AuthorizeCode.success:
          await restartCore();
          return Result.error("");
        case AuthorizeCode.none:
          break;
        case AuthorizeCode.error:
          enableTun = false;
          break;
      }
    }
    _ref.read(realTunEnableProvider.notifier).value = enableTun;
    return Result.success(enableTun);
  }

  Future<void> setupClashConfig() async {
    final commonScaffoldState = globalState.homeScaffoldKey.currentState;
    if (commonScaffoldState?.mounted != true) return;
    await commonScaffoldState?.loadingRun(() async {
      await _setupClashConfig();
    });
  }

  Future<void> _setupClashConfig() async {
    await _ref.read(currentProfileProvider)?.checkAndUpdate();
    var patchConfig = _ref.read(patchClashConfigProvider);

    // Sync network settings from provider config if not overriding
    final appSetting = _ref.read(appSettingProvider);
    if (!appSetting.overrideNetworkSettings) {
      final syncedConfig =
          await globalState.syncNetworkSettingsFromProvider(patchConfig);
      // Always update provider when using provider settings to ensure UI reflects config
      _ref
          .read(patchClashConfigProvider.notifier)
          .updateState((state) => syncedConfig);
      patchConfig = syncedConfig;
    }

    final res = await _requestAdmin(patchConfig.tun.enable);
    if (res.isError) {
      return;
    }
    final realTunEnable = _ref.read(realTunEnableProvider);
    // The effective mihomo mode is DERIVED from the current profile's work mode
    // (Country ⇒ global, everything else ⇒ rule), mirroring how realTunEnable
    // overrides tun.enable. The persisted patchClashConfig.mode (the old
    // rule/global UI axis) is irrelevant on this path — work mode owns it now.
    final workMode =
        _ref.read(currentProfileProvider)?.workMode ?? WorkMode.standard;
    final effectiveMode =
        workMode == WorkMode.country ? Mode.global : Mode.rule;
    // Write the derived mode back into the provider so EVERY consumer reads the
    // mode the core actually runs, not the stale rule/global UI axis:
    //   • currentGroupsState (state.dart) filters groups on patchConfig.mode —
    //     a Country profile runs global, so GroupName.GLOBAL must be visible.
    //   • trayState.mode (the desktop checkmark) and the VPN notification's
    //     mode label (service isolate, fed via the 'updateMode' IPC below).
    // Loop-safety: this mutates only `mode`. It does NOT touch needSetupProvider
    // (the only trigger for handleChangeProfile → _setupClashConfig), so it can
    // never re-enter this method. It DOES change updateParamsProvider (which
    // selects `mode`), whose ClashManager listener fires updateClashConfigDebounce
    // → _updateClashConfig → core.updateConfig — the correct live mode-change
    // effect. That path never writes `mode` back, and copyWith with an unchanged
    // mode yields a value-equal (Freezed) state Riverpod drops, so the write is
    // idempotent and cannot loop. The `!= ` guard keeps it a no-op on steady state.
    if (patchConfig.mode != effectiveMode) {
      _ref
          .read(patchClashConfigProvider.notifier)
          .updateState((state) => state.copyWith(mode: effectiveMode));
      patchConfig = patchConfig.copyWith(mode: effectiveMode);
      // Keep the service-isolate notification label in sync. The deleted
      // changeMode() used to send this; mode is derived now, so the single
      // place that changes mode is also the single place that emits the IPC.
      clashLib?.sendIpcMessage({
        'action': 'updateMode',
        'mode': effectiveMode.name,
      });
    }
    final realPatchConfig = patchConfig.copyWith
        .tun(enable: realTunEnable)
        .copyWith(mode: effectiveMode);

    // Content-hash gate: skip the expensive full core setup when nothing that
    // affects the effective config changed. checkAndUpdate (may rewrite the
    // profile file → new mtime) and _requestAdmin (sets realTunEnable →
    // realPatchConfig) have already run above, so their side effects are
    // reflected in the inputs below. Only getSetupParams + setupConfig +
    // lastProfileModified bookkeeping are skipped on a hit.
    final setupHash = await _computeSetupHash(realPatchConfig);
    if (setupHash != null && setupHash == _lastSetupHash) {
      commonPrint.log('[trace] setup skipped (hash match)');
      return;
    }

    // Geo safety net: regular init now copies the bundled geo assets lazily, so
    // a profile that enables geodata after first launch may not have the four
    // geo files on disk yet. Stat-and-copy them here, right before core setup,
    // only when the effective profile actually needs geodata. Sits after the
    // hash gate on purpose: a hash hit means the effective config didn't change,
    // so the geo state is already correct and nothing needs copying.
    await Geodata.ensureGeoFilesIfNeeded(
      await Geodata.currentProfileNeedsGeodata(),
    );

    final params = await globalState.getSetupParams(
      pathConfig: realPatchConfig,
    );
    final message = await clashCore.setupConfig(params);
    lastProfileModified = await _ref.read(
      currentProfileProvider.select(
        (state) => state?.profileLastModified,
      ),
    );
    if (message.isNotEmpty) {
      // Setup failed — do not record the hash, so the next attempt re-runs.
      _lastSetupHash = null;
      throw message;
    }
    // Only record the hash after a successful core setup.
    _lastSetupHash = setupHash;
  }

  /// Builds the content hash for [_setupClashConfig]'s cache gate over the
  /// inputs that actually feed `patchRawConfig`. Returns null when there is no
  /// current profile (nothing meaningful to cache), forcing a full setup.
  ///
  /// `appFlags` enumerates exactly the `config.appSetting` / `config.networkProps`
  /// / script reads inside `patchRawConfig` that branch the patching logic:
  ///   * overrideNetworkSettings — gates the find-process/allow-lan/ipv6/
  ///     mixed-port + tun.stack override branches.
  ///   * routeMode — feeds `tun.getRealTun(...)`.
  ///   * overrideDns — gates the DNS override branch.
  ///   * scriptId / scriptContent — `handleEvaluate` runs the current script;
  ///     editing it (same id, new content) changes the patched output.
  /// selectedMap is deliberately excluded (applied via changeProxy).
  Future<String?> _computeSetupHash(ClashConfig realPatchConfig) async {
    final profile = _ref.read(currentProfileProvider);
    if (profile == null) {
      return null;
    }
    int profileFileLength = 0;
    DateTime? profileFileLastModified;
    try {
      final path = await appPath.getProfilePath(profile.id);
      final file = File(path);
      if (await file.exists()) {
        profileFileLength = await file.length();
        profileFileLastModified = await file.lastModified();
      }
    } catch (_) {
      // If the file can't be stat'd, fall through with zero/null markers; the
      // hash stays deterministic for that (degenerate) state.
    }

    final config = globalState.config;
    final currentScript = config.scriptProps.currentScript;
    final appFlags = <String, dynamic>{
      'overrideNetworkSettings': config.appSetting.overrideNetworkSettings,
      'routeMode': config.networkProps.routeMode.name,
      'overrideDns': config.overrideDns,
      'scriptId': currentScript?.id,
      'scriptContent': currentScript?.content,
      // Work mode lives on Profile in config JSON (NOT the profile file), and
      // it drives both `applyWorkModePatch` (additive group) and the derived
      // mihomo mode. Without these in the hash a mode switch would not rebuild
      // the config (Block A cache would short-circuit it). CRITICAL.
      'workMode': profile.workMode.name,
      'staticCountry': profile.staticCountry,
    };

    return computeSetupHash(
      profileId: profile.id,
      profileFileLastModified: profileFileLastModified,
      profileFileLength: profileFileLength,
      patchConfigJson: realPatchConfig.toJson(),
      overrideDataJson: profile.overrideData.toJson(),
      appFlagsJson: appFlags,
    );
  }

  Future _applyProfile() async {
    clashCore.requestGc();
    await setupClashConfig();
    await updateGroups();
    await updateProviders();
  }

  Future applyProfile({bool silence = false}) async {
    if (silence) {
      await _applyProfile();
    } else {
      final commonScaffoldState = globalState.homeScaffoldKey.currentState;
      if (commonScaffoldState?.mounted != true) return;
      await commonScaffoldState?.loadingRun(() async {
        await _applyProfile();
      });
    }
    addCheckIpNumDebounce();
  }

  void handleChangeProfile() {
    // Switching profiles changes the effective config independently of any
    // single hashed input, so force a full setup on the next run.
    _lastSetupHash = null;
    _ref.read(delayDataSourceProvider.notifier).value = {};

    final currentProfileId = _ref.read(currentProfileIdProvider);
    if (currentProfileId != null) {
      final profiles = _ref.read(profilesProvider);
      var currentProfile = profiles.firstWhere(
        (p) => p.id == currentProfileId,
        orElse: () => profiles.first,
      );

      // Drop the previous operator's theme first so switching to a profile
      // without a `dropweb-theme` header reverts to the dropweb default
      // instead of inheriting stale colors. Then re-apply this profile's own
      // theme/header settings if it has any.
      if (_ref.read(appSettingProvider).applySubscriptionTheme) {
        _resetSubscriptionTheme();
      }

      if (currentProfile.providerHeaders.isNotEmpty) {
        _applyAllHeaderSettings(currentProfile, isNewProfile: false);
      }
    }

    applyProfile();
    _ref.read(logsProvider.notifier).value = FixedList(500);
    _ref.read(requestsProvider.notifier).value = FixedList(500);
    globalState.cacheHeightMap = {};
    globalState.cacheScrollPosition = {};

    if (currentProfileId != null) {
      _updateGeoFilesAfterProfileUpdate(forceUpdate: true).catchError((e) {
        commonPrint.log("Error updating geo files on profile change: $e");
      });
    }
  }

  void updateBrightness(Brightness brightness) {
    _ref.read(appBrightnessProvider.notifier).value = brightness;
  }

  Future<void> autoUpdateProfiles() async {
    for (final profile in _ref.read(profilesProvider)) {
      // Cheap checks first: profiles with `autoUpdate == false` or whose
      // next-update timestamp is still in the future are skipped without
      // touching secure storage. The secure-store read happens only when
      // those gates pass; due file profiles still cost one resolved-URL
      // lookup to confirm they have no URL to fetch.
      if (!profile.autoUpdate) continue;
      final nextUpdate =
          profile.lastUpdateDate?.add(profile.autoUpdateDuration);
      if (nextUpdate != null && !nextUpdate.isBefore(DateTime.now())) {
        continue;
      }

      final resolvedUrl = await preferences.getProfileUrl(profile);
      if (!shouldAutoUpdateProfile(
        profile: profile,
        now: DateTime.now(),
        resolvedUrl: resolvedUrl,
      )) {
        continue;
      }
      try {
        await updateProfile(profile);
      } catch (e) {
        commonPrint.log(e.toString());
      }
    }
  }

  /// Updates subscription info for the current profile on app startup.
  /// This ensures the subscription info is always up-to-date when the app launches.
  Future<void> _updateCurrentProfileSubscription() async {
    try {
      final currentProfileId = _ref.read(currentProfileIdProvider);
      commonPrint.log(
          "_updateCurrentProfileSubscription: currentProfileId = $currentProfileId");
      if (currentProfileId == null) {
        commonPrint.log(
            "_updateCurrentProfileSubscription: No current profile selected, skipping");
        return;
      }

      final profiles = _ref.read(profilesProvider);
      commonPrint.log(
          "_updateCurrentProfileSubscription: profiles count = ${profiles.length}");

      final currentProfile =
          profiles.where((p) => p.id == currentProfileId).firstOrNull;
      if (currentProfile == null) {
        commonPrint.log(
            "_updateCurrentProfileSubscription: Profile not found in list, skipping");
        return;
      }

      // Use the resolved subscription URL (from secure storage) instead of
      // `currentProfile.type`, which is `ProfileType.file` for migrated URL
      // profiles whose plaintext `Profile.url` is empty.
      final resolvedUrl = await preferences.getProfileUrl(currentProfile);
      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        commonPrint.log(
            "_updateCurrentProfileSubscription: No subscription URL available, skipping");
        return;
      }

      commonPrint.log(
          "Updating subscription info for current profile '${currentProfile.label}' on startup...");
      await updateProfile(currentProfile);
      commonPrint.log("Subscription info updated successfully");
    } catch (e, stackTrace) {
      commonPrint.log("Failed to update subscription info on startup: $e");
      commonPrint.log("Stack trace: $stackTrace");
    }
  }

  Future<void> updateGroups() async {
    try {
      final newGroups = await retry(
        task: () async => clashCore.getProxiesGroups(),
        retryIf: (res) => res.isEmpty,
      );

      if (newGroups.isNotEmpty) {
        _ref.read(groupsProvider.notifier).value = newGroups;
        _ref.read(versionProvider.notifier).value =
            _ref.read(versionProvider) + 1;
      } else {
        commonPrint
            .log("updateGroups: received empty groups, keeping old state");
      }
    } catch (e) {
      commonPrint.log("updateGroups error: $e, keeping old groups");
    }
  }

  Future<void> updateProfiles() async {
    for (final profile in _ref.read(profilesProvider)) {
      if (profile.type == ProfileType.file) {
        continue;
      }
      await updateProfile(profile);
    }
  }

  Future<void> savePreferences() async {
    commonPrint.log("save preferences");
    await preferences.saveConfig(globalState.config);
  }

  Future<void> changeProxy({
    required String groupName,
    required String proxyName,
  }) async {
    await clashCore.changeProxy(
      ChangeProxyParams(
        groupName: groupName,
        proxyName: proxyName,
      ),
    );
    if (_ref.read(appSettingProvider).closeConnections) {
      clashCore.closeConnections();
    }
    addCheckIpNumDebounce();
  }

  Future<void> handleBackOrExit() async {
    if (_ref.read(backBlockProvider)) {
      return;
    }
    if (_ref.read(appSettingProvider).minimizeOnExit) {
      if (system.isDesktop) {
        savePreferencesDebounce();
      }
      await system.back();
    } else {
      await handleExit();
    }
  }

  void backBlock() {
    _ref.read(backBlockProvider.notifier).value = true;
  }

  void unBackBlock() {
    _ref.read(backBlockProvider.notifier).value = false;
  }

  Future<void> handleExit() async {
    _profileUpdateTimer?.cancel();
    Future.delayed(commonDuration, system.exit);
    try {
      await savePreferences();
      await system.setMacOSDns(true);
      await proxy?.stopProxy();
      await clashCore.shutdown();
      await clashService?.destroy();
    } finally {
      system.exit();
    }
  }

  Future<void> handleRestart() async {
    commonPrint.log("Starting application restart...");

    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      final executablePath = Platform.resolvedExecutable;
      commonPrint.log("Launching new process: $executablePath");

      try {
        await Process.start(
          executablePath,
          [],
          mode: ProcessStartMode.detached,
        );
        commonPrint.log("New process started, exiting old process...");
      } catch (e) {
        commonPrint.log("Failed to start new process: $e");
        return;
      }
    }

    system.exit();
  }

  Future handleClear() async {
    try {
      // Stop proxy/VPN first
      await globalState.handleStop();
      commonPrint.log("stopped proxy/VPN");

      // Stop core
      await clashCore.shutdown();
      commonPrint.log("shutdown core");

      // Wait a bit for all file handles to close
      await Future.delayed(const Duration(milliseconds: 500));

      // Clear preferences
      await preferences.clearPreferences();
      commonPrint.log("cleared preferences");

      // Get paths
      final homePath = await appPath.homeDirPath;
      final profilesPath = await appPath.profilesPath;

      // Delete profiles directory
      final profilesDir = Directory(profilesPath);
      if (await profilesDir.exists()) {
        try {
          await profilesDir.delete(recursive: true);
          commonPrint.log("deleted profiles directory");
        } catch (e) {
          commonPrint.log("failed to delete profiles directory: $e");
        }
      }

      // Delete cache and temporary files
      final filesToDelete = [
        'cache.db',
        'libCachedImageData.json',
        'dropweb.lock',
      ];

      for (final fileName in filesToDelete) {
        final file = File(join(homePath, fileName));
        if (await file.exists()) {
          try {
            await file.delete();
            commonPrint.log("deleted $fileName");
          } catch (e) {
            commonPrint.log("failed to delete $fileName: $e");
          }
        }
      }

      // Reset config
      globalState.config = const Config(
        themeProps: defaultThemeProps,
      );

      commonPrint.log("handleClear completed");

      // Close file logger to release file handles (MUST be last step)
      await fileLogger.dispose();
    } catch (e) {
      commonPrint.log("handleClear error: $e");
      await fileLogger.dispose();
      rethrow;
    }
  }

  Future<void> autoCheckUpdate() async {
    if (!shouldRunAutoUpdateCheck(
      isAndroid: Platform.isAndroid,
      autoCheckUpdate: _ref.read(appSettingProvider).autoCheckUpdate,
    )) {
      return;
    }
    final res = await request.checkForUpdate();
    checkUpdateResultHandle(data: res);
  }

  /// Resolves a safe, release-specific URL from a GitHub release payload.
  /// Prefers the release's own `html_url`, falls back to a tagged URL,
  /// and finally to the generic `releases/latest` page.
  String _resolveReleaseUrl(Map<String, dynamic> data) {
    final htmlUrl = data['html_url'];
    if (htmlUrl is String && htmlUrl.isNotEmpty) {
      final parsed = Uri.tryParse(htmlUrl);
      if (parsed != null && parsed.hasScheme) {
        return htmlUrl;
      }
    }
    final tag = data['tag_name'];
    if (tag is String && tag.isNotEmpty) {
      return "https://github.com/$repository/releases/tag/$tag";
    }
    return "https://github.com/$repository/releases/latest";
  }

  Future<void> checkUpdateResultHandle({
    Map<String, dynamic>? data,
    bool handleError = false,
  }) async {
    if (!shouldHandleUpdateResult(
      isPre: globalState.isPre,
      handleError: handleError,
    )) {
      return;
    }
    if (data != null) {
      final tagName = data['tag_name'];
      final body = data['body'];
      final submits = utils.parseReleaseBody(body);
      final textTheme = context.textTheme;
      final res = await globalState.showMessage(
        title: appLocalizations.discoverNewVersion,
        message: TextSpan(
          text: "$tagName \n",
          style: textTheme.headlineSmall,
          children: [
            TextSpan(
              text: "\n",
              style: textTheme.bodyMedium,
            ),
            for (final submit in submits)
              TextSpan(
                text: "- $submit \n",
                style: textTheme.bodyMedium,
              ),
          ],
        ),
        confirmText: appLocalizations.goDownload,
      );
      if (res != true) {
        return;
      }
      final releaseUrl = _resolveReleaseUrl(data);
      unawaited(launchUrl(Uri.parse(releaseUrl)));
    } else if (handleError) {
      globalState.showMessage(
        title: appLocalizations.checkUpdate,
        message: TextSpan(
          text: appLocalizations.checkUpdateError,
        ),
      );
    }
  }

  Future<void> _handlePreference() async {
    if (await preferences.isInit) {
      return;
    }
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.cacheCorrupt),
    );
    if (res == true) {
      final file = File(await appPath.sharedPreferencesPath);
      final isExists = await file.exists();
      if (isExists) {
        await file.delete();
      }
    }
    await handleExit();
  }

  Future<void> _initCore() async {
    final isInit = await clashCore.isInit;
    if (!isInit) {
      await clashCore.init();
      await clashCore.setState(
        globalState.getCoreState(),
      );
    }
    await applyProfile();
  }

  Future<void> init() async {
    FlutterError.onError = (details) {
      commonPrint.log(details.stack.toString());
    };
    // PlatformDispatcher catches isolate/native-channel errors FlutterError misses.
    PlatformDispatcher.instance.onError = (error, stack) {
      commonPrint.log('[PlatformDispatcher] $error\n$stack');
      return true;
    };
    updateTray(true);
    await _initCore();
    await _initStatus();
    autoLaunch?.updateStatus(
      _ref.read(appSettingProvider).autoLaunch,
    );
    // Delay subscription update to ensure network is ready after app initialization
    Future.delayed(
        const Duration(seconds: 1), _updateCurrentProfileSubscription);
    autoUpdateProfiles();
    autoCheckUpdate();
    if (!Platform.isMacOS) {
      if (!_ref.read(appSettingProvider).silentLaunch) {
        window?.show();
      } else {
        window?.hide();
      }
    }
    await _handlePreference();
    await _handlerDisclaimer();
    _ref.read(initProvider.notifier).value = true;

    // Post-frame so a slow keystore can't freeze the splash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        preferences.migrateProfileUrlsIfNeeded().catchError(
              (e) => commonPrint.log(
                '[migrateProfileUrlsIfNeeded] deferred: $e',
              ),
            ),
      );
    });
  }

  Future<void> _initStatus() async {
    if (Platform.isAndroid) {
      await globalState.updateStartTime();
    }
    final status = globalState.isStart == true
        ? true
        : _ref.read(appSettingProvider).autoRun;

    await updateStatus(status);
    if (!status) {
      addCheckIpNumDebounce();
    }
  }

  void setDelay(Delay delay) {
    _ref.read(delayDataSourceProvider.notifier).setDelay(delay);
  }

  void toPage(PageLabel pageLabel) {
    _ref.read(currentPageLabelProvider.notifier).value = pageLabel;
  }

  void toProfiles() {
    toPage(PageLabel.profiles);
  }

  void initLink() {
    linkManager.initAppLinksListen(
      (url) async {
        // Bring the desktop app to the foreground before showing the in-app
        // confirm dialog. Without this the window/popover stays hidden and the
        // user never sees the prompt. Mobile keeps its existing flow untouched.
        if (Platform.isMacOS) {
          await StatusBarManager.showWindow();
        } else if (system.isDesktop) {
          await window?.show();
        }
        final res = await globalState.showMessage(
          title: "${appLocalizations.add} ${appLocalizations.profile}",
          message: TextSpan(
            children: [
              TextSpan(text: appLocalizations.doYouWantToPass),
              TextSpan(
                text: " $url",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        );

        if (res != true) {
          return;
        }
        addProfileFormURL(url);
      },
    );
  }

  Future<bool> showDisclaimer() async {
    final accepted = await globalState.showCommonDialog<bool>(
      dismissible: false,
      child: CommonDialog(
        title: appLocalizations.disclaimer,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop<bool>(false);
            },
            child: Text(appLocalizations.exit),
          ),
          TextButton(
            onPressed: () {
              _ref.read(appSettingProvider.notifier).updateState(
                    (state) => state.copyWith(disclaimerAccepted: true),
                  );
              Navigator.of(context).pop<bool>(true);
            },
            child: Text(appLocalizations.agree),
          )
        ],
        child: SelectableText(
          appLocalizations.disclaimerDesc,
        ),
      ),
    );
    return accepted ?? false;
  }

  Future<void> _handlerDisclaimer() async {
    if (_ref.read(appSettingProvider).disclaimerAccepted) {
      return;
    }
    final isDisclaimerAccepted = await showDisclaimer();
    if (!isDisclaimerAccepted) {
      await handleExit();
    }
    return;
  }

  Future<void> addProfileFormURL(String url) async {
    // SECURITY: restrict schemes — no file://, data:, javascript: reaching HTTP/YAML parser.
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      unawaited(App().playUiSound(DropwebSoundCue.importError));
      unawaited(
        globalState.showMessage(
          message: TextSpan(text: appLocalizations.invalidProfileUrl),
        ),
      );
      return;
    }
    final normalizedUrl = uri.toString();

    if (globalState.navigatorKey.currentState?.canPop() ?? false) {
      globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    toPage(PageLabel.dashboard);
    final commonScaffoldState = globalState.homeScaffoldKey.currentState;
    if (commonScaffoldState?.mounted != true) return;

    try {
      final profile = await commonScaffoldState?.loadingRun<Profile>(
        () async {
          final prefs = await SharedPreferences.getInstance();
          final shouldSend = prefs.getBool('sendDeviceHeaders') ?? true;
          return Profile.normal(url: normalizedUrl)
              .update(shouldSendHeaders: shouldSend);
        },
        title: appLocalizations.addProfile,
      );

      if (profile != null) {
        _applyAllHeaderSettings(profile, isNewProfile: true);

        final headers = profile.providerHeaders;
        final showHwidLimit = headers['x-hwid-limit']?.toLowerCase() == 'true';
        final announceText = headers['announce'];
        if (showHwidLimit && announceText != null && announceText.isNotEmpty) {
          _showHwidLimitNotice(announceText, headers['support-url']);
        }

        await addProfile(profile);
        unawaited(App().playUiSound(DropwebSoundCue.importSuccess));
      }
    } catch (err) {
      unawaited(App().playUiSound(DropwebSoundCue.importError));
      commonPrint.log('Add Profile Failed: $err');
      final message = ErrorMapper.mapError(err.toString()) ??
          appLocalizations.genericErrorMessage;
      unawaited(globalState.showMessage(message: TextSpan(text: message)));
    }
  }

  Future<Null> addProfileFormFile() async {
    final platformFile = await globalState.safeRun(picker.pickerFile);
    final bytes = platformFile?.bytes;
    if (bytes == null) {
      return null;
    }
    if (!context.mounted) return;
    globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    toPage(PageLabel.dashboard);
    final commonScaffoldState = globalState.homeScaffoldKey.currentState;
    if (commonScaffoldState?.mounted != true) return;
    final profile = await commonScaffoldState?.loadingRun<Profile?>(
      () async {
        await Future.delayed(const Duration(milliseconds: 300));
        return Profile.normal(label: platformFile?.name).saveFile(bytes);
      },
      title: appLocalizations.addProfile,
    );
    if (profile != null) {
      await addProfile(profile);
    }
  }

  Future<void> addProfileFormQrCode() async {
    final url = await globalState.safeRun(picker.pickerConfigQRCode);
    if (url == null) return;
    addProfileFormURL(url);
  }

  void updateViewSize(Size size) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ref.read(viewSizeProvider.notifier).value = size;
    });
  }

  void setProvider(ExternalProvider? provider) {
    _ref.read(providersProvider.notifier).setProvider(provider);
  }

  List<Proxy> _sortOfName(List<Proxy> proxies) => List.of(proxies)
    ..sort(
      (a, b) => utils.sortByChar(
        utils.getPinyin(a.name),
        utils.getPinyin(b.name),
      ),
    );

  List<Proxy> _sortOfDelay({
    required List<Proxy> proxies,
    String? testUrl,
  }) =>
      List.of(proxies)
        ..sort(
          (a, b) {
            final aDelay = _ref.read(getDelayProvider(
              proxyName: a.name,
              testUrl: testUrl,
            ));
            final bDelay = _ref.read(
              getDelayProvider(
                proxyName: b.name,
                testUrl: testUrl,
              ),
            );
            if (aDelay == null && bDelay == null) {
              return 0;
            }
            if (aDelay == null || aDelay == -1) {
              return 1;
            }
            if (bDelay == null || bDelay == -1) {
              return -1;
            }
            return aDelay.compareTo(bDelay);
          },
        );

  List<Proxy> getSortProxies(List<Proxy> proxies, [String? url]) =>
      switch (_ref.read(proxiesStyleSettingProvider).sortType) {
        ProxiesSortType.none => proxies,
        ProxiesSortType.delay => _sortOfDelay(
            proxies: proxies,
            testUrl: url,
          ),
        ProxiesSortType.name => _sortOfName(proxies),
      };

  Future<Null> clearEffect(String profileId) async {
    final profilePath = await appPath.getProfilePath(profileId);
    final providersDirPath = await appPath.getProvidersDirPath(profileId);
    return Isolate.run(() async {
      final profileFile = File(profilePath);
      final isExists = await profileFile.exists();
      if (isExists) {
        unawaited(profileFile.delete(recursive: true));
      }
      final providersFileDir = File(providersDirPath);
      final providersFileIsExists = await providersFileDir.exists();
      if (providersFileIsExists) {
        unawaited(providersFileDir.delete(recursive: true));
      }
    });
  }

  void updateTun() {
    _ref.read(patchClashConfigProvider.notifier).updateState(
          (state) => state.copyWith.tun(enable: !state.tun.enable),
        );
  }

  void updateSystemProxy() {
    _ref.read(networkSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            systemProxy: !state.systemProxy,
          ),
        );
  }

  void _applyCustomViewSettings(Profile profile) {
    final headers = profile.providerHeaders;

    final dashboardLayout = headers['dropweb-widgets'];
    if (dashboardLayout != null && dashboardLayout.isNotEmpty) {
      final newLayout = DashboardWidgetParser.parseLayout(dashboardLayout);
      if (newLayout.isNotEmpty) {
        _ref.read(appSettingProvider.notifier).updateState(
              (state) => state.copyWith(dashboardWidgets: newLayout),
            );
      }
    }

    final proxiesView = headers['dropweb-view'];
    if (proxiesView != null && proxiesView.isNotEmpty) {
      final proxiesStyleNotifier =
          _ref.read(proxiesStyleSettingProvider.notifier);
      proxiesStyleNotifier.updateState((currentState) {
        var newState = currentState;
        final settings = proxiesView.split(';');
        for (final setting in settings) {
          final parts = setting.split(':');
          if (parts.length == 2) {
            final key = parts[0].trim().toLowerCase();
            final value = parts[1].trim().toLowerCase();
            switch (key) {
              case 'type':
                switch (value) {
                  case 'list':
                    newState = newState.copyWith(type: ProxiesType.list);
                    break;
                  case 'tab':
                    newState = newState.copyWith(type: ProxiesType.tab);
                    break;
                }
                break;
              case 'sort':
                switch (value) {
                  case 'none':
                    newState =
                        newState.copyWith(sortType: ProxiesSortType.none);
                    break;
                  case 'delay':
                    newState =
                        newState.copyWith(sortType: ProxiesSortType.delay);
                    break;
                  case 'name':
                    newState =
                        newState.copyWith(sortType: ProxiesSortType.name);
                    break;
                }
                break;
              case 'layout':
                switch (value) {
                  case 'loose':
                    newState = newState.copyWith(layout: ProxiesLayout.loose);
                    break;
                  case 'standard':
                    newState =
                        newState.copyWith(layout: ProxiesLayout.standard);
                    break;
                  case 'tight':
                    newState = newState.copyWith(layout: ProxiesLayout.tight);
                    break;
                }
                break;
              case 'icon':
                switch (value) {
                  case 'standard':
                  case 'icon':
                    newState =
                        newState.copyWith(iconStyle: ProxiesIconStyle.icon);
                    break;
                  case 'none':
                    newState =
                        newState.copyWith(iconStyle: ProxiesIconStyle.none);
                    break;
                }
                break;
              case 'card':
                switch (value) {
                  case 'expand':
                    newState =
                        newState.copyWith(cardType: ProxyCardType.expand);
                    break;
                  case 'shrink':
                    newState =
                        newState.copyWith(cardType: ProxyCardType.shrink);
                    break;
                  case 'min':
                    newState = newState.copyWith(cardType: ProxyCardType.min);
                    break;
                  case 'oneline':
                    newState =
                        newState.copyWith(cardType: ProxyCardType.oneline);
                    break;
                }
                break;
            }
          }
        }
        return newState;
      });
    }
  }

  Future<List<Package>> getPackages() async {
    if (_ref.read(isMobileViewProvider)) {
      await Future.delayed(commonDuration);
    }
    if (_ref.read(packagesProvider).isEmpty) {
      _ref.read(packagesProvider.notifier).value =
          await app?.getPackages() ?? [];
    }
    return _ref.read(packagesProvider);
  }

  void updateStart() {
    updateStatus(!_ref.read(runTimeProvider.notifier).isStart);
  }

  void updateCurrentSelectedMap(String groupName, String proxyName) {
    final currentProfile = _ref.read(currentProfileProvider);
    if (currentProfile != null &&
        currentProfile.selectedMap[groupName] != proxyName) {
      final selectedMap = Map<String, String>.from(
        currentProfile.selectedMap,
      )..[groupName] = proxyName;
      _ref.read(profilesProvider.notifier).setProfile(
            currentProfile.copyWith(
              selectedMap: selectedMap,
            ),
          );
    }
  }

  /// Applies a per-profile work mode. Persists the mode fields, rewrites only
  /// the `selectedMap` keys WE own (the main router + `GLOBAL`) without touching
  /// the user's other selections, invalidates the Block A setup-hash cache and
  /// triggers a full re-setup. The additive YAML group itself is injected by
  /// [applyWorkModePatch] in the config-build path (`patchRawConfig`).
  Future<void> applyWorkMode(
    WorkMode mode, {
    String? staticCountry,
  }) async {
    final currentProfile = _ref.read(currentProfileProvider);
    if (currentProfile == null) return;

    // Resolve the intercept groups from the profile's parsed config so we
    // manage exactly the selectedMap keys we own.
    var smartGroups = const <String>[];
    // Whether the smart `Умный` group will actually be injected for this config
    // (≥1 qualifying rule-referenced group resolves to ≥1 leaf node). Must match
    // the patch's injection condition exactly so we never point selectedMap at a
    // group that was never created.
    var smartAvailable = false;
    try {
      final cfg = await globalState.getProfileConfig(currentProfile.id);
      // ALL rule-referenced groups «Умный» is injected into (not just the
      // primary router) — the controller binds selectedMap for each so YouTube /
      // Discord / etc. route through «Умный» too (ИТЕРАЦИЯ 2).
      smartGroups = smartInterceptGroups(cfg);
      smartAvailable = smartGroupWillInject(cfg);
    } catch (e) {
      commonPrint.log('applyWorkMode: failed to read profile config: $e');
    }

    final selectedMap = Map<String, String>.from(currentProfile.selectedMap);
    // Clear OUR keys by VALUE-ownership: any key a prior work mode pointed at
    // «Умный» or a «Страна <flag>» group is ours to drop, regardless of which
    // group name carried it (the rule-referenced set can shift between applies,
    // e.g. after a subscription update). Plus GLOBAL. Never touch the user's
    // own manual selections.
    selectedMap
      ..removeWhere((_, v) =>
          v == workModeSmartGroupName ||
          v.startsWith('$workModeCountryGroupPrefix '))
      ..remove(GroupName.GLOBAL.name);

    switch (mode) {
      case WorkMode.smart:
        // Only bind when «Умный» will actually be injected AS A MEMBER of each
        // group (smartAvailable). The core honors a forced `selected` only among
        // a group's own members, so binding without the injected member would be
        // inert (D2); binding when smart is unavailable would dangle.
        if (smartAvailable) {
          for (final group in smartGroups) {
            selectedMap[group] = workModeSmartGroupName;
          }
        }
        break;
      case WorkMode.country:
        if (staticCountry != null && staticCountry.isNotEmpty) {
          // Point GLOBAL at the additive «Страна <flag>» fallback group injected
          // by applyWorkModePatch (in-country failover). No per-node/IP pin.
          selectedMap[GroupName.GLOBAL.name] =
              workModeCountryGroupName(staticCountry);
        }
        break;
      case WorkMode.standard:
      case WorkMode.gaming:
        break;
    }

    // Rollback on failure (B-12): keep the pre-mutation profile so a failed
    // apply can't leave the UI on a mode the core never accepted. The
    // `currentProfile` snapshot is captured BEFORE mutating (and copyWith is
    // non-destructive), so restoring it rolls back workMode, staticCountry and
    // selectedMap in one shot. applyProfile() surfaces setup errors to the user
    // itself (nested loadingRun → showMessage), so we only restore state + reset
    // the cache here; no duplicate notifier, and we deliberately do NOT rethrow
    // so the calling UI (_apply) settles.
    try {
      _ref.read(profilesProvider.notifier).setProfile(
            currentProfile.copyWith(
              workMode: mode,
              staticCountry: staticCountry,
              selectedMap: selectedMap,
            ),
          );

      // Work-mode fields feed _computeSetupHash; invalidate so the next setup
      // rebuilds the config rather than short-circuiting on the Block A cache.
      _lastSetupHash = null;
      await applyProfile();
    } catch (e) {
      commonPrint.log('applyWorkMode failed, rolling back work mode: $e');
      _ref.read(profilesProvider.notifier).setProfile(currentProfile);
      _lastSetupHash = null;
    }
  }

  /// After a subscription refresh, verifies the profile's work mode is still
  /// satisfiable against the fresh config. FAIL-OPEN (ИТЕРАЦИЯ 2): the mode is
  /// reset to Standard ONLY on POSITIVE proof of invalidity (a well-formed fresh
  /// config that genuinely can no longer satisfy the mode). An empty, missing or
  /// odd-shaped config — which can also mean the read raced an in-flight rebuild
  /// — is NOT proof; the mode is preserved and the anomaly logged. (A device
  /// repro showed a spurious smart→standard reset after restart when the read
  /// returned a not-yet-rebuilt config.) Returns the (possibly reset) profile;
  /// other modes pass through untouched.
  Future<Profile> _revalidateWorkMode(Profile profile) async {
    if (profile.workMode != WorkMode.country &&
        profile.workMode != WorkMode.smart) {
      return profile;
    }
    try {
      final cfg = await globalState.getProfileConfig(profile.id);
      // FAIL-OPEN: an empty config is not positive proof the mode is invalid
      // (e.g. the read raced a rebuild). Preserve the mode.
      if (cfg.isEmpty) {
        commonPrint.log(
            'work-mode revalidation: empty config, preserving ${profile.workMode.name}');
        return profile;
      }
      if (profile.workMode == WorkMode.country) {
        final proxies = cfg['proxies'];
        final groups = cfg['proxy-groups'];
        final rules = cfg['rules'] ?? cfg['rule'];
        // FAIL-OPEN: country candidates come from the rule-group leaves, which
        // are only decidable over a well-formed proxies + proxy-groups + rules
        // triple. If any is missing/odd, we can't positively prove the country
        // lost its nodes — preserve Country mode.
        if (proxies is! List || groups is! List || rules is! List) {
          commonPrint.log(
              'work-mode revalidation: config sections missing, preserving country');
          return profile;
        }
        // Candidate nodes = rule-group leaves only (disconeko SOS pool in raw
        // `proxies` is structurally excluded). Validate country presence
        // against this set, never the raw proxies.
        final names = interceptLeafNodes(cfg);
        final country = profile.staticCountry;
        final hasNodes = country != null &&
            (groupNodesByCountry(names)[country]?.isNotEmpty ?? false);
        if (!hasNodes) {
          globalState.showNotifier(
            appLocalizations.workModeResetNotice,
          );
          final selectedMap = Map<String, String>.from(profile.selectedMap)
            ..remove(GroupName.GLOBAL.name);
          return profile.copyWith(
            workMode: WorkMode.standard,
            staticCountry: null,
            selectedMap: selectedMap,
          );
        }
      } else if (profile.workMode == WorkMode.smart) {
        final groups = cfg['proxy-groups'];
        final rules = cfg['rules'] ?? cfg['rule'];
        // FAIL-OPEN: smart-availability is only decidable over a well-formed
        // proxy-groups + rules pair. If either is missing/odd, we can't prove
        // «Умный» is uninjectable — preserve Smart mode and log.
        if (groups is! List || rules is! List) {
          commonPrint.log(
              'work-mode revalidation: proxy-groups/rules missing, preserving smart');
          return profile;
        }
        // Smart survives only if «Умный» is still injectable on the fresh
        // config (≥1 qualifying rule-referenced group resolves to ≥1 leaf node)
        // — same condition the patch and applyWorkMode use, so a refresh that
        // strips every router or its leaves resets cleanly to Standard instead
        // of going inert. This is the ONLY positive-proof reset path for smart.
        if (!smartGroupWillInject(cfg)) {
          globalState.showNotifier(
            appLocalizations.workModeResetNotice,
          );
          return profile.copyWith(workMode: WorkMode.standard);
        }
      }
    } catch (e) {
      commonPrint.log('work-mode revalidation skipped: $e');
    }
    return profile;
  }

  void updateCurrentUnfoldSet(Set<String> value) {
    final currentProfile = _ref.read(currentProfileProvider);
    if (currentProfile == null) {
      return;
    }
    _ref.read(profilesProvider.notifier).setProfile(
          currentProfile.copyWith(
            unfoldSet: value,
          ),
        );
  }

  // changeMode / _autoSelectFastestForGlobal removed: the rule/global/direct
  // axis is dead. Mode is DERIVED from the current profile's work mode in
  // _setupClashConfig, which writes it back to patchClashConfigProvider and
  // emits the 'updateMode' IPC. Nothing switches mode imperatively anymore, so
  // the GLOBAL selectedMap auto-select (our key) is gone too.

  void updateAutoLaunch() {
    _ref.read(appSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            autoLaunch: !state.autoLaunch,
          ),
        );
  }

  void updateTheme(ThemeProps themeProps) {
    _ref.read(themeSettingProvider.notifier).updateState((_) => themeProps);
  }

  Future<void> updateVisible() async {
    if (Platform.isMacOS) return;

    final visible = await window?.isVisible;
    if (visible != null && !visible) {
      window?.show();
    } else {
      window?.hide();
    }
  }

  // updateMode removed: mode is derived (see _setupClashConfig). The desktop
  // hotkey (HotAction.mode) is now a no-op and the tray submenu is gone.

  Future<void> handleAddOrUpdate(WidgetRef ref, [Rule? rule]) async {
    final res = await globalState.showCommonDialog<Rule>(
      child: AddRuleDialog(
        rule: rule,
        snippet: ref.read(
          profileOverrideStateProvider.select(
            (state) => state.snippet!,
          ),
        ),
      ),
    );
    if (res == null) {
      return;
    }
    ref.read(profileOverrideStateProvider.notifier).updateState(
      (state) {
        final model = state.copyWith.overrideData!(
          rule: state.overrideData!.rule.updateRules(
            (rules) {
              final index = rules.indexWhere((item) => item.id == res.id);
              if (index == -1) {
                return List.from([res, ...rules]);
              }
              return List.from(rules)..[index] = res;
            },
          ),
        );
        return model;
      },
    );
  }

  Future<bool> exportLogs() async {
    final logsRaw = _ref.read(logsProvider).list.map(
          (item) => item.toString(),
        );
    final data = await Isolate.run<List<int>>(() async {
      final logsRawString = logsRaw.join("\n");
      return utf8.encode(logsRawString);
    });
    return await picker.saveFile(
          utils.logFile,
          Uint8List.fromList(data),
        ) !=
        null;
  }

  Future<List<int>> backupData() async {
    final homeDirPath = await appPath.homeDirPath;
    final profilesPath = await appPath.profilesPath;
    final configJson = globalState.config.toJson();
    return Isolate.run<List<int>>(() async {
      final archive = Archive();
      archive.addJson("config.json", configJson);
      archive.addDirectoryToArchive(profilesPath, homeDirPath);
      final zipEncoder = ZipEncoder();
      return zipEncoder.encode(archive);
    });
  }

  Future<void> updateTray([bool focus = false]) async {
    tray.update(
      trayState: _ref.read(trayStateProvider),
    );
  }

  Future<void> recoveryData(
    List<int> data,
    RecoveryOption recoveryOption,
  ) async {
    final archive = await Isolate.run<Archive>(() {
      final zipDecoder = ZipDecoder();
      return zipDecoder.decodeBytes(data);
    });
    final homeDirPath = await appPath.homeDirPath;
    final configs =
        archive.files.where((item) => item.name.endsWith(".json")).toList();
    final profiles =
        archive.files.where((item) => !item.name.endsWith(".json"));
    final configIndex =
        configs.indexWhere((config) => config.name == "config.json");
    if (configIndex == -1) throw "invalid backup file";
    final configFile = configs[configIndex];
    var tempConfig = Config.compatibleFromJson(
      json.decode(
        utf8.decode(configFile.content),
      ),
    );
    for (final profile in profiles) {
      if (!profile.isFile) continue;
      // profile.name is attacker-controlled (from the backup ZIP). Reject any
      // entry that would escape the profiles directory (Zip-Slip) before
      // File.create(recursive: true) builds the escape path on disk.
      final filePath = safeArchivePath(homeDirPath, profile.name);
      if (filePath == null) {
        commonPrint.log(
          '[restore] skipped unsafe archive entry: ${profile.name}',
        );
        continue;
      }
      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsBytes(profile.content);
    }
    final clashConfigIndex =
        configs.indexWhere((config) => config.name == "clashConfig.json");
    if (clashConfigIndex != -1) {
      final clashConfigFile = configs[clashConfigIndex];
      tempConfig = tempConfig.copyWith(
        patchClashConfig: ClashConfig.fromJson(
          json.decode(
            utf8.decode(
              clashConfigFile.content,
            ),
          ),
        ),
      );
    }
    _recovery(
      tempConfig,
      recoveryOption,
    );
  }

  void _recovery(Config config, RecoveryOption recoveryOption) {
    final recoveryStrategy = _ref.read(appSettingProvider.select(
      (state) => state.recoveryStrategy,
    ));
    final profiles = config.profiles;
    if (recoveryStrategy == RecoveryStrategy.override) {
      _ref.read(profilesProvider.notifier).value = profiles;
    } else {
      for (final profile in profiles) {
        _ref.read(profilesProvider.notifier).setProfile(
              profile,
            );
      }
    }
    final onlyProfiles = recoveryOption == RecoveryOption.onlyProfiles;
    if (!onlyProfiles) {
      _ref.read(patchClashConfigProvider.notifier).value =
          config.patchClashConfig;
      _ref.read(appSettingProvider.notifier).value = config.appSetting;
      _ref.read(currentProfileIdProvider.notifier).value =
          config.currentProfileId;
      _ref.read(appDAVSettingProvider.notifier).value = config.dav;
      _ref.read(themeSettingProvider.notifier).value = config.themeProps;
      _ref.read(windowSettingProvider.notifier).value = config.windowProps;
      _ref.read(vpnSettingProvider.notifier).value = config.vpnProps;
      _ref.read(proxiesStyleSettingProvider.notifier).value =
          config.proxiesStyle;
      _ref.read(overrideDnsProvider.notifier).value = config.overrideDns;
      _ref.read(networkSettingProvider.notifier).value = config.networkProps;
      _ref.read(hotKeyActionsProvider.notifier).value = config.hotKeyActions;
      _ref.read(scriptStateProvider.notifier).value = config.scriptProps;
    }
    final currentProfile = _ref.read(currentProfileProvider);
    if (currentProfile == null) {
      _ref.read(currentProfileIdProvider.notifier).value = profiles.first.id;
    }
    savePreferencesDebounce();
  }
}
