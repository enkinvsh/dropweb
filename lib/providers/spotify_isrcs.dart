import 'dart:async';

import 'package:dropweb/providers/spotify.dart';
import 'package:dropweb/views/meowzic/spotify/playback.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/spotify_isrcs.g.dart';

/// Which ISRC belongs to which Spotify track, as far as this run knows.
///
/// This notifier exists because `/v1/tracks?ids=` throttles, and the throttle
/// was measured rather than feared. On the device, tapping around the search
/// results earned:
///
///     [dropweb] spotify isrc lookup answered 429
///     [dropweb] spotify playback degraded to text queries for 10 tracks
///
/// and the second line is the damage. Without an ISRC every track in the window
/// falls back to a text query against ytbridge — a live YouTube Music lookup per
/// track, seconds each against a fifteen-second ceiling, which is the long spin
/// the owner saw. Worse than the wait is what it plays: text matching is exactly
/// the live-cuts-and-lyric-videos mismatching this feature spent a day removing
/// by moving search onto Spotify in the first place. An exact-ISRC match, by
/// contrast, was measured at about half a second. So the 429 is the fault and
/// the spinner is only its shadow.
///
/// The fix is memory, not retries. An ISRC is a permanent fact about a
/// recording: the identifier does not expire, does not change, and cannot go
/// stale while the app is open. Asking Spotify a second time can therefore only
/// be answered with what we already have — or with a 429.
///
/// keepAlive IS the cache. That is the standing rule in this feature, the same
/// one `SpotifyDetail` and `SpotifyLikes` are built on: a provider that outlives
/// its screen is already a cache, and Riverpod is already holding it. Do NOT
/// "improve" this with a TTL, an LRU or a disk store — there is nothing here to
/// expire, and a second caching mechanism beside the one the app depends on
/// would be two sources of truth for "have we looked this up". The map costs a
/// track id and a twelve-character string per entry; a listening session cannot
/// grow it to a size worth a policy.
///
/// One notifier holding one map rather than a family keyed by track id, for the
/// reason `SpotifyLikes` gives: a family would grow one provider element per
/// track anybody scrolled past, which over a session is unbounded.
///
/// Deliberately absent: any "fetch in flight" flag. Ephemeral interaction state
/// in a keepAlive provider is how this project earned its resolve-spinner bug —
/// a mark set on one screen, never taken off, refusing the very tap meant to
/// recover on a screen that had nothing to do with it. A cache holds durable
/// facts about recordings; it does not hold what a finger is doing right now.
@Riverpod(keepAlive: true)
class SpotifyIsrcs extends _$SpotifyIsrcs {
  /// Guards the continuation of an await that landed after this notifier went
  /// away. Rare for a keepAlive provider — it takes the whole scope going down
  /// — but a lookup can be in flight for fifteen seconds, and assigning state
  /// to a disposed notifier throws. Same guard, same reason, as the one in
  /// `spotify_detail.dart`.
  bool _disposed = false;

  @override
  Map<String, String> build() {
    ref
      ..onDispose(() => _disposed = true)
      // Listened to rather than watched: `watch` would rebuild this notifier
      // and throw the identifiers away on any auth change at all, including the
      // display name arriving a moment after sign-in — which would put the app
      // straight back on the throttled endpoint.
      ..listen(spotifyAuthProvider, _onAuthChanged);
    return const <String, String>{};
  }

  void _onAuthChanged(SpotifyAuthState? _, SpotifyAuthState next) {
    if (next.phase != SpotifyPhase.signedOut) return;
    // Emptied on sign-out, the call `SpotifySearch` and `SpotifySavedTracks`
    // make. Nothing here is private to an account — an ISRC is public catalogue
    // data — but a provider that survives the account it was filled under is a
    // provider nobody can reason about, and the entries are cheap to earn back.
    state = const <String, String>{};
  }

  /// What we currently believe [trackId]'s ISRC to be, without asking anyone.
  ///
  /// Unknown reads as null, and null is a perfectly good answer: the caller
  /// degrades that one track to a text query, which still plays something.
  String? isrcOf(String trackId) => state[trackId];

  /// The ISRCs for [trackIds], asking the network only about the ones we have
  /// never been told.
  ///
  /// Returns only what is known for the ids that were asked for — never the
  /// whole map — so the caller cannot accidentally match a window against
  /// somebody else's playlist.
  ///
  /// A refusal does not poison anything. `fetchSpotifyIsrcs` answers a 429, or
  /// any other non-200, with an empty map; nothing is merged, the entries we
  /// already hold stand, and the ids we never learned simply stay unknown. A
  /// negative result is never written down as though it were an answer — doing
  /// so would turn one throttled minute into a permanently text-matched track
  /// for the rest of the run.
  Future<Map<String, String>> ensureFor(
    List<String> trackIds, {
    http.Client? client,
  }) async {
    final known = state;
    final wanted = <String>[];
    final seen = <String>{};
    for (final id in trackIds) {
      if (id.isEmpty) continue;
      if (known.containsKey(id)) continue;
      if (!seen.add(id)) continue;
      wanted.add(id);
    }

    // The whole point of the provider: a window whose ids are all already known
    // reaches the player without touching `api.spotify.com` at all, which is
    // what stops the throttle from ever being earned on a second tap.
    if (wanted.isEmpty) return _slice(known, trackIds);

    final fetched = await fetchSpotifyIsrcs(
      notifier: ref.read(spotifyAuthProvider.notifier),
      trackIds: wanted,
      client: client,
    );
    if (_disposed) return _slice(known, trackIds);
    if (fetched.isEmpty) return _slice(state, trackIds);

    // Merged rather than replaced, and read from `state` again rather than from
    // the `known` taken before the await: another window may have landed while
    // this one was on the wire, and rebuilding from the stale copy would drop
    // what it just learned.
    final merged = {...state, ...fetched};
    state = merged;
    return _slice(merged, trackIds);
  }

  /// The entries of [source] that [trackIds] asked about, and nothing else.
  Map<String, String> _slice(Map<String, String> source, List<String> trackIds) {
    final answer = <String, String>{};
    for (final id in trackIds) {
      final isrc = source[id];
      if (isrc != null) answer[id] = isrc;
    }
    return answer;
  }
}
