import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/views/meowzic/audio.dart';
import 'package:dropweb/views/meowzic/faded_list.dart';
import 'package:dropweb/views/meowzic/phase.dart';
import 'package:dropweb/views/meowzic/spotify/cover_tile.dart';
import 'package:dropweb/views/meowzic/spotify/detail.dart';
import 'package:dropweb/views/meowzic/spotify/gql.dart';
import 'package:dropweb/views/meowzic/spotify/library.dart';
import 'package:dropweb/views/meowzic/spotify/radio.dart';
import 'package:dropweb/views/meowzic/track_row.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

/// What a library tile opens: the container's cover and name, and its tracks.
///
/// Listing, playing, and — for a playlist — keeping. No following, no editing
/// and no now-playing screen: the mini player already on the dashboard strip is
/// where playback is watched, and duplicating it here would give the app two
/// places claiming to be the player.
///
/// [item] is the tile that was tapped. It is carried rather than re-fetched so
/// the header is drawn complete on the first frame: the name and the cover are
/// already known, and blanking them for the second the query takes would make
/// opening a playlist flash empty for no reason. It is also the only source of
/// a title for "Liked Songs", whose query answers with tracks alone.
class SpotifyDetailPage extends ConsumerStatefulWidget {
  const SpotifyDetailPage({
    super.key,
    required this.item,
    this.autoPlay = false,
  });

  final SpotifyLibraryItem item;

  /// Whether to start playing the first track as soon as the listing lands.
  ///
  /// Set only by track radio, and only because a radio mix is asked for by
  /// pressing play in everything but name: the listener wanted music, and the
  /// screen is opened alongside it so the mix can be seen and saved rather than
  /// instead of it. Every other way into this screen is somebody browsing, and
  /// browsing must not seize the player.
  ///
  /// It lives here rather than in the caller because the tracks are not known
  /// until this page has loaded them; driving the first play from the previous
  /// screen would mean racing this one's own `ensureLoaded`.
  final bool autoPlay;

  @override
  ConsumerState<SpotifyDetailPage> createState() => _SpotifyDetailPageState();
}

class _SpotifyDetailPageState extends ConsumerState<SpotifyDetailPage> {
  late final _provider = spotifyDetailProvider(
    widget.item.uri,
    widget.item.kind,
  );

  /// The track whose radio is being looked up right now, or null.
  ///
  /// Plain `State` on purpose, and it is the whole mechanism. A resolve is
  /// something a finger is doing on this screen; parking it in a keepAlive
  /// provider is exactly how this project earned a spinner that outlived its
  /// screen and kept turning on an unrelated playlist. This one cannot: it is
  /// born with the route and dies with it.
  String? _radioTrackUri;

  @override
  void initState() {
    super.initState();
    // On mount rather than inside the notifier's own build, which runs while
    // the tree is building and may not assign state.
    unawaited(_load());
  }

  /// Loads the container, then does the two things that depend on having it.
  ///
  /// The saved-status read is fired first and not awaited: it decides what one
  /// glyph in the header looks like, and making the listing wait on it would
  /// trade the whole screen for a checkmark.
  Future<void> _load() async {
    if (widget.item.kind == SpotifyLibraryKind.playlist) {
      unawaited(
        ref
            .read(spotifySavedProvider.notifier)
            .fetchSavedStatus([widget.item.uri]),
      );
    }
    await ref.read(_provider.notifier).ensureLoaded();
    if (!mounted || !widget.autoPlay) return;
    final tracks = ref.read(_provider).detail?.tracks ?? const <SpotifyTrack>[];
    if (tracks.isEmpty) return;
    // Past two awaits, so well clear of the build pass `ensureLoaded` has to
    // defer around — nothing here is assigning provider state mid-frame.
    await _play(0);
  }

  /// Shows why a tap could not play, when the notifier says it could not.
  ///
  /// The reason is decided there — it needs the tunnel, not a widget — and
  /// shown here, because a `BuildContext` is the one thing a notifier has no
  /// business holding. The same split the search tab already keeps.
  Future<void> _play(int index) async {
    final message = await ref.read(_provider.notifier).play(index);
    if (!mounted || message == null) return;
    unawaited(context.showNotifier(message));
  }

