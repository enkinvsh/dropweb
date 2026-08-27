// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../spotify_saved_tracks.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$spotifySavedTracksHash() =>
    r'3130e7661b10687868a2cc9aacfcf2dbb93dcd6f';

/// The account's saved tracks — the rows behind the Сохранённые tab.
///
/// Its own notifier rather than another `SpotifyDetail` family element, because
/// saved tracks are not a container the app opens: they have no uri to key a
/// family on. The tab was first built as though they did — find the Liked Songs
/// pseudo-playlist in the Playlists library, read its uri, open that — and on a
/// live account that row is not in the library answer at all, so the tab
/// shipped showing «Здесь пока пусто» over a full Liked Songs. There is one of
/// these per account and the session already says which account; see
/// `saved_tracks.dart`.
///
/// Nothing here may wait on `spotifyLibraryProvider`. That coupling is the bug,
/// not an implementation detail of it: the Плейлисты filter failing, or simply
/// never having been opened, must have no bearing on whether this tab can draw.
///
/// keepAlive for the reason `SpotifySearch`, `SpotifyAuth` and `SpotifyLibrary`
/// have it: the meowzic page is pushed as a route, so anything kept in the
/// tab's `State` is built fresh on every open — and this is the first tab, the
/// one every arrival lands on.
///
/// In memory only. Surviving an app restart would need a table and is a
/// separate decision; surviving navigation is this one.
///
/// Copied from [SpotifySavedTracks].
@ProviderFor(SpotifySavedTracks)
final spotifySavedTracksProvider =
    NotifierProvider<SpotifySavedTracks, SpotifySavedTracksState>.internal(
  SpotifySavedTracks.new,
  name: r'spotifySavedTracksProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$spotifySavedTracksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SpotifySavedTracks = Notifier<SpotifySavedTracksState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
