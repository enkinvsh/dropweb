import 'package:dropweb/common/secure_profile_store.dart';

/// In-memory замена защищённого хранилища для юнит-тестов (без KeyStore).
class FakeSecureProfileStore implements SecureProfileUrlStoreInterface {
  final Map<String, String> urls = {};
  final Map<String, String> fallbacks = {};
  final Map<String, List<String>> mirrors = {};
  final Map<String, String> subIds = {};
  final Map<String, String> preferred = {};
  final Map<String, List<String>> beaconUrls = {};
  final Map<String, List<String>> beaconKeys = {};
  final Map<String, String> beaconStates = {};
  bool migrated = true;

  /// Профили, чья запись preferredUrl должна «упасть» (сбой KeyStore).
  final Set<String> failPreferredFor = {};

  @override
  Future<String?> getUrl(String profileId) async => urls[profileId];

  @override
  Future<String?> getFallbackUrl(String profileId) async =>
      fallbacks[profileId];

  @override
  Future<List<String>?> getMirrors(String profileId) async =>
      mirrors[profileId];

  @override
  Future<String?> getSubId(String profileId) async => subIds[profileId];

  @override
  Future<String?> getPreferredUrl(String profileId) async =>
      preferred[profileId];

  bool _put<T>(Map<String, T> map, String id, T? value, bool empty) {
    if (value == null || empty) {
      map.remove(id);
    } else {
      map[id] = value;
    }
    return true;
  }

  @override
  Future<bool> setUrl(String profileId, String? url) async =>
      _put(urls, profileId, url, url?.isEmpty ?? true);

  @override
  Future<bool> setFallbackUrl(String profileId, String? url) async =>
      _put(fallbacks, profileId, url, url?.isEmpty ?? true);

  @override
  Future<bool> setMirrors(String profileId, List<String>? value) async =>
      _put(mirrors, profileId, value, value?.isEmpty ?? true);

  @override
  Future<bool> setSubId(String profileId, String? value) async =>
      _put(subIds, profileId, value, value?.isEmpty ?? true);

  @override
  Future<bool> setPreferredUrl(String profileId, String? url) async {
    if (failPreferredFor.contains(profileId)) return false;
    return _put(preferred, profileId, url, url?.isEmpty ?? true);
  }

  @override
  Future<List<String>?> getBeaconUrls(String profileId) async =>
      beaconUrls[profileId];

  @override
  Future<bool> setBeaconUrls(String profileId, List<String>? value) async =>
      _put(beaconUrls, profileId, value, value?.isEmpty ?? true);

  @override
  Future<List<String>?> getBeaconKeys(String profileId) async =>
      beaconKeys[profileId];

  @override
  Future<bool> setBeaconKeys(String profileId, List<String>? value) async =>
      _put(beaconKeys, profileId, value, value?.isEmpty ?? true);

  @override
  Future<String?> getBeaconState(String profileId) async =>
      beaconStates[profileId];

  @override
  Future<bool> setBeaconState(String profileId, String? value) async =>
      _put(beaconStates, profileId, value, value?.isEmpty ?? true);

  @override
  Future<void> removeProfile(String profileId) async {
    for (final map in <Map<String, Object>>[
      urls,
      fallbacks,
      mirrors,
      subIds,
      preferred,
      beaconUrls,
      beaconKeys,
      beaconStates,
    ]) {
      map.remove(profileId);
    }
  }

  @override
  Future<bool> isMigrated() async => migrated;

  @override
  Future<bool> markMigrated() async {
    migrated = true;
    return true;
  }
}
