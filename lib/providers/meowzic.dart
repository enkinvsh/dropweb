import 'package:audio_service/audio_service.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/app.dart';
import 'package:dropweb/providers/state.dart';
import 'package:dropweb/views/meowzic/audio.dart';
import 'package:dropweb/views/meowzic/bridge.dart';
import 'package:dropweb/views/meowzic/phase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/meowzic.g.dart';

/// The search tab's whole visible state.
///
/// Immutable and replaced wholesale rather than patched: there are four
/// transitions and each one names every field it means, which is cheaper to
/// read than a `copyWith` that has to distinguish "keep the failure" from
/// "clear the failure".
class MeowzicSearchState {
  const MeowzicSearchState({
    this.query = '',
    this.phase = MeowzicPhase.idle,
    this.results = const [],
    this.failure,
  });

  /// What was actually searched for, so the box can be refilled with it. The
  /// live text of the field is the field's own business until it is submitted.
  final String query;
  final MeowzicPhase phase;
  final List<MeowzicTrack> results;
  final MeowzicFailure? failure;
}

/// The search and the queue behind it, held above the route.
///
/// The shape follows Spotube's `AudioPlayerNotifier`
/// (lib/provider/audio_player/audio_player.dart): the queue lives in a
/// notifier and the screen only renders it. That is what buys the fix — the
/// meowzic page is pushed as a route, so anything kept in its `State` is built
/// fresh on every open and a search someone waited thirty seconds for is gone
/// the moment they tap a track and come back.
///
/// keepAlive for the same reason `AppUpdate` has it: an auto-disposing
/// provider would be torn down the instant the last route watching it pops,
/// which is exactly the moment this exists to survive.
///
/// In memory only. Surviving an app restart would need a table and is a
/// separate decision; surviving navigation is this one.
@Riverpod(keepAlive: true)
class MeowzicSearch extends _$MeowzicSearch {
  /// Guards against a slow first query landing after a faster second one and
  /// overwriting it. The bridge takes seconds on a cold lookup, which is long
  /// enough for someone to retype.
  int _generation = 0;

  @override
  MeowzicSearchState build() => const MeowzicSearchState();

  Future<void> search(String raw) async {
    final query = raw.trim();
    final bridge = ref.read(meowzicBridgeProvider);
    if (query.isEmpty || bridge == null) return;

    final generation = ++_generation;
    state = MeowzicSearchState(
      query: query,
      phase: MeowzicPhase.loading,
      // Carried through the loading and failed states so a query that turns
      // out badly does not also wipe the results that were on screen.
      results: state.results,
    );

    try {
      final tracks = await searchMeowzic(bridge, query);
      if (generation != _generation) return;
      state = MeowzicSearchState(
        query: query,
        phase: MeowzicPhase.done,
        results: tracks,
      );
    } on MeowzicException catch (error) {
      if (generation != _generation) return;
      state = MeowzicSearchState(
        query: query,
        phase: MeowzicPhase.failed,
        results: state.results,
        failure: _explain(error.failure),
      );
    }
  }

  /// Turns the transport's guess into something the tunnel can back up.
  ///
  /// `searchMeowzic` holds no `ref` and cannot ask whether the VPN is on, so
  /// every dead socket leaves it as `unreachable` — whose copy tells the
  /// listener to switch the VPN on. Read literally that is a guess, and the
  /// comment on the enum admits as much; when the tunnel is demonstrably up it
  /// is simply false, and it sends somebody to re-toggle a switch that was
  /// never the problem while the actual fault goes unreported. `upstream`
  /// reads "мост не ответил", which is precisely what happened.
  ///
  /// This is the same question [play] has always asked, answered the same way
  /// from the same provider. One screen must not give two verdicts on one
  /// fault depending on which button reached it.
  MeowzicFailure _explain(MeowzicFailure failure) =>
      failure == MeowzicFailure.unreachable &&
              ref.read(runTimeProvider) != null
          ? MeowzicFailure.upstream
          : failure;

  /// Plays the result at [index] and queues everything shown with it.
  ///
  /// The whole list goes over, not the tail from [index]: skipping backwards
  /// has to reach the results above the tapped one, which is where somebody
  /// looks first when they meant the row above.
  ///
  /// Returns the message a failed tap has to show, or null when it played.
  /// The message is decided here because the reason is — which failure it is
  /// cannot be read off the player's error code, but the tunnel answers it
  /// directly: the bridge is reachable only through it. Showing it needs a
  /// `BuildContext`, which is the screen's to hold, not this one's.
  Future<String?> play(int index) async {
    final bridge = ref.read(meowzicBridgeProvider);
    if (bridge == null) return null;
    try {
      final handler = await meowzicAudio();
      await handler.playQueue(
        [
          for (final track in state.results)
            MeowzicQueueItem(
              uri: bridge.audioUri(track.id),
              item: MediaItem(
                // The video id, not the audio URL. The URL is fine to hold —
                // the token lives in a header — but the id is what the system
                // media session publishes, and it has no business carrying a
                // URL.
                id: track.id,
                title: track.title,
                artist: track.author.isEmpty ? null : track.author,
                duration:
                    track.duration > Duration.zero ? track.duration : null,
                artUri: track.thumbnail,
              ),
            ),
        ],
        index,
        headers: bridge.headers,
      );
      return null;
    } catch (error, stackTrace) {
      commonPrint.log('meowzic play failed: $error\n$stackTrace');
      final connected = ref.read(runTimeProvider) != null;
      return connected
          ? appLocalizations.meowzicBridgeError
          : appLocalizations.meowzicNeedVpn;
    }
  }
}
