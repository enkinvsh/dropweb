// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../spotify_detail.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$spotifyDetailHash() => r'4be4ebbf7ab3367e66878815cf74b2d1f092b9a5';

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

abstract class _$SpotifyDetail extends BuildlessNotifier<SpotifyDetailState> {
  late final String uri;
  late final SpotifyLibraryKind kind;

  SpotifyDetailState build(
    String uri,
    SpotifyLibraryKind kind,
  );
}

/// One opened playlist, album, artist or saved-tracks collection.
///
/// Keyed by [uri] and [kind] rather than held as a single current-container
/// notifier: two detail screens can be on the stack at once — an artist opened
/// from the grid, then one of its albums — and a single notifier would mean the
/// one underneath quietly showing the one on top's tracks when you came back to
/// it.
///
/// keepAlive, and that IS the cache. There is no store, no TTL and no eviction
/// anywhere in this feature, on purpose: a family provider that outlives its
/// screen is already a keyed cache, and Riverpod is already the thing holding
/// it. Spotube's whole metadata layer is built this exact way — every one of
/// its paginated notifiers is a keepAlive family keyed by the thing it fetched
/// — and inventing a second caching mechanism beside the one the app already
/// depends on would be two sources of truth for "have we read this".
///
/// This was auto-disposing until the owner used it on a phone: backing out of a
/// playlist tore the notifier down, and opening it again paid a full round trip
/// through the tunnel to redraw what had been on screen a second earlier. That
/// is the "лаги пиздец словно мы ничего не кешируем" — the app genuinely was
/// not caching, because the provider was told to throw the answer away. The
/// justification that stood here, that keeping every opened container alive
/// grows without bound, is true and does not matter at this size: the bound is
/// how many containers one person opens in one run of the app, each a list of
/// track names, and paying a network round trip per revisit to save that is a
/// bad trade.
///
/// Copied from [SpotifyDetail].
@ProviderFor(SpotifyDetail)
const spotifyDetailProvider = SpotifyDetailFamily();

/// One opened playlist, album, artist or saved-tracks collection.
///
/// Keyed by [uri] and [kind] rather than held as a single current-container
/// notifier: two detail screens can be on the stack at once — an artist opened
/// from the grid, then one of its albums — and a single notifier would mean the
/// one underneath quietly showing the one on top's tracks when you came back to
/// it.
///
/// keepAlive, and that IS the cache. There is no store, no TTL and no eviction
/// anywhere in this feature, on purpose: a family provider that outlives its
/// screen is already a keyed cache, and Riverpod is already the thing holding
/// it. Spotube's whole metadata layer is built this exact way — every one of
/// its paginated notifiers is a keepAlive family keyed by the thing it fetched
/// — and inventing a second caching mechanism beside the one the app already
/// depends on would be two sources of truth for "have we read this".
///
/// This was auto-disposing until the owner used it on a phone: backing out of a
/// playlist tore the notifier down, and opening it again paid a full round trip
/// through the tunnel to redraw what had been on screen a second earlier. That
/// is the "лаги пиздец словно мы ничего не кешируем" — the app genuinely was
/// not caching, because the provider was told to throw the answer away. The
/// justification that stood here, that keeping every opened container alive
/// grows without bound, is true and does not matter at this size: the bound is
/// how many containers one person opens in one run of the app, each a list of
/// track names, and paying a network round trip per revisit to save that is a
/// bad trade.
///
/// Copied from [SpotifyDetail].
class SpotifyDetailFamily extends Family<SpotifyDetailState> {
  /// One opened playlist, album, artist or saved-tracks collection.
  ///
  /// Keyed by [uri] and [kind] rather than held as a single current-container
  /// notifier: two detail screens can be on the stack at once — an artist opened
  /// from the grid, then one of its albums — and a single notifier would mean the
  /// one underneath quietly showing the one on top's tracks when you came back to
  /// it.
  ///
  /// keepAlive, and that IS the cache. There is no store, no TTL and no eviction
  /// anywhere in this feature, on purpose: a family provider that outlives its
  /// screen is already a keyed cache, and Riverpod is already the thing holding
  /// it. Spotube's whole metadata layer is built this exact way — every one of
  /// its paginated notifiers is a keepAlive family keyed by the thing it fetched
  /// — and inventing a second caching mechanism beside the one the app already
  /// depends on would be two sources of truth for "have we read this".
  ///
  /// This was auto-disposing until the owner used it on a phone: backing out of a
  /// playlist tore the notifier down, and opening it again paid a full round trip
  /// through the tunnel to redraw what had been on screen a second earlier. That
  /// is the "лаги пиздец словно мы ничего не кешируем" — the app genuinely was
  /// not caching, because the provider was told to throw the answer away. The
  /// justification that stood here, that keeping every opened container alive
  /// grows without bound, is true and does not matter at this size: the bound is
  /// how many containers one person opens in one run of the app, each a list of
  /// track names, and paying a network round trip per revisit to save that is a
  /// bad trade.
  ///
  /// Copied from [SpotifyDetail].
  const SpotifyDetailFamily();

