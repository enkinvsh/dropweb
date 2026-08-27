import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/spotify.dart';
import 'package:dropweb/views/meowzic/spotify/gql.dart';
import 'package:dropweb/views/meowzic/spotify/queries.dart';
import 'package:http/http.dart' as http;

/// Which slice of the library to ask for.
///
/// Three values, one query. Spotify serves all of them from `libraryV3` and
/// distinguishes them by a string in `filters`, so this enum is a wire value
/// with a Dart name on it rather than three separate calls.
enum SpotifyLibraryFilter {
  playlists,
  albums,
  artists;

  /// The literal Spotify expects. Written out rather than derived from [name]
  /// with a capitalisation helper: these are their tokens, not ours, and the
  /// day one of them stops matching its Dart name a clever helper would fail
  /// silently while this fails visibly.
  String get wireName => switch (this) {
        SpotifyLibraryFilter.playlists => 'Playlists',
        SpotifyLibraryFilter.albums => 'Albums',
        SpotifyLibraryFilter.artists => 'Artists',
      };
}

/// What a row actually is, once the wrapper is unpacked.
///
/// Kept separate from [SpotifyLibraryFilter] because the two do not line up:
/// the Playlists filter returns both [playlist] and [likedSongs], and the
/// screen has to be able to tell them apart — one is a real playlist with an
/// owner, the other is the account's saved-tracks pseudo-collection.
enum SpotifyLibraryKind { playlist, likedSongs, album, artist }

/// One tile in the library grid.
///
/// Flattened out of Spotify's four wrapper shapes on purpose. The widget layer
/// must not be the place where `Album` versus `PseudoPlaylist` is decided —
/// that question is answered once, here, against recorded responses, and what
/// reaches the grid is four fields that always mean the same thing.
class SpotifyLibraryItem {
  const SpotifyLibraryItem({
    required this.uri,
    required this.title,
    required this.kind,
    this.subtitle,
    this.image,
  });

  /// The `spotify:` URI. Nothing navigates on it yet; it is carried because it
  /// is the identity of the row, and a list whose rows have no identity cannot
  /// be diffed, deduplicated across pages, or opened later.
  final String uri;
  final String title;

  /// The second line, when there is one. Artists have none — their name is the
  /// whole of what Spotify knows about them at this level, and inventing a
  /// constant "Artist" caption under every tile in a grid the user explicitly
  /// filtered to artists would be noise.
  final String? subtitle;
  final Uri? image;
  final SpotifyLibraryKind kind;
}

/// One answered page, with the size of the whole so the caller knows when to
/// stop asking.
class SpotifyLibraryPage {
  const SpotifyLibraryPage({required this.items, required this.totalCount});

  final List<SpotifyLibraryItem> items;

  /// How many rows the filter has in total, not how many came back. Paging is
  /// driven off this rather than off "a short page means the end": a page can
  /// legitimately come back short of the limit once unparseable rows are
  /// dropped, and treating that as the end would silently truncate a library.
  final int totalCount;
}

/// Spotify's own page size for this query, and the one the web player sends.
const spotifyLibraryPageSize = 50;

/// Roughly the width a grid tile is drawn at on a phone, in device pixels.
///
/// Used to choose among the sources Spotify offers rather than to size
/// anything: it is the smallest art that still has more pixels than the tile.
/// The 640s are four times the bytes for pixels that get scaled away, and the
/// 64s are a visibly soft square on a modern display.
const _artTargetWidth = 300;