  /// Builds a radio mix around [track] and opens it, playing.
  ///
  /// Two taps cannot overlap: the second is dropped rather than queued, the
  /// same rule the notifier applies to a resolve in flight. Without it a
  /// double-tap on the menu would push two copies of the same mix onto the
  /// stack, each starting playback of the other's first track.
  ///
  /// The mix is pushed with a placeholder name, because the seed service
  /// answers with a uri and nothing else. It is on screen for as long as the
  /// container query takes and is then replaced by Spotify's own title, which
  /// the header already prefers when it has one.
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
  /// the same call the library grid makes and for the same reason: an item
  /// builder runs during layout, and starting a fetch from there mutates
  /// provider state in the middle of a frame. Waiting for the scroll to settle
  /// also means one request per flick instead of one per row crossed.
  bool _onScrollEnd(ScrollEndNotification notification) {
    if (notification.metrics.extentAfter < meowzicLoadMoreThreshold) {
      unawaited(ref.read(_provider.notifier).fetchMore());
    }
    return false;
  }

  /// The tracks, and an artist's releases under them.
  ///
  /// Slivers rather than a list, because there are two sections and only one of
  /// them is rows. This is NOT the body-sized `CustomScrollView` that had to be
  /// taken out: it lives inside the [Expanded] below the fixed header, exactly
  /// where the [ListView] it replaces did, so it never reaches the app bar that
  /// `extendBodyBehindAppBar` leaves floating over the body.
  ///
  /// The fade, the padding and the threshold are the shared ones from
  /// `faded_list.dart`. They were copied into this file from the search tab
  /// once already, which is how two screens ended up with one defect each to
  /// fix separately.
  /// The listing, with the row that is currently playing marked.
  ///
  /// Same shape as the search tab's own results builder, deliberately: handler
  /// is observed through the notifier rather than by calling `meowzicAudio()`,
  /// which would spin up the media service for anyone who merely opened a
  /// playlist to look at it.
  ///
  /// Matched on `extras['spotifyUri']` rather than on `MediaItem.id`, because
  /// `id` is the bridge's video id and these rows only know their Spotify uri.
  /// That is the same value the like control reads, so a row is marked here
  /// exactly when the heart elsewhere is talking about it.
  Widget _buildListening(SpotifyDetailState detail) =>
      ValueListenableBuilder<MeowzicAudioHandler?>(
        valueListenable: meowzicHandlerListenable,
        builder: (context, handler, _) => handler == null
            ? _buildList(detail, null)
            : StreamBuilder<MediaItem?>(
                stream: handler.mediaItem,
                builder: (context, snapshot) => _buildList(
                  detail,
                  snapshot.data?.extras?['spotifyUri'] as String?,
                ),
              ),
      );

