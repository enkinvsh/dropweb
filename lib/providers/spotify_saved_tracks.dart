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
import 'package:dropweb/views/meowzic/spotify/saved_tracks.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/spotify_saved_tracks.g.dart';

/// How long handing a queue to the player may take before the tap is abandoned.
///
/// The twin of the constants in `spotify_detail.dart` and `spotify_search.dart`,
/// and deliberately the same number: all three are the same act — ten bridge
/// lookups and a `playQueue` — and a tap that gave up at different moments
/// depending on which list it started from would be one app behaving as three.
/// It exists only so that a load which will never finish cannot hold the
/// resolving mark forever.
const _playbackStartTimeout = Duration(seconds: 45);

/// The Сохранённые tab's whole visible state.
///
/// Immutable and replaced wholesale rather than patched, the call
/// `SpotifySearchState`, `SpotifyLibraryState` and `SpotifyDetailState` all
/// make: every transition names every field it means, which is cheaper to read
/// than a `copyWith` that has to say whether it is keeping or clearing the
/// failure.
class SpotifySavedTracksState {
  const SpotifySavedTracksState({
    this.phase = MeowzicPhase.idle,
    this.tracks = const [],
    this.failure,
    this.loadingMore = false,
    this.hasMore = false,
  });

  final MeowzicPhase phase;
  final List<SpotifyTrack> tracks;
  final SpotifyGqlFailure? failure;

  /// A further page is being appended to rows that are already on screen.
  /// Separate from [phase] so the list is never taken away to show a spinner —
  /// the same split the search and container states keep for the same reason.
  final bool loadingMore;

  /// Whether asking again would return anything.
  ///
  /// Driven off "the last page came back full" rather than off a total, the way
  /// `SpotifySearchState` is and unlike the library grid: `fetchLibraryTracks`
  /// does carry a `totalCount`, but the honest count of what is on screen is
  /// not derivable from it here — the parser drops rows it cannot read, so
  /// `tracks.length` sits at or below what Spotify has already handed over and
  /// comparing the two would stop the listing short. A full page is evidence
  /// there is more; a short page is the end.
  final bool hasMore;
}

/// The account's saved tracks — the rows behind the Сохранённые tab.
///
/// Its own notifier rather than another `SpotifyDetail` family element, because
/// saved tracks are not a container the app opens: they have no uri to key a
/// family on. The tab was first built as though they did — find the Liked Songs
/// pseudo-playlist in the Playlists library, read its uri, open that — and on a
/// live account that row is not in the library answer at all, so the tab
/// shipped showing «Здесь пока пусто» over a full Liked Songs. There is one of
/// these per account and the session already says which account; see
/// `saved_tracks.dart`.
///
/// Nothing here may wait on `spotifyLibraryProvider`. That coupling is the bug,
/// not an implementation detail of it: the Плейлисты filter failing, or simply
/// never having been opened, must have no bearing on whether this tab can draw.
///
/// keepAlive for the reason `SpotifySearch`, `SpotifyAuth` and `SpotifyLibrary`
/// have it: the meowzic page is pushed as a route, so anything kept in the
/// tab's `State` is built fresh on every open — and this is the first tab, the
/// one every arrival lands on.
///
/// In memory only. Surviving an app restart would need a table and is a
/// separate decision; surviving navigation is this one.
@Riverpod(keepAlive: true)
class SpotifySavedTracks extends _$SpotifySavedTracks {
  /// Guards against a slow page landing after a newer one and overwriting it —
  /// a first page and a sign-out racing, or two `fetchMore` calls a fast scroll
  /// let through, or a refresh crossing either.
  int _generation = 0;

  /// Where the next page starts, counted in rows *asked for* rather than rows
  /// kept.
  ///
  /// The two differ: the parser drops anything in `items` it cannot read, so
  /// `tracks.length` is at or below the number Spotify has already handed over.
  /// Paging off the kept count would re-ask for rows we were already given and
  /// print them twice.
  int _offset = 0;

  /// Guards the continuation of an await that landed after this notifier went
  /// away. Same guard, same reason, as the one in `spotify_detail.dart`.
  bool _disposed = false;

  @override
  SpotifySavedTracksState build() {
    ref
      ..onDispose(() => _disposed = true)
      // Listened to rather than watched: `watch` would rebuild this notifier
      // and throw the rows away on any auth change at all, including the
      // display name arriving a moment after sign-in.
      ..listen(spotifyAuthProvider, _onAuthChanged);
    return const SpotifySavedTracksState();
  }