  /// One opened playlist, album, artist or saved-tracks collection.
  ///
  /// Keyed by [uri] and [kind] rather than held as a single current-container
  /// notifier: two detail screens can be on the stack at once — an artist opened
  /// from the grid, then one of its albums — and a single notifier would mean the
  /// one underneath quietly showing the one on top's tracks when you came back to
  /// it.
  ///
  /// keepAlive, and that IS the cache. There is no store, no TTL and no eviction
  /// anywhere in this feature, on purpose: a family provider that outlives its
  /// screen is already a keyed cache, and Riverpod is already the thing holding
  /// it. Spotube's whole metadata layer is built this exact way — every one of
  /// its paginated notifiers is a keepAlive family keyed by the thing it fetched
  /// — and inventing a second caching mechanism beside the one the app already
  /// depends on would be two sources of truth for "have we read this".
  ///
  /// This was auto-disposing until the owner used it on a phone: backing out of a
  /// playlist tore the notifier down, and opening it again paid a full round trip
  /// through the tunnel to redraw what had been on screen a second earlier. That
  /// is the "лаги пиздец словно мы ничего не кешируем" — the app genuinely was
  /// not caching, because the provider was told to throw the answer away. The
  /// justification that stood here, that keeping every opened container alive
  /// grows without bound, is true and does not matter at this size: the bound is
  /// how many containers one person opens in one run of the app, each a list of
  /// track names, and paying a network round trip per revisit to save that is a
  /// bad trade.
  ///
  /// Copied from [SpotifyDetail].
  SpotifyDetailProvider call(
    String uri,
    SpotifyLibraryKind kind,
  ) {
    return SpotifyDetailProvider(
      uri,
      kind,
    );
  }