  Widget _buildList(SpotifyDetailState detail, String? playingUri) {
    final tracks = detail.detail?.tracks ?? const <SpotifyTrack>[];
    final releases = detail.detail?.releases ?? const <SpotifyLibraryItem>[];
    if (tracks.isEmpty && releases.isEmpty) {
      return NullStatus(label: appLocalizations.meowzicContainerEmpty);
    }
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
                  // Two different waits, drawn as one mark: matching a track
                  // on the bridge, and building a radio around it. To the
                  // listener they are the same statement — this row is being
                  // worked on — and inventing a second treatment for the
                  // second one would say something the screen does not mean.
                  final isBusy = tracks[index].uri == resolvingUri ||
                      tracks[index].uri == _radioTrackUri;
                  return MeowzicTrackRow(
                    title: tracks[index].title,
                    subtitle: tracks[index].artists,
                    image: tracks[index].image,
                    // The band marks what is PLAYING, not what is loading —
                    // the same thing it means one tab over in search. It used
                    // to mark the busy row, which left the listing with no way
                    // at all to say where the listener actually is. Loading
                    // keeps the spinner in the corner; the two no longer share
                    // one mark.
                    isSelected: tracks[index].uri == playingUri,
                    onPressed: () => _play(index),
                    // The row ends in an IconButton, which reserves its own
                    // tap padding — see [MeowzicTrackRow.trailingPadsItself].
                    trailingPadsItself: true,
                    trailing: Row(
                      // Min, or the row would hand the whole free width to the
                      // trailing and push the title into an ellipsis.
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Length is deliberately not printed. It said nothing
                        // the listener had asked for and crowded the corner
                        // the menu needs; search has never printed one either,
                        // and these two listings answer to the same eye.
                        if (isBusy)
                          const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        MeowzicTrackMenu(
                          onListen: () => _play(index),
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
          // reaching the bottom of a long playlist must not take the playlist
          // away to show that more is coming.
          if (detail.loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (releases.isNotEmpty) ..._releaseSlivers(releases),
          const SliverToBoxAdapter(
            child: SizedBox(height: meowzicListBottomPadding),
          ),
        ],
      ),
    );
  }

  /// The artist's records, drawn as the library grid draws albums.
  ///
  /// The same [SpotifyLibraryItem], the same tile, and a tap that pushes the
  /// same [SpotifyDetailPage] this file already is — an album opened from an
  /// artist is the album screen, not a variant of it. Nothing here is new; the
  /// only thing that had to be written was reading the discography out of a
  /// response we were already fetching.
  List<Widget> _releaseSlivers(List<SpotifyLibraryItem> releases) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text(
              appLocalizations.meowzicArtistReleases,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              // The library grid's ratio, so a cover is the same size and shape
              // wherever it is drawn.
              childAspectRatio: 0.72,
            ),
            itemCount: releases.length,
            itemBuilder: (context, index) => SpotifyCoverTile(
              item: releases[index],
              onPressed: () => unawaited(
                BaseNavigator.push<void>(
                  context,
                  SpotifyDetailPage(item: releases[index]),
                ),
              ),
            ),
          ),
        ),
      ];

  /// What the app bar calls this container.
  ///
  /// `likedSongs` is named as a playlist rather than given a label of its own:
  /// it is a playlist in everything the user can do with it, and its actual
  /// name — "Liked Songs" — is right underneath, so a separate word here would
  /// only be the duplication this label exists to avoid.
  String _kindLabel(SpotifyLibraryKind kind) => switch (kind) {
        SpotifyLibraryKind.playlist ||
        SpotifyLibraryKind.likedSongs =>
          appLocalizations.meowzicKindPlaylist,
        SpotifyLibraryKind.album => appLocalizations.meowzicKindAlbum,
        SpotifyLibraryKind.artist => appLocalizations.meowzicKindArtist,
      };

  Widget _buildBody(SpotifyDetailState detail) => switch (detail.phase) {
        MeowzicPhase.idle ||
        MeowzicPhase.loading =>
          const Center(child: CircularProgressIndicator()),
        MeowzicPhase.failed => NullStatus(
            label: spotifyGqlFailureLabel(
              detail.failure ?? SpotifyGqlFailure.upstream,
            ),
          ),
        MeowzicPhase.done => _buildListening(detail),
      };

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(_provider);
    final title = detail.detail?.title ?? widget.item.title;
    return CommonScaffold(
      // What this is, not what it is called. The name is already set in the
      // header immediately below, in full and at heading size; repeating it
      // in the app bar spends the one line that could say where you are, and
      // spends it on something the eye has already read. It also reads worst
      // exactly where names are longest, since the bar truncates and the
      // header does not.
      title: _kindLabel(widget.item.kind),
      // Header fixed above the list, list scrolling inside it — the search
      // tab's shape, not a single scrollable holding both.
      //
      // It was one `CustomScrollView` for a while so the cover would scroll
      // away, and that is what put the rows under the app bar. `CommonScaffold`
      // sets `extendBodyBehindAppBar` for every dark screen, which is every
      // screen, so a body-sized scrollable runs beneath the bar: rows were
      // guillotined on a hard horizontal edge and the strip above it read as a
      // grey slab laid over the mesh. The search tab never had the fault
      // because its list is nested below other widgets and never reaches the
      // bar. Reclaiming a fifth of the screen on scroll is not worth a screen
      // that looks broken while you use it.
      body: Column(
        children: [
          _DetailHeader(
            item: widget.item,
            title: title,
            subtitle: detail.detail?.subtitle ?? widget.item.subtitle,
            image: detail.detail?.image ?? widget.item.image,
          ),
          Expanded(
            child: NotificationListener<ScrollEndNotification>(
              onNotification: _onScrollEnd,
              child: _buildBody(detail),
            ),
          ),
        ],
      ),
    );
  }
}