  void _onAuthChanged(SpotifyAuthState? _, SpotifyAuthState next) {
    if (next.phase == SpotifyPhase.signedOut) {
      // Emptied, not left to go stale. Somebody who unlinks and hands the phone
      // over must not find the previous account's saved tracks sitting behind
      // the sign-in prompt. The generation bump is what stops a page still in
      // flight from landing on top of this.
      _generation++;
      _offset = 0;
      state = const SpotifySavedTracksState();
      return;
    }
    // Guarded on our own phase rather than on the auth transition, the same
    // trade `SpotifyLibrary` makes and for the same saving: signing in also
    // rebuilds the tab, whose `initState` calls [ensureLoaded], and Riverpod
    // makes no promise about which of the two runs first. Both asking "is this
    // still idle?" means whichever arrives second steps aside instead of firing
    // a duplicate page the generation guard would throw away after paying for
    // it.
    if (next.phase == SpotifyPhase.signedIn &&
        state.phase == MeowzicPhase.idle) {
      unawaited(_loadFirstPage(keepRows: false));
    }
  }

  /// Loads the first page if it has never been loaded.
  ///
  /// Called on mount and on every tap of the chip. After the first success the
  /// phase is no longer idle and this returns without touching anything, which
  /// is what makes coming back to the tab instant.
  ///
  /// The turn yielded below is load-bearing and is the same one `SpotifyDetail`
  /// and `SpotifyLibrary` yield. The tab calls this from `initState`, which
  /// runs *inside* the build pass, and everything up to the first `await` still
  /// runs synchronously — so the loading assignment would land in the one
  /// window Riverpod refuses. It answers by throwing, the assignment is
  /// dropped, and the tab keeps a spinner that never resolves. `unawaited` at
  /// the call site defers nothing; it only ignores the result. The deferral
  /// belongs here so a future caller cannot reintroduce the bug by looking
  /// safe.
  Future<void> ensureLoaded() async {
    if (state.phase != MeowzicPhase.idle) return;
    if (ref.read(spotifyAuthProvider).phase != SpotifyPhase.signedIn) return;
    await Future<void>.delayed(Duration.zero);
    if (_disposed || state.phase != MeowzicPhase.idle) return;
    await _loadFirstPage(keepRows: false);
  }

  /// Reads the listing again from scratch — the only retry a failed tab offers,
  /// reached by tapping its chip.
  Future<void> reload() async {
    if (state.phase == MeowzicPhase.loading) return;
    await _loadFirstPage(keepRows: false);
  }

  /// Re-reads the first page after a like was written, keeping what is on
  /// screen while it happens.
  ///
  /// A re-read rather than a `ref.invalidate`, and that is not a preference. A
  /// keepAlive notifier that a mounted tab is watching comes back from an
  /// invalidate in its idle state with nobody left to call [ensureLoaded] — the
  /// tab's `initState` has already run — which is a spinner that never
  /// resolves on the one screen the write was meant to update.
  ///
  /// It genuinely does drop back to one page: somebody who had scrolled deep
  /// keeps the top fifty and scrolls again for the rest. That is the same net
  /// effect an invalidate would have had, without the frozen tab, and it costs
  /// one round trip on an action the listener took deliberately.
  ///
  /// A tab that was never opened has nothing to re-read, and returning here is
  /// the correct outcome rather than a missed refresh: the first [ensureLoaded]
  /// will fetch the listing after the write anyway.
  Future<void> refresh() async {
    if (state.phase == MeowzicPhase.idle) return;
    if (ref.read(spotifyAuthProvider).phase != SpotifyPhase.signedIn) return;
    await _loadFirstPage(keepRows: state.phase == MeowzicPhase.done);
  }

