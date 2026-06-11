import 'dart:io';

import 'package:dropweb/clash/core.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/state.dart';
import 'package:path/path.dart';

/// Shared "does this profile need geodata?" detection.
///
/// The bundled geo assets (geoip.metadb / GeoIP.dat / GeoSite.dat / ASN.mmdb)
/// are a BOOTSTRAP SEED kept in the APK so the app can start offline. Copying
/// them to the home dir on first run is a load-bearing cost only for profiles
/// that actually consume geodata, so both the regular init path and the Quick
/// Settings tile path gate the copy on the same condition via this helper.
class Geodata {
  const Geodata._();

  /// The exact condition the tile quick-start path uses: a profile needs the
  /// geo assets when its raw config has `geodata-mode == true`.
  static bool profileConfigNeedsGeodata(Map<dynamic, dynamic> profileConfig) {
    return profileConfig["geodata-mode"] == true;
  }

  /// Resolves the active profile's config and returns whether it needs geodata.
  /// Returns false when there is no current profile or the config can't be read
  /// (geo copy stays skipped; the safety net before core setup still covers a
  /// profile that enables geodata later).
  static Future<bool> currentProfileNeedsGeodata() async {
    try {
      final currentProfileId = globalState.config.currentProfileId;
      if (currentProfileId == null) {
        return false;
      }
      final profileConfig =
          await globalState.getProfileConfig(currentProfileId);
      return profileConfigNeedsGeodata(profileConfig);
    } catch (e) {
      commonPrint.log("Geodata: need-check failed, skipping geo init: $e");
      return false;
    }
  }

  /// Safety net before core setup: when [needsGeodata] is true and any of the
  /// four geo files is missing from the home dir, copy the bundled seed via
  /// [ClashCore.initGeo]. Cheap on the hot path — it only stats the files when
  /// geodata is actually needed.
  static Future<void> ensureGeoFilesIfNeeded(bool needsGeodata) async {
    if (!needsGeodata) {
      return;
    }
    const geoFileNameList = [
      mmdbFileName,
      geoIpFileName,
      geoSiteFileName,
      asnFileName,
    ];
    final homePath = await appPath.homeDirPath;
    for (final geoFileName in geoFileNameList) {
      final geoFile = File(join(homePath, geoFileName));
      if (!await geoFile.exists()) {
        await ClashCore.initGeo();
        return;
      }
    }
  }
}