/// How wide the header cover is drawn.
const _headerArtSize = 96.0;

/// The cover, the name and whoever it belongs to.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.item,
    required this.title,
    required this.subtitle,
    required this.image,
  });

  final SpotifyLibraryItem item;
  final String title;
  final String? subtitle;
  final Uri? image;

  @override
  Widget build(BuildContext context) {
    final art = image;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          SizedBox.square(
            dimension: _headerArtSize,
            // Round for artists and squircle for everything else, the same
            // shape rule the grid tile applies — an artist that arrives round
            // in the grid and square on their own page reads as two different
            // things.
            child: item.kind == SpotifyLibraryKind.artist
                ? ClipOval(child: _art(context, art))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(Lumina.radiusMd),
                    child: _art(context, art),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle case final line?) ...[
                  const SizedBox(height: 4),
                  Text(
                    line,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Playlists only. An album or an artist is saved by a different
          // rootlist operation with a different notion of what "saved" means,
          // and Liked Songs cannot be unsaved at all — it is the account's own
          // collection. A control that appeared on all four and worked on one
          // would be worse than one that appears where it works.
          if (item.kind == SpotifyLibraryKind.playlist)
            _SavePlaylistButton(uri: item.uri),
        ],
      ),
    );
  }

  Widget _art(BuildContext context, Uri? uri) {
    final placeholder = ColoredBox(
      color: context.colorScheme.onSurface.opacity10,
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedMusicNote01,
          size: 32,
          color: context.colorScheme.onSurface.opacity38,
        ),
      ),
    );
    if (uri == null) return placeholder;
    final cacheSize =
        (_headerArtSize * MediaQuery.devicePixelRatioOf(context)).round();
    return CachedNetworkImage(
      imageUrl: uri.toString(),
      fit: BoxFit.cover,
      memCacheWidth: cacheSize,
      memCacheHeight: cacheSize,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

/// Keeps this playlist, or lets it go.
///
/// The whole control is two glyphs and a colour. `hugeicons 1.1.7` is a
/// stroke-only set — there is no filled twin of anything in it — so a state
/// that other clients carry with a fill is carried here with the accent, the
/// same way the heart in the mini player does it. The glyph changes too, plus
/// to tick, because that pairing is what every music app means by saved and
/// costs nothing to honour.
///
/// A [ConsumerWidget] of its own rather than a branch inside the header, so
/// that a save flipping repaints one icon instead of the cover, the title and
/// the artist line with it.
class _SavePlaylistButton extends ConsumerWidget {
  const _SavePlaylistButton({required this.uri});

  final String uri;

  /// Flips it, and says so — or says why not.
  ///
  /// The icon has already moved by the time this is awaited: the notifier is
  /// optimistic and rolls itself back, so there is nothing to undo here, only
  /// something to report. The confirmation on the way up is worth its line
  /// because the result of a save is a playlist appearing in a grid on another
  /// screen, which is not something this one can show.
  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final wasSaved = ref.read(spotifySavedProvider.notifier).isSaved(uri);
    final message = await ref.read(spotifySavedProvider.notifier).toggleSaved(
          uri,
        );
    if (!context.mounted) return;
    if (message != null) {
      unawaited(context.showNotifier(message));
      return;
    }
    if (!wasSaved) {
      unawaited(context.showNotifier(appLocalizations.meowzicPlaylistSaved));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(spotifySavedProvider)[uri] ?? false;
    return IconButton(
      onPressed: () => unawaited(_toggle(context, ref)),
      tooltip: saved
          ? appLocalizations.meowzicPlaylistRemove
          : appLocalizations.meowzicPlaylistSave,
      icon: HugeIcon(
        icon: saved
            ? HugeIcons.strokeRoundedCheckmarkCircle02
            : HugeIcons.strokeRoundedAddCircle,
        size: 24,
        color: saved
            ? context.colorScheme.primary
            : context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// The right-hand end of a row: the running time, or a spinner while the track
/// is being matched.
///
