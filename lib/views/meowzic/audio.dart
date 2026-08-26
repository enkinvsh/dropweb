import 'package:audio_service/audio_service.dart';
import 'package:dropweb/common/common.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Why playback is parked, when it is.
enum MeowzicStall {
  /// Nothing is parked.
  none,

  /// The tunnel went away mid-track. The socket is dead, so the position is
  /// held and the play button brings the tunnel back instead of pushing
  /// audio into a closed pipe.
  needVpn,

  /// The tunnel is up and the bridge is what failed — measured as a 502 out of
  /// just_audio's local proxy. Pressing play retries rather than reconnecting,
  /// which is worth doing because mihomo may pick a different exit node.
  bridgeError,
}

/// One queued track: where to fetch the bytes and what to announce.
///
/// The URL is held beside the [MediaItem] rather than inside its `extras`,
/// because extras reach the system media session and the audio URL has no
/// business there — the same reason [MediaItem.id] carries the video id alone.
class MeowzicQueueItem {
  const MeowzicQueueItem({required this.uri, required this.item});

  final Uri uri;
  final MediaItem item;
}

/// Playback for meowzic, fronted by a media notification.
///
/// Deliberately NOT started at app launch: [meowzicAudio] builds the service on
/// first use, so somebody who never opens music never gets a media service or
/// its notification. The VPN foreground service is unrelated and unaffected —
/// this one is typed mediaPlayback and carries no runtime cap.
class MeowzicAudioHandler extends BaseAudioHandler with SeekHandler {
  MeowzicAudioHandler() {
    _player.playbackEventStream.map(_toState).pipe(playbackState);
    // Following the player rather than announcing the next track ourselves is
    // what keeps the notification and the dashboard strip honest when a track
    // ends on its own: the advance happens inside ExoPlayer and nothing here
    // gets a chance to run first.
    _player.currentIndexStream.listen(_handleIndex);
  }

