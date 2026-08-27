import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
// The narrow imports rather than the `providers` barrel, matching the rest of
// this directory: the barrel exports notifiers that import these files back.
import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/spotify.dart';
import 'package:dropweb/providers/state.dart';
import 'package:dropweb/views/meowzic/audio.dart';
import 'package:dropweb/views/meowzic/bridge.dart';
import 'package:dropweb/views/meowzic/spotify/detail.dart';
import 'package:dropweb/views/meowzic/spotify/session.dart';
import 'package:http/http.dart' as http;

/// How many tracks a tap queues: the one tapped and the nine behind it.
///
/// Not the whole container, and the arithmetic is the reason. Every track needs
/// its own ytbridge lookup, a cold one takes seconds, and a fifty-track
/// playlist would therefore hold the screen for the better part of a minute
/// before a single note played — to build a queue whose tail the listener will
/// most likely never reach. Ten resolves in one round of parallel calls and
/// gives the player enough runway that the gap is never heard.
///
/// The proper fix is a batch resolve on ytbridge: hand it a list of ISRCs and
/// get video ids back in one round trip, which would make queueing a whole
/// container cost what queueing ten costs now. It is deliberately not built
/// yet, because building the client half first would leave this app depending
/// on an endpoint that is not deployed — every tap would 404 until the bridge
/// caught up, on every node, and the app cannot tell "not deployed here yet"
/// from "broken".
const spotifyPlaybackWindow = 10;

/// Spotify's own ceiling on `/v1/tracks?ids=`. One window fits comfortably
/// inside it, so the ISRC lookup is always a single request.
const _isrcBatchLimit = 50;

const _isrcTimeout = Duration(seconds: 15);

/// The ISRCs for [trackIds], by track id, best-effort.
///
/// Never throws. A missing ISRC degrades the lookup to a text query, which
/// still plays something; a thrown error would degrade it to nothing at all,
/// and an identifier service has no business being able to stop playback.
///
/// This is the Web API rather than the GraphQL endpoint the rest of this
/// directory uses, because none of the recorded pathfinder responses carry an
/// ISRC — not the library, not the playlist, not the album. The web-player
/// bearer is accepted here: an anonymous token comes back 429, not 401, so the
/// credential is the right one and only the rate limit stands in the way.
Future<Map<String, String>> fetchSpotifyIsrcs({
  required SpotifyAuth notifier,
  required List<String> trackIds,
  http.Client? client,
}) async {
  if (trackIds.isEmpty) return const {};
  final credentials = await notifier.credentials();
  if (credentials == null) return const {};

  final borrowed = client != null;
  final transport = client ?? http.Client();
  try {
    final response = await transport.get(
      Uri.https('api.spotify.com', '/v1/tracks', {
        'ids': trackIds.take(_isrcBatchLimit).join(','),
      }),
      headers: {
        'Authorization': 'Bearer ${credentials.accessToken}',
        'Accept': 'application/json',
        'User-Agent': spotifyUserAgent,
      },
    ).timeout(_isrcTimeout);

    if (response.statusCode != HttpStatus.ok) {
      // 429 in particular is expected rather than exceptional — see above — and
      // is written down so a run of text-quality matches has an explanation
      // sitting in the log rather than being attributed to the bridge.
      commonPrint.log('spotify isrc lookup answered ${response.statusCode}');
      return const {};
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final tracks = decoded is Map<String, dynamic> ? decoded['tracks'] : null;
    if (tracks is! List) return const {};

    final isrcs = <String, String>{};
    for (final track in tracks.whereType<Map<String, dynamic>>()) {
      final id = track['id'];
      final external = track['external_ids'];
      final isrc = external is Map<String, dynamic> ? external['isrc'] : null;
      if (id is String && isrc is String && isrc.isNotEmpty) isrcs[id] = isrc;
    }
    return isrcs;
  } catch (error) {
    commonPrint.log('spotify isrc lookup failed: $error');
    return const {};
  } finally {
    if (!borrowed) transport.close();
  }
}

/// Turns Spotify tracks into a playable queue, in one round of parallel work.
///
/// [tracks] must start with the track that was tapped. The queue comes back
/// empty when that first one could not be resolved: the alternative is to drop
/// it like any other and start playing the track after it, which would answer a
/// deliberate tap by playing something else — a far worse outcome than saying
/// plainly that this one could not be found. Everything after the first is
/// dropped silently, because a hole in a queue is a track that stalls the
/// player when it advances into it.
Future<List<MeowzicQueueItem>> resolveSpotifyQueue({
  required SpotifyAuth notifier,
  required MeowzicBridge bridge,
  required List<SpotifyTrack> tracks,
  http.Client? client,
}) async {
  if (tracks.isEmpty) return const [];

  final borrowed = client != null;
  // One client for the whole window rather than one per lookup: ten tracks
  // means ten requests to the same host, and a shared client keeps them on the
  // connections it already has instead of opening ten and paying ten TLS
  // handshakes through the tunnel.
  final transport = client ?? http.Client();
  try {
    final isrcs = await fetchSpotifyIsrcs(
      notifier: notifier,
      trackIds: [for (final track in tracks) track.id],
      client: transport,
    );
    if (isrcs.isEmpty) {
      commonPrint.log(
        'spotify playback degraded to text queries for ${tracks.length} tracks',
      );
    }

    final resolved = await Future.wait([
      for (final track in tracks)
        _resolveTrack(bridge, track, isrcs[track.id], transport),
    ]);

    if (resolved.first == null) return const [];
    return [for (final item in resolved) if (item != null) item];
  } finally {
    if (!borrowed) transport.close();
  }
}

/// One Spotify track, matched to something the bridge can stream.
Future<MeowzicQueueItem?> _resolveTrack(
  MeowzicBridge bridge,
  SpotifyTrack track,
  String? isrc,
  http.Client transport,
) async {
  final artists = track.artists;
  final query = artists == null ? track.title : '${track.title} $artists';
  try {
    final results = await searchMeowzic(
      bridge,
      query,
      isrc: isrc,
      client: transport,
    );
    if (results.isEmpty) {
      commonPrint.log('spotify playback found no match for ${track.uri}');
      return null;
    }
    return MeowzicQueueItem(
      uri: bridge.audioUri(results.first.id),
      // Announced with Spotify's own metadata, not the YouTube result's. The
      // bridge returns whatever the uploader typed — "(Official Video)",
      // "[HQ]", a channel name in place of an artist — and that string is what
      // the lock screen and the car head unit would show. The id is the only
      // thing taken from the match, because it is the only thing Spotify
      // cannot supply.
      item: MediaItem(
        id: results.first.id,
        title: track.title,
        artist: track.artists,
        duration: track.duration > Duration.zero ? track.duration : null,
        artUri: track.image,
      ),
    );
  } on MeowzicException catch (error) {
    // Swallowed per track rather than aborted: one unreachable lookup out of
    // ten must not cost the other nine, and the caller already reports the
    // case that actually matters — the tapped track failing.
    commonPrint.log('spotify playback resolve failed for ${track.uri}: $error');
    return null;
  }
}
