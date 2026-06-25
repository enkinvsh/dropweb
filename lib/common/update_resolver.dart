import 'package:dropweb/common/constant.dart';
import 'package:dropweb/common/utils.dart' show utils;
import 'package:dropweb/models/models.dart';

/// Pure: maps a fetched `update.json` manifest to an [AppUpdateInfo] for the
/// android-arm64 platform, or null when there is no newer/valid update.
///
/// Single source of truth for the GitHub fallback URL is the `repository`
/// const (matching `AppUpdateService._resolveReleaseUrl`). The YC `url` from
/// the manifest is the primary source; the GitHub release asset is the
/// fallback (RU ТСПУ throttles GitHub, so YC goes first).
///
/// No IO: callers fetch the manifest (tunnel-aware) and pass it in, which keeps
/// this unit-testable without a network.
AppUpdateInfo? resolveAndroidUpdate({
  required Map<String, dynamic> manifest,
  required String localVersion,
  String platformKey = 'android-arm64',
}) {
  final remote = (manifest['version']?.toString() ?? '').trim();
  if (remote.isEmpty) return null;
  // remote <= local (older or equal) => nothing to offer.
  if (utils.compareVersions(remote, localVersion) <= 0) return null;

  final platforms = manifest['platforms'];
  if (platforms is! Map) return null;
  final entry = platforms[platformKey];
  if (entry is! Map) return null;
  final url = entry['url'];
  if (url is! String || url.isEmpty) return null;

  final tag = remote.startsWith('v') ? remote : 'v$remote';
  final asset = kGithubApkAssetByPlatform[platformKey];
  final fallback = asset == null
      ? null
      : 'https://github.com/$repository/releases/download/$tag/$asset';

  final notes = manifest['notes'] is List
      ? (manifest['notes'] as List).map((e) => e.toString()).toList()
      : const <String>[];

  return AppUpdateInfo(
    version: remote.startsWith('v') ? remote.substring(1) : remote,
    tag: tag,
    notes: notes,
    primaryUrl: url,
    fallbackUrl: fallback,
    sha256: (entry['sha256'] as String?)?.toLowerCase(),
    mandatory: manifest['mandatory'] == true,
    minSupported: manifest['minSupported']?.toString(),
  );
}
