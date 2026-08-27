import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/spotify.dart';
import 'package:dropweb/views/meowzic/spotify/detail.dart';
import 'package:dropweb/views/meowzic/spotify/gql.dart';
import 'package:dropweb/views/meowzic/spotify/library.dart';
import 'package:dropweb/views/meowzic/spotify/queries.dart';
import 'package:http/http.dart' as http;

/// Spotify's own page size for the saved-tracks document, and the one the web
/// player sends.
///
/// Written down here rather than left as a default nobody can see, because the
/// paging above needs the number twice: once to ask, and once to decide whether
/// a full page means there is another behind it.
const spotifySavedTracksPageSize = 50;

/// Asks Spotify for one page of the account's saved tracks.
///
/// Saved tracks are NOT a playlist, and they do NOT come from `libraryV3`.
/// That assumption is the reason this function exists: the Сохранённые tab was
/// first built to load the Playlists filter, find the `PseudoPlaylist` row
/// inside it, take its uri and open that as a container — and on a live account
/// the row is simply not in that answer. The Плейлисты grid comes back holding
/// real playlists and nothing else, the lookup found nothing, and a listener
/// with a full Liked Songs got a tab reading «Здесь пока пусто». It shipped
/// that way. Nobody may reintroduce the detour: there is no library page to
/// wait for here, no tile to read a uri off, and nothing on this path that can
/// be blocked by the Playlists filter failing.
///
/// The document takes no uri at all — `{offset, limit}` is the whole of its
/// variables — because "whose saved tracks" is already answered by the session
/// the request is signed with. That is the shape of the thing: an account has
/// exactly one of these, so it needs no identity to address.
///
/// A read, not a mutation: `mutation: true` would demand an empty GraphQL
/// `errors` list on a document that answers tolerantly, and the strictness
/// exists to stop a *write* claiming a success it did not have.
///
/// Throws [SpotifyGqlException] — the caller decides what a failure looks like
/// on screen, the same division the library and container fetchers keep.
Future<List<SpotifyTrack>> fetchSpotifySavedTracks({
  required SpotifyAuth notifier,
  int offset = 0,
  int limit = spotifySavedTracksPageSize,
  http.Client? client,
}) async {
  final data = await spotifyGqlQuery(
    notifier: notifier,
    operationName: 'fetchLibraryTracks',
    sha256Hash: spotifyFetchLibraryTracksHash,
    variables: {'offset': offset, 'limit': limit},
    client: client,
  );

  final me = data['me'];
  final library = me is Map<String, dynamic> ? me['library'] : null;
  final tracks = library is Map<String, dynamic> ? library['tracks'] : null;
  final items = tracks is Map<String, dynamic> ? tracks['items'] : null;
  if (items is! List) {
    // Reported as upstream rather than answered as an empty account, the call
    // `fetchSpotifyLibrary` makes for the same reason. An account with nothing
    // saved answers with `items: []`, which IS a list — so reaching this line
    // means the shape changed, most likely a rotated persisted hash. Printing
    // "здесь пока пусто" over that is the exact bug this file was written to
    // end, and doing it a second time from a different cause would be worse
    // than the first.
    commonPrint.log(
      'spotify fetchLibraryTracks answered without me.library.tracks.items',
    );
    throw const SpotifyGqlException(SpotifyGqlFailure.upstream);
  }

  final parsed = <SpotifyTrack>[];
  for (final entry in items.whereType<Map<String, dynamic>>()) {
    // Two levels down and the uri is not where a reader expects it. Each row is
    // a `UserLibraryTrackResponse` carrying `addedAt` and a `track` wrapper; the
    // payload is `track.data`, and the wrapper is what holds the identity, as
    // `_uri`. Reading the uri off the payload instead yields a row that parses
    // perfectly and has no id — and the id is what the ISRC lookup, the heart
    // and the now-playing mark are all keyed on.
    final wrapper = entry['track'];
    if (wrapper is! Map<String, dynamic>) continue;
    final payload = wrapper['data'];
    if (payload is! Map<String, dynamic>) continue;
    // [spotifyTrackOf] rather than a reader of our own. It is the one place
    // that knows a track's length arrives under `trackDuration` in some
    // documents and `duration` in others, and a second copy of that gets it
    // wrong silently — a screen of 0:00 rows that still play, which nothing
    // reports until somebody squints at it.
    final track = spotifyTrackOf(
      payload,
      wrapperUri: spotifyStringOf(wrapper['_uri']),
    );
    // Dropped rather than thrown, for the reason the library and container
    // parsers give: one row this code has never seen — a local file, whatever
    // Spotify adds next — must not be able to blank the whole listing for
    // whoever happens to have saved it.
    if (track != null) parsed.add(track);
  }
  return parsed;
}
