// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../spotify_isrcs.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$spotifyIsrcsHash() => r'bfb2f9630a5abeba6609b56b3c6f65f7df2a51f2';

/// Which ISRC belongs to which Spotify track, as far as this run knows.
///
/// This notifier exists because `/v1/tracks?ids=` throttles, and the throttle
/// was measured rather than feared. On the device, tapping around the search
/// results earned:
///
///     [dropweb] spotify isrc lookup answered 429
///     [dropweb] spotify playback degraded to text queries for 10 tracks
///
/// and the second line is the damage. Without an ISRC every track in the window
/// falls back to a text query against ytbridge — a live YouTube Music lookup per
/// track, seconds each against a fifteen-second ceiling, which is the long spin
/// the owner saw. Worse than the wait is what it plays: text matching is exactly
/// the live-cuts-and-lyric-videos mismatching this feature spent a day removing
/// by moving search onto Spotify in the first place. An exact-ISRC match, by
/// contrast, was measured at about half a second. So the 429 is the fault and
/// the spinner is only its shadow.
///
/// The fix is memory, not retries. An ISRC is a permanent fact about a
/// recording: the identifier does not expire, does not change, and cannot go
/// stale while the app is open. Asking Spotify a second time can therefore only
/// be answered with what we already have — or with a 429.
///
/// keepAlive IS the cache. That is the standing rule in this feature, the same
/// one `SpotifyDetail` and `SpotifyLikes` are built on: a provider that outlives
/// its screen is already a cache, and Riverpod is already holding it. Do NOT
/// "improve" this with a TTL, an LRU or a disk store — there is nothing here to
/// expire, and a second caching mechanism beside the one the app depends on
/// would be two sources of truth for "have we looked this up". The map costs a
/// track id and a twelve-character string per entry; a listening session cannot
/// grow it to a size worth a policy.
///
/// One notifier holding one map rather than a family keyed by track id, for the
/// reason `SpotifyLikes` gives: a family would grow one provider element per
/// track anybody scrolled past, which over a session is unbounded.
///
/// Deliberately absent: any "fetch in flight" flag. Ephemeral interaction state
/// in a keepAlive provider is how this project earned its resolve-spinner bug —
/// a mark set on one screen, never taken off, refusing the very tap meant to
/// recover on a screen that had nothing to do with it. A cache holds durable
/// facts about recordings; it does not hold what a finger is doing right now.
///
/// Copied from [SpotifyIsrcs].
@ProviderFor(SpotifyIsrcs)
final spotifyIsrcsProvider =
    NotifierProvider<SpotifyIsrcs, Map<String, String>>.internal(
  SpotifyIsrcs.new,
  name: r'spotifyIsrcsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$spotifyIsrcsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SpotifyIsrcs = Notifier<Map<String, String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