/// Asks Spotify for one page of [filter].
///
/// Throws [SpotifyGqlException] — the caller decides what a failure looks like
/// on screen, the same division `searchMeowzic` keeps with its notifier.
Future<SpotifyLibraryPage> fetchSpotifyLibrary({
  required SpotifyAuth notifier,
  required SpotifyLibraryFilter filter,
  int offset = 0,
  int limit = spotifyLibraryPageSize,
  http.Client? client,
}) async {
  final data = await spotifyGqlQuery(
    notifier: notifier,
    operationName: 'libraryV3',
    sha256Hash: spotifyLibraryV3Hash,
    variables: {
      'filters': [filter.wireName],
      'order': null,
      'textFilter': '',
      'features': const <String>[],
      'limit': limit,
      'offset': offset,
      'flatten': true,
      'expandedFolders': const <String>[],
      'folderUri': null,
      'includeFoldersWhenFlattening': true,
    },
    client: client,
  );

  final me = data['me'];
  final library = me is Map<String, dynamic> ? me['libraryV3'] : null;
  if (library is! Map<String, dynamic>) {
    // `data` was there but not the shape we asked for. Reported as upstream
    // rather than as an empty library: an empty library is a real state a user
    // can be in, and printing "здесь пока пусто" over a protocol change would
    // send them looking for playlists they did in fact save.
    commonPrint.log('spotify libraryV3 answered without data.me.libraryV3');
    throw const SpotifyGqlException(SpotifyGqlFailure.upstream);
  }

  final rawItems = library['items'];
  final items = <SpotifyLibraryItem>[];
  if (rawItems is List) {
    for (final entry in rawItems.whereType<Map<String, dynamic>>()) {
      final parsed = _parseEntry(entry);
      if (parsed != null) items.add(parsed);
    }
  }

  final total = library['totalCount'];
  return SpotifyLibraryPage(
    items: items,
    // Falling back to what we actually received keeps paging terminating when
    // Spotify omits the count: `offset + items.length` is never less than what
    // is on screen, so the loop stops rather than asking forever.
    totalCount: total is num ? total.toInt() : offset + items.length,
  );
}

/// Unpacks one `items[]` entry, or null when it is something we cannot draw.
///
/// Null rather than an exception, and this is the load-bearing decision in the
/// file. Spotify's library is a heterogeneous list — today four content types,
/// tomorrow whatever they add next, and folders already exist behind a variable
/// we do not set. A parser that threw on an unknown `__typename` would let one
/// unfamiliar row take down the whole page, so the account that saved it would
/// see an error where everyone else sees their library. Dropping the row costs
/// one tile; the log line is what makes the omission findable.
SpotifyLibraryItem? _parseEntry(Map<String, dynamic> entry) {
  final wrapper = entry['item'];
  if (wrapper is! Map<String, dynamic>) return null;
  final data = wrapper['data'];
  if (data is! Map<String, dynamic>) return null;

  // `data.uri` for everything we handle, with the wrapper's `_uri` behind it —
  // the two agree in every recorded response, and the fallback costs nothing
  // against the day one shape stops carrying its own.
  final uri = switch (data['uri']) {
    final String value when value.isNotEmpty => value,
    _ => switch (wrapper['_uri']) {
        final String value when value.isNotEmpty => value,
        _ => null,
      },
  };
  if (uri == null) return null;

  switch (data['__typename']) {
    case 'Album':
      final name = spotifyStringOf(data['name']);
      if (name == null) return null;
      return SpotifyLibraryItem(
        uri: uri,
        title: name,
        subtitle: spotifyArtistNames(data['artists']),
        image: spotifyArtOf(data['coverArt']),
        kind: SpotifyLibraryKind.album,
      );

    case 'Artist':
      final profile = data['profile'];
      final name = profile is Map<String, dynamic>
          ? spotifyStringOf(profile['name'])
          : null;
      if (name == null) return null;
      final visuals = data['visuals'];
      return SpotifyLibraryItem(
        uri: uri,
        title: name,
        image: spotifyArtOf(
          visuals is Map<String, dynamic> ? visuals['avatarImage'] : null,
        ),
        kind: SpotifyLibraryKind.artist,
      );

    case 'Playlist':
      final name = spotifyStringOf(data['name']);
      if (name == null) return null;
      final owner = data['ownerV2'];
      final ownerData = owner is Map<String, dynamic> ? owner['data'] : null;
      return SpotifyLibraryItem(
        uri: uri,
        title: name,
        subtitle: ownerData is Map<String, dynamic>
            ? spotifyStringOf(ownerData['name'])
            : null,
        image: spotifyPlaylistArtOf(data['images']),
        kind: SpotifyLibraryKind.playlist,
      );

    // "Liked Songs" — the first row of the Playlists filter on every account,
    // and the one shape that is not a playlist at all: no owner, a track count
    // instead, and art served from a different host. Handled explicitly rather
    // than left to the default branch, because the default branch drops rows
    // and dropping this one would delete the entry every user opens first.
    case 'PseudoPlaylist':
      final name = spotifyStringOf(data['name']);
      if (name == null) return null;
      final count = data['count'];
      return SpotifyLibraryItem(
        uri: uri,
        title: name,
        // Localised here rather than in the tile, so the widget receives a
        // finished second line whatever the row turned out to be — the same
        // reason `MeowzicSearch.play` decides its own message.
        subtitle: count is num
            ? appLocalizations.meowzicLibraryTrackCount(count.toInt())
            : null,
        image: spotifyArtOf(data['image']),
        kind: SpotifyLibraryKind.likedSongs,
      );

    default:
      commonPrint.log('spotify library skipped ${data['__typename']}');
      return null;
  }
}

