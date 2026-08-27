import 'dart:async';

import 'package:dropweb/providers/spotify.dart';
import 'package:dropweb/views/meowzic/phase.dart';
import 'package:dropweb/views/meowzic/spotify/gql.dart';
import 'package:dropweb/views/meowzic/spotify/library.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/spotify_library.g.dart';

/// One filter's whole visible state.
///
/// Immutable and replaced wholesale rather than patched, the same call
/// [SpotifyAuthState] and `MeowzicSearchState` make: every transition names
/// every field it means, which is cheaper to read than a `copyWith` that has to
/// say whether it is keeping or clearing the failure.
class SpotifyLibraryState {
  const SpotifyLibraryState({
    this.phase = MeowzicPhase.idle,
    this.items = const [],
    this.totalCount = 0,
    this.loadingMore = false,
    this.failure,
  });

  final MeowzicPhase phase;
  final List<SpotifyLibraryItem> items;

  /// What the filter holds in total, so the grid knows whether asking again
  /// would return anything.
  final int totalCount;

  /// A page is being appended to a list that is already on screen. Separate
  /// from [phase] on purpose: a spinner replacing the grid every time somebody
  /// scrolls to the bottom would be a worse experience than the one this
  /// exists to provide.
  final bool loadingMore;
  final SpotifyGqlFailure? failure;

  /// Whether there is more to fetch. Driven off [totalCount] rather than off
  /// "the last page came back short", because a page legitimately comes back
  /// short when unparseable rows are dropped — see [SpotifyLibraryPage].
  bool get hasMore => items.length < totalCount;
}

/// Which filter the grid is showing.
///
/// Held in a provider rather than in the tab's `State` because the tab does not
/// survive: it lives inside a `TabBarView`, which disposes the off-screen
/// child, so a selection kept in the widget would reset to Playlists every time
/// somebody swiped to search and back. It is deliberately the ONLY thing the
/// selection owns — the items behind each filter live in
/// [SpotifyLibrary], one instance per filter.
@Riverpod(keepAlive: true)
class SpotifyLibrarySelection extends _$SpotifyLibrarySelection {
  @override
  SpotifyLibraryFilter build() {
    // Back to the first filter when the account goes, so the next person to
    // link one does not arrive on a tab labelled Artists that was chosen by
    // somebody else.
    ref.listen(spotifyAuthProvider, (_, next) {
      if (next.phase == SpotifyPhase.signedOut) {
        state = SpotifyLibraryFilter.playlists;
      }
    });
    return SpotifyLibraryFilter.playlists;
  }

  /// Re-selecting the filter that is already showing is swallowed rather than
  /// re-published: it is the tap somebody makes by accident while scrolling,
  /// and answering it by notifying every listener would rebuild the grid for
  /// nothing.
  void select(SpotifyLibraryFilter filter) {
    if (filter == state) return;
    state = filter;
  }
}

/// One library filter's items, held above the route.
///
/// The filter is the family key, and that IS the cache. Before this there was
/// one notifier holding whichever filter was last asked for, so Плейлисты →
/// Альбомы → Плейлисты was three trips through the tunnel to show two answers
/// the app had already had — which is precisely the lag the owner reported.
/// Keyed, each filter keeps its own answer alive and switching back is a
/// rebuild rather than a fetch.
///
/// No TTL, no eviction, no store. Three filters per account, each a page of
/// names and cover URLs; a cache that needs a policy is a cache that is holding
/// something big enough to matter, and this is not. It is the same shape
/// Spotube's metadata layer uses for the same reason.
///
/// keepAlive for the reason `MeowzicSearch` and `SpotifyAuth` have it as well:
/// the meowzic page is pushed as a route, so anything kept in the tab's `State`
/// is rebuilt on every open.
///
/// In memory only. Surviving an app restart would need a table and is a
/// separate decision; surviving navigation is this one.
@Riverpod(keepAlive: true)
class SpotifyLibrary extends _$SpotifyLibrary {
  /// Guards against a slow page landing after a newer one and overwriting it.
  /// Scoped to this filter now that each has its own instance, so what it
  /// actually catches is a first page and a sign-out racing, or two `loadMore`
  /// calls that a fast scroll let through.
  int _generation = 0;

