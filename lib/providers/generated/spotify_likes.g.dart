// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../spotify_likes.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$spotifyLikesHash() => r'fcafb901c416e32cc3b15f95965d23c8166945c0';

/// Which tracks are in the account's Liked Songs, as far as this run knows.
///
/// One notifier holding one `Map<String, bool>`, rather than a family keyed by
/// track uri. A family would grow one provider element per track anybody so
/// much as looked at, and over a listening session that is unbounded — the
/// queue alone hands over a window at a time, and every playlist opened adds
/// its whole listing. The map costs a string and a bit per track and never
/// needs a policy to keep it that way; there is nothing here big enough to
/// evict.
///
/// The second reason matters more than the memory. There is exactly one owner
/// of "is this liked", so the answer cannot disagree with itself between the
/// mini-player and the notification shade, and dropping the Liked Songs
/// container after a write is one call from one place instead of a rule every
/// caller has to remember.
///
/// keepAlive for the reason [SpotifyAuth], [SpotifyLibrary] and [SpotifyDetail]
/// have it: meowzic lives inside a pushed route, so an auto-disposing provider
/// would be torn down the moment the last screen watching it popped — and every
/// heart would be re-fetched on the way back in.
///
/// Copied from [SpotifyLikes].
@ProviderFor(SpotifyLikes)
final spotifyLikesProvider =
    NotifierProvider<SpotifyLikes, Map<String, bool>>.internal(
  SpotifyLikes.new,
  name: r'spotifyLikesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$spotifyLikesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SpotifyLikes = Notifier<Map<String, bool>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
