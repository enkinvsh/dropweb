import 'dart:convert';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/controller.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../common/common.dart';

/// Profile-domain concern carved out of [AppController].
///
/// [AppController] keeps thin delegating methods with identical signatures, so
/// every existing call site (`globalState.appController.addProfile(...)`,
/// `setProfile(...)`, `autoUpdateProfiles()`, …) stays untouched. The pure
/// decision helper `shouldAutoUpdateProfile` deliberately remains top-level in
/// `controller.dart` (its test imports it from there); this service calls into
/// it.
///
/// No [BuildContext] is stored here — the moved code reaches the rest of the
/// app exclusively via `_ref`, `globalState`, and the public [AppController]
/// facade (`globalState.appController.*`) for the few controller methods that
/// stay (`applyProfileDebounce`, `clearEffect`, `updateStatus`,
/// `savePreferencesDebounce`, `updateProfile`). Methods that stay in the
/// controller because they depend on its private work-mode revalidation /
/// config state, or build raw dialogs against the stored context
/// (`updateProfile`, `setProfileWithRevalidationAndAutoApply`,
/// `handleChangeProfile`, `_showHwidLimitNotice`, `addProfileFormURL/File/QrCode`),
/// call back into this service through the controller's private delegate stubs.
class ProfileService {
  ProfileService(this._ref);

  final WidgetRef _ref;

  Future<void> addProfile(Profile profile) async {
    _ref.read(profilesProvider.notifier).setProfile(profile);
    // Always select the freshly added profile so importing a config switches
    // to it (previously it only auto-selected when no profile existed yet).
    _ref.read(currentProfileIdProvider.notifier).value = profile.id;
    globalState.appController.applyProfileDebounce(silence: true);
  }

  Future<void> deleteProfile(String id) async {
    _ref.read(profilesProvider.notifier).deleteProfileById(id);
    globalState.appController.clearEffect(id);
    if (globalState.config.currentProfileId == id) {
      final profiles = globalState.config.profiles;
      final currentProfileId = _ref.read(currentProfileIdProvider.notifier);
      if (profiles.isNotEmpty) {
        final updateId = profiles.first.id;
        currentProfileId.value = updateId;
      } else {
        currentProfileId.value = null;
        globalState.appController.updateStatus(false);
      }
    }
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

  void applyAllHeaderSettings(Profile profile, {required bool isNewProfile}) {
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
    applyAllHeaderSettings(profile, isNewProfile: false);
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
  void resetSubscriptionTheme() {
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

      globalState.appController.savePreferencesDebounce();
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

  Future<void> updateGeoFilesAfterProfileUpdate(
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
          // The metadata HEAD fetch above stays outside the lock; only the
          // download+write (updateGeoData mutates the on-disk geo files) and the
          // subsequent core reload must be serialized against profile apply to
          // avoid sharing violations / corrupt geodata (see withGeoFileLock).
          final result = await globalState.appController.withGeoFileLock(
            () => clashCore.updateGeoData(
              UpdateGeoDataParams(geoType: geoType, geoName: fileName),
            ),
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
      globalState.appController.applyProfileDebounce(silence: true);
    }
  }

  void setProfiles(List<Profile> profiles) {
    _ref.read(profilesProvider.notifier).value = profiles;
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

      try {
        // The secure-store read (getProfileUrl) and the auto-update gate live
        // INSIDE the per-profile try: a secure-storage exception here must only
        // skip this one profile, not escape and kill the whole loop AND the
        // 20-minute timer chain that drives it.
        final resolvedUrl = await preferences.getProfileUrl(profile);
        if (!shouldAutoUpdateProfile(
          profile: profile,
          now: DateTime.now(),
          resolvedUrl: resolvedUrl,
        )) {
          continue;
        }
        await globalState.appController.updateProfile(profile);
      } catch (e) {
        commonPrint.log(e.toString());
      }
    }
  }

  /// Updates subscription info for the current profile on app startup.
  /// This ensures the subscription info is always up-to-date when the app launches.
  Future<void> updateCurrentProfileSubscription() async {
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
      await globalState.appController.updateProfile(currentProfile);
      commonPrint.log("Subscription info updated successfully");
    } catch (e, stackTrace) {
      commonPrint.log("Failed to update subscription info on startup: $e");
      commonPrint.log("Stack trace: $stackTrace");
    }
  }

  Future<void> updateProfiles() async {
    for (final profile in _ref.read(profilesProvider)) {
      if (profile.type == ProfileType.file) {
        continue;
      }
      await globalState.appController.updateProfile(profile);
    }
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
}
