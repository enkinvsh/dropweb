import 'dart:async';
import 'dart:math' as math;

import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/app.dart';
import 'package:dropweb/providers/spotify.dart';
import 'package:dropweb/providers/spotify_isrcs.dart';
import 'package:dropweb/providers/state.dart';
import 'package:dropweb/views/meowzic/audio.dart';
import 'package:dropweb/views/meowzic/phase.dart';
import 'package:dropweb/views/meowzic/spotify/detail.dart';
import 'package:dropweb/views/meowzic/spotify/gql.dart';
import 'package:dropweb/views/meowzic/spotify/playback.dart';
import 'package:dropweb/views/meowzic/spotify/search.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/spotify_search.g.dart';

/// How many results one page of a Spotify search asks for.
///
/// Twenty, which is what `searchSpotifyTracks` defaults to and what the web
/// player sends. It is written down here rather than left implicit because the
/// paging below needs the number twice: once to ask, and once to decide whether
/// a full page means there is another behind it.
const spotifySearchPageSize = 20;

/// How long handing a queue to the player may take before the tap is abandoned.
///
/// The twin of the constant in `spotify_detail.dart`, and deliberately the same
/// number: both are the same act — ten bridge lookups and a `playQueue` — and a
/// tap that gives up after fifteen seconds in search and forty-five in a
/// playlist would be one app behaving as two. It exists only so that a load
/// which will never finish cannot hold the resolving mark forever.
const _playbackStartTimeout = Duration(seconds: 45);

/// The Spotify search tab's whole visible state.
///
/// Immutable and replaced wholesale rather than patched, the call
/// `MeowzicSearchState`, `SpotifyLibraryState` and `SpotifyDetailState` all
/// make: every transition names every field it means, which is cheaper to read
/// than a `copyWith` that has to say whether it is keeping or clearing the
/// failure.
///
/// Deliberately a second state next to `MeowzicSearchState` rather than one
/// type holding both. A bridge hit is a `MeowzicTrack` — a YouTube video id —
/// and a Spotify hit is a [SpotifyTrack] with a uri and no video id at all
/// until the bridge is asked. A union of the two would push the question "which
/// one is this" into every row, every menu and every play path, to save one
/// class.
class SpotifySearchState {
  const SpotifySearchState({
    this.query = '',
    this.phase = MeowzicPhase.idle,
    this.results = const [],
    this.failure,
    this.loadingMore = false,
    this.hasMore = false,
  });

  /// What was actually searched for, so the box can be refilled with it. The
  /// live text of the field is the field's own business until it is submitted.
  final String query;
  final MeowzicPhase phase;
  final List<SpotifyTrack> results;
  final SpotifyGqlFailure? failure;

  /// A further page is being appended to results that are already on screen.
  /// Separate from [phase] so the list is never taken away to show a spinner —
  /// the same split `SpotifyDetailState` keeps for the same reason.
  final bool loadingMore;

  /// Whether asking again would return anything.
  ///
  /// Driven off "the last page came back full" rather than off a total, because
  /// this is the one paginated thing in meowzic that has no total to drive it:
  /// `searchSpotifyTracks` answers with tracks and nothing else. A full page is
  /// the only evidence there is that Spotify has more, and a page short of the
  /// limit is the end.
  final bool hasMore;
}

/// Spotify search, held above the route.
///
/// This is the search a listener with a linked account gets, and it exists
/// because ytbridge's own search is a video search: a measured `ytsearch10` for
/// one ordinary query answered with six wrong tracks out of ten — live cuts,
/// lyric videos, a translated title, a clean edit — because a video catalogue
/// has no notion of "the track". Spotify does. ytbridge stays the source of
/// sound; it stops being the source of truth about what was asked for.
///
/// Playing a result therefore goes the same way a playlist row does:
/// [resolveSpotifyQueue] looks the ISRC up and hands *that* to the bridge. It
/// must never fall back to searching the bridge by title text — that is
/// precisely the matching this notifier exists to remove, and it would fail
/// silently, playing the wrong recording rather than reporting anything.
///
/// keepAlive for the reason `MeowzicSearch`, [SpotifyAuth] and `SpotifyLibrary`
/// have it: the meowzic page is pushed as a route, so anything kept in the
/// tab's `State` is built fresh on every open and a search someone waited on is
/// gone the moment they tap a track and come back.
///
/// In memory only. Surviving an app restart would need a table and is a
/// separate decision; surviving navigation is this one.
@Riverpod(keepAlive: true)
class SpotifySearch extends _$SpotifySearch {
  /// Guards against a slow query landing after a faster later one and
  /// overwriting it. Spotify is reached over the tunnel, which is long enough
  /// for somebody to retype.
  int _generation = 0;