String? spotifyStringOf(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// Every artist on a `{items: [{profile: {name}}]}` block, joined the way
/// Spotify's own player joins them.
///
/// Shared by the library grid and the detail screens rather than reimplemented
/// per query: albums, playlist tracks, album tracks and artist top tracks all
/// carry this exact shape, and four copies of a join would be four places for a
/// missing profile to throw.
String? spotifyArtistNames(Object? artists) {
  if (artists is! Map<String, dynamic>) return null;
  final items = artists['items'];
  if (items is! List) return null;
  final names = <String>[];
  for (final artist in items.whereType<Map<String, dynamic>>()) {
    final profile = artist['profile'];
    final name = profile is Map<String, dynamic>
        ? spotifyStringOf(profile['name'])
        : null;
    if (name != null) names.add(name);
  }
  return names.isEmpty ? null : names.join(', ');
}

/// A `{sources: [...]}` block, unwrapped.
List<Map<String, dynamic>> _sourcesOf(Object? image) {
  if (image is! Map<String, dynamic>) return const [];
  final sources = image['sources'];
  return sources is List
      ? sources.whereType<Map<String, dynamic>>().toList()
      : const [];
}

/// The cover behind a `{sources: [...]}` block — album covers, artist avatars,
/// the Liked Songs image, and every track's `albumOfTrack.coverArt`.
Uri? spotifyArtOf(Object? image) => _pickSource(_sourcesOf(image));

/// The cover behind a `{items: [{sources: [...]}]}` block, which is how
/// playlists carry theirs.
///
/// `images.items` is a list because a playlist can carry a collage of four
/// covers; the first entry that actually has sources is the one to draw. It is
/// routinely `[]` — a playlist someone made and never gave art to — and that is
/// a normal row, not a broken one.
Uri? spotifyPlaylistArtOf(Object? images) {
  if (images is! Map<String, dynamic>) return null;
  final items = images['items'];
  if (items is! List) return null;
  for (final image in items.whereType<Map<String, dynamic>>()) {
    final sources = _sourcesOf(image);
    if (sources.isNotEmpty) return _pickSource(sources);
  }
  return null;
}

/// The source worth downloading, out of the several Spotify offers.
///
/// Chosen, not indexed. The array is genuinely unordered — the recorded album
/// response lists 300, 64, 640 in that order — so taking `[0]` means the tile
/// is sometimes a 64px square blown up to 170 and sometimes a 640px download
/// for it, at random, on the same screen. The rule is the smallest source that
/// still out-resolves the tile, falling back to the largest when everything on
/// offer is too small.
///
/// Unmeasured sources are kept rather than discarded, because two real shapes
/// have no dimensions at all: playlist covers arrive with `width: null`, and an
/// artist's top-track covers carry a bare `url` and nothing else. Discarding
/// them would leave every playlist tile and every artist track blank.
Uri? _pickSource(List<Map<String, dynamic>> sources) {
  Map<String, dynamic>? best;
  Map<String, dynamic>? largest;
  Map<String, dynamic>? unmeasured;

  for (final source in sources) {
    if (spotifyStringOf(source['url']) == null) continue;
    final width = source['width'];
    if (width is! num) {
      unmeasured ??= source;
      continue;
    }
    if (largest == null || width > (largest['width'] as num)) largest = source;
    if (width >= _artTargetWidth &&
        (best == null || width < (best['width'] as num))) {
      best = source;
    }
  }

  final chosen = best ?? largest ?? unmeasured;
  return chosen == null ? null : Uri.tryParse(chosen['url'] as String);
}
