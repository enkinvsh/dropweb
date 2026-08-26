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

/// Playback for meowzic, fronted by a media notification.
///
/// Deliberately NOT started at app launch: [handler] builds the service on
/// first use, so somebody who never opens music never gets a media service or
/// its notification. The VPN foreground service is unrelated and unaffected —
/// this one is typed mediaPlayback and carries no runtime cap.
class MeowzicAudioHandler extends BaseAudioHandler with SeekHandler {
  MeowzicAudioHandler() {
    _player.playbackEventStream.map(_toState).pipe(playbackState);
  }

  final AudioPlayer _player = AudioPlayer();

  Uri? _source;
  Map<String, String>? _sourceHeaders;
  MediaItem? _item;
  Duration _resumeFrom = Duration.zero;

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

  /// Plays [uri], announcing [item] to the notification and lock screen.
  ///
  /// [headers] carries the bridge token. It must never move into [uri]:
  /// [item] is handed to the system media session, and any app holding
  /// notification access can read the ids in it.
  Future<void> playUri(
    Uri uri,
    MediaItem item, {
    Map<String, String>? headers,
  }) async {
    // Recorded before the player is touched so that a tunnel drop landing
    // mid-load already has a session to park. A load that fails for any other
    // reason must NOT keep one — see the rollback below.
    _source = uri;
    _sourceHeaders = headers;
    _item = item;
    _resumeFrom = Duration.zero;
    stallListenable.value = MeowzicStall.none;
    meowzicSessionListenable.value = true;

    mediaItem.add(item);
    try {
      await _player.setAudioSource(AudioSource.uri(uri, headers: headers));
      await _player.play();
    } catch (_) {
      if (stallListenable.value != MeowzicStall.needVpn) {
        // Nothing parked this, so nothing can bring it back: leaving the
        // session up would keep the dashboard cell showing a mini player for
        // a track that never loaded and whose play button does nothing.
        _source = null;
        _sourceHeaders = null;
        _item = null;
        _resumeFrom = Duration.zero;
        _wasPlaying = false;
        meowzicSessionListenable.value = false;
        mediaItem.add(null);
      }
      // The caller reports the failure either way; rolling back must not
      // swallow it.
      rethrow;
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
  /// surfaces that do render subtext still get it, and [_item] stays pristine,
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
    final item = _item;
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

  /// Re-prepares the same track at the held position and resumes it if the
  /// user wants it playing — either it was playing when the tunnel dropped,
  /// or they pressed play while it was parked.
  ///
  /// `initialPosition` makes just_audio issue a ranged request, which is why
  /// this costs one seek rather than a re-download.
  Future<void> resumeAfterTunnel() async {
    final generation = ++_tunnelGeneration;
    // Any stall is retryable, not just the tunnel one: a bridgeError press
    // lands here directly.
    if (stallListenable.value == MeowzicStall.none) return;

    final source = _source;
    final item = _item;
    if (source == null || item == null) {
      stallListenable.value = MeowzicStall.none;
      return;
    }

    mediaItem.add(item);
    // Cleared here, not after the awaits. Putting the correct state behind a
    // guard designed to skip means the skip leaves the stall armed over
    // playing audio, and an invisible stall makes the next park early-return.
    // Up front, the worst a stale continuation can do is nothing at all.
    stallListenable.value = MeowzicStall.none;
    try {
      await _player.setAudioSource(
        AudioSource.uri(source, headers: _sourceHeaders),
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
  Future<void> stop() async {
    // Ending the session, not just the sound: nothing is left for a reconnect
    // to come back to, so the dashboard cell may go with it.
    _item = null;
    _source = null;
    _sourceHeaders = null;
    _resumeFrom = Duration.zero;
    _wasPlaying = false;
    stallListenable.value = MeowzicStall.none;
    meowzicSessionListenable.value = false;
    await _player.stop();
    await super.stop();
  }

  PlaybackState _toState(PlaybackEvent event) => PlaybackState(
        controls: [
          MediaControl.rewind,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.fastForward,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 3],
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
