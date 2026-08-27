import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/views/meowzic/audio.dart';
import 'package:dropweb/views/meowzic/bridge.dart';
import 'package:dropweb/views/meowzic/faded_list.dart';
import 'package:dropweb/views/meowzic/library_tab.dart';
import 'package:dropweb/views/meowzic/phase.dart';
import 'package:dropweb/views/meowzic/spotify/account_sheet.dart';
import 'package:dropweb/views/meowzic/spotify/cover_tile.dart';
import 'package:dropweb/views/meowzic/spotify/detail_page.dart';
import 'package:dropweb/views/meowzic/spotify/gql.dart';
import 'package:dropweb/views/meowzic/spotify/library.dart';
import 'package:dropweb/views/meowzic/spotify/login_webview.dart';
import 'package:dropweb/views/meowzic/spotify/session.dart';
import 'package:dropweb/views/meowzic/spotify/track_list.dart';
import 'package:dropweb/views/meowzic/track_row.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

/// The height of the controls that sit directly under the tab bar.
///
/// [GlassTabBar] is 48, and the search box under it was not — `isDense` left it
/// visibly shorter, so the two never read as the same row of chrome. Anything
/// that lands in that slot uses this.
const _chromeHeight = 48.0;

/// The gap under that slot, before the content starts.
///
/// One value for both tabs. They had 16 and 8, which is why moving between
/// Поиск and Библиотека looked like the whole screen shifted.
const _chromeGap = 12.0;

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
/// Search is served by the bridge; the library tab is where Spotify is linked
/// and unlinked. Linking is the whole of it today — the account is proved and
/// named, and nothing is browsed yet — so the tab still spends most of its
/// life as an empty state. Those states are the product's real ones, not
/// scaffolding.
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
        actions: const [
          _MeowzicSettingsButton(),
          SizedBox(width: 8),
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
                children: const [
                  _SearchTab(),
                  _LibraryTab(),
                ],
              ),
            ),
          ],
        ),
      );
}

