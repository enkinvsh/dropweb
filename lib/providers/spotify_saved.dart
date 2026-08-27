import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/spotify.dart';
import 'package:dropweb/providers/spotify_library.dart';
import 'package:dropweb/views/meowzic/spotify/gql.dart';
import 'package:dropweb/views/meowzic/spotify/library.dart';
import 'package:dropweb/views/meowzic/spotify/queries.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/spotify_saved.g.dart';

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
@Riverpod(keepAlive: true)
class SpotifySaved extends _$SpotifySaved {
  /// Guards the continuation of an await that landed after this notifier went
  /// away. Rare for a keepAlive provider — it takes the whole scope going down
  /// — but a mutation can be in flight for fifteen seconds, and assigning state
  /// to a disposed notifier throws. The same guard as in `spotify_likes.dart`.
  bool _disposed = false;

  @override
  Map<String, bool> build() {
    ref.onDispose(() => _disposed = true);
    return const <String, bool>{};
  }

  /// What we currently believe about [uri].
  ///
  /// Unknown reads as not saved, the same honest default the heart takes: the
  /// alternative is a tri-state the header would have to draw as a third thing,
  /// and there is nothing sensible for it to look like.
  bool isSaved(String uri) => state[uri] ?? false;

  /// Asks Spotify about the container uris we have no answer for yet.
  ///
  /// Only the unknown ones go on the wire — anything already in the map is a
  /// value we set from a read or from a write of our own.
  ///
  /// A failure here is swallowed, exactly as in `fetchLikedStatus`: not knowing
  /// whether a playlist is saved is the state this provider starts in and draws
  /// perfectly well, and putting an error banner over a playlist that opened
  /// fine would be reporting a fault the listener never asked about. It is
  /// written down in the log by `spotifyGqlQuery` either way.
  ///
  /// NOT sent with `mutation: true`, unlike the two writes below, and that is
  /// not an oversight. `_readMutationResult` insists on a non-null node keyed by
  /// the operation name; this document answers with `data.lookup`, so the strict
  /// check would throw on every successful read and the save control would never
  /// learn its own state. The flag guards writes claiming success they did not
  /// have — there is no such claim to guard here.
  Future<void> fetchSavedStatus(List<String> uris) async {
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
        operationName: 'areEntitiesInLibrary',
        sha256Hash: spotifyAreEntitiesInLibraryHash,
        variables: {'uris': wanted},
      );
      if (_disposed) return;

      final lookup = data['lookup'];
      if (lookup is! List) return;

      // Paired back to what we asked for by position and bounded by the shorter
      // of the two, for the reason spelled out in `fetchLikedStatus`: this
      // document answers positionally and carries no uri to key on, so a short
      // or reordered `lookup` can only be believed less, never repaired.
      // Anything malformed is skipped and stays unknown, which is a state this
      // provider already handles.
      final merged = {...state};
      var changed = false;
      for (var i = 0; i < wanted.length && i < lookup.length; i++) {
        final entry = lookup[i];
        if (entry is! Map<String, dynamic>) continue;
        final payload = entry['data'];
        if (payload is! Map<String, dynamic>) continue;
        final saved = payload['saved'];
        if (saved is! bool) continue;
        merged[wanted[i]] = saved;
        changed = true;
      }
      if (changed) state = merged;
    } catch (error) {
      commonPrint.log('spotify saved status fetch failed: $error');
    }
  }

  /// Flips [uri]'s membership of the library and tells Spotify about it.
  /// Returns null when it stuck, or the sentence the screen has to show.
  ///
  /// Optimistic: the map is flipped and published before anything is sent, so
  /// the control answers the tap in the same frame rather than after a round
  /// trip through the tunnel. On any failure the previous value goes back — and
  /// back to *unknown* if that is what it was, rather than being pinned to
  /// false by a rollback that guessed.
  ///
  /// Deliberately absent: any per-uri "in flight" flag in the state. Storing
  /// ephemeral interaction state in a keepAlive provider is how this project
  /// earned its resolve-spinner bug, and a keepAlive cache holds facts about
  /// the account, not what a finger is doing right now.
  ///
  /// The `mutation` flag is passed on both writes and is not optional. Without
  /// it a rotated persisted-query hash comes back as HTTP 200 with an `errors`
  /// list, this would count it as success, and the header would read "saved"
  /// over an account where nothing was written.
  Future<String?> toggleSaved(String uri) async {
    final previous = state[uri];
    final next = !(previous ?? false);
    state = {...state, uri: next};

    try {
      await spotifyGqlQuery(
        notifier: ref.read(spotifyAuthProvider.notifier),
        operationName: next ? 'addItemsToRootlist' : 'removeItemsFromRootlist',
        sha256Hash: next
            ? spotifyAddItemsToRootlistHash
            : spotifyRemoveItemsFromRootlistHash,
        variables: {
          'uris': [uri],
        },
        mutation: true,
      );
    } catch (error) {
      commonPrint.log('spotify toggle saved failed: $error');
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

    // The playlists grid is the one list a rootlist write changes, and it is
    // keepAlive, so nothing brings it back on its own. Exactly that one filter:
    // saving a playlist has no bearing on the albums or artists the listener
    // has already loaded, and dropping those too would pay two round trips to
    // redraw what did not move.
    if (!_disposed) {
      ref.invalidate(spotifyLibraryProvider(SpotifyLibraryFilter.playlists));
    }
    return null;
  }
}
