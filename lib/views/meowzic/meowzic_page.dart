import 'package:audio_service/audio_service.dart';
import 'package:dropweb/common/common.dart';
// Narrowed on purpose: the models barrel and `audio_service` both carry names
// this file already uses, and the menu needs exactly one type out of it.
import 'package:dropweb/models/models.dart' show PopupMenuItemData;
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/views/meowzic/art_wash.dart';
import 'package:dropweb/views/meowzic/audio.dart';
import 'package:dropweb/views/meowzic/bridge.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

/// The meowzic screen: search and library behind tabs at the top.
///
/// The tabs sit above the content and are the same [GlassTabBar] the
/// subscription page uses, so arriving here from the dashboard lands on chrome
/// that is already familiar rather than on a bar at the bottom this app uses
/// nowhere else.
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

class _MeowzicPageState extends State<MeowzicPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CommonScaffold(
        title: 'meowzic',
        actions: [
          // Dimmed and unpressable on purpose — not a stub waiting to be
          // wired. There are no meowzic settings yet, and a gear that opens
          // nothing is worse than one that plainly reads as not ready. It is
          // drawn now so the slot is settled and the header does not
          // rearrange itself the day settings arrive; the strip on the
          // dashboard makes the same call with its skip arrows when there is
          // nowhere to skip to.
          //
          // A [HugeIcon] rather than an SVG: the project carries no .svg
          // assets and no flutter_svg, and every glyph in the app comes from
          // this set. Pulling in a renderer for one gear would put this
          // header on a different footing from every other one.
          IconButton(
            onPressed: null,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedSettings02,
              size: 24,
              color: context.colorScheme.onSurface.opacity38,
            ),
          ),
          const SizedBox(width: 8),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassTabBar(
                controller: _tabController,
                tabs: [
                  appLocalizations.meowzicSearchTab,
                  appLocalizations.meowzicLibraryTab,
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              // A swap, not an IndexedStack: TabBarView does dispose the
              // off-screen child, and that is safe here for one specific
              // reason. The query, the results and the queue live in
              // `meowzicSearchProvider`, not in _SearchTabState — the State
              // only holds a TextEditingController, and that re-seeds itself
              // from `ref.read(meowzicSearchProvider).query` on every mount.
              // Leaving the tab therefore throws away nothing anyone waited
              // on. Do not "fix" this back to an IndexedStack.
              child: TabBarView(
                controller: _tabController,
                children: [
                  const _SearchTab(),
                  NullStatus(label: appLocalizations.meowzicLibraryEmpty),
                ],
              ),
            ),
          ],
        ),
      );
}

/// How deep the results dissolve into the background at the bottom edge.
const _listFade = 40.0;

