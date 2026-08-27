import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/views/meowzic/audio.dart';
import 'package:dropweb/views/meowzic/faded_list.dart';
import 'package:dropweb/views/meowzic/spotify/detail.dart';
import 'package:dropweb/views/meowzic/spotify/detail_page.dart';
import 'package:dropweb/views/meowzic/spotify/library.dart';
import 'package:dropweb/views/meowzic/spotify/radio.dart';
import 'package:dropweb/views/meowzic/track_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A list of Spotify tracks, drawn the way the container screen draws them.
///
/// Written once and used by both surfaces that grew after `SpotifyDetailPage`
/// did — the Spotify search results and the Сохранённые tab — because they are
/// the same object to a listener: rows with a Spotify identity, a three-dot
/// menu that can seed a radio, no running time, and the row that is playing
/// marked. Two hand-made copies of that is precisely the "одни и те же косяки
/// на разных страницах" [MeowzicTrackRow] was extracted to end, and this is the
/// next layer up of the same problem.
///
/// It does NOT own the tracks, the phase or the paging — those belong to
/// whichever notifier is behind the caller. What it owns is one thing and one
/// thing only: which row a radio is being built for right now.
class SpotifyTrackList extends ConsumerStatefulWidget {
  const SpotifyTrackList({
    super.key,
    required this.tracks,
    required this.onPlay,
    this.loadingMore = false,
    this.onLoadMore,
  });

  final List<SpotifyTrack> tracks;

  /// Plays the row at that index. Async because the caller reports the reason a
  /// tap could not play, and only it holds the `BuildContext` to report it in.
  final Future<void> Function(int index) onPlay;

  /// A further page is on its way; drawn under the rows rather than instead of
  /// them.
  final bool loadingMore;

  /// Asked for the next page as the list comes to rest near its end. Null where
  /// there is nothing to page.
  final VoidCallback? onLoadMore;

  @override
  ConsumerState<SpotifyTrackList> createState() => _SpotifyTrackListState();
}

class _SpotifyTrackListState extends ConsumerState<SpotifyTrackList> {
  /// The track whose radio is being looked up right now, or null.
  ///
  /// Plain `State` on purpose, and it is the whole mechanism. A resolve is
  /// something a finger is doing on this screen; parking it in a keepAlive
  /// provider is exactly how this project earned a spinner that outlived its
  /// screen and kept turning on an unrelated playlist. This one cannot: it is
  /// born with the widget and dies with it.
  String? _radioTrackUri;

  /// Builds a radio mix around [track] and opens it, playing.
  ///
  /// Two taps cannot overlap: the second is dropped rather than queued, the
  /// same rule the notifiers apply to a resolve in flight. Without it a
  /// double-tap on the menu would push two copies of the same mix onto the
  /// stack, each starting playback of the other's first track.
  ///
  /// The mix is pushed with a placeholder name, because the seed service
  /// answers with a uri and nothing else. It is on screen for as long as the
  /// container query takes and is then replaced by Spotify's own title.
  Future<void> _openRadio(SpotifyTrack track) async {
    if (_radioTrackUri != null) return;
    setState(() => _radioTrackUri = track.uri);
    unawaited(context.showNotifier(appLocalizations.meowzicRadioLoading));
    try {
      final playlistUri = await resolveSpotifyTrackRadio(
        notifier: ref.read(spotifyAuthProvider.notifier),
        trackUri: track.uri,
      );
      if (!mounted) return;
      unawaited(
        BaseNavigator.push<void>(
          context,
          SpotifyDetailPage(
            item: SpotifyLibraryItem(
              uri: playlistUri,
              title: appLocalizations.meowzicTrackRadio,
              subtitle: track.title,
              kind: SpotifyLibraryKind.playlist,
            ),
            autoPlay: true,
          ),
        ),
      );
    } catch (error) {
      commonPrint.log('spotify track radio failed: $error');
      if (!mounted) return;
      unawaited(context.showNotifier(appLocalizations.meowzicRadioFailed));
    } finally {
      // Unconditional. Whatever else went wrong, the row must not stay marked
      // as working — that is the defect this whole shape exists to avoid.
      if (mounted) setState(() => _radioTrackUri = null);
    }
  }

