import 'dart:async';
import 'dart:math' as math;

import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/app.dart';
import 'package:dropweb/providers/spotify.dart';
import 'package:dropweb/providers/state.dart';
import 'package:dropweb/views/meowzic/audio.dart';
import 'package:dropweb/views/meowzic/phase.dart';
import 'package:dropweb/views/meowzic/spotify/detail.dart';
import 'package:dropweb/views/meowzic/spotify/gql.dart';
import 'package:dropweb/views/meowzic/spotify/library.dart';
import 'package:dropweb/views/meowzic/spotify/playback.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/spotify_detail.g.dart';

/// One opened container's whole visible state.
class SpotifyDetailState {
  const SpotifyDetailState({
    this.phase = MeowzicPhase.idle,
    this.detail,
    this.failure,
    this.loadingMore = false,
  });

  final MeowzicPhase phase;
  final SpotifyContainerDetail? detail;
  final SpotifyGqlFailure? failure;

  /// A further page is being appended to a listing that is already on screen.
  /// Separate from [phase] so the list is never taken away to show a spinner:
  /// blanking a hundred rows the moment somebody reaches the bottom of them is
  /// worse than the wait it would be reporting.
  final bool loadingMore;

  /// How many tracks are on screen — and therefore the offset the next page
  /// starts at.
  int get loadedCount => detail?.tracks.length ?? 0;

  /// Whether Spotify has more of this container than we have asked for.
  bool get hasMore => loadedCount < (detail?.totalCount ?? 0);

}

/// One opened playlist, album, artist or saved-tracks collection.
///
/// Keyed by [uri] and [kind] rather than held as a single current-container
/// notifier: two detail screens can be on the stack at once — an artist opened
/// from the grid, then one of its albums — and a single notifier would mean the
/// one underneath quietly showing the one on top's tracks when you came back to
/// it.
///
/// keepAlive, and that IS the cache. There is no store, no TTL and no eviction
/// anywhere in this feature, on purpose: a family provider that outlives its
/// screen is already a keyed cache, and Riverpod is already the thing holding
/// it. Spotube's whole metadata layer is built this exact way — every one of
/// its paginated notifiers is a keepAlive family keyed by the thing it fetched
/// — and inventing a second caching mechanism beside the one the app already
/// depends on would be two sources of truth for "have we read this".
///
/// This was auto-disposing until the owner used it on a phone: backing out of a
/// playlist tore the notifier down, and opening it again paid a full round trip
/// through the tunnel to redraw what had been on screen a second earlier. That
/// is the "лаги пиздец словно мы ничего не кешируем" — the app genuinely was
/// not caching, because the provider was told to throw the answer away. The
/// justification that stood here, that keeping every opened container alive
/// grows without bound, is true and does not matter at this size: the bound is
/// how many containers one person opens in one run of the app, each a list of
/// track names, and paying a network round trip per revisit to save that is a
/// bad trade.
@Riverpod(keepAlive: true)
class SpotifyDetail extends _$SpotifyDetail {
  /// Guards the continuation of an await that landed after this notifier went
  /// away. Rarer now that it is keepAlive — the container has to be disposed
  /// with the whole scope rather than by pressing back — but a resolve can run
  /// for ten seconds, and assigning state to a disposed notifier throws.
  bool _disposed = false;

  @override
  SpotifyDetailState build(String uri, SpotifyLibraryKind kind) {
    ref.onDispose(() => _disposed = true);
    return const SpotifyDetailState();
  }

  /// Fetches the container's first page, once.
  ///
  /// Safe to call again: after the first call the phase is no longer idle and
  /// this returns without touching anything. That early return is what makes
  /// reopening a playlist instant — the screen mounts, asks, and is told there
  /// is nothing to do because the answer is still here.
  ///
  /// The turn yielded below is load-bearing and cost an afternoon. The screen
  /// calls this from `initState`, which runs *inside* the build pass — and
  /// moving the call out of the notifier's own `build` was not enough, because
  /// everything here up to the first `await` still runs synchronously, so the
  /// loading assignment landed in that same forbidden window. Riverpod answers
  /// a state change made while the tree is building by throwing, which means
  /// the assignment is dropped, the phase never advances, and the screen shows
  /// a spinner that resolves for no reason and never stops. `unawaited` at the
  /// call site does not help: it defers nothing, it only ignores the result.
  ///
  /// So nothing is assigned until a turn has passed. This is the deferral
  /// Riverpod's own error message prescribes, and it belongs here rather than
  /// at the call site so that a future caller cannot reintroduce the bug by
  /// looking safe.
  Future<void> ensureLoaded() async {
    if (state.phase != MeowzicPhase.idle) return;
    await Future<void>.delayed(Duration.zero);
    if (_disposed || state.phase != MeowzicPhase.idle) return;
    state = const SpotifyDetailState(phase: MeowzicPhase.loading);
    try {
      final detail = await fetchSpotifyContainer(
        notifier: ref.read(spotifyAuthProvider.notifier),
        uri: uri,
        kind: kind,
      );
      if (_disposed) return;
      state = SpotifyDetailState(
        phase: MeowzicPhase.done,
        detail: detail,
      );
    } on SpotifyGqlException catch (error) {
      if (_disposed) return;
      state = SpotifyDetailState(
        phase: MeowzicPhase.failed,
        failure: error.failure,
      );
    }
  }