  /// Appends the next page, when there is one and nothing is already in flight.
  Future<void> fetchMore() async {
    if (state.phase != MeowzicPhase.done) return;
    if (state.loadingMore || !state.hasMore) return;

    final generation = _generation;
    final existing = state.tracks;
    state = SpotifySavedTracksState(
      phase: MeowzicPhase.done,
      tracks: existing,
      loadingMore: true,
      hasMore: true,
    );

    try {
      final page = await fetchSpotifySavedTracks(
        notifier: ref.read(spotifyAuthProvider.notifier),
        offset: _offset,
        limit: spotifySavedTracksPageSize,
      );
      if (_disposed || generation != _generation) return;
      _offset += spotifySavedTracksPageSize;
      state = SpotifySavedTracksState(
        phase: MeowzicPhase.done,
        tracks: [...existing, ...page],
        hasMore: page.length >= spotifySavedTracksPageSize,
      );
    } on SpotifyGqlException {
      if (_disposed || generation != _generation) return;
      // The rows that are already up survive a failed page, the call
      // `SpotifyDetail.fetchMore` makes: reaching the bottom on a dropped
      // connection must not delete what was read on the way down, and the
      // failure is not surfaced either because the screen is still showing a
      // working listing. It is written down in the log by `spotifyGqlQuery`;
      // the next scroll retries.
      state = SpotifySavedTracksState(
        phase: MeowzicPhase.done,
        tracks: existing,
        hasMore: true,
      );
    } catch (error, stackTrace) {
      // Everything that is not a `SpotifyGqlException` — a `TimeoutException`, a
      // cast that failed on a shape Spotify moved, a `StateError`. The owner hit
      // this on a Pixel: the Сохранённые tab spun forever, the flutter log for
      // that moment was completely EMPTY, and killing the app was the only cure.
      // That is what an escaping throwable does here — the future is unawaited,
      // so the zone swallows it silently, `phase` is left on `loading`, and
      // [ensureLoaded] returns early on anything but `idle`, so nothing ever
      // retries. The screen is wedged until the process dies.
      //
      // The invariant this establishes, and the reason none of the catch-alls in
      // this file is defensive noise to be tidied away: after any load attempt,
      // `phase` is `done` or `failed` — never `loading`.
      //
      // The log line is the other half of the fix and is not optional. This
      // failure mode was not merely wrong, it was invisible.
      commonPrint.log(
        'SpotifySavedTracks.fetchMore failed: $error\n$stackTrace',
      );
      if (_disposed || generation != _generation) return;
      // Same landing as the typed branch above: the rows already on screen stay,
      // and no failure is surfaced over a listing that still reads correctly.
      state = SpotifySavedTracksState(
        phase: MeowzicPhase.done,
        tracks: existing,
        hasMore: true,
      );
    }
  }

  /// Fetches page one and publishes it.
  ///
  /// [keepRows] decides what the listener looks at while it runs and what they
  /// are left with if it fails: false blanks to a spinner and then to the
  /// failure copy, which is right for a tab that has nothing to show yet, and
  /// true keeps the listing standing, which is right for a background re-read
  /// nobody asked to watch.
  Future<void> _loadFirstPage({required bool keepRows}) async {
    final generation = ++_generation;
    final existing = keepRows ? state.tracks : const <SpotifyTrack>[];
    final hadMore = keepRows && state.hasMore;

    state = SpotifySavedTracksState(
      phase: keepRows ? MeowzicPhase.done : MeowzicPhase.loading,
      tracks: existing,
      hasMore: hadMore,
    );

    try {
      final page = await fetchSpotifySavedTracks(
        notifier: ref.read(spotifyAuthProvider.notifier),
        limit: spotifySavedTracksPageSize,
      );
      if (_disposed || generation != _generation) return;
      _offset = spotifySavedTracksPageSize;
      state = SpotifySavedTracksState(
        phase: MeowzicPhase.done,
        tracks: page,
        hasMore: page.length >= spotifySavedTracksPageSize,
      );
    } on SpotifyGqlException catch (error) {
      if (_disposed || generation != _generation) return;
      state = SpotifySavedTracksState(
        phase: keepRows ? MeowzicPhase.done : MeowzicPhase.failed,
        tracks: existing,
        hasMore: hadMore,
        // Not carried when the rows survived: an error banner over a listing
        // that still reads correctly reports a fault the listener did not ask
        // about and cannot act on.
        failure: keepRows ? null : error.failure,
      );
    } catch (error, stackTrace) {
      // The path that actually wedged the tab; see the catch-all in [fetchMore]
      // for what it looked like from the device. Nothing may leave `phase` on
      // `loading`.
      commonPrint.log(
        'SpotifySavedTracks._loadFirstPage failed '
        '(keepRows: $keepRows): $error\n$stackTrace',
      );
      if (_disposed || generation != _generation) return;
      state = SpotifySavedTracksState(
        phase: keepRows ? MeowzicPhase.done : MeowzicPhase.failed,
        tracks: existing,
        hasMore: hadMore,
        // `upstream` because that is the whole of what an untyped throwable
        // supports saying: something answered and misbehaved. Kept null when the
        // rows survived, for the reason the typed branch keeps it null.
        failure: keepRows ? null : SpotifyGqlFailure.upstream,
      );
    }
  }

  /// Plays the track at [index] and queues the window behind it.
  ///
  /// Character for character the path a search hit and a playlist row take —
  /// [resolveSpotifyQueue], which looks the ISRC up and matches on that — and
  /// that identity is the feature: the same saved track plays the same
  /// recording whichever list it was tapped in.
  ///
  /// Returns the message a failed tap has to show, or null when it played. The
  /// message is decided here because the reason is; showing it needs a
  /// `BuildContext`, which is the screen's to hold, not this one's.
  Future<String?> play(int index) async {
    final tracks = state.tracks;
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
        // Handed in from here because this is where the `ref` lives. The same
        // cache all three play paths use, which is the point: a saved track
        // played after the same track was played from search costs no lookup
        // at all.
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
      commonPrint.log('spotify saved tracks play failed: $error\n$stackTrace');
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