/// The header's gear — meowzic's settings, which today are the linked account.
///
/// It used to be dimmed and unpressable, with a note saying a gear that opens
/// nothing is worse than one that plainly reads as not ready. That note is now
/// obsolete: there IS something behind it. The account moved here out of the
/// Library tab, where it sat above the covers repeating a fact that is read
/// once — settings is where a thing you change twice a year belongs.
///
/// Still dimmed while signed out, and for the original reason rather than as a
/// leftover: with no account linked the sheet would have nothing in it, and the
/// Library tab is already carrying the sign-in prompt.
///
/// A [HugeIcon] rather than an SVG: the project carries no .svg assets and no
/// flutter_svg, and every glyph in the app comes from this set. Pulling in a
/// renderer for one gear would put this header on a different footing from
/// every other one.
class _MeowzicSettingsButton extends ConsumerWidget {
  const _MeowzicSettingsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn =
        ref.watch(spotifyAuthProvider).phase == SpotifyPhase.signedIn;
    return IconButton(
      onPressed: signedIn ? () => showSpotifyAccount(context) : null,
      icon: HugeIcon(
        icon: HugeIcons.strokeRoundedSettings02,
        size: 24,
        color: signedIn
            ? context.colorScheme.onSurface
            : context.colorScheme.onSurface.opacity38,
      ),
    );
  }
}

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab();

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  /// Seeded from whichever notifier is serving this tab, because this State is
  /// built fresh every time the route is pushed and an empty box over a full
  /// list reads as a bug.
  ///
  /// Read once, on mount, rather than watched: the box holds what somebody
  /// typed, and rewriting it under them because a token was refreshed in the
  /// background would be the autocorrect problem this field already refuses.
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _isSpotify
          ? ref.read(spotifySearchProvider).query
          : ref.read(meowzicSearchProvider).query,
    );
  }

  /// Whether this tab is searching Spotify rather than the bridge.
  ///
  /// The one question that decides the source, and it is asked of the same
  /// provider the settings gear and the library tab ask — there is exactly one
  /// notion of "signed in" in this screen, and a second one invented here would
  /// be able to disagree with the account sheet about whether an account is
  /// linked.
  bool get _isSpotify =>
      ref.read(spotifyAuthProvider).phase == SpotifyPhase.signedIn;

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

  /// The results, dissolved where they meet the bottom of the viewport by the
  /// shared [MeowzicFade] — which is where the reasoning for that fade now
  /// lives, because the container screen needs the identical treatment and had
  /// a pasted copy of it.
  Widget _buildList(List<MeowzicTrack> results, String? playingId) =>
      MeowzicFade(
        child: ListView.separated(
          padding: meowzicListPadding,
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) => MeowzicTrackRow(
            title: results[index].title,
            subtitle: results[index].author,
            image: results[index].thumbnail,
            isSelected: results[index].id == playingId,
            onPressed: () => _play(index),
            // The row ends in an IconButton, which reserves its own tap
            // padding — see [MeowzicTrackRow.trailingPadsItself].
            trailingPadsItself: true,
            trailing: MeowzicTrackMenu(onListen: () => _play(index)),
          ),
        ),
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
    // Watched, not read: linking an account while standing on this tab has to
    // move the source under the box on the next frame, not on the next push of
    // the route.
    final signedIn =
        ref.watch(spotifyAuthProvider).phase == SpotifyPhase.signedIn;
    return Column(
      children: [
        Padding(
          // Top zero: the gap under the tab bar is the one the parent already
          // sets for both tabs. Adding another 8 here is what made arriving at
          // Поиск and arriving at Библиотека look different — one sat 16 below
          // the bar, the other 8.
          padding: const EdgeInsets.fromLTRB(16, 0, 16, _chromeGap),
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
            // Routed by authorisation, and this is the whole of change (A):
            // once an account is linked the bridge stops being asked what the
            // listener meant. It stays the source of sound — a Spotify hit is
            // played by ISRC through it — but a video catalogue has no notion
            // of "the track", and a measured `ytsearch10` answered one ordinary
            // query with six wrong recordings out of ten. Nobody who never
            // links Spotify loses anything: they keep the branch below,
            // unchanged.
            onSubmitted: signedIn
                ? ref.read(spotifySearchProvider.notifier).search
                : ref.read(meowzicSearchProvider.notifier).search,
            decoration: InputDecoration(
              hintText: appLocalizations.meowzicSearchHint,
              prefixIcon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                size: 20,
              ),
              // Pinned to the tab bar's own height instead of `isDense`, which
              // is what left this box visibly shorter than the bar it sits
              // under. The padding does the centring; the constraint does the
              // height.
              isDense: true,
              constraints: const BoxConstraints(
                minHeight: _chromeHeight,
                maxHeight: _chromeHeight,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Lumina.radiusLg),
              ),
            ),
          ),
        ),
        Expanded(
          child: signedIn
              ? const _SpotifySearchResults()
              : _buildBody(ref.watch(meowzicSearchProvider)),
        ),
      ],
    );
  }
}

/// What a Spotify search found.
///
/// A widget of its own rather than a branch inside [_SearchTab] so that the
/// bridge state is not watched at all while an account is linked — the two
/// sources have nothing to say to each other, and a tab that rebuilt on both
/// would be rebuilding on a notifier it is not showing.
///
/// The rows are [SpotifyTrackList], which is the container screen's own list:
/// same card, same menu with «Радио по треку» on it, same no-duration corner,
/// same marking of the row that is playing. A search hit and a playlist row are
/// the same object once both have a Spotify uri, and drawing them differently
/// would be inventing a distinction the listener cannot act on.
class _SpotifySearchResults extends ConsumerWidget {
  const _SpotifySearchResults();