  /// Appends the next page of tracks, when there is one and nothing is already
  /// in flight.
  ///
  /// The header is not touched. A second page answers with the same header the
  /// first did — these documents have no tracks-only variant — so it is read,
  /// discarded, and the container we already hold keeps its own name and cover
  /// rather than being rebuilt from an identical copy.
  Future<void> fetchMore() async {
    final current = state.detail;
    if (current == null) return;
    if (state.phase != MeowzicPhase.done) return;
    if (state.loadingMore || !state.hasMore) return;

    state = SpotifyDetailState(
      phase: state.phase,
      detail: current,
      loadingMore: true,
    );

    try {
      final page = await fetchSpotifyContainer(
        notifier: ref.read(spotifyAuthProvider.notifier),
        uri: uri,
        kind: kind,
        offset: current.tracks.length,
      );
      if (_disposed) return;
      state = SpotifyDetailState(
        phase: MeowzicPhase.done,
        // The newly fetched container carries the authoritative count, which
        // can legitimately have moved: somebody adding to a playlist from
        // another device while this one is scrolling it is ordinary, and
        // keeping the first page's count would then either stop short of the
        // end or keep asking past it.
        detail: page.withTracks([...current.tracks, ...page.tracks]),
      );
    } on SpotifyGqlException {
      if (_disposed) return;
      // The listing that is already up survives a failed page. Reaching the
      // bottom on a dropped connection must not delete what was read on the way
      // down — and the failure is not surfaced either, because the screen is
      // still showing a working listing and an error banner over it would be
      // reporting a fault the user did not ask about and cannot act on. It is
      // written down in the log by `spotifyGqlQuery`; the next scroll retries.
      state = SpotifyDetailState(
        phase: MeowzicPhase.done,
        detail: current,
      );
    }
  }

  /// Plays the track at [index] and queues the window behind it.
  ///
  /// Returns the message a failed tap has to show, or null when it played.
  /// The message is decided here for the reason `MeowzicSearch.play` decides
  /// its own: which failure it is cannot be read off the player's error code,
  /// but the tunnel answers it directly — the bridge is reachable only through
  /// it. Showing the message needs a `BuildContext`, which is the screen's to
  /// hold, not this one's.
  Future<String?> play(int index) async {
    final tracks = state.detail?.tracks;
    if (tracks == null || index < 0 || index >= tracks.length) return null;

    // A second tap while the first is still resolving is ignored rather than
    // queued. Ten bridge lookups are already in flight; starting ten more would
    // make both slower and leave whichever finished last deciding what plays.
    //
    // Read from the shared value, not from this container's own state: the tap
    // being waited on may have come from a different playlist entirely, and two
    // containers each minding their own flag is how one of them ends up
    // spinning forever while the other plays.
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
      );
      if (_disposed) return null;
      // Empty means the tapped track itself did not resolve — the queue builder
      // refuses to substitute the next one. Reported as "not found" rather than
      // as a bridge fault, because the bridge answered; it simply had nothing.
      if (queue.isEmpty) return appLocalizations.meowzicTrackNotFound;

      final handler = await meowzicAudio();
      // Always 0: the window is built starting at the tapped track, so the
      // thing that was tapped is the head of the queue by construction. Passing
      // `index` here would point into the container's numbering, which the
      // queue does not share.
      //
      // Bounded, unlike the two calls above it. Both of those carry their own
      // timeout, but handing sources to the player carries none — and on a
      // tunnel that is up while its node is not, loading a source does not
      // fail, it waits. That wait is what left a row marked as resolving with
      // nothing ever arriving to unmark it, and with the guard above reading
      // that same mark, the tap that was meant to recover was refused too.
      // Whatever else goes wrong, the mark has to come off.
      await handler
          .playQueue(queue, 0, headers: bridge.headers)
          .timeout(_playbackStartTimeout);
      return null;
    } catch (error, stackTrace) {
      commonPrint.log('spotify detail play failed: $error\n$stackTrace');
      final connected = ref.read(runTimeProvider) != null;
      return connected
          ? appLocalizations.meowzicBridgeError
          : appLocalizations.meowzicNeedVpn;
    } finally {
      // Unconditional, and deliberately not guarded on `_disposed`: the value
      // is the app's, not this provider's, so leaving it set because this
      // screen went away is precisely the bug being fixed here.
      meowzicResolvingListenable.value = null;
    }
  }
}

/// How long handing a queue to the player may take before the tap is abandoned.
///
/// Generous, because it covers a real first load over the tunnel and being
/// impatient here would cut off playback that was about to start. It exists
/// only so that a load which will never finish cannot hold the resolving mark
/// forever.
const _playbackStartTimeout = Duration(seconds: 45);
