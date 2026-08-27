import 'dart:async';

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
import 'package:dropweb/views/meowzic/track_row.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

/// What a library tile opens: the container's cover and name, and its tracks.
///
/// Listing and playing, nothing else. No following, no saving, no editing and
/// no now-playing screen — the mini player already on the dashboard strip is
/// where playback is watched, and duplicating it here would give the app two
/// places claiming to be the player.
///
/// [item] is the tile that was tapped. It is carried rather than re-fetched so
/// the header is drawn complete on the first frame: the name and the cover are
/// already known, and blanking them for the second the query takes would make
/// opening a playlist flash empty for no reason. It is also the only source of
/// a title for "Liked Songs", whose query answers with tracks alone.
class SpotifyDetailPage extends ConsumerStatefulWidget {
  const SpotifyDetailPage({super.key, required this.item});

  final SpotifyLibraryItem item;

  @override
  ConsumerState<SpotifyDetailPage> createState() => _SpotifyDetailPageState();
}

class _SpotifyDetailPageState extends ConsumerState<SpotifyDetailPage> {
  late final _provider = spotifyDetailProvider(
    widget.item.uri,
    widget.item.kind,
  );

  @override
  void initState() {
    super.initState();
    // On mount rather than inside the notifier's own build, which runs while
    // the tree is building and may not assign state.
    unawaited(ref.read(_provider.notifier).ensureLoaded());
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
  Widget _buildList(SpotifyDetailState detail) {
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
                  final isResolving = tracks[index].uri == resolvingUri;
                  return MeowzicTrackRow(
                    title: tracks[index].title,
                    subtitle: tracks[index].artists,
                    image: tracks[index].image,
                    isSelected: isResolving,
                    onPressed: () => _play(index),
                    trailing: _TrackTrailing(
                      duration: tracks[index].duration,
                      isResolving: isResolving,
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
        MeowzicPhase.done => _buildList(detail),
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

/// The right-hand end of a row: the running time, or a spinner while the track
/// is being matched.
///
/// The time is printed here and not on the search rows, where the corner was
/// given to an overflow menu instead. There is no menu to give it to here — a
/// track in a library has nowhere else to go yet — and a listing whose rows
/// show no length looks unfinished next to every other music app.
class _TrackTrailing extends StatelessWidget {
  const _TrackTrailing({required this.duration, required this.isResolving});

  final Duration duration;
  final bool isResolving;

  /// `m:ss`, and no hours: nothing in a track listing runs to an hour, and a
  /// format that budgets for one would print `0:03:41` on every row.
  String get _label {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (isResolving) {
      return const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    // Zero means Spotify did not say, and printing "0:00" would be a claim
    // about the track rather than an admission about the answer.
    if (duration <= Duration.zero) return const SizedBox.shrink();
    return Text(
      _label,
      style: context.textTheme.bodySmall?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