  @override
  SpotifyLibraryState build(SpotifyLibraryFilter filter) {
    // Listened to rather than watched. `watch` would rebuild this notifier and
    // throw the loaded pages away on any auth change at all — including the
    // display name arriving a moment after sign-in, which changes nothing here.
    ref.listen(spotifyAuthProvider, _onAuthChanged);
    return const SpotifyLibraryState();
  }

  void _onAuthChanged(SpotifyAuthState? _, SpotifyAuthState next) {
    if (next.phase == SpotifyPhase.signedOut) {
      // Emptied, not left to go stale. Somebody who unlinks and hands the phone
      // over must not find the previous account's playlists sitting behind the
      // sign-in prompt, and somebody who links a second account must not see
      // the first one's library until the fetch happens to finish. Every live
      // filter empties itself; there is no central list of them to walk, and
      // there does not need to be.
      _generation++;
      state = const SpotifyLibraryState();
      return;
    }
    // Guarded on our own phase rather than on the auth transition, and that is
    // the difference between one request and two. Signing in also rebuilds the
    // tab, whose `initState` calls [ensureLoaded] — and Riverpod makes no
    // promise about which of the two runs first. Both asking "is this still
    // idle?" means whichever arrives second finds a load already under way and
    // steps aside, instead of firing a duplicate page that the generation guard
    // would then throw away after paying for it.
    if (next.phase == SpotifyPhase.signedIn &&
        state.phase == MeowzicPhase.idle) {
      unawaited(_load(append: false));
    }
  }

  /// Loads the first page if this filter has never been loaded.
  ///
  /// Called on mount and on every chip tap. After the first success the phase
  /// is no longer idle and this returns without touching anything — which is
  /// what makes switching back to a filter instant, and is the whole of the
  /// caching policy.
  ///
  /// The turn yielded below is load-bearing. The tab calls this from
  /// `initState`, which runs *inside* the build pass, and `_load` assigns the
  /// loading phase synchronously before its own first `await` — so the
  /// assignment landed in the one window Riverpod refuses. It answers by
  /// throwing, the assignment is dropped, and the grid keeps a spinner that
  /// never resolves. That is exactly the "то грузится, то висит" this screen
  /// showed: whether it worked came down to whether the mount happened to
  /// coincide with a build, which is a race, not a feature.
  ///
  /// Deferred here rather than at the call site so a future caller cannot
  /// reintroduce it. See the twin in `spotify_detail.dart`.
  Future<void> ensureLoaded() async {
    if (state.phase != MeowzicPhase.idle) return;
    if (ref.read(spotifyAuthProvider).phase != SpotifyPhase.signedIn) return;
    await Future<void>.delayed(Duration.zero);
    if (state.phase != MeowzicPhase.idle) return;
    await _load(append: false);
  }

  /// Fetches this filter again from scratch — the only retry a failed grid
  /// offers, reached by tapping its chip.
  Future<void> reload() async {
    if (state.phase == MeowzicPhase.loading) return;
    await _load(append: false);
  }

  /// Appends the next page, when there is one and nothing is already in flight.
  Future<void> loadMore() async {
    if (state.phase != MeowzicPhase.done) return;
    if (state.loadingMore || !state.hasMore) return;
    await _load(append: true);
  }

  Future<void> _load({required bool append}) async {
    final generation = ++_generation;
    final existing = append ? state.items : const <SpotifyLibraryItem>[];

    state = SpotifyLibraryState(
      phase: append ? MeowzicPhase.done : MeowzicPhase.loading,
      items: existing,
      totalCount: state.totalCount,
      loadingMore: append,
    );

    try {
      final page = await fetchSpotifyLibrary(
        notifier: ref.read(spotifyAuthProvider.notifier),
        filter: filter,
        offset: existing.length,
      );
      if (generation != _generation) return;
      state = SpotifyLibraryState(
        phase: MeowzicPhase.done,
        items: [...existing, ...page.items],
        totalCount: page.totalCount,
      );
    } on SpotifyGqlException catch (error) {
      if (generation != _generation) return;
      state = SpotifyLibraryState(
        // A failed page appended to a list that is already up keeps the list:
        // scrolling to the bottom on a dropped connection should not delete
        // what was read on the way down. A failed first page has nothing to
        // keep, and `existing` is empty there by construction.
        phase: append ? MeowzicPhase.done : MeowzicPhase.failed,
        items: existing,
        totalCount: state.totalCount,
        failure: error.failure,
      );
    }
  }
}
