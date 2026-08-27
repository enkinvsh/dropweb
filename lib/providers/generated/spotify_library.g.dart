// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../spotify_library.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$spotifyLibrarySelectionHash() =>
    r'd69fa092b0d5923a533528da7f3db04ae9455c9e';

/// Which filter the grid is showing.
///
/// Held in a provider rather than in the tab's `State` because the tab does not
/// survive: it lives inside a `TabBarView`, which disposes the off-screen
/// child, so a selection kept in the widget would reset to Playlists every time
/// somebody swiped to search and back. It is deliberately the ONLY thing the
/// selection owns — the items behind each filter live in
/// [SpotifyLibrary], one instance per filter.
///
/// Copied from [SpotifyLibrarySelection].
@ProviderFor(SpotifyLibrarySelection)
final spotifyLibrarySelectionProvider =
    NotifierProvider<SpotifyLibrarySelection, SpotifyLibraryFilter>.internal(
  SpotifyLibrarySelection.new,
  name: r'spotifyLibrarySelectionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$spotifyLibrarySelectionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SpotifyLibrarySelection = Notifier<SpotifyLibraryFilter>;
String _$spotifyLibraryHash() => r'23c7e97aa510bc7dc88f2dbe9a911b8adf5f7461';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$SpotifyLibrary extends BuildlessNotifier<SpotifyLibraryState> {
  late final SpotifyLibraryFilter filter;

  SpotifyLibraryState build(
    SpotifyLibraryFilter filter,
  );
}

/// One library filter's items, held above the route.
///
/// The filter is the family key, and that IS the cache. Before this there was
/// one notifier holding whichever filter was last asked for, so Плейлисты →
/// Альбомы → Плейлисты was three trips through the tunnel to show two answers
/// the app had already had — which is precisely the lag the owner reported.
/// Keyed, each filter keeps its own answer alive and switching back is a
/// rebuild rather than a fetch.
///
/// No TTL, no eviction, no store. Three filters per account, each a page of
/// names and cover URLs; a cache that needs a policy is a cache that is holding
/// something big enough to matter, and this is not. It is the same shape
/// Spotube's metadata layer uses for the same reason.
///
/// keepAlive for the reason `MeowzicSearch` and `SpotifyAuth` have it as well:
/// the meowzic page is pushed as a route, so anything kept in the tab's `State`
/// is rebuilt on every open.
///
/// In memory only. Surviving an app restart would need a table and is a
/// separate decision; surviving navigation is this one.
///
/// Copied from [SpotifyLibrary].
@ProviderFor(SpotifyLibrary)
const spotifyLibraryProvider = SpotifyLibraryFamily();

/// One library filter's items, held above the route.
///
/// The filter is the family key, and that IS the cache. Before this there was
/// one notifier holding whichever filter was last asked for, so Плейлисты →
/// Альбомы → Плейлисты was three trips through the tunnel to show two answers
/// the app had already had — which is precisely the lag the owner reported.
/// Keyed, each filter keeps its own answer alive and switching back is a
/// rebuild rather than a fetch.
///
/// No TTL, no eviction, no store. Three filters per account, each a page of
/// names and cover URLs; a cache that needs a policy is a cache that is holding
/// something big enough to matter, and this is not. It is the same shape
/// Spotube's metadata layer uses for the same reason.
///
/// keepAlive for the reason `MeowzicSearch` and `SpotifyAuth` have it as well:
/// the meowzic page is pushed as a route, so anything kept in the tab's `State`
/// is rebuilt on every open.
///
/// In memory only. Surviving an app restart would need a table and is a
/// separate decision; surviving navigation is this one.
///
/// Copied from [SpotifyLibrary].
class SpotifyLibraryFamily extends Family<SpotifyLibraryState> {
  /// One library filter's items, held above the route.
  ///
  /// The filter is the family key, and that IS the cache. Before this there was
  /// one notifier holding whichever filter was last asked for, so Плейлисты →
  /// Альбомы → Плейлисты was three trips through the tunnel to show two answers
  /// the app had already had — which is precisely the lag the owner reported.
  /// Keyed, each filter keeps its own answer alive and switching back is a
  /// rebuild rather than a fetch.
  ///
  /// No TTL, no eviction, no store. Three filters per account, each a page of
  /// names and cover URLs; a cache that needs a policy is a cache that is holding
  /// something big enough to matter, and this is not. It is the same shape
  /// Spotube's metadata layer uses for the same reason.
  ///
  /// keepAlive for the reason `MeowzicSearch` and `SpotifyAuth` have it as well:
  /// the meowzic page is pushed as a route, so anything kept in the tab's `State`
  /// is rebuilt on every open.
  ///
  /// In memory only. Surviving an app restart would need a table and is a
  /// separate decision; surviving navigation is this one.
  ///
  /// Copied from [SpotifyLibrary].
  const SpotifyLibraryFamily();

  /// One library filter's items, held above the route.
  ///
  /// The filter is the family key, and that IS the cache. Before this there was
  /// one notifier holding whichever filter was last asked for, so Плейлисты →
  /// Альбомы → Плейлисты was three trips through the tunnel to show two answers
  /// the app had already had — which is precisely the lag the owner reported.
  /// Keyed, each filter keeps its own answer alive and switching back is a
  /// rebuild rather than a fetch.
  ///
  /// No TTL, no eviction, no store. Three filters per account, each a page of
  /// names and cover URLs; a cache that needs a policy is a cache that is holding
  /// something big enough to matter, and this is not. It is the same shape
  /// Spotube's metadata layer uses for the same reason.
  ///
  /// keepAlive for the reason `MeowzicSearch` and `SpotifyAuth` have it as well:
  /// the meowzic page is pushed as a route, so anything kept in the tab's `State`
  /// is rebuilt on every open.
  ///
  /// In memory only. Surviving an app restart would need a table and is a
  /// separate decision; surviving navigation is this one.
  ///
  /// Copied from [SpotifyLibrary].
  SpotifyLibraryProvider call(
    SpotifyLibraryFilter filter,
  ) {
    return SpotifyLibraryProvider(
      filter,
    );
  }

  @override
  SpotifyLibraryProvider getProviderOverride(
    covariant SpotifyLibraryProvider provider,
  ) {
    return call(
      provider.filter,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'spotifyLibraryProvider';
}

/// One library filter's items, held above the route.
///
/// The filter is the family key, and that IS the cache. Before this there was
/// one notifier holding whichever filter was last asked for, so Плейлисты →
/// Альбомы → Плейлисты was three trips through the tunnel to show two answers
/// the app had already had — which is precisely the lag the owner reported.
/// Keyed, each filter keeps its own answer alive and switching back is a
/// rebuild rather than a fetch.
///
/// No TTL, no eviction, no store. Three filters per account, each a page of
/// names and cover URLs; a cache that needs a policy is a cache that is holding
/// something big enough to matter, and this is not. It is the same shape
/// Spotube's metadata layer uses for the same reason.
///
/// keepAlive for the reason `MeowzicSearch` and `SpotifyAuth` have it as well:
/// the meowzic page is pushed as a route, so anything kept in the tab's `State`
/// is rebuilt on every open.
///
/// In memory only. Surviving an app restart would need a table and is a
/// separate decision; surviving navigation is this one.
///
/// Copied from [SpotifyLibrary].
class SpotifyLibraryProvider
    extends NotifierProviderImpl<SpotifyLibrary, SpotifyLibraryState> {
  /// One library filter's items, held above the route.
  ///
  /// The filter is the family key, and that IS the cache. Before this there was
  /// one notifier holding whichever filter was last asked for, so Плейлисты →
  /// Альбомы → Плейлисты was three trips through the tunnel to show two answers
  /// the app had already had — which is precisely the lag the owner reported.
  /// Keyed, each filter keeps its own answer alive and switching back is a
  /// rebuild rather than a fetch.
  ///
  /// No TTL, no eviction, no store. Three filters per account, each a page of
  /// names and cover URLs; a cache that needs a policy is a cache that is holding
  /// something big enough to matter, and this is not. It is the same shape
  /// Spotube's metadata layer uses for the same reason.
  ///
  /// keepAlive for the reason `MeowzicSearch` and `SpotifyAuth` have it as well:
  /// the meowzic page is pushed as a route, so anything kept in the tab's `State`
  /// is rebuilt on every open.
  ///
  /// In memory only. Surviving an app restart would need a table and is a
  /// separate decision; surviving navigation is this one.
  ///
  /// Copied from [SpotifyLibrary].
  SpotifyLibraryProvider(
    SpotifyLibraryFilter filter,
  ) : this._internal(
          () => SpotifyLibrary()..filter = filter,
          from: spotifyLibraryProvider,
          name: r'spotifyLibraryProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$spotifyLibraryHash,
          dependencies: SpotifyLibraryFamily._dependencies,
          allTransitiveDependencies:
              SpotifyLibraryFamily._allTransitiveDependencies,
          filter: filter,
        );

  SpotifyLibraryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.filter,
  }) : super.internal();

  final SpotifyLibraryFilter filter;

  @override
  SpotifyLibraryState runNotifierBuild(
    covariant SpotifyLibrary notifier,
  ) {
    return notifier.build(
      filter,
    );
  }

  @override
  Override overrideWith(SpotifyLibrary Function() create) {
    return ProviderOverride(
      origin: this,
      override: SpotifyLibraryProvider._internal(
        () => create()..filter = filter,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        filter: filter,
      ),
    );
  }

  @override
  NotifierProviderElement<SpotifyLibrary, SpotifyLibraryState> createElement() {
    return _SpotifyLibraryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SpotifyLibraryProvider && other.filter == filter;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, filter.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SpotifyLibraryRef on NotifierProviderRef<SpotifyLibraryState> {
  /// The parameter `filter` of this provider.
  SpotifyLibraryFilter get filter;
}

class _SpotifyLibraryProviderElement
    extends NotifierProviderElement<SpotifyLibrary, SpotifyLibraryState>
    with SpotifyLibraryRef {
  _SpotifyLibraryProviderElement(super.provider);

  @override
  SpotifyLibraryFilter get filter => (origin as SpotifyLibraryProvider).filter;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