  final AudioPlayer _player = AudioPlayer(
    // Two defaults are load-bearing and deliberately left alone.
    //
    // `useLazyPreparation` stays true: eager preparation would fire a resolve
    // at the bridge for every queued track at once, and each resolve is a live
    // yt-dlp extraction against YouTube. That burst is exactly how an exit node
    // gets flagged.
    //
    // `maxSkipsOnError` stays 0. It skips to the next source on a load error,
    // and on a flagged node every track fails — the player would silently run
    // the whole queue out and give up, which reads as "the playlist vanished"
    // rather than as a diagnosable failure. The MeowzicStall states are the
    // honest mechanism and stay in charge.
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        // Five minutes instead of the stock 50 seconds. The bridge streams
        // through the tunnel, so a bearer change or a brief tunnel hiccup
        // stops the bytes for seconds at a time; 50 seconds of runway is
        // routinely not enough to cover one and the audio audibly cuts out.
        // Five minutes covers a whole track for most of what people search,
        // and costs a few megabytes: opus at ~128 kbps is about 1 MB a minute,
        // so this is roughly 5 MB of heap while something plays.
        //
        // min and max are kept equal, as the package's own defaults are:
        // ExoPlayer buffers up to max, then resumes once the buffer falls
        // below min, and a gap between them just makes the refill start later.
        minBufferDuration: Duration(minutes: 5),
        maxBufferDuration: Duration(minutes: 5),
        // The default false makes ExoPlayer stop buffering when its byte
        // budget is hit rather than when the time target is met, which is why
        // the runway collapses on a compressed stream. Without this the
        // durations above are advisory.
        prioritizeTimeOverSizeThresholds: true,
        // bufferForPlaybackDuration and bufferForPlaybackAfterRebufferDuration
        // are left at their defaults on purpose: they decide how fast playback
        // *starts*, and raising them makes every press feel slower.
      ),
    ),
  );

  /// The tracks handed over by the last tap, in the order they were shown.
  List<MeowzicQueueItem> _queue = const [];

  /// Carries the bridge token, so it is held once for the whole queue rather
  /// than baked into any URL.
  Map<String, String>? _headers;

  /// Which entry of [_queue] is current. Kept in step with the player by
  /// [_handleIndex], and the value a resume re-prepares at.
  int _index = 0;

  Duration _resumeFrom = Duration.zero;

  /// True while this handler is itself (re)loading the playlist.
  ///
  /// The player republishes the outgoing index while a new playlist is being
  /// installed, and acting on that would overwrite the index the load was
  /// asked for — losing the track a stalled skip just picked.
  bool _preparing = false;

  /// Whether the user wants this playing — not merely whether it happened to
  /// be playing. Set from the player when the tunnel parks a track, and set
  /// outright by an explicit play press, which is a request to play as soon
  /// as the tunnel allows it.
  bool _wasPlaying = false;

  /// Bumped by every tunnel event so a resume that was awaiting when the next
  /// one arrived can tell it no longer owns the state. Same guard as
  /// `_generation` in the search tab: the danger is not the await itself but
  /// the stale continuation that lands after a newer event decided otherwise.
  int _tunnelGeneration = 0;

  /// Why playback is parked, for anything that has to explain it.
  final ValueNotifier<MeowzicStall> stallListenable =
      ValueNotifier(MeowzicStall.none);

  /// Asks whoever owns the tunnel to bring it back, and reports whether it is
  /// up by the time it returns — whether it already was, or the request brought
  /// it back. Wired by `MeowzicManager` so this handler needs no knowledge of
  /// the VPN controller — it is built by `AudioService.init`, which leaves no
  /// room for constructor injection.
  Future<bool> Function()? onTunnelRequested;

  /// The human-readable reason for a stall, supplied by the UI layer.
  ///
  /// Wired alongside [onTunnelRequested] so this handler carries no
  /// localization of its own and each stall can name itself.
  String Function(MeowzicStall stall)? stallReason;

  Duration get position => _player.position;

  /// The entry currently loaded, or null when nothing is.
  MediaItem? get _current =>
      _index >= 0 && _index < _queue.length ? _queue[_index].item : null;

  /// Rebuilds the platform sources from the held queue.
  ///
  /// Rebuilt on every load rather than cached, because an [AudioSource] is
  /// bound to the player that consumed it and a resume installs a fresh
  /// playlist.
  List<AudioSource> _buildSources() => [
        for (final entry in _queue)
          AudioSource.uri(entry.uri, headers: _headers),
      ];

  /// Plays [tracks] starting at [startAt], and keeps the rest queued behind it.
  ///
  /// [headers] carries the bridge token. It must never move into the URLs:
  /// the [MediaItem]s are handed to the system media session, and any app
  /// holding notification access can read what is published there.
  Future<void> playQueue(
    List<MeowzicQueueItem> tracks,
    int startAt, {
    Map<String, String>? headers,
  }) async {
    if (tracks.isEmpty) return;
    final start = startAt.clamp(0, tracks.length - 1);

    // Recorded before the player is touched so that a tunnel drop landing
    // mid-load already has a session to park. A load that fails for any other
    // reason must NOT keep one — see the rollback below.
    _queue = List.unmodifiable(tracks);
    _headers = headers;
    _index = start;
    _resumeFrom = Duration.zero;
    stallListenable.value = MeowzicStall.none;
    meowzicSessionListenable.value = true;

    queue.add([for (final entry in tracks) entry.item]);
    mediaItem.add(tracks[start].item);
    _preparing = true;
    try {
      await _player.setAudioSources(
        _buildSources(),
        initialIndex: start,
        initialPosition: Duration.zero,
      );
      await _player.play();
    } catch (_) {
      if (stallListenable.value != MeowzicStall.needVpn) {
        // Nothing parked this, so nothing can bring it back: leaving the
        // session up would keep the dashboard cell showing a mini player for
        // a track that never loaded and whose play button does nothing.
        _clearSession();
      }
      // The caller reports the failure either way; rolling back must not
      // swallow it.
      rethrow;
    } finally {
      _preparing = false;
    }
  }

  /// Drops everything a reconnect could come back to.
  void _clearSession() {
    _queue = const [];
    _headers = null;
    _index = 0;
    _resumeFrom = Duration.zero;
    _wasPlaying = false;
    stallListenable.value = MeowzicStall.none;
    meowzicSessionListenable.value = false;
    mediaItem.add(null);
    queue.add(const []);
  }

  /// Follows the player's own idea of which track is current.
  ///
  /// This is the only path that reports an automatic advance, so it publishes
  /// the new [MediaItem] itself. While a stall is armed it republishes the
  /// stalled face instead — the reason still applies, and overwriting it with
  /// pristine metadata would leave the shade claiming everything is fine.
  void _handleIndex(int? index) {
    if (_preparing) return;
    if (index == null || index < 0 || index >= _queue.length) return;
    if (index == _index) return;
    _index = index;
    // A track reached on its own starts at the top; carrying the previous
    // one's offset would make the next tunnel drop resume in the wrong place.
    _resumeFrom = Duration.zero;
    final item = _queue[index].item;
    final stall = stallListenable.value;
    if (stall == MeowzicStall.none) {
      mediaItem.add(item);
    } else {
      _publishStalled(item, stall);
    }
  }

  /// Publishes [item] carrying the reason for [stall].
  ///
  /// The reason goes into the artist slot, not only the album one. audio_service
  /// maps `MediaItem.album` to `METADATA_KEY_ALBUM`, which reaches `setSubText`
  /// — and Android's compact media-control widget does not draw subtext, so a
  /// reason living only there is invisible in the shade, which is exactly where
  /// somebody with the app minimised has to read it. Measured on a Pixel 10:
  /// metadata carried `description=Creep, Radiohead, Нужен VPN` while the
  /// widget rendered only the title and the artist.
  ///
  /// Artist is `setContentText`, the second line the widget does draw, so the
  /// reason is appended to it rather than replacing it. Both slots are written:
  /// surfaces that do render subtext still get it, and [_queue] stays pristine,
  /// so the resume restores the untouched metadata.
  void _publishStalled(MediaItem item, MeowzicStall stall) {
    final reason = stallReason?.call(stall);
    if (reason == null) {
      mediaItem.add(item);
      return;
    }
    final artist = item.artist;
    mediaItem.add(
      item.copyWith(
        artist: artist == null || artist.isEmpty ? reason : '$artist · $reason',
        album: reason,
      ),
    );
  }

  /// Parks playback because the tunnel went away.
  Future<void> suspendForTunnel() async {
    _tunnelGeneration++;
    final item = _current;
    if (item == null) return;

    // Scoped to what a repeat call may actually damage — the held position and
    // the user's intent, which must not be overwritten with post-pause values.
    // A drop landing on top of a bridgeError must not re-snapshot either: the
    // player is idle by then and its position means nothing.
    //
    // Returning outright on an armed stall was load-bearing in the wrong
    // direction: it made a wrong state permanent instead of correcting it, so
    // a track left armed while audio was live could never be parked again.
    // Pausing, arming and republishing therefore always run — and a bridgeError
    // becomes needVpn, because the tunnel is now the true reason.
    if (stallListenable.value == MeowzicStall.none) {
      _wasPlaying = _player.playing;
      _resumeFrom = _player.position;
    }
    await _player.pause();
    stallListenable.value = MeowzicStall.needVpn;
    _publishStalled(item, MeowzicStall.needVpn);
  }

  /// Re-prepares the queue at the held track and position, and resumes it if
  /// the user wants it playing — either it was playing when the tunnel
  /// dropped, or they pressed play while it was parked.
  ///
  /// The whole queue is re-installed, not just the held track, so an advance
  /// still has somewhere to go after a reconnect. `initialPosition` makes
  /// just_audio issue a ranged request, which is why this costs one seek
  /// rather than a re-download.
  Future<void> resumeAfterTunnel() async {
    final generation = ++_tunnelGeneration;
    // Any stall is retryable, not just the tunnel one: a bridgeError press
    // lands here directly.
    if (stallListenable.value == MeowzicStall.none) return;

    final item = _current;
    if (item == null) {
      stallListenable.value = MeowzicStall.none;
      return;
    }

    mediaItem.add(item);
    // Cleared here, not after the awaits. Putting the correct state behind a
    // guard designed to skip means the skip leaves the stall armed over
    // playing audio, and an invisible stall makes the next park early-return.
    // Up front, the worst a stale continuation can do is nothing at all.
    stallListenable.value = MeowzicStall.none;
    _preparing = true;
    try {
      await _player.setAudioSources(
        _buildSources(),
        initialIndex: _index,
        initialPosition: _resumeFrom,
      );
      // The tunnel can go away again inside that await; a newer event then
      // owns the state and this continuation must not push audio on its
      // behalf.
      if (generation != _tunnelGeneration) return;
      if (_wasPlaying) await _player.play();
    } catch (error, stackTrace) {
      // The tunnel came back but the bridge did not — measured as a 502 out of
      // just_audio's local proxy. Arming needVpn here would blame the tunnel
      // for something it is not doing, so the stall names the bridge instead
      // and the next press retries rather than reconnecting. Unless a newer
      // event already owns the state, in which case a stale failure must not
      // re-arm what it resolved.
      commonPrint.log('meowzic resume failed: $error\n$stackTrace');
      if (generation != _tunnelGeneration) return;
      stallListenable.value = MeowzicStall.bridgeError;
      _publishStalled(item, MeowzicStall.bridgeError);
    } finally {
      _preparing = false;
    }
  }

  @override
  Future<void> play() async {
    // Switched without a default on purpose: a fourth stall must break the
    // build here rather than fall through to pushing audio at a dead source.
    // One path serves both the strip button and the notification's play
    // control.
    switch (stallListenable.value) {
      case MeowzicStall.none:
        await _player.play();
      case MeowzicStall.needVpn:
        // Pressing play while parked means "bring it back", not "push audio
        // into a dead socket".
        //
        // Set before the request, because whichever resume runs first — this
        // one or the manager's, in the foreground — reads it to decide whether
        // to make sound. It is the only thing carrying the press across the
        // reconnect: without it a track the user had paused by hand before the
        // drop would re-prepare in silence and the press would read as dead.
        _wasPlaying = true;
        // The request is awaited to completion, so a true here means the tunnel
        // is up now — whether it already was, or this press brought it back.
        // Waiting for a runTime transition instead would strand every press
        // made from the notification, which is the one place this has to work:
        // that provider is fed by a task the app pauses while backgrounded.
        if (await onTunnelRequested?.call() ?? false) {
          await resumeAfterTunnel();
        }
      case MeowzicStall.bridgeError:
        // The tunnel is already up; only the bridge failed. Retry straight
        // away — a new request may land on a different exit node.
        _wasPlaying = true;
        await resumeAfterTunnel();
    }
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _skipBy(1);

  @override
  Future<void> skipToPrevious() => _skipBy(-1);

  @override
  Future<void> skipToQueueItem(int index) => _skipTo(index);

  Future<void> _skipBy(int delta) =>
      // The player owns the index while audio is live; while parked its
      // playlist is bound to a dead socket and the held index is the truth.
      _skipTo((stallListenable.value == MeowzicStall.none
              ? _player.currentIndex ?? _index
              : _index) +
          delta);

  /// Moves to [index], or does nothing when there is nothing there.
  ///
  /// Routed through the stall the same way [play] is: pressing next while
  /// parked must ask for the tunnel back rather than push audio into a dead
  /// socket.
  Future<void> _skipTo(int index) async {
    if (index < 0 || index >= _queue.length) return;
    switch (stallListenable.value) {
      case MeowzicStall.none:
        // Position zero because this is a track change, not a seek.
        await _player.seek(Duration.zero, index: index);
      case MeowzicStall.needVpn:
        _holdAt(index);
        if (await onTunnelRequested?.call() ?? false) {
          await resumeAfterTunnel();
        }
      case MeowzicStall.bridgeError:
        _holdAt(index);
        await resumeAfterTunnel();
    }
  }

  /// Points the parked session at [index] without touching the player.
  ///
  /// Seeking the loaded playlist would resolve to nothing — whatever it is
  /// reading from is gone. The resume re-prepares from here, which is the only
  /// thing that can actually produce sound, and `_wasPlaying` carries the press
  /// across the reconnect for the same reason it does in [play].
  void _holdAt(int index) {
    _index = index;
    _resumeFrom = Duration.zero;
    _wasPlaying = true;
    _publishStalled(_queue[index].item, stallListenable.value);
  }

  @override
  Future<void> stop() async {
    // Ending the session, not just the sound: nothing is left for a reconnect
    // to come back to, so the dashboard cell may go with it.
    _clearSession();
    await _player.stop();
    await super.stop();
  }

  PlaybackState _toState(PlaybackEvent event) {
    // A single result played on its own has nowhere to skip to, and a dead
    // button in the shade is worse than an absent one.
    final queued = _queue.length > 1;
    return PlaybackState(
      controls: [
        if (queued) MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        if (queued) MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek},
      // The collapsed notification draws at most three, and previous/play/next
      // are the three worth having there; stop stays reachable expanded.
      androidCompactActionIndices: queued ? const [0, 1, 2] : const [0],
      processingState: switch (event.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}

/// The live handler, or null while music has never been started.
///
/// Lets the dashboard strip observe playback WITHOUT bringing the service
/// into existence: reading a getter would be enough to start it, and someone
/// who never opens music must not get a media service. Stays null until
/// [meowzicAudio] is actually called.
final ValueNotifier<MeowzicAudioHandler?> meowzicHandlerListenable =
    ValueNotifier(null);

/// True while a track is loaded — playing, paused, or parked waiting for the
/// tunnel. The dashboard reads it so the strip survives a disconnect: a
/// session that outlives the tunnel still needs somewhere to come back to.
final ValueNotifier<bool> meowzicSessionListenable = ValueNotifier(false);

MeowzicAudioHandler? _handler;
Future<MeowzicAudioHandler>? _pending;

/// The handler, built on first call and reused after.
///
/// [AudioService.init] may only run once per process, so concurrent callers
/// share the same in-flight future rather than racing to start a second
/// service.
Future<MeowzicAudioHandler> meowzicAudio() {
  final ready = _handler;
  if (ready != null) return Future.value(ready);
  return _pending ??= AudioService.init(
    builder: MeowzicAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'app.dropweb.meowzic',
      androidNotificationChannelName: 'meowzic',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  ).then((handler) {
    _handler = handler;
    meowzicHandlerListenable.value = handler;
    return handler;
  });
}