  @override
  SpotifyDetailProvider getProviderOverride(
    covariant SpotifyDetailProvider provider,
  ) {
    return call(
      provider.uri,
      provider.kind,
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
  String? get name => r'spotifyDetailProvider';
}

/// One opened playlist, album, artist or saved-tracks collection.
///
/// Keyed by [uri] and [kind] rather than held as a single current-container
/// notifier: two detail screens can be on the stack at once — an artist opened
/// from the grid, then one of its albums — and a single notifier would mean the
/// one underneath quietly showing the one on top's tracks when you came back to
/// it.
///
/// keepAlive, and that IS the cache. There is no store, no TTL and no eviction
/// anywhere in this feature, on purpose: a family provider that outlives its
/// screen is already a keyed cache, and Riverpod is already the thing holding
/// it. Spotube's whole metadata layer is built this exact way — every one of
/// its paginated notifiers is a keepAlive family keyed by the thing it fetched
/// — and inventing a second caching mechanism beside the one the app already
/// depends on would be two sources of truth for "have we read this".
///
/// This was auto-disposing until the owner used it on a phone: backing out of a
/// playlist tore the notifier down, and opening it again paid a full round trip
/// through the tunnel to redraw what had been on screen a second earlier. That
/// is the "лаги пиздец словно мы ничего не кешируем" — the app genuinely was
/// not caching, because the provider was told to throw the answer away. The
/// justification that stood here, that keeping every opened container alive
/// grows without bound, is true and does not matter at this size: the bound is
/// how many containers one person opens in one run of the app, each a list of
/// track names, and paying a network round trip per revisit to save that is a
/// bad trade.
///
/// Copied from [SpotifyDetail].
class SpotifyDetailProvider
    extends NotifierProviderImpl<SpotifyDetail, SpotifyDetailState> {
  /// One opened playlist, album, artist or saved-tracks collection.
  ///
  /// Keyed by [uri] and [kind] rather than held as a single current-container
  /// notifier: two detail screens can be on the stack at once — an artist opened
  /// from the grid, then one of its albums — and a single notifier would mean the
  /// one underneath quietly showing the one on top's tracks when you came back to
  /// it.
  ///
  /// keepAlive, and that IS the cache. There is no store, no TTL and no eviction
  /// anywhere in this feature, on purpose: a family provider that outlives its
  /// screen is already a keyed cache, and Riverpod is already the thing holding
  /// it. Spotube's whole metadata layer is built this exact way — every one of
  /// its paginated notifiers is a keepAlive family keyed by the thing it fetched
  /// — and inventing a second caching mechanism beside the one the app already
  /// depends on would be two sources of truth for "have we read this".
  ///
  /// This was auto-disposing until the owner used it on a phone: backing out of a
  /// playlist tore the notifier down, and opening it again paid a full round trip
  /// through the tunnel to redraw what had been on screen a second earlier. That
  /// is the "лаги пиздец словно мы ничего не кешируем" — the app genuinely was
  /// not caching, because the provider was told to throw the answer away. The
  /// justification that stood here, that keeping every opened container alive
  /// grows without bound, is true and does not matter at this size: the bound is
  /// how many containers one person opens in one run of the app, each a list of
  /// track names, and paying a network round trip per revisit to save that is a
  /// bad trade.
  ///
  /// Copied from [SpotifyDetail].
  SpotifyDetailProvider(
    String uri,
    SpotifyLibraryKind kind,
  ) : this._internal(
          () => SpotifyDetail()
            ..uri = uri
            ..kind = kind,
          from: spotifyDetailProvider,
          name: r'spotifyDetailProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$spotifyDetailHash,
          dependencies: SpotifyDetailFamily._dependencies,
          allTransitiveDependencies:
              SpotifyDetailFamily._allTransitiveDependencies,
          uri: uri,
          kind: kind,
        );

  SpotifyDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.uri,
    required this.kind,
  }) : super.internal();

  final String uri;
  final SpotifyLibraryKind kind;

  @override
  SpotifyDetailState runNotifierBuild(
    covariant SpotifyDetail notifier,
  ) {
    return notifier.build(
      uri,
      kind,
    );
  }

  @override
  Override overrideWith(SpotifyDetail Function() create) {
    return ProviderOverride(
      origin: this,
      override: SpotifyDetailProvider._internal(
        () => create()
          ..uri = uri
          ..kind = kind,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        uri: uri,
        kind: kind,
      ),
    );
  }

  @override
  NotifierProviderElement<SpotifyDetail, SpotifyDetailState> createElement() {
    return _SpotifyDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SpotifyDetailProvider &&
        other.uri == uri &&
        other.kind == kind;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, uri.hashCode);
    hash = _SystemHash.combine(hash, kind.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SpotifyDetailRef on NotifierProviderRef<SpotifyDetailState> {
  /// The parameter `uri` of this provider.
  String get uri;

  /// The parameter `kind` of this provider.
  SpotifyLibraryKind get kind;
}

class _SpotifyDetailProviderElement
    extends NotifierProviderElement<SpotifyDetail, SpotifyDetailState>
    with SpotifyDetailRef {
  _SpotifyDetailProviderElement(super.provider);

  @override
  String get uri => (origin as SpotifyDetailProvider).uri;
  @override
  SpotifyLibraryKind get kind => (origin as SpotifyDetailProvider).kind;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
