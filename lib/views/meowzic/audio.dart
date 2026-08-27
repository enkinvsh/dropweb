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

/// The actions the collapsed notification is allowed to draw.
///
/// Membership, not position: the control list is assembled conditionally, so
/// the indices the platform is given have to be looked up in the list that was
/// actually built. Play and pause are both here because exactly one of them is
/// ever in the list.
const Set<MediaAction> _compactActions = {
  MediaAction.skipToPrevious,
  MediaAction.play,
  MediaAction.pause,
  MediaAction.skipToNext,
};

/// The custom action name the notification's heart fires.
///
/// Shared between the control that carries it and the handler that answers it,
/// so the two cannot drift apart on a typo the compiler would not catch.
const String meowzicToggleLikeAction = 'toggleLike';

/// Whether the track currently loaded is in the listener's Liked Songs.
///
/// The same idiom as [meowzicSessionListenable] and for the same reason: the
/// handler is built by `AudioService.init` and holds no `Ref`, so the Riverpod
/// layer pushes the answer down here rather than the handler reaching up for
/// it. `MeowzicManager` keeps it in sync with `spotifyLikesProvider`; the
/// handler listens and republishes its state so the shade redraws the glyph.
///
/// False while nothing is loaded, while the track has no Spotify identity, and
/// while the status is simply not known yet — an unknown heart is a hollow
/// heart, exactly as it is in the mini player.
final ValueNotifier<bool> meowzicLikedListenable = ValueNotifier(false);