  /// Shows why a tap could not play, when the notifier says it could not.
  ///
  /// The reason is decided there — it needs the tunnel, not a widget — and
  /// shown here, because a `BuildContext` is the one thing a notifier has no
  /// business holding. The same split every other meowzic surface keeps.
  Future<void> _play(BuildContext context, WidgetRef ref, int index) async {
    final message = await ref.read(spotifySearchProvider.notifier).play(index);
    if (!context.mounted || message == null) return;
    unawaited(context.showNotifier(message));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(spotifySearchProvider);
    return switch (search.phase) {
      MeowzicPhase.idle =>
        NullStatus(label: appLocalizations.meowzicSearchEmpty),
      MeowzicPhase.loading => const Center(child: CircularProgressIndicator()),
      MeowzicPhase.failed => NullStatus(
          label: spotifyGqlFailureLabel(
            search.failure ?? SpotifyGqlFailure.upstream,
          ),
        ),
      MeowzicPhase.done when search.results.isEmpty =>
        NullStatus(label: appLocalizations.meowzicSearchNothing),
      MeowzicPhase.done => SpotifyTrackList(
          tracks: search.results,
          loadingMore: search.loadingMore,
          onPlay: (index) => _play(context, ref, index),
          // Paging, which the bridge could not offer at all: its `/s` endpoint
          // has no cursor and a hard ceiling of twenty rows. Spotify's search
          // takes an offset, so the list simply keeps going.
          onLoadMore: () =>
              unawaited(ref.read(spotifySearchProvider.notifier).fetchMore()),
        ),
    };
  }
}

/// The library tab: link a Spotify account, then browse what it holds.
///
/// Browsing only. Tiles are not pressable and there is no menu on them — the
/// screens they would open do not exist yet, and a tile that swallows a tap is
/// worse than one that plainly does not take them. They become pressable when
/// there is somewhere to go.
class _LibraryTab extends ConsumerWidget {
  const _LibraryTab();

  /// Opens Spotify's own login page and hands what it yields to the notifier.
  ///
  /// The webview is opened here rather than by the notifier because it needs a
  /// `BuildContext`, which is the screen's to hold — the same division the
  /// search tab already keeps when it shows a failure the notifier decided.
  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final cookies = await showSpotifyLogin(context);
    // Null means the back button. Nothing is reported and nothing changes:
    // backing out of a login is not a failed login.
    if (cookies == null) return;
    await ref.read(spotifyAuthProvider.notifier).signIn(cookies);
  }

  String _failureLabel(SpotifyAuthFailure failure) => switch (failure) {
        SpotifyAuthFailure.unreachable =>
          appLocalizations.meowzicSpotifyUnreachable,
        SpotifyAuthFailure.cookieExpired =>
          appLocalizations.meowzicSpotifyCookieExpired,
        SpotifyAuthFailure.anonymous =>
          appLocalizations.meowzicSpotifyAnonymous,
        SpotifyAuthFailure.upstream => appLocalizations.meowzicSpotifyUpstream,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(spotifyAuthProvider);
    // The signed-in branch is pulled out of the centred column rather than
    // added to it: a grid has to own the full height of the tab, and a [Center]
    // above it would shrink-wrap the whole library into the middle of the
    // screen. Everything else here is one sentence and a button, which is
    // exactly what a Center is for.
    if (auth.phase == SpotifyPhase.signedIn) return const _SpotifyLibraryView();
    return Padding(
      // Matching the results list, so the two tabs do not shift their content
      // sideways as you swipe between them.
      padding: meowzicListPadding,
      child: Center(
        child: switch (auth.phase) {
          SpotifyPhase.working => const CircularProgressIndicator(),
          SpotifyPhase.failed => _SpotifyPrompt(
              label: _failureLabel(
                auth.failure ?? SpotifyAuthFailure.upstream,
              ),
              action: appLocalizations.meowzicSpotifyRetry,
              onPressed: () => _signIn(context, ref),
            ),
          // Unreachable — handled above — but named rather than defaulted, so
          // the day a fifth phase is added the compiler asks about it here.
          SpotifyPhase.signedIn => const SizedBox.shrink(),
          SpotifyPhase.signedOut => _SpotifyPrompt(
              label: appLocalizations.meowzicLibraryEmpty,
              action: appLocalizations.meowzicSpotifySignIn,
              onPressed: () => _signIn(context, ref),
            ),
        },
      ),
    );
  }
}

