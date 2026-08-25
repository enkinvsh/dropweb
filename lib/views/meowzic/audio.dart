import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

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

  Duration get position => _player.position;

  /// Plays [uri], announcing [item] to the notification and lock screen.
  Future<void> playUri(Uri uri, MediaItem item) async {
    mediaItem.add(item);
    await _player.setAudioSource(AudioSource.uri(uri));
    await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
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
