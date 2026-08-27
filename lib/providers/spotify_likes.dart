import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/spotify.dart';
import 'package:dropweb/providers/spotify_detail.dart';
import 'package:dropweb/providers/spotify_library.dart';
import 'package:dropweb/providers/spotify_saved_tracks.dart';
import 'package:dropweb/views/meowzic/spotify/gql.dart';
import 'package:dropweb/views/meowzic/spotify/queries.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/spotify_likes.g.dart';

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
@Riverpod(keepAlive: true)
class SpotifyLikes extends _$SpotifyLikes {
  /// Guards the continuation of an await that landed after this notifier went
  /// away. Rare for a keepAlive provider — it takes the whole scope going down
  /// — but a mutation can be in flight for fifteen seconds, and assigning state
  /// to a disposed notifier throws. Same guard, same reason, as the one in
  /// `spotify_detail.dart`.
  bool _disposed = false;

  @override
  Map<String, bool> build() {
    ref.onDispose(() => _disposed = true);
    return const <String, bool>{};
  }

  /// What we currently believe about [uri].
  ///
  /// Unknown reads as not liked. That is the honest default for a hollow heart:
  /// the alternative is a tri-state the widget layer would have to render as a
  /// third thing, and Spotify's own client does not have one either.
  bool isLiked(String uri) => state[uri] ?? false;

  /// Asks Spotify about the uris we have no answer for yet.
  ///
  /// Only the unknown ones go on the wire — anything already in the map is a
  /// value we set from a read or from a write of our own, and re-asking would
  /// spend a round trip to be told what we just did.
  ///
  /// A failure here is swallowed. Not knowing whether a track is liked is the
  /// state this provider starts in and renders perfectly well; interrupting a
  /// listing with an error banner because a background status check did not
  /// land would be reporting a fault the listener did not ask about. It is
  /// written down in the log by `spotifyGqlQuery` either way.
  Future<void> fetchLikedStatus(List<String> uris) async {
    final wanted = <String>[];
    final seen = <String>{};
    for (final uri in uris) {
      if (state.containsKey(uri)) continue;
      if (!seen.add(uri)) continue;
      wanted.add(uri);
    }
    if (wanted.isEmpty) return;

    try {
      final data = await spotifyGqlQuery(
        notifier: ref.read(spotifyAuthProvider.notifier),
        operationName: 'isCurated',
        sha256Hash: spotifyIsCuratedHash,
        variables: {'uris': wanted},
      );
      if (_disposed) return;

      final lookup = data['lookup'];
      if (lookup is! List) return;

      // Paired back to what we asked for by position, and bounded by the
      // shorter of the two. Spotify answers this document positionally and has
      // no uri in the reply to key on, so a short or reordered `lookup` cannot
      // be repaired — it can only be believed less. Walking past the end of
      // either list would either throw or, worse, pin one track's status onto
      // another's heart. Anything malformed is skipped and simply stays
      // unknown, which is a state this provider already handles.
      final merged = {...state};
      var changed = false;
      for (var i = 0; i < wanted.length && i < lookup.length; i++) {
        final entry = lookup[i];
        if (entry is! Map<String, dynamic>) continue;
        final payload = entry['data'];
        if (payload is! Map<String, dynamic>) continue;
        final isCurated = payload['isCurated'];
        if (isCurated is! bool) continue;
        merged[wanted[i]] = isCurated;
        changed = true;
      }
      if (changed) state = merged;
    } catch (error) {
      commonPrint.log('spotify liked status fetch failed: $error');
    }
  }

  /// Flips [uri]'s like and tells Spotify about it. Returns null when it stuck,
  /// or the sentence the screen has to show when it did not.
  ///
  /// Optimistic: the map is flipped and published before anything is sent, so
  /// the heart answers the tap in the same frame rather than after a round trip
  /// through the tunnel. On any failure the previous value goes back — and back
  /// to *unknown* if that is what it was, rather than being pinned to false by
  /// a rollback that guessed.
  ///
  /// Deliberately absent: any per-uri "in flight" flag in the state. Storing
  /// ephemeral interaction state in a keepAlive provider is exactly how this
  /// project earned its resolve-spinner bug — a row marked as busy, the mark
  /// never taken off, and the guard that read it refusing the very tap meant to
  /// recover, on a screen that had nothing to do with the one that set it. A
  /// keepAlive cache holds facts about the account; it does not hold what a
  /// finger is doing right now. The optimistic flip plus a rollback is the
  /// whole mechanism, and it has nothing to leak.
  ///
  /// The `mutation` flag is passed on both calls and is not optional here.
  /// Without it a
  /// rotated persisted-query hash comes back as HTTP 200 with an `errors` list,
  /// this would count it as success, and the heart would stay filled over an
  /// account where nothing was written.
  Future<String?> toggleLike(String uri) async {
    final previous = state[uri];
    final next = !(previous ?? false);
    state = {...state, uri: next};

    try {
      final notifier = ref.read(spotifyAuthProvider.notifier);
      if (next) {
        await spotifyGqlQuery(
          notifier: notifier,
          operationName: 'addToLibrary',
          sha256Hash: spotifyAddToLibraryHash,
          variables: {
            'uris': [uri],
          },
          mutation: true,
        );
      } else {
        await spotifyGqlQuery(
          notifier: notifier,
          operationName: 'applyCurations',
          sha256Hash: spotifyApplyCurationsHash,
          variables: {
            'input': {
              'curations': [
                // Unliking a track is a curation, not `removeFromLibrary` —
                // that operation is for albums and artists. The literal below
                // is Spotify's name for the saved-tracks curation context in
                // *this payload* and is not the uri of the Liked Songs
                // container on the account; see [_invalidateLikedSongs] for
                // where that one actually comes from.
                {
                  'contextUri': 'spotify:collection:tracks',
                  'curationType': 'UNCURATE',
                },
              ],
              'itemUris': [uri],
            },
          },
          mutation: true,
        );
      }
    } catch (error) {
      commonPrint.log('spotify toggle like failed: $error');
      if (_disposed) return null;
      final rolled = {...state};
      if (previous == null) {
        rolled.remove(uri);
      } else {
        rolled[uri] = previous;
      }
      state = rolled;
      return appLocalizations.meowzicMutationFailed;
    }

    if (!_disposed) _invalidateLikedSongs();
    return null;
  }

  /// Tells the Сохранённые listing to read itself again, so a track just
  /// liked appears in it and one just unliked leaves.
  ///
  /// This used to go the long way round: look through the loaded Playlists
  /// library for a row whose kind is `likedSongs`, take its uri, and invalidate
  /// the [SpotifyDetail] family element under it. The comment that stood here
  /// argued at length that the uri must be read from the server rather than
  /// hard-coded — which was true, and beside the point. On a live account there
  /// IS no such row: `libraryV3` with the Playlists filter answers with real
  /// playlists and nothing else, so the lookup found nothing, invalidated
  /// nothing, and every like left the saved listing exactly as it was. Saved
  /// tracks are not a playlist; they have their own document and now their own
  /// notifier, addressed by the session rather than by a uri. Nothing here may
  /// go back through the library to reach them.
  ///
  /// [SpotifySavedTracks.refresh] rather than `ref.invalidate` on it: the tab
  /// that shows this listing may be the very screen the like was tapped on, and
  /// an invalidated keepAlive notifier comes back idle with nobody left to
  /// start it — a spinner that never resolves. It re-reads in place instead,
  /// and returns without asking Spotify anything when the tab was never opened.
  void _invalidateLikedSongs() {
    unawaited(ref.read(spotifySavedTracksProvider.notifier).refresh());
  }
}
