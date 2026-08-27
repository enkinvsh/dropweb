import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
// The narrow imports rather than the `providers` barrel, matching the rest of
// this directory: the barrel exports notifiers that import these files back.
import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/spotify.dart';
import 'package:dropweb/providers/spotify_isrcs.dart';
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

/// How long the rest of the window may keep the tapped track waiting.
///
/// Deliberately short. The first track is already resolved and playable by the
/// time this starts, so every second here is silence the listener is paying for
/// tracks they have not asked for yet. Whatever misses it is dropped from the
/// queue, not waited on.
const _prefetchBudget = Duration(seconds: 6);

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
      //
      // Named apart from every other refusal because the two ask different
      // things of whoever reads the log. Throttled means the credential and the
      // request were both right and the endpoint simply said "not so fast" —
      // the answer is to ask it less, which is what `SpotifyIsrcs` now does.
      // Any other code means the request itself is wrong, and asking less would
      // hide it. A single line reading "answered 401" for both was the reason
      // the throttle went unattributed for a day.
      commonPrint.log(
        response.statusCode == HttpStatus.tooManyRequests
            ? 'spotify isrc lookup throttled: answered 429'
            : 'spotify isrc lookup answered ${response.statusCode}',
      );
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
///
/// [isrcCache] is where the identifiers come from when the caller has one, and
/// every caller in the app does — all three `play` paths hold a `ref`. It is
/// optional rather than required so this function still behaves exactly as it
/// did when nobody hands one over: the network is asked directly, which is what
/// keeps tests and any future caller honest instead of silently uncached.
///
/// Handing the cache in rather than reaching for the provider from here is
/// deliberate. This is a plain function in the views layer; a global read would
/// tie it to a container it does not own and make it untestable without one.
Future<List<MeowzicQueueItem>> resolveSpotifyQueue({
  required SpotifyAuth notifier,
  required MeowzicBridge bridge,
  required List<SpotifyTrack> tracks,
  SpotifyIsrcs? isrcCache,
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
    final trackIds = [for (final track in tracks) track.id];
    // The cache is asked first and the network only for what it cannot answer.
    // That ordering is the fix for a measured 429 on `/v1/tracks?ids=`: the
    // endpoint is throttled hard against the web-player bearer, and the old
    // path spent a request on every single tap — including a tap on a window
    // whose ISRCs it had just been given a second earlier.
    final isrcs = isrcCache == null
        ? await fetchSpotifyIsrcs(
            notifier: notifier,
            trackIds: trackIds,
            client: transport,
          )
        : await isrcCache.ensureFor(trackIds, client: transport);

    // Counted per track rather than reported on an empty map, so this line now
    // means what it says. It is the expensive outcome and deserves to be
    // legible: a track with no ISRC is matched by title text against ytbridge,
    // which is both slow — a live YouTube Music lookup, seconds each — and the
    // very mismatching (live cuts, lyric videos, covers) that moving search to
    // Spotify was meant to end. It should now appear only when an identifier
    // genuinely could not be had, not on every throttled call.
    final missing = trackIds.where((id) => !isrcs.containsKey(id)).length;
    if (missing > 0) {
      commonPrint.log(
        'spotify playback degraded to text queries for $missing tracks',
      );
    }

    // The tapped track is resolved ALONE and first, and only then is the rest
    // of the window given a short budget of its own.
    //
    // This used to be one `Future.wait` over the whole window, and on a device
    // it timed out: `TimeoutException after 0:00:45` with the listener staring
    // at a spinner the whole time. The cause is head-of-line blocking — ten
    // lookups go out through the tunnel and the queue is handed back only when
    // the SLOWEST returns, so a track that was ready in a second is held
    // hostage by a straggler that never comes. One deliberate tap must not be
    // priced at ten network round trips.
    //
    // The prefetch keeps a deadline rather than a `Future.wait`, because a
    // short queue that plays beats a complete queue that never arrives. What
    // misses the deadline is dropped, which the queue contract above already
    // allows for: everything after the first is droppable, and a hole would
    // stall the player when it advanced into it.
    final head = await _resolveTrack(
      bridge,
      tracks.first,
      isrcs[tracks.first.id],
      transport,
    );
    if (head == null) return const [];
    if (tracks.length == 1) return [head];

    // Indexed slots, not `add` on completion: the queue must keep the order of
    // the listing the tap came from, and completion order is arrival order.
    final rest = List<MeowzicQueueItem?>.filled(tracks.length - 1, null);
    await Future.wait<void>([
      for (var i = 1; i < tracks.length; i++)
        _resolveTrack(bridge, tracks[i], isrcs[tracks[i].id], transport)
            .then((item) => rest[i - 1] = item),
    ]).timeout(_prefetchBudget, onTimeout: () => const <void>[]);

    return [head, for (final item in rest) if (item != null) item];
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
        // The one thing the queue keeps of where this track came from. `id` is
        // a YouTube video, so without this the player — and the notification
        // shade behind it — has no way to name the Spotify track it is
        // playing, and nothing to write a like against. Tracks queued from the
        // search tab come from the bridge alone and never get this key, which
        // is how the UI knows not to offer an action it cannot perform.
        extras: {'spotifyUri': track.uri},
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