  /// Where the next page starts, counted in rows *asked for* rather than rows
  /// kept.
  ///
  /// The two differ: the parser drops anything in `tracksV2` that is not a
  /// playable track — a podcast episode, a local file — so `results.length` is
  /// at or below the number Spotify has already handed over. Paging off the
  /// kept count would re-ask for rows we were already given and print them
  /// twice.
  int _offset = 0;

  /// Guards the continuation of an await that landed after this notifier went
  /// away. Same guard, same reason, as the one in `spotify_detail.dart`.
  bool _disposed = false;

  @override
  SpotifySearchState build() {
    ref
      ..onDispose(() => _disposed = true)
      // Listened to rather than watched: `watch` would rebuild this notifier
      // and throw the results away on any auth change at all, including the
      // display name arriving a moment after sign-in.
      ..listen(spotifyAuthProvider, _onAuthChanged);
    return const SpotifySearchState();
  }

  void _onAuthChanged(SpotifyAuthState? _, SpotifyAuthState next) {
    if (next.phase != SpotifyPhase.signedOut) return;
    // Emptied, not left to go stale. The tab falls back to the bridge the
    // moment the account goes, and somebody who links a second account must not
    // find the first one's results sitting behind the box. The generation bump
    // is what stops a page that is still in flight from landing on top of this.
    _generation++;
    _offset = 0;
    state = const SpotifySearchState();
  }

  /// Runs [raw] as a fresh search, replacing whatever was found before.
  Future<void> search(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;

    final generation = ++_generation;
    state = SpotifySearchState(
      query: query,
      phase: MeowzicPhase.loading,
      // Carried through the loading and failed states so a query that turns out
      // badly does not also wipe the results that were on screen.
      results: state.results,
    );

    try {
      final tracks = await searchSpotifyTracks(
        notifier: ref.read(spotifyAuthProvider.notifier),
        query: query,
        limit: spotifySearchPageSize,
      );
      if (_disposed || generation != _generation) return;
      _offset = spotifySearchPageSize;
      state = SpotifySearchState(
        query: query,
        phase: MeowzicPhase.done,
        results: tracks,
        hasMore: tracks.length >= spotifySearchPageSize,
      );
    } on SpotifyGqlException catch (error) {
      if (_disposed || generation != _generation) return;
      state = SpotifySearchState(
        query: query,
        phase: MeowzicPhase.failed,
        results: state.results,
        failure: error.failure,
      );
    } catch (error, stackTrace) {
      // Everything that is not a `SpotifyGqlException` — a `TimeoutException`, a
      // cast that failed on a shape Spotify moved, a `StateError`. The owner hit
      // this class of defect on a Pixel, on the sibling Сохранённые tab: the
      // list spun forever, the flutter log for that moment was completely EMPTY,
      // and killing the app was the only cure. That is what an escaping
      // throwable does — the future is unawaited, so the zone swallows it
      // silently and `phase` is left on `loading`, which every guard in here
      // reads as "already working" and steps aside for.
      //
      // The invariant this establishes, and the reason neither catch-all in this
      // file is defensive noise to be tidied away: after any load attempt,
      // `phase` is `done` or `failed` — never `loading`.
      //
      // The log line is the other half of the fix and is not optional. This
      // failure mode was not merely wrong, it was invisible.
      commonPrint.log(
        'SpotifySearch.search failed (query: $query): $error\n$stackTrace',
      );
      if (_disposed || generation != _generation) return;
      state = SpotifySearchState(
        query: query,
        phase: MeowzicPhase.failed,
        results: state.results,
        // `upstream` because that is the whole of what an untyped throwable
        // supports saying: something answered and misbehaved.
        failure: SpotifyGqlFailure.upstream,
      );
    }
  }