/// The library's tabs and whatever is under them.
///
/// The account row that used to sit on top has moved behind the header's gear:
/// "kinvsh — отвязать" is a setting, and it was occupying the first band of a
/// screen whose subject is covers. Nothing here replaced it, deliberately —
/// the tab is the library now.
///
/// Stateless, and each band under the chips fetches its own. Nothing here is
/// held: the chosen tab lives in `spotifyLibrarySelectionProvider`, the items
/// behind each filter in `spotifyLibraryProvider`, which is why swiping to
/// search and back does not refetch.
class _SpotifyLibraryView extends ConsumerWidget {
  const _SpotifyLibraryView();

  /// Switches to [tab] and makes sure it has something in it.
  ///
  /// Two calls rather than one because they answer two different questions:
  /// which chip is lit, and whether that filter has ever been fetched. The
  /// second is a no-op for a filter that is already loaded, which is what makes
  /// going back to Playlists after a look at Albums instant instead of another
  /// trip through the tunnel.
  ///
  /// A filter that previously failed is the exception: there the tap is the
  /// only retry the screen offers, so it reloads rather than sitting on the
  /// failure.
  void _select(WidgetRef ref, MeowzicLibraryTab tab) {
    ref.read(spotifyLibrarySelectionProvider.notifier).select(tab);
    final filter = tab.filter;
    // Сохранённые is not a filter of the library and is not fetched like one:
    // it has its own notifier over its own document. Routed here rather than
    // returning early, so that tapping its chip retries a failure exactly the
    // way tapping any other chip does.
    if (filter == null) {
      final saved = ref.read(spotifySavedTracksProvider.notifier);
      unawaited(
        ref.read(spotifySavedTracksProvider).phase == MeowzicPhase.failed
            ? saved.reload()
            : saved.ensureLoaded(),
      );
      return;
    }
    final notifier = ref.read(spotifyLibraryProvider(filter).notifier);
    unawaited(
      ref.read(spotifyLibraryProvider(filter)).phase == MeowzicPhase.failed
          ? notifier.reload()
          : notifier.ensureLoaded(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(spotifyLibrarySelectionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LibraryFilters(
          selected: tab,
          onSelected: (selected) => _select(ref, selected),
        ),
        Expanded(
          // Keyed by the filter so switching chips remounts the grid and its
          // `initState` asks for the new one. Without the key Flutter reuses
          // the State — same widget type, same position — and the second filter
          // would render whatever the first had fetched.
          child: switch (tab.filter) {
            final filter? => _LibraryGrid(key: ValueKey(filter), filter: filter),
            null => const _SavedTracksTab(),
          },
        ),
      ],
    );
  }
}

/// One filter's covers.
///
/// Stateful only to kick the first fetch. The notifier cannot start it from its
/// own `build` — that runs while the widget tree is building, and assigning
/// state there throws — so the grid asks once on mount and the notifier ignores
/// every later ask.
class _LibraryGrid extends ConsumerStatefulWidget {
  const _LibraryGrid({super.key, required this.filter});

  final SpotifyLibraryFilter filter;

