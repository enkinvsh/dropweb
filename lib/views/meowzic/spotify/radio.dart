import 'package:dropweb/providers/spotify.dart';
import 'package:dropweb/views/meowzic/spotify/gql.dart';
import 'package:http/http.dart' as http;

/// Spotify's seed-to-playlist service: hand it one thing, get a mix built
/// around it.
///
/// Not a pathfinder operation and therefore not in `queries.dart` — there is no
/// persisted hash to rotate here, only a path. It lives on
/// `spclient.wg.spotify.com`, which the web token already opens; see
/// [spotifyRestGet] for why that is the same envelope and not a second client.
const _spotifyRadioEndpoint =
    'https://spclient.wg.spotify.com/inspiredby-mix/v2/seed_to_playlist';

/// Asks Spotify to build a radio mix around [trackUri] and returns the uri of
/// the playlist it made.
///
/// The seed is passed as a whole `spotify:track:<id>` uri rather than a bare
/// id, because that is what the path segment is: this service seeds from
/// several entity types and tells them apart by the uri it was given.
///
/// Throws [SpotifyGqlException] and nothing else — the same four verdicts every
/// other Spotify call in this directory answers with, so the screen has one
/// vocabulary of failure rather than one per endpoint. An answer that carries
/// no mix is [SpotifyGqlFailure.upstream]: Spotify was reached and understood,
/// it simply had nothing to give, and there is no retry or credential that
/// changes that.
///
/// Deliberately a plain function and not a provider. A radio resolve is
/// something a finger is doing right now, not a fact about the account, and the
/// one place this project has already been burned is caching exactly that kind
/// of in-flight state in a keepAlive provider — a spinner that outlived its
/// screen and kept spinning on a playlist that had nothing to do with it. The
/// pending mark belongs in the widget that started it and dies with it.
Future<String> resolveSpotifyTrackRadio({
  required SpotifyAuth notifier,
  required String trackUri,
  http.Client? client,
}) async {
  final decoded = await spotifyRestGet(
    notifier: notifier,
    uri: Uri.parse(
      '$_spotifyRadioEndpoint/$trackUri?response-format=json',
    ),
    client: client,
  );

  // Read positionally off `mediaItems` rather than off `total`. The count is
  // advisory — an empty list with a non-zero total is still no mix — so the
  // list is the thing that decides, and a `total` of zero simply arrives here
  // as an empty list anyway.
  final items = decoded is Map<String, dynamic> ? decoded['mediaItems'] : null;
  if (items is! List || items.isEmpty) {
    throw const SpotifyGqlException(SpotifyGqlFailure.upstream);
  }

  final first = items.first;
  final uri = first is Map<String, dynamic> ? first['uri'] : null;
  // Checked for the prefix, not merely for being a string: this uri is about to
  // be opened as a playlist container and played from, and a seed answered with
  // some other entity type would fail much further downstream, where it would
  // read as "the playlist is empty" instead of "there is no radio".
  if (uri is! String || !uri.startsWith('spotify:playlist:')) {
    throw const SpotifyGqlException(SpotifyGqlFailure.upstream);
  }
  return uri;
}