  /// Asks for the next page as the list comes to rest near its end.
  ///
  /// Hung off the scroll notification rather than off "the last row was built",
  /// the same call the library grid and the container screen make: an item
  /// builder runs during layout, and starting a fetch from there mutates
  /// provider state in the middle of a frame. Waiting for the scroll to settle
  /// also means one request per flick instead of one per row crossed.
  bool _onScrollEnd(ScrollEndNotification notification) {
    final loadMore = widget.onLoadMore;
    if (loadMore != null &&
        notification.metrics.extentAfter < meowzicLoadMoreThreshold) {
      loadMore();
    }
    return false;
  }

  /// The rows, with the one that is currently playing marked.
  ///
  /// The handler is observed through the shared notifier rather than by calling
  /// `meowzicAudio()`, which would spin up the media service for anyone who
  /// merely searched or opened a list to look at it.
  ///
  /// Matched on `extras['spotifyUri']` rather than on `MediaItem.id`, because
  /// `id` is the bridge's video id and these rows only know their Spotify uri.
  /// That is the same value the like control reads, so a row is marked here
  /// exactly when the heart elsewhere is talking about it.
  Widget _buildListening() => ValueListenableBuilder<MeowzicAudioHandler?>(
        valueListenable: meowzicHandlerListenable,
        builder: (context, handler, _) => handler == null
            ? _buildList(null)
            : StreamBuilder<MediaItem?>(
                stream: handler.mediaItem,
                builder: (context, snapshot) => _buildList(
                  snapshot.data?.extras?['spotifyUri'] as String?,
                ),
              ),
      );

  Widget _buildList(String? playingUri) {
    final tracks = widget.tracks;
    return MeowzicFade(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: tracks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              // Subscribed per row rather than once around the list: a resolve
              // starting or ending repaints the one row that changed instead of
              // every row on screen.
              itemBuilder: (_, index) => ValueListenableBuilder<String?>(
                valueListenable: meowzicResolvingListenable,
                builder: (_, resolvingUri, __) {
                  // Two different waits, drawn as one mark: matching a track on
                  // the bridge, and building a radio around it. To the listener
                  // they are the same statement — this row is being worked on.
                  final isBusy = tracks[index].uri == resolvingUri ||
                      tracks[index].uri == _radioTrackUri;
                  return MeowzicTrackRow(
                    title: tracks[index].title,
                    subtitle: tracks[index].artists,
                    image: tracks[index].image,
                    // The band marks what is PLAYING, not what is loading — the
                    // same thing it means on the container screen. Loading keeps
                    // the spinner in the corner; the two do not share one mark.
                    isSelected: tracks[index].uri == playingUri,
                    onPressed: () => unawaited(widget.onPlay(index)),
                    // The row ends in an IconButton, which reserves its own tap
                    // padding — see [MeowzicTrackRow.trailingPadsItself].
                    trailingPadsItself: true,
                    trailing: Row(
                      // Min, or the row would hand the whole free width to the
                      // trailing and push the title into an ellipsis.
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Length is deliberately not printed. It said nothing
                        // the listener had asked for and crowded the corner the
                        // menu needs; the container screen stopped printing one
                        // for the same reason, and these listings answer to the
                        // same eye.
                        if (isBusy)
                          const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        MeowzicTrackMenu(
                          onListen: () => unawaited(widget.onPlay(index)),
                          onRadio: () => unawaited(_openRadio(tracks[index])),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          // Appended under what is already readable, never in place of it:
          // reaching the bottom of a long listing must not take the listing away
          // to show that more is coming.
          if (widget.loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: meowzicListBottomPadding),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollEndNotification>(
        onNotification: _onScrollEnd,
        child: _buildListening(),
      );
}
