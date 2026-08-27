import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/meowzic/audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps meowzic honest about the tunnel it depends on.
///
/// `runTime` is the signal because it derives from the core's start timestamp:
/// it answers only to the core starting or stopping. A bearer change
/// (wifi -> LTE) or a mode switch leaves it alive, and mihomo heals those
/// itself — reacting to them would pause music that was never actually cut
/// off. Connectivity events and proxy changes are exactly the causes this
/// manager must not answer to.
///
/// It is not, however, an edge signal — see `_handleTunnelSettled` for why
/// every transition is debounced before it is acted on.
class MeowzicManager extends ConsumerStatefulWidget {
  const MeowzicManager({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<MeowzicManager> createState() => _MeowzicManagerState();
}

class _MeowzicManagerState extends ConsumerState<MeowzicManager> {
  /// The tunnel state as last delivered by the subscription below.
  ///
  /// Measured on a Pixel 10: a bare `ref.read(runTimeProvider)` from the two
  /// detached callbacks here — the debounced closure and the one handed to the
  /// audio handler — answered null while `dumpsys connectivity` showed a live
  /// VPN. The consequence was not cosmetic. The notification's play button took
  /// the "tunnel is down" branch and called `updateStatus(true)` on an already
  /// running core, which fell through the readiness machine's failure paths —
  /// `connect_service.dart:186,199`, both of which `updateStatus(false)` — and
  /// stopped the VPN. The same phantom let a disconnect suspend a resume that
  /// was still in flight.
  ///
  /// Two things make an on-demand read untrustworthy here, and only one of them
  /// has to hold for the bug to reproduce. `runTimeProvider` is published by
  /// the periodic `updateRunTime`, which emits null on every tick where
  /// `globalState.startTime` is still null, so a raw read can land on a
  /// transient null the debounce below is specifically there to discard. And it
  /// is an `AutoDisposeNotifierProvider` (`providers/generated/app.g.dart`), so
  /// a read is only ever as good as whatever is keeping it alive.
  ///
  /// The cache sidesteps both: it holds the value this manager's own
  /// subscription delivered, which is the same value that gated the debounce.
  /// Do not "simplify" it back into a `ref.read`.
  bool _connected = false;

  /// The Spotify uri of the track currently loaded, or null when there is none
  /// — nothing loaded, or a bridge-search track with no Spotify counterpart.
  ///
  /// Held here rather than read from the handler on demand for the same reason
  /// [_connected] is held: the answer has to be available inside detached
  /// callbacks, and it is the value this manager's own subscription delivered.
  String? _likeUri;

  StreamSubscription<MediaItem?>? _mediaItemSubscription;

  @override
  void initState() {
    super.initState();
    // The boolean select is load-bearing: runTime ticks once a second while
    // connected, and listening to the raw value would fire just as often.
    ref.listenManual(
      runTimeProvider.select((state) => state != null),
      (previous, connected) {
        _connected = connected;
        // The seeding delivery reports no change, so there is nothing to act
        // on and nothing to debounce.
        if (previous == null) return;
        debouncer.call(
          FunctionTag.meowzicTunnel,
          _handleTunnelSettled,
          duration: const Duration(seconds: 2),
        );
      },
      fireImmediately: true,
    );
    meowzicHandlerListenable.addListener(_wireHandler);
    // The notification's heart is drawn from a native drawable and cannot
    // change colour, so the handler has to be told when the account's answer
    // moves. Watching the whole map rather than one key: which track is loaded
    // changes under this listener, and the uri it cares about is read fresh
    // each time.
    ref.listenManual(
      spotifyLikesProvider,
      (previous, next) => _publishLiked(),
    );
    _wireHandler();
  }

  /// Acts on the tunnel only once it has stopped moving.
  ///
  /// `runTime` is published by `ConnectService.updateRunTime`, a periodic task
  /// registered through `globalState.startUpdateTasks`. Every tick reads
  /// `globalState.startTime` and publishes null while that is still null, so
  /// ticks landing inside the start sequence emit null after the core is
  /// already coming up: one user connect produces several false -> true ->
  /// false -> true transitions. Acting on an unsettled value is what left the
  /// stall armed over live audio, and a stall nobody can see disables the next
  /// park.
  ///
  /// Two seconds costs nothing on the disconnect side — the stream is dead
  /// long before the timer fires and anything already buffered keeps playing —
  /// and it is long enough to swallow the start-up settle.
  ///
  /// This path covers the foreground only, which is why the play press has one
  /// of its own. `updateRunTime` is cancelled by `globalState.pauseUpdateTasks`
  /// whenever the app leaves the front, so a tunnel coming back while minimised
  /// never reaches this manager. Stops do reach it either way — `_applyStopped`
  /// nulls `runTimeProvider` directly rather than waiting for a tick — so a
  /// track still parks with the app in the background.
  void _handleTunnelSettled() {
    if (!mounted) return;
    // Read the notifier rather than meowzicAudio(): somebody who never opened
    // music must not have a media service brought into existence by a tunnel
    // event.
    final handler = meowzicHandlerListenable.value;
    if (handler == null) return;
    // The cache holds the latest delivered value, which after the debounce is
    // the settled one — the unsettled transitions this exists to discard have
    // already been overwritten by it.
    if (_connected) {
      unawaited(handler.resumeAfterTunnel());
    } else {
      unawaited(handler.suspendForTunnel());
    }
  }

  /// The handler is built lazily on first playback, so the callback is wired
  /// both now and every time the notifier hands over a new one.
  ///
  /// The manager owns this because it is the only piece that may read the
  /// tunnel and the only piece allowed to ask for it. Answering whether it was
  /// already up matters: the handler has to retry itself in that case, because
  /// no runTime transition is coming to wake this manager. `updateStatus(true)`
  /// stays reachable only from a play press — nothing here connects on its own.
  ///
  /// Stall labels are wired from the same place so the handler holds no
  /// localization: it decides what broke, the UI layer decides how to say it.
  ///
  /// The like seam is wired here for the same reason and in the same idiom: the
  /// handler may not hold a `Ref`, so this manager reaches down into it rather
  /// than the other way round. Which track is loaded arrives on the handler's
  /// own `mediaItem` stream — the only place an automatic advance is announced,
  /// so a track the player reached on its own gets its heart looked up too.
  void _wireHandler() {
    final handler = meowzicHandlerListenable.value;
    if (handler == null) return;
    handler
      ..onLikeRequested = ((uri) =>
          ref.read(spotifyLikesProvider.notifier).toggleLike(uri))
      ..onTunnelRequested = (() async {
        if (_connected) return true;
        // Awaited all the way through _startWithTunRecovery -> handleStart, so
        // this returns only once the tun is genuinely up or the start failed.
        await globalState.appController.updateStatus(true);
        // Not `_connected`: that mirrors runTimeProvider, which is published by
        // a periodic task the app pauses while backgrounded, so it stays false
        // here however well the start went. `globalState.isStart` is a plain
        // field set inside handleStart/handleStop, so it tells the truth in
        // either state.
        return globalState.isStart;
      })
      ..stallReason = ((stall) => switch (stall) {
            MeowzicStall.none => '',
            MeowzicStall.needVpn => appLocalizations.meowzicNeedVpnShort,
            MeowzicStall.bridgeError =>
              appLocalizations.meowzicBridgeErrorShort,
          });
    // Guarded rather than assumed to run once: this method is called both from
    // initState and from every hand-over of the notifier, and two live
    // subscriptions would ask for the same status twice.
    unawaited(_mediaItemSubscription?.cancel());
    _mediaItemSubscription = handler.mediaItem.listen(_handleMediaItem);
  }

  /// Follows which track the heart is about, and makes sure its status is known.
  ///
  /// Runs on a stream event, which is outside the build phase — the only place
  /// a notifier may legally publish. Asking for the status from a widget's
  /// `initState` instead is how this project earned a screen that threw and
  /// then sat on a spinner forever.
  void _handleMediaItem(MediaItem? item) {
    final uri = item?.extras?['spotifyUri'];
    _likeUri = uri is String ? uri : null;
    // Published before the fetch so a track whose status is already cached
    // shows the right glyph in the same beat, without a round trip.
    _publishLiked();
    final wanted = _likeUri;
    if (wanted == null) return;
    unawaited(
      ref.read(spotifyLikesProvider.notifier).fetchLikedStatus([wanted]),
    );
  }

  /// Hands the handler the answer for whatever is loaded right now.
  ///
  /// False for a track with no Spotify identity and for one whose status has
  /// not come back yet: the shade gets the hollow heart, which is what unknown
  /// looks like everywhere else in this app.
  void _publishLiked() {
    final uri = _likeUri;
    meowzicLikedListenable.value = uri != null &&
        ref.read(spotifyLikesProvider.notifier).isLiked(uri);
  }

  @override
  void dispose() {
    meowzicHandlerListenable.removeListener(_wireHandler);
    unawaited(_mediaItemSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
