// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../spotify_saved.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$spotifySavedHash() => r'7c25880f5289945b6918f005b0426dbe7452043e';

/// Which containers are in the account's own library, as far as this run knows.
///
/// The playlist half of what `SpotifyLikes` does for tracks next door, and
/// deliberately built to the same shape: one keepAlive notifier
/// owning one `Map<String, bool>` of container uri to saved, a batch read that
/// only asks about uris it has no answer for, and an optimistic toggle that
/// rolls back. Two notifiers rather than one map holding both because the wire
/// operations have nothing in common — `isCurated` against `applyCurations` for
/// a track, `areEntitiesInLibrary` against the rootlist for a container — and a
/// single map would have to branch on the uri's entity type at every call site
/// to know which of those to send.
///
/// keepAlive for the reason [SpotifyAuth] and `SpotifyDetail` have it: meowzic
/// lives inside a
/// pushed route, and an auto-disposing provider would be torn down the moment
/// the last screen watching it popped, re-fetching the saved state of a
/// playlist the listener backed out of one second ago.
///
/// Copied from [SpotifySaved].
@ProviderFor(SpotifySaved)
final spotifySavedProvider =
    NotifierProvider<SpotifySaved, Map<String, bool>>.internal(
  SpotifySaved.new,
  name: r'spotifySavedProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$spotifySavedHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SpotifySaved = Notifier<Map<String, bool>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
