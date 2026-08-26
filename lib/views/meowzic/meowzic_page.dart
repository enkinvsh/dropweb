import 'package:audio_service/audio_service.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/views/meowzic/audio.dart';
import 'package:dropweb/views/meowzic/bridge.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

/// The meowzic screen: search and library behind bottom tabs.
///
/// Built on [CommonScaffold] rather than a bare [Scaffold] so it inherits the
/// house app bar and the Lumina mesh background — a plain Scaffold renders
/// flat black and reads as a different app the moment you arrive from the
/// dashboard.
///
/// Search is served by the bridge; the library stays empty until a Spotify
/// adapter fills it. The empty states are the product's real ones, not
/// scaffolding, so they survive that arrival.
class MeowzicPage extends StatefulWidget {
  const MeowzicPage({super.key});

  @override
  State<MeowzicPage> createState() => _MeowzicPageState();
}

class _MeowzicPageState extends State<MeowzicPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => CommonScaffold(
        title: 'meowzic',
        // IndexedStack, not a swap: leaving the tab must not throw away a
        // search someone waited on.
        body: IndexedStack(
          index: _index,
          children: [
            const _SearchTab(),
            NullStatus(label: appLocalizations.meowzicLibraryEmpty),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          backgroundColor: Colors.transparent,
          destinations: [
            NavigationDestination(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                size: 24,
              ),
              label: appLocalizations.meowzicSearchTab,
            ),
            NavigationDestination(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedLibrary,
                size: 24,
              ),
              label: appLocalizations.meowzicLibraryTab,
            ),
          ],
        ),
      );
}

enum _Phase { idle, loading, done, failed }

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab();

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  final TextEditingController _controller = TextEditingController();

  _Phase _phase = _Phase.idle;
  List<MeowzicTrack> _results = const [];
  MeowzicFailure? _failure;

  /// Guards against a slow first query landing after a faster second one and
  /// overwriting it. The bridge takes seconds on a cold lookup, which is long
  /// enough for someone to retype.
  int _generation = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String raw) async {
    final query = raw.trim();
    final bridge = ref.read(meowzicBridgeProvider);
    if (query.isEmpty || bridge == null) return;

    final generation = ++_generation;
    setState(() {
      _phase = _Phase.loading;
      _failure = null;
    });

    try {
      final tracks = await searchMeowzic(bridge, query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = tracks;
        _phase = _Phase.done;
      });
    } on MeowzicException catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failure = error.failure;
        _phase = _Phase.failed;
      });
    }
  }

  /// Plays the tapped result and queues everything shown with it.
  ///
  /// The whole list goes over, not the tail from [index]: skipping backwards
  /// has to reach the results above the tapped one, which is where somebody
  /// looks first when they meant the row above.
  Future<void> _play(int index) async {
    final bridge = ref.read(meowzicBridgeProvider);
    if (bridge == null) return;
    try {
      final handler = await meowzicAudio();
      await handler.playQueue(
        [
          for (final track in _results)
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
    } catch (error, stackTrace) {
      // A tap that fails must say why. Which failure it is cannot be read off
      // the player's error code, but the tunnel answers it directly: the
      // bridge is reachable only through it.
      commonPrint.log('meowzic play failed: $error\n$stackTrace');
      if (!mounted) return;
      final connected = ref.read(runTimeProvider) != null;
      context.showNotifier(
        connected
            ? appLocalizations.meowzicBridgeError
            : appLocalizations.meowzicNeedVpn,
      );
    }
  }

  String _failureLabel(MeowzicFailure failure) => switch (failure) {
        MeowzicFailure.unreachable => appLocalizations.meowzicNeedVpn,
        MeowzicFailure.rejected => appLocalizations.meowzicAccessRejected,
        MeowzicFailure.upstream => appLocalizations.meowzicBridgeError,
      };

  /// The results, with whichever row is currently loaded marked.
  ///
  /// The handler is observed through the notifier rather than by calling
  /// `meowzicAudio()`, which would spin up the media service for anyone who
  /// merely searched. `MediaItem.id` is the video id, so it compares directly
  /// against the track.
  Widget _buildResults() => ValueListenableBuilder<MeowzicAudioHandler?>(
        valueListenable: meowzicHandlerListenable,
        builder: (context, handler, _) => handler == null
            ? _buildList(null)
            : StreamBuilder<MediaItem?>(
                stream: handler.mediaItem,
                builder: (context, snapshot) => _buildList(snapshot.data?.id),
              ),
      );

  Widget _buildList(String? playingId) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) => _TrackRow(
          track: _results[index],
          isPlaying: _results[index].id == playingId,
          onPressed: () => _play(index),
        ),
      );

  Widget _buildBody() => switch (_phase) {
        _Phase.idle => NullStatus(label: appLocalizations.meowzicSearchEmpty),
        _Phase.loading => const Center(child: CircularProgressIndicator()),
        _Phase.failed =>
          NullStatus(label: _failureLabel(_failure ?? MeowzicFailure.upstream)),
        _Phase.done when _results.isEmpty =>
          NullStatus(label: appLocalizations.meowzicSearchNothing),
        _Phase.done => _buildResults(),
      };

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: appLocalizations.meowzicSearchHint,
                prefixIcon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  size: 20,
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Lumina.radiusLg),
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      );
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.isPlaying,
    required this.onPressed,
  });

  final MeowzicTrack track;

  /// Whether this is the row the handler currently has loaded. Marked with the
  /// card's own selected border and a tinted title rather than a new treatment
  /// invented for this list.
  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CommonCard(
        isSelected: isPlaying,
        onPressed: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _Cover(art: track.thumbnail),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      track.title,
                      style: context.textTheme.titleSmall?.copyWith(
                        color: isPlaying
                            ? context.colorScheme.primary
                            : context.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (track.author.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        track.author,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (track.duration > Duration.zero) ...[
                const SizedBox(width: 12),
                Text(
                  _formatDuration(track.duration),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

/// Square cover with the same note glyph fallback the dashboard strip uses:
/// art comes from YouTube's CDN, so it stays blank whenever the tunnel is
/// down, and a broken image must not break the row.
class _Cover extends StatelessWidget {
  const _Cover({this.art});

  final Uri? art;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedMusicNote01,
        size: 22,
        color: context.colorScheme.primary,
      ),
    );
    final source = art;
    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colorScheme.primary.opacity10,
        borderRadius: BorderRadius.circular(Lumina.radiusMd),
      ),
      child: source == null
          ? fallback
          : Image.network(
              source.toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

String _formatDuration(Duration value) {
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${value.inMinutes}:$seconds';
}
