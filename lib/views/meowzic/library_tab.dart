import 'package:dropweb/views/meowzic/spotify/library.dart';

/// Which band of the library the chips are showing.
///
/// A screen enum, not a wire one. [SpotifyLibraryFilter] next door is a set of
/// literals Spotify expects in `filters` on `libraryV3` — its doc comment says
/// so — and "Сохранённые" has no such literal: the account's saved tracks are
/// not a filter of the library, they are a pseudo-playlist that arrives *inside*
/// the Playlists filter and is opened by its own document. Adding a fourth value
/// there to get a fourth chip would be a lie in the one place in this feature
/// that is currently honest, and it would send `filters: ['Saved']` on the wire
/// the first time anybody forgot.
///
/// So the tabs are their own list and the last three map back onto the filter
/// they read from. [saved] maps onto nothing, which is exactly the fact the
/// screen needs to know: that tab is a track listing rather than a grid, and it
/// gets its rows from a container rather than from a library page.
///
/// It lives in the views layer rather than in the page file so the selection
/// notifier can hold it without a provider importing a screen.
enum MeowzicLibraryTab {
  saved,
  playlists,
  albums,
  artists;

  /// The library filter this tab draws, or null for [saved].
  ///
  /// Null rather than a default of `playlists`, and the difference matters: a
  /// default would quietly make the Сохранённые chip fetch and draw the
  /// playlists grid, which is the failure mode this enum exists to prevent.
  SpotifyLibraryFilter? get filter => switch (this) {
        MeowzicLibraryTab.saved => null,
        MeowzicLibraryTab.playlists => SpotifyLibraryFilter.playlists,
        MeowzicLibraryTab.albums => SpotifyLibraryFilter.albums,
        MeowzicLibraryTab.artists => SpotifyLibraryFilter.artists,
      };
}