  @override
  ConsumerState<_LibraryGrid> createState() => _LibraryGridState();
}

class _LibraryGridState extends ConsumerState<_LibraryGrid> {
  late final _provider = spotifyLibraryProvider(widget.filter);

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(_provider.notifier).ensureLoaded());
  }

  /// Asks for the next page as the grid comes to rest near its end.
  ///
  /// Hung off the scroll notification rather than off "the last tile was
  /// built", which is the other common way to do this and is wrong here: an
  /// item builder runs during layout, and starting a fetch from there mutates
  /// provider state in the middle of a frame. [ScrollEndNotification] arrives
  /// between frames, and waiting for the scroll to settle also means a fast
  /// flick through a long library fires one request instead of several.
  bool _onScrollEnd(ScrollEndNotification notification) {
    if (notification.metrics.extentAfter < meowzicLoadMoreThreshold) {
      unawaited(ref.read(_provider.notifier).loadMore());
    }
    return false;
  }

  Widget _buildGrid(SpotifyLibraryState library) =>
      NotificationListener<ScrollEndNotification>(
        onNotification: _onScrollEnd,
        // Faded at the bottom like the track lists are. A grid of squircles
        // guillotined on a straight line reads as the same rendering fault a
        // guillotined card does.
        child: MeowzicFade(
          child: GridView.builder(
            padding: meowzicListPadding,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              // Taller than square: the tile is a square cover with two lines
              // under it, and a ratio that only budgets for the cover pushes
              // the second line out of the card on the first long title.
              childAspectRatio: 0.72,
            ),
            itemCount: library.items.length,
            itemBuilder: (context, index) {
              final item = library.items[index];
              return SpotifyCoverTile(
                item: item,
                // Pushed from here rather than from inside the tile, because
                // opening a route needs the `BuildContext` of something that
                // is still mounted after the push — the same reason the
                // sign-in webview is opened by the tab and not by the notifier.
                onPressed: () => unawaited(
                  BaseNavigator.push<void>(
                    context,
                    SpotifyDetailPage(item: item),
                  ),
                ),
              );
            },
          ),
        ),
      );

  Widget _buildBody(SpotifyLibraryState library) => switch (library.phase) {
        MeowzicPhase.idle ||
        MeowzicPhase.loading =>
          const Center(child: CircularProgressIndicator()),
        MeowzicPhase.failed => NullStatus(
            label: spotifyGqlFailureLabel(
              library.failure ?? SpotifyGqlFailure.upstream,
            ),
          ),
        MeowzicPhase.done when library.items.isEmpty =>
          NullStatus(label: appLocalizations.meowzicLibraryNothing),
        MeowzicPhase.done => _buildGrid(library),
      };

  @override
  Widget build(BuildContext context) => _buildBody(ref.watch(_provider));
}

/// «Сохранённые» — the account's liked tracks, listed here rather than behind a
/// tile.
///
/// It is the first tab because it is the thing a listener reaches for first,
/// and it is a list rather than a cover because there is exactly one of them:
/// a grid holding a single square that opens another screen is two taps and a
/// push to reach rows this tab can simply draw.
///
/// It depends on nothing else on this screen, and that independence is the
/// whole of the fix that produced this version. It used to load the Плейлисты
/// filter first, hunt through it for a row whose kind is `likedSongs`, and open
/// that row's uri as a container — on the reasoning that the uri must come from
/// the server rather than from a literal. The reasoning was sound and the
/// premise was false: measured on a live account, `libraryV3` with the
/// Playlists filter answers with real playlists and no Liked Songs tile at all.
/// The hunt found nothing and the tab shipped reading «Здесь пока пусто» over a
/// full saved list.
///
/// Saved tracks have their own document, addressed by the session rather than
/// by a uri, and [SpotifySavedTracks] is the whole of what this tab watches.
/// Nothing here may be made to wait on a library page again.
class _SavedTracksTab extends ConsumerStatefulWidget {
  const _SavedTracksTab();

  @override
  ConsumerState<_SavedTracksTab> createState() => _SavedTracksTabState();
}

class _SavedTracksTabState extends ConsumerState<_SavedTracksTab> {
  @override
  void initState() {
    super.initState();
    // On mount rather than in `build`: a notifier may not assign state while
    // the tree is building. `ensureLoaded` yields a turn of its own before it
    // touches anything, which is what makes this call site safe, and it is a
    // no-op once the listing has been fetched — so swiping away to Поиск and
    // back costs nothing.
    unawaited(ref.read(spotifySavedTracksProvider.notifier).ensureLoaded());
  }

