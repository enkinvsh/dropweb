import 'package:dropweb/common/constant.dart';
import 'package:dropweb/common/utils.dart' show utils;
import 'package:dropweb/models/models.dart';

/// Pure: maps a fetched `update.json` manifest to an [AppUpdateInfo] for the
/// requested Android platform (default `android-universal`), or null when there
/// is no newer/valid update. Explicit `platformKey: 'android-arm64'` stays
/// valid for the per-arch artifact.
///
/// Eligibility is decided by the Android **versionCode** (`build`), NOT the
/// marketing semver — Android's PackageManager only lets you install a package
/// whose versionCode is strictly greater than the installed one, and our codes
/// were polluted by mistyped/date-encoded values, so semver ordering can
/// disagree with what the OS will actually accept. When BOTH the manifest
/// `build` and the installed [localBuild] parse to positive ints we offer the
/// update iff `remoteBuild > localBuild` (semver is then display/tag data only:
/// a higher semver with a lower/equal build is NOT offered; the same semver
/// with a higher build IS). When either build is missing/malformed/zero/
/// negative we fall back to the legacy semver comparison — this preserves
/// old-manifest behavior and stays conservative when the installed build string
/// is unparseable.
///
/// Single source of truth for the GitHub fallback URL is the `repository`
/// const. The YC `url` from the manifest is the primary source; the GitHub
/// release asset is the fallback (RU ТСПУ throttles GitHub, so YC goes first).
///
/// No IO: callers fetch the manifest (tunnel-aware) and pass it in, which keeps
/// this unit-testable without a network.
AppUpdateInfo? resolveAndroidUpdate({
  required Map<String, dynamic> manifest,
  required String localVersion,
  String? localBuild,
  String platformKey = 'android-universal',
}) {
  final remote = (manifest['version']?.toString() ?? '').trim();
  if (remote.isEmpty) return null;

  final remoteBuild = _positiveBuild(manifest['build']);
  final localBuildInt = _positiveBuild(localBuild);

  final bool isNewer;
  if (remoteBuild != null && localBuildInt != null) {
    // versionCode governs; marketing semver is irrelevant to install ordering.
    isNewer = remoteBuild > localBuildInt;
  } else {
    // No usable build on one side => legacy semver fallback (older/equal => no).
    isNewer = utils.compareVersions(remote, localVersion) > 0;
  }
  if (!isNewer) return null;

  final platforms = manifest['platforms'];
  if (platforms is! Map) return null;
  final entry = platforms[platformKey];
  if (entry is! Map) return null;
  final url = entry['url'];
  if (url is! String || url.isEmpty) return null;

  final version = remote.startsWith('v') ? remote.substring(1) : remote;
  final tag = 'v$version';
  final suffix = kGithubApkAssetByPlatform[platformKey];
  final fallback = suffix == null
      ? null
      : 'https://github.com/$repository/releases/download/$tag/dropweb-$version-$suffix';

  final notes = manifest['notes'] is List
      ? (manifest['notes'] as List).map((e) => e.toString()).toList()
      : const <String>[];

  return AppUpdateInfo(
    version: version,
    tag: tag,
    build: remoteBuild,
    notes: notes,
    primaryUrl: url,
    fallbackUrl: fallback,
    sha256: (entry['sha256'] as String?)?.toLowerCase(),
    mandatory: manifest['mandatory'] == true,
    minSupported: manifest['minSupported']?.toString(),
  );
}

/// Parses an Android versionCode from a manifest field or a `PackageInfo`
/// build-number string. Returns the value only when it is a valid **positive**
/// integer; zero, negative, and malformed inputs return null (treated as
/// "no usable build" => semver fallback).
int? _positiveBuild(Object? raw) {
  if (raw == null) return null;
  final int? value;
  if (raw is int) {
    value = raw;
  } else if (raw is num) {
    value = raw.toInt();
  } else {
    value = int.tryParse(raw.toString().trim());
  }
  if (value == null || value <= 0) return null;
  return value;
}