/// Playback for meowzic, fronted by a media notification.
///
/// Deliberately NOT started at app launch: [meowzicAudio] builds the service on
/// first use, so somebody who never opens music never gets a media service or
/// its notification. The VPN foreground service is unrelated and unaffected —
/// this one is typed mediaPlayback and carries no runtime cap.
class MeowzicAudioHandler extends BaseAudioHandler with SeekHandler {
  MeowzicAudioHandler() {
    // Listened rather than piped, because a pipe is an `addStream` and rxdart
    // refuses `add` while one is running ("You cannot add items while items are
    // being added from addStream", rxdart Subject.add). The like state has to
    // republish this outside the player's own events — see [_republishState] —
    // so the stream is forwarded by hand. Errors are forwarded exactly as the
    // pipe forwarded them; only the close-on-done is dropped, and this player
    // is never disposed.
    _player.playbackEventStream.listen(
      (event) => playbackState.add(_toState(event)),
      onError: playbackState.addError,
    );
    // Following the player rather than announcing the next track ourselves is
    // what keeps the notification and the dashboard strip honest when a track
    // ends on its own: the advance happens inside ExoPlayer and nothing here
    // gets a chance to run first.
    //
    // Followed by ACTIVE SOURCE, never by index — the idiom Spotube uses
    // (`activeSourceChangedStream`, audio_players_streams_mixin.dart). An index
    // is only a position in whichever list the player is holding right now, so
    // the moment a new playlist goes in it names a track in the outgoing one.
    // A source names the track itself and cannot mean a different one. Do NOT
    // "simplify" this back into `currentIndexStream`: that is the bug, not the
    // shorter spelling of it.
    _player.sequenceStateStream.listen(_handleSequence);
    // The shade's heart is a native drawable, so nothing about it can change
    // until this handler publishes a new PlaybackState. Nothing in the player
    // moves when a like is written, so the listenable is what moves it.
    meowzicLikedListenable.addListener(_republishState);
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

  /// Which entry of [_queue] is current. Resolved from the player's active
  /// source by [_handleSequence], and the value a resume re-prepares at.
  int _index = 0;

  Duration _resumeFrom = Duration.zero;

  /// The source this handler last asked the player to make active.
  ///
  /// just_audio installs a playlist before it moves the index onto it:
  /// `setAudioSources` runs `_playlist._init`, which broadcasts a sequence
  /// carrying the NEW sources under the PREVIOUS index (just_audio 0.10.6,
  /// just_audio.dart `_init` -> `_broadcastSequence`). That one event names a
  /// real track of the new queue — just not the one the load asked for — so
  /// source identity alone cannot tell it from an advance. Events are held
  /// back until the requested source actually shows up; from then on the
  /// player leads and this clears, so a track it reaches on its own is news
  /// rather than an echo.
  Uri? _requestedUri;

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

  /// Asks whoever owns the Spotify account to flip the like on that track uri.
  ///
  /// Wired by `MeowzicManager` for the same reason [onTunnelRequested] is: this
  /// handler is built by `AudioService.init`, which leaves no room to hand it a
  /// `Ref`, and reaching for a provider from here would put account state
  /// inside the media service. The answer is deliberately not carried back —
  /// the notifier rolls its own optimistic flip back on failure, and the shade
  /// has nowhere to show a sentence anyway.
  Future<void> Function(String uri)? onLikeRequested;

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
    _requestedUri = tracks[start].uri;
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
    }
  }

  /// Drops everything a reconnect could come back to.
  void _clearSession() {
    _queue = const [];
    _headers = null;
    _index = 0;
    _resumeFrom = Duration.zero;
    _requestedUri = null;
    _wasPlaying = false;
    stallListenable.value = MeowzicStall.none;
    meowzicSessionListenable.value = false;
    mediaItem.add(null);
    queue.add(const []);
  }

  /// Follows the player's own idea of which track is current, by asking which
  /// SOURCE is active rather than which index.
  ///
  /// This is the only path that reports an automatic advance, so it publishes
  /// the new [MediaItem] itself. While a stall is armed it republishes the
  /// stalled face instead — the reason still applies, and overwriting it with
  /// pristine metadata would leave the shade claiming everything is fine.
  void _handleSequence(SequenceState state) {
    final source = state.currentSource;
    // Every source this handler builds is a `UriAudioSource`; anything else
    // did not come from here.
    if (source is! UriAudioSource) return;
    final uri = source.uri;

    final requested = _requestedUri;
    if (requested != null) {
      if (uri != requested) return;
      _requestedUri = null;
    }

    // The URI is the identity, so a source belonging to a playlist this
    // handler no longer owns simply is not found and is ignored — where an
    // index would have been found in the wrong list and believed.
    final index = _queue.indexWhere((entry) => entry.uri == uri);
    if (index < 0) return;
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
    _requestedUri = _queue[_index].uri;
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

  /// The Spotify identity of the loaded track, or null when it has none.
  ///
  /// Tracks found through the bridge's own text search have no counterpart in
  /// Spotify, so there is nothing a like could be written against. They get no
  /// heart at all rather than one that cannot do anything.
  String? get _likeableUri {
    final uri = _current?.extras?['spotifyUri'];
    return uri is String ? uri : null;
  }

  /// Publishes the current state again without waiting for the player to move.
  ///
  /// The only reason this exists: a like is written outside the player, and the
  /// shade cannot notice it until a new [PlaybackState] carries a new icon.
  void _republishState() {
    if (playbackState.isClosed) return;
    playbackState.add(_toState(_player.playbackEvent));
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name != meowzicToggleLikeAction) {
      return super.customAction(name, extras);
    }
    // Read from the queue rather than from the control that was pressed: the
    // shade may be showing a notification built a track ago.
    final uri = _likeableUri;
    if (uri == null) return null;
    await onLikeRequested?.call(uri);
    return null;
  }

  PlaybackState _toState(PlaybackEvent event) {
    // A single result played on its own has nowhere to skip to, and a dead
    // button in the shade is worse than an absent one.
    final queued = _queue.length > 1;
    final likeable = _likeableUri != null;
    final liked = meowzicLikedListenable.value;
    final controls = <MediaControl>[
      if (queued) MediaControl.skipToPrevious,
      if (_player.playing) MediaControl.pause else MediaControl.play,
      if (queued) MediaControl.skipToNext,
      MediaControl.stop,
      // Last, because the expanded shade lays them out in order and the
      // transport belongs on the left. Absent entirely for a track with no
      // Spotify identity — same honesty as the mini player's.
      if (likeable)
        MediaControl.custom(
          androidIcon:
              liked ? 'drawable/ic_heart_filled' : 'drawable/ic_heart',
          label: liked
              ? appLocalizations.meowzicUnlike
              : appLocalizations.meowzicLike,
          name: meowzicToggleLikeAction,
        ),
    ];
    return PlaybackState(
      controls: controls,
      systemActions: const {MediaAction.seek},
      // The collapsed notification draws at most three, and previous/play/next
      // are the three worth having there; stop and the heart stay reachable
      // expanded.
      //
      // Derived from the list actually built and never written as a literal
      // `[0, 1, 2]`. The skip controls above are conditional, so on a single
      // track play/pause sits at index 0 and stop at index 1 — fixed numbers
      // would put stop under the finger that meant pause.
      androidCompactActionIndices: [
        for (var i = 0; i < controls.length; i++)
          if (_compactActions.contains(controls[i].action)) i,
      ],
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
      // The resolved index, not `event.currentIndex`: this position is read
      // against the queue published above, and the player's own index still
      // points into the outgoing list while a playlist is going in.
      queueIndex: _queue.isEmpty ? null : _index,
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

/// The track a tap is currently turning into something playable, as a Spotify
/// uri, or null when nothing is being matched.
///
/// One value for the whole app, next to the session it belongs to, because
/// resolving is singular in fact: one tap wins, one queue loads, one track
/// plays. It lived on the container's own state until a playlist opened
/// earlier sat with a spinner on a track forever while a different playlist
/// played something else — each container kept a private copy, and a copy that
/// nobody else can see is a copy nobody else can clear. Moving to `keepAlive`
/// providers made that permanent instead of merely invisible.
///
/// Screens read it and none of them own it. A screen that owns a flag can only
/// clear the flag it set.
final ValueNotifier<String?> meowzicResolvingListenable = ValueNotifier(null);

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
