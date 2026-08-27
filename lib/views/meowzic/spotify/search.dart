import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/spotify.dart';
import 'package:dropweb/views/meowzic/spotify/detail.dart';
import 'package:dropweb/views/meowzic/spotify/gql.dart';
import 'package:dropweb/views/meowzic/spotify/library.dart';
import 'package:dropweb/views/meowzic/spotify/queries.dart';
import 'package:http/http.dart' as http;

/// Every wrapper key a search row has been seen to hide its track behind.
///
/// Ordered, and the order is the point: `item` is what the recorded search
/// responses carry, the other two are the names the sibling documents in this
/// directory use for the same job (`track` in the album and saved-track
/// queries, `itemV2` in a playlist's contents). Spotify renames this field
/// between documents freely — it is a field of a registered document, not a
/// contract — so the reader tries the family rather than betting the whole
/// screen on one spelling. Falling through to the row itself covers the day
/// they drop the wrapper entirely.
const _wrapperKeys = ['item', 'track', 'itemV2'];

/// Asks Spotify for tracks matching [query].
///
/// This is the search path for a listener who has linked an account, and it
/// replaces nothing on the audio side: ytbridge stays the source of sound,
/// matched to whatever comes back here by ISRC. What it replaces is ytbridge's
/// idea of what the listener asked for — a naive `ytsearch10` for one measured
/// query answered with six wrong tracks out of ten, live cuts and lyric videos
/// and translations of the title, because a video catalogue has no notion of
/// "the track". Spotify does, so the whole class of error goes away rather
/// than being ranked around.
///
/// [offset] and [limit] are real here, which they never were before; see the
/// note on [spotifySearchTracksHash] for why that decided the operation.
///
/// An answer with nothing in it is an empty list, not a failure: "ничего не
/// нашлось" is a normal outcome of typing, and raising it as an error would
/// tell the listener the app is broken when their spelling simply is. A
/// transport fault is still a [SpotifyGqlException] and is still the screen's
/// to explain — a rotated persisted hash never reaches the parsing below,
/// because it comes back as GraphQL `errors` with no `data` block at all.
Future<List<SpotifyTrack>> searchSpotifyTracks({
  required SpotifyAuth notifier,
  required String query,
  int offset = 0,
  int limit = 20,
  http.Client? client,
}) async {
  final data = await spotifyGqlQuery(
    notifier: notifier,
    operationName: 'searchTracks',
    sha256Hash: spotifySearchTracksHash,
    // Read off the registered document, not composed. A persisted query
    // rejects variables it was not registered with, so the fields that look
    // irrelevant to a track search — audiobooks, authors, the top-results
    // count — are sent anyway at the values the web player sends: they are the
    // document's shape, and trimming them to what we care about is how the
    // whole call starts answering with nothing.
    variables: {
      'searchTerm': query,
      'offset': offset,
      'limit': limit,
      'includePreReleases': false,
      'numberOfTopResults': 20,
      'includeAudiobooks': true,
      'includeAuthors': false,
    },
    client: client,
  );

  final search = data['searchV2'];
  final tracks = search is Map<String, dynamic> ? search['tracksV2'] : null;
  final items = tracks is Map<String, dynamic> ? tracks['items'] : null;
  if (items is! List) {
    // Logged and answered as "no results" rather than thrown, unlike the
    // container fetchers next door. Those open something the user already
    // knows exists, so a missing block there is a protocol change worth
    // reporting. Here the honest reading is ambiguous — a query nobody matched
    // and a facet Spotify stopped sending look identical from the outside — and
    // between blanking a search box with an error and printing "ничего не
    // нашлось", only this log line has to tell them apart.
    commonPrint.log('spotify searchTracks answered without searchV2.tracksV2');
    return const [];
  }

  final results = <SpotifyTrack>[];
  for (final entry in items.whereType<Map<String, dynamic>>()) {
    final parsed = _trackOf(entry);
    if (parsed != null) results.add(parsed);
  }
  return results;
}

/// Unpacks one `tracksV2.items[]` row, or null when it is not a playable track.
///
/// Null rather than an exception, for the reason the library parser gives: a
/// search answer is heterogeneous by construction, and one row this code has
/// never seen must not be able to empty the results for whoever's typing
/// produced it.
SpotifyTrack? _trackOf(Map<String, dynamic> entry) {
  for (final wrapper in _wrappersOf(entry)) {
    // `ResponseWrapper` puts the entity under `data` and its URI beside it as
    // `_uri`; some shapes hand the entity over bare. Both are tried on the same
    // candidate rather than guessed at per query, because guessing wrong here
    // does not fail — it yields a row with no URI, and the heart, the radio
    // menu and the now-playing highlight all key off that URI.
    final payload = wrapper['data'];
    final parsed = spotifyTrackOf(
      payload is Map<String, dynamic> ? payload : wrapper,
      wrapperUri: spotifyStringOf(wrapper['_uri']),
    );
    // Checked for the prefix the way `resolveSpotifyTrackRadio` checks its
    // playlist: `tracksV2` should hold only tracks, but a podcast episode or a
    // local file reaching the list would be parseable and unplayable, and the
    // ISRC lookup would report it as "нет аудио" instead of as a row that never
    // belonged here.
    if (parsed != null && parsed.uri.startsWith('spotify:track:')) {
      return parsed;
    }
  }
  return null;
}

/// The candidates for "the track" inside one row, best guess first.
Iterable<Map<String, dynamic>> _wrappersOf(Map<String, dynamic> entry) sync* {
  for (final key in _wrapperKeys) {
    final value = entry[key];
    if (value is Map<String, dynamic>) yield value;
  }
  yield entry;
}