  /// Shows why a tap could not play, when the notifier says it could not.
  Future<void> _play(int index) async {
    final message =
        await ref.read(spotifySavedTracksProvider.notifier).play(index);
    if (!mounted || message == null) return;
    unawaited(context.showNotifier(message));
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(spotifySavedTracksProvider);
    return switch (saved.phase) {
      MeowzicPhase.idle ||
      MeowzicPhase.loading =>
        const Center(child: CircularProgressIndicator()),
      MeowzicPhase.failed => NullStatus(
          label: spotifyGqlFailureLabel(
            saved.failure ?? SpotifyGqlFailure.upstream,
          ),
        ),
      // An account that has genuinely saved nothing. It is now the ONLY way
      // this tab draws an empty state — a fetch that could not be made says so
      // in the failed branch above, and a protocol change is reported as a
      // failure by the fetcher rather than parsed into silence.
      MeowzicPhase.done when saved.tracks.isEmpty =>
        NullStatus(label: appLocalizations.meowzicContainerEmpty),
      MeowzicPhase.done => SpotifyTrackList(
          tracks: saved.tracks,
          loadingMore: saved.loadingMore,
          onPlay: _play,
          onLoadMore: () => unawaited(
            ref.read(spotifySavedTracksProvider.notifier).fetchMore(),
          ),
        ),
    };
  }
}

/// The library's tabs, as chips.
///
/// The chosen one is drawn with an accent border — [CommonChip.isSelected] —
/// and that is the whole of it. It used to be marked with a tick in the avatar
/// slot, because the atom had no selected state and the slot was there; the
/// tick was the only one in the app and read as borrowed from somewhere else.
/// Giving the atom the state it was missing was the smaller fix, and it keeps
/// the chips the same width whether chosen or not, so the row does not reflow
/// under the thumb.
class _LibraryFilters extends StatelessWidget {
  const _LibraryFilters({required this.selected, required this.onSelected});

  final MeowzicLibraryTab selected;
  final void Function(MeowzicLibraryTab) onSelected;

  String _label(MeowzicLibraryTab tab) => switch (tab) {
        MeowzicLibraryTab.saved => appLocalizations.meowzicLibrarySaved,
        MeowzicLibraryTab.playlists =>
          appLocalizations.meowzicLibraryPlaylists,
        MeowzicLibraryTab.albums => appLocalizations.meowzicLibraryAlbums,
        MeowzicLibraryTab.artists => appLocalizations.meowzicLibraryArtists,
      };

  @override
  Widget build(BuildContext context) => Padding(
        // The same gap the search box leaves, from the same constant, so the
        // content does not start at a different height depending on which tab
        // you are on.
        padding: const EdgeInsets.fromLTRB(16, 0, 16, _chromeGap),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tab in MeowzicLibraryTab.values)
              CommonChip(
                label: _label(tab),
                // The house corner. Material's chip default is 8, which reads
                // as a different app directly under a tab bar drawn at 26.
                radius: Lumina.radiusLg,
                isSelected: tab == selected,
                onPressed: () => onSelected(tab),
              ),
          ],
        ),
      );
}

/// An explanation with one thing to do about it.
///
/// [NullStatus] carries the sentence and nothing else, which is right for the
/// search tab — there is nothing to press there — and wrong here, where the
/// sentence exists to be answered. Its typography is reused rather than
/// re-invented so the two tabs read as one screen.
class _SpotifyPrompt extends StatelessWidget {
  const _SpotifyPrompt({
    required this.label,
    required this.action,
    required this.onPressed,
  });

  final String label;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NullStatus(label: label),
          const SizedBox(height: 24),
          FilledButton(onPressed: onPressed, child: Text(action)),
        ],
      );
}