  /// Appends the next page, when there is one and nothing is already in flight.
  ///
  /// The same shape `SpotifyDetail.fetchMore` has, wired to the same scroll
  /// notification, because it is the same gesture. It is also the whole point
  /// of moving off the bridge for search: ytbridge's `/s` endpoint has no
  /// cursor and a hard ceiling of twenty results, so "показать ещё" was not
  /// something the app could offer at all.
  Future<void> fetchMore() async {
    if (state.phase != MeowzicPhase.done) return;
    if (state.loadingMore || !state.hasMore) return;

    final query = state.query;
    final generation = _generation;
    final existing = state.results;
    state = SpotifySearchState(
      query: query,
      phase: MeowzicPhase.done,
      results: existing,
      loadingMore: true,
      hasMore: true,
    );

    try {
      final page = await searchSpotifyTracks(
        notifier: ref.read(spotifyAuthProvider.notifier),
        query: query,
        offset: _offset,
        limit: spotifySearchPageSize,
      );
      if (_disposed || generation != _generation) return;
      _offset += spotifySearchPageSize;
      state = SpotifySearchState(
        query: query,
        phase: MeowzicPhase.done,
        results: [...existing, ...page],
        hasMore: page.length >= spotifySearchPageSize,
      );
    } on SpotifyGqlException {
      if (_disposed || generation != _generation) return;
      // The results that are already up survive a failed page, the call
      // `SpotifyDetail.fetchMore` makes: reaching the bottom on a dropped
      // connection must not delete what was read on the way down, and the
      // failure is not surfaced either because the screen is still showing a
      // working listing. It is written down in the log by `spotifyGqlQuery`;
      // the next scroll retries.
      state = SpotifySearchState(
        query: query,
        phase: MeowzicPhase.done,
        results: existing,
        hasMore: true,
      );
    } catch (error, stackTrace) {
      // See the catch-all in [search]. Nothing may leave `phase` on `loading`,
      // and nothing may fail without saying so in the log.
      commonPrint.log(
        'SpotifySearch.fetchMore failed (query: $query, offset: $_offset): '
        '$error\n$stackTrace',
      );
      if (_disposed || generation != _generation) return;
      // Same landing as the typed branch above: the results already on screen
      // stay, and no failure is surfaced over a listing that still reads
      // correctly.
      state = SpotifySearchState(
        query: query,
        phase: MeowzicPhase.done,
        results: existing,
        hasMore: true,
      );
    }
  }

  /// Plays the result at [index] and queues the window behind it.
  ///
  /// Character for character the path a playlist row takes —
  /// [resolveSpotifyQueue], which looks the ISRC up and matches on that — and
  /// that identity is the feature. A result found on Spotify and played from
  /// search is the same recording as the same result played from a playlist,
  /// because both are resolved by the same identifier rather than by the title
  /// somebody typed.
  ///
  /// Returns the message a failed tap has to show, or null when it played. The
  /// message is decided here because the reason is; showing it needs a
  /// `BuildContext`, which is the screen's to hold, not this one's.
  Future<String?> play(int index) async {
    final tracks = state.results;
    if (index < 0 || index >= tracks.length) return null;

    // A second tap while the first is still resolving is ignored rather than
    // queued, and the mark is read from the shared value rather than from this
    // notifier: the tap being waited on may have come from a playlist screen
    // entirely, and two owners each minding their own flag is how one of them
    // ends up spinning forever while the other plays.
    if (meowzicResolvingListenable.value != null) return null;

    final bridge = ref.read(meowzicBridgeProvider);
    if (bridge == null) return null;

    final window = tracks.sublist(
      index,
      math.min(index + spotifyPlaybackWindow, tracks.length),
    );
    meowzicResolvingListenable.value = window.first.uri;

    try {
      final queue = await resolveSpotifyQueue(
        notifier: ref.read(spotifyAuthProvider.notifier),
        bridge: bridge,
        tracks: window,
        // Handed in from here because this is where the `ref` lives. The search
        // tab is where the throttle was actually observed: tapping one result
        // after another walks overlapping windows through the same endpoint,
        // and the cache is what stops the second tap from paying for it.
        isrcCache: ref.read(spotifyIsrcsProvider.notifier),
      );
      if (_disposed) return null;
      // Empty means the tapped track itself did not resolve — the queue builder
      // refuses to substitute the next one. Reported as "not found" rather than
      // as a bridge fault, because the bridge answered; it simply had nothing.
      if (queue.isEmpty) return appLocalizations.meowzicTrackNotFound;

      final handler = await meowzicAudio();
      // Always 0: the window is built starting at the tapped track, so the
      // thing that was tapped is the head of the queue by construction.
      await handler
          .playQueue(queue, 0, headers: bridge.headers)
          .timeout(_playbackStartTimeout);
      return null;
    } catch (error, stackTrace) {
      commonPrint.log('spotify search play failed: $error\n$stackTrace');
      final connected = ref.read(runTimeProvider) != null;
      return connected
          ? appLocalizations.meowzicBridgeError
          : appLocalizations.meowzicNeedVpn;
    } finally {
      // Unconditional, and deliberately not guarded on `_disposed`: the value is
      // the app's, not this provider's, so leaving it set because this screen
      // went away is exactly the bug that guard would reintroduce.
      meowzicResolvingListenable.value = null;
    }
  }
}