/// Bottom padding of the results list.
///
/// Deliberately clear of [_listFade] on both counts: the final card has to
/// come to rest above the fade rather than inside it, and it should not be
/// crowded against the gesture bar once it gets there.
const _listBottomPadding = 56.0;

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab();

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  /// Seeded from the notifier, because this State is built fresh every time
  /// the route is pushed and an empty box over a full list reads as a bug.
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(meowzicSearchProvider).query,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Shows why a tap could not play, when the notifier says it could not.
  ///
  /// The reason is decided there — it needs the tunnel, not a widget — and
  /// shown here, because a `BuildContext` is the one thing a notifier has no
  /// business holding.
  Future<void> _play(int index) async {
    final message = await ref.read(meowzicSearchProvider.notifier).play(index);
    if (!mounted || message == null) return;
    context.showNotifier(message);
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
  Widget _buildResults(List<MeowzicTrack> results) =>
      ValueListenableBuilder<MeowzicAudioHandler?>(
        valueListenable: meowzicHandlerListenable,
        builder: (context, handler, _) => handler == null
            ? _buildList(results, null)
            : StreamBuilder<MediaItem?>(
                stream: handler.mediaItem,
                builder: (context, snapshot) =>
                    _buildList(results, snapshot.data?.id),
              ),
      );

  /// The results, dissolved where they meet the bottom of the viewport.
  ///
  /// A bare [ListView] guillotines whichever row the bottom edge lands on. On
  /// a flat list that reads as scrolling; on these cards it reads as a
  /// rendering fault, because a squircle carrying cover art suddenly ends in a
  /// straight line with the gesture pill sitting on top of it.
  ///
  /// Masked, not scrimmed. The mesh behind the list is a live gradient, so a
  /// fade painted down to [Lumina.void_] would sit on it as a dark band;
  /// taking the alpha down instead lets the mesh through untouched. That is
  /// the same call [MeowzicArtWash] makes horizontally, for the same reason.
  ///
  /// [_listFade] is a count of logical pixels turned into a stop against the
  /// measured viewport, so the fade stays the same physical depth on a tall
  /// phone and a short one. [_listBottomPadding] is deliberately larger: at
  /// full scroll the fade has to be lying on empty padding, or the last card
  /// would come to rest half transparent — which would be a worse bug than
  /// the one this fixes.
  Widget _buildList(List<MeowzicTrack> results, String? playingId) =>
      LayoutBuilder(
        builder: (context, constraints) {
          // A viewport too short to hold the fade and something to read would
          // be all fade; leave those alone rather than dim the whole list.
          final fade = constraints.maxHeight <= _listFade * 3
              ? 0.0
              : _listFade / constraints.maxHeight;
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 1 - fade, 1.0],
            ).createShader(rect),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, _listBottomPadding),
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) => _TrackRow(
                track: results[index],
                isPlaying: results[index].id == playingId,
                onPressed: () => _play(index),
              ),
            ),
          );
        },
      );

  Widget _buildBody(MeowzicSearchState search) => switch (search.phase) {
        MeowzicPhase.idle =>
          NullStatus(label: appLocalizations.meowzicSearchEmpty),
        MeowzicPhase.loading => const Center(child: CircularProgressIndicator()),
        MeowzicPhase.failed => NullStatus(
            label: _failureLabel(search.failure ?? MeowzicFailure.upstream),
          ),
        MeowzicPhase.done when search.results.isEmpty =>
          NullStatus(label: appLocalizations.meowzicSearchNothing),
        MeowzicPhase.done => _buildResults(search.results),
      };

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(meowzicSearchProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            // Autocorrect off, and this box in particular. What gets typed
            // here is artist and track names — "yung", "Bladee", "GENER8ION",
            // half of them deliberate misspellings — and every dictionary on
            // the phone reads those as typos and rewrites them ("yung" ->
            // "young"). The rewrite is applied as the field is committed, so
            // the query that reaches the bridge is not the one that was typed,
            // and the keyboard's own swipe-up-to-restore gesture has nothing
            // left to restore by then.
            //
            // Suggestions stay ON: offering a completion someone can tap is
            // help, substituting the word behind their back is not.
            autocorrect: false,
            onSubmitted: ref.read(meowzicSearchProvider.notifier).search,
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
        Expanded(child: _buildBody(search)),
      ],
    );
  }
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
  Widget build(BuildContext context) => SizedBox(
        height: getWidgetHeight(1),
        child: CommonCard(
          radius: Lumina.radiusLg,
          isSelected: isPlaying,
          onPressed: onPressed,
          // No ClipRRect here and none is needed — CommonCard is an
          // `OutlinedButton` with `clipBehavior: Clip.antiAlias` and a
          // `RoundedSuperellipseBorder` (lib/widgets/card.dart), so the wash is
          // already clipped to the card's squircle. Adding a clip of our own
          // would only cost a second saveLayer and round the art to the wrong
          // curve.
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (track.thumbnail case final uri?) MeowzicArtWash(uri: uri),
              // 8 on the right, matching the dashboard strip: the row ends in
              // an IconButton, and its own tap padding around the glyph is
              // what carries the rest of the way to an optical 16.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
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
                    const SizedBox(width: 8),
                    _TrackMenu(onListen: onPressed),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// The row's overflow menu — the same [CommonPopupBox] the profile cards use,
/// down to the glyph, so a long-press-shaped habit learned on one screen keeps
/// working on the other.
///
/// It stands where the running time used to. The time was read-only trivia on
/// a row you can already only do one thing with; the corner is worth more as
/// the way into the things a track is attached to.
///
/// Only "listen" is offered today, and that is the honest whole of it: artist
/// and playlist entries belong here, and they land when there are screens to
/// send them to — the library tab is still waiting on Spotify. An item that
/// opened nothing would be worse than a short menu. The duplication with the
/// row tap is deliberate: a menu that can be opened has to be able to do
/// something, and this is the one thing that works.
class _TrackMenu extends StatelessWidget {
  const _TrackMenu({required this.onListen});

  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) => CommonPopupBox(
        popup: CommonPopupMenu(
          items: [
            PopupMenuItemData(
              label: appLocalizations.listen,
              onPressed: onListen,
            ),
          ],
        ),
        targetBuilder: (open) => IconButton(
          onPressed: open,
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedMoreVertical,
            size: 24,
          ),
        ),
      );
}
