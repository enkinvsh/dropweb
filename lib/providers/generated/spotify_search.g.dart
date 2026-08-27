// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../spotify_search.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$spotifySearchHash() => r'26e9f21cd67f7d0c4570cc42da2014c8238fa859';

/// Spotify search, held above the route.
///
/// This is the search a listener with a linked account gets, and it exists
/// because ytbridge's own search is a video search: a measured `ytsearch10` for
/// one ordinary query answered with six wrong tracks out of ten — live cuts,
/// lyric videos, a translated title, a clean edit — because a video catalogue
/// has no notion of "the track". Spotify does. ytbridge stays the source of
/// sound; it stops being the source of truth about what was asked for.
///
/// Playing a result therefore goes the same way a playlist row does:
/// [resolveSpotifyQueue] looks the ISRC up and hands *that* to the bridge. It
/// must never fall back to searching the bridge by title text — that is
/// precisely the matching this notifier exists to remove, and it would fail
/// silently, playing the wrong recording rather than reporting anything.
///
/// keepAlive for the reason `MeowzicSearch`, [SpotifyAuth] and `SpotifyLibrary`
/// have it: the meowzic page is pushed as a route, so anything kept in the
/// tab's `State` is built fresh on every open and a search someone waited on is
/// gone the moment they tap a track and come back.
///
/// In memory only. Surviving an app restart would need a table and is a
/// separate decision; surviving navigation is this one.
///
/// Copied from [SpotifySearch].
@ProviderFor(SpotifySearch)
final spotifySearchProvider =
    NotifierProvider<SpotifySearch, SpotifySearchState>.internal(
  SpotifySearch.new,
  name: r'spotifySearchProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$spotifySearchHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SpotifySearch = Notifier<SpotifySearchState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
