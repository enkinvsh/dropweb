import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/spotify.dart';
import 'package:dropweb/views/meowzic/spotify/gql.dart';
import 'package:dropweb/views/meowzic/spotify/library.dart';
import 'package:dropweb/views/meowzic/spotify/queries.dart';
import 'package:http/http.dart' as http;

/// One track inside a container, as Spotify describes it.
///
/// Deliberately not the same type as `MeowzicTrack`: that one is a YouTube
/// result and is identified by a video id, this one is a Spotify entry and has
/// no video id at all until the bridge is asked. Collapsing the two would put
/// an empty `id` in the type the media session publishes, which is the field
/// playback keys off.
class SpotifyTrack {
  const SpotifyTrack({
    required this.uri,
    required this.title,
    required this.duration,
    this.artists,
    this.image,
  });

  /// `spotify:track:<id>`.
  final String uri;
  final String title;
  final String? artists;

  /// Zero when Spotify did not say. Shown as nothing rather than as 0:00 —
  /// see the note on the two duration fields in [spotifyTrackOf].
  final Duration duration;
  final Uri? image;

  /// The bare id, which is what the Web API's `/v1/tracks?ids=` wants.
  String get id => uri.split(':').last;
}

/// A container's header and the tracks under it.
class SpotifyContainerDetail {
  const SpotifyContainerDetail({
    required this.tracks,
    required this.totalCount,
    this.title,
    this.subtitle,
    this.image,
    this.releases = const [],
  });

  /// The same container with [tracks] replaced — how a further page is folded
  /// into what is already on screen without re-reading a header that has not
  /// changed.
  SpotifyContainerDetail withTracks(List<SpotifyTrack> next) =>
      SpotifyContainerDetail(
        tracks: next,
        totalCount: totalCount,
        title: title,
        subtitle: subtitle,
        image: image,
        releases: releases,
      );

  /// Null when the query carries no header of its own — the saved-tracks
  /// document answers with tracks and nothing else. The screen then keeps
  /// showing what the tile it was opened from already had, which is Spotify's
  /// own name for that collection in the account's own language: better than a
  /// string of ours pretending to be theirs.
  final String? title;
  final String? subtitle;
  final Uri? image;
  final List<SpotifyTrack> tracks;

  /// How many tracks the container holds in total, not how many came back.
  ///
  /// Paging is driven off this rather than off "a short page means the end",
  /// for the reason `SpotifyLibraryPage` gives: a page legitimately comes back
  /// short once unparseable rows are dropped, and reading that as the end is
  /// exactly how a listing gets silently truncated — which is the bug this
  /// field exists to close.
  final int totalCount;

  /// What else this artist has put out — albums and singles, newest first.
  ///
  /// Typed as [SpotifyLibraryItem] rather than as a release model of its own,
  /// and that is the point: a release IS an album, the library grid already
  /// draws albums, and `SpotifyDetailPage` already opens one. A release type
  /// and a release tile of its own would be a third copy of something the app
  /// has twice already, and tapping it would need a screen that also exists.
  ///
  /// Empty for everything but artists. A playlist's tracks belong to whatever
  /// albums they came from, and listing those under it would be a section
  /// nobody asked for.
  final List<SpotifyLibraryItem> releases;
}

/// One page of a container.
///
/// 50 across the board. The 25 this used to send is the reference plugin's
/// default and not a Spotify limit; combined with never asking for a second
/// page it is what cut every playlist at track 25 with nothing on screen to
/// say so. Doubling it is not the fix — the paging below is — but 50 halves
/// the number of round trips through the tunnel for the same listing, and the
/// album and saved-track queries were already answering at this size.
const _pageLimit = 50;

/// Opens whatever the tapped tile was.
///
/// One entry point over four persisted queries, because the caller has a tile
/// and a kind and should not have to know that Spotify serves playlists,
/// albums, artists and saved tracks from four unrelated documents with four
/// different names for the same field.
///
/// [offset] asks for a further page. The header comes back with every page and
/// is simply re-read; asking Spotify for tracks 50..99 of a playlist without
/// its name is not something these documents offer, so the alternative would be
/// throwing the second header away in the fetcher instead of at the caller —
/// the same work, further from the code that knows why.
///
/// Throws [SpotifyGqlException]; the screen decides what a failure looks like.
Future<SpotifyContainerDetail> fetchSpotifyContainer({
  required SpotifyAuth notifier,
  required String uri,
  required SpotifyLibraryKind kind,
  int offset = 0,
  http.Client? client,
}) =>
    switch (kind) {
      SpotifyLibraryKind.playlist => _fetchPlaylist(
          notifier: notifier,
          uri: uri,
          offset: offset,
          client: client,
        ),
      SpotifyLibraryKind.album => _fetchAlbum(
          notifier: notifier,
          uri: uri,
          offset: offset,
          client: client,
        ),
      SpotifyLibraryKind.artist =>
        _fetchArtist(notifier: notifier, uri: uri, client: client),
      SpotifyLibraryKind.likedSongs => _fetchSavedTracks(
          notifier: notifier,
          offset: offset,
          client: client,
        ),
    };

/// A playlist: header, owner, and one page of contents.
Future<SpotifyContainerDetail> _fetchPlaylist({
  required SpotifyAuth notifier,
  required String uri,
  required int offset,
  http.Client? client,
}) async {
  final data = await spotifyGqlQuery(
    notifier: notifier,
    operationName: 'fetchPlaylist',
    sha256Hash: spotifyFetchPlaylistHash,
    variables: {
      'uri': uri,
      'offset': offset,
      'limit': _pageLimit,
      'enableWatchFeedEntrypoint': true,
    },
    client: client,
  );

  final playlist = _blockOf(data['playlistV2'], 'playlistV2');
  final owner = playlist['ownerV2'];
  final ownerData = owner is Map<String, dynamic> ? owner['data'] : null;
  final content = playlist['content'];
  final items = content is Map<String, dynamic> ? content['items'] : null;

  return SpotifyContainerDetail(
    totalCount: _totalOf(content, offset, items),
    title: spotifyStringOf(playlist['name']),
    subtitle: ownerData is Map<String, dynamic>
        ? spotifyStringOf(ownerData['name'])
        : null,
    image: spotifyPlaylistArtOf(playlist['images']),
    // `itemV2` is a response wrapper like the library's, so the track sits one
    // level in. Every other query in this file hands over the track directly.
    tracks: _parseTracks(items, unwrap: (entry) {
      final wrapper = entry['itemV2'];
      return wrapper is Map<String, dynamic> ? wrapper['data'] : null;
    }),
  );
}

/// An album: header, artists, and its tracks.
Future<SpotifyContainerDetail> _fetchAlbum({
  required SpotifyAuth notifier,
  required String uri,
  required int offset,
  http.Client? client,
}) async {
  final data = await spotifyGqlQuery(
    notifier: notifier,
    operationName: 'getAlbum',
    sha256Hash: spotifyGetAlbumHash,
    variables: {
      'uri': uri,
      'locale': '',
      'offset': offset,
      'limit': _pageLimit,
    },
    client: client,
  );

  final album = _blockOf(data['albumUnion'], 'albumUnion');
  final cover = spotifyArtOf(album['coverArt']);
  final tracksV2 = album['tracksV2'];
  final items = tracksV2 is Map<String, dynamic> ? tracksV2['items'] : null;

  return SpotifyContainerDetail(
    totalCount: _totalOf(tracksV2, offset, items),
    title: spotifyStringOf(album['name']),
    subtitle: spotifyArtistNames(album['artists']),
    image: cover,
    // The album's own cover is handed down to every row, because an album
    // track carries NO `albumOfTrack` at all — verified against the recorded
    // response. Without this the whole listing would be art-less, and the
    // MediaItem the notification shows would have no artwork either.
    tracks: _parseTracks(
      items,
      unwrap: (entry) => entry['track'],
      fallbackImage: cover,
    ),
  );
}

/// An artist: header, their ten top tracks, and their releases.
///
/// The releases used to be dropped on the floor with a comment saying top
/// tracks were enough, which is how the artist page became "какой-то огрызок
/// песен" — ten rows and a dead end, on a screen reached by tapping somebody
/// you deliberately follow. The overview answers with the discography in the
/// same response we were already paying for, so not reading it was pure loss.
///
/// The only fetcher here that takes no offset, because there is nothing to
/// page: `topTracks` carries no `totalCount` and no paging block in the
/// recorded response — the ten it returns are the whole set. Reporting the
/// count as what came back is therefore the truth, not a fallback, and it is
/// what stops the screen asking for an eleventh that does not exist. The
/// releases are not paged either; what the overview returns is the artist's
/// catalogue as Spotify chose to summarise it.
Future<SpotifyContainerDetail> _fetchArtist({
  required SpotifyAuth notifier,
  required String uri,
  http.Client? client,
}) async {
  final data = await spotifyGqlQuery(
    notifier: notifier,
    operationName: 'queryArtistOverview',
    sha256Hash: spotifyArtistOverviewHash,
    // Read off `ArtistClient.kt`, not invented: an empty locale and
    // `preReleaseV2: false`. A persisted query rejects variables it was not
    // registered with, so a plausible-looking extra field is not harmless.
    variables: {'uri': uri, 'locale': '', 'preReleaseV2': false},
    client: client,
  );

  final artist = _blockOf(data['artistUnion'], 'artistUnion');
  final profile = artist['profile'];
  final visuals = artist['visuals'];
  final discography = artist['discography'];
  final topTracks =
      discography is Map<String, dynamic> ? discography['topTracks'] : null;
  final items = topTracks is Map<String, dynamic> ? topTracks['items'] : null;
  final tracks = _parseTracks(items, unwrap: (entry) => entry['track']);

  return SpotifyContainerDetail(
    totalCount: tracks.length,
    title: profile is Map<String, dynamic>
        ? spotifyStringOf(profile['name'])
        : null,
    image: spotifyArtOf(
      visuals is Map<String, dynamic> ? visuals['avatarImage'] : null,
    ),
    tracks: tracks,
    releases: _parseReleases(discography),
  );
}

/// An artist's albums and singles, newest first, as library tiles.
///
/// Three groups are read and merged. `compilations` is included even though the
/// recorded artist has none — the key is there with `totalCount: 0`, so an
/// artist who does have them gets them, and leaving it out would be a gap that
/// only shows up on somebody else's account.
///
/// `popularReleasesAlbums` and `latest` are deliberately NOT read. They are the
/// same records under different orderings — `latest` is a single release
/// object, not a list, and `popularReleasesAlbums` is Spotify's own selection
/// out of the other three — so merging them in would add nothing the
/// de-duplication would not immediately remove.
///
/// De-duplicated by URI because the groups genuinely overlap: a record can be
/// both an album and, as a different edition, appear again. Sorted by release
/// date descending afterwards, so the section reads as a discography rather
/// than as "albums, then singles" — which is a grouping the user did not ask
/// for and cannot see the boundary of.
List<SpotifyLibraryItem> _parseReleases(Object? discography) {
  if (discography is! Map<String, dynamic>) return const [];

  final byUri = <String, SpotifyLibraryItem>{};
  final dates = <String, int>{};

  void take(Map<String, dynamic> release) {
    final uri = spotifyStringOf(release['uri']);
    final name = spotifyStringOf(release['name']);
    if (uri == null || name == null || byUri.containsKey(uri)) return;
    final year = _releaseYear(release['date']);
    byUri[uri] = SpotifyLibraryItem(
      uri: uri,
      title: name,
      // The year alone. The artist's own name is what the whole screen is
      // about, so repeating it under every tile would say nothing, and the
      // release type is already legible from the cover and the title.
      subtitle: year == null ? null : '$year',
      image: spotifyArtOf(release['coverArt']),
      kind: SpotifyLibraryKind.album,
    );
    dates[uri] = _releaseSortKey(release['date']);
  }

  for (final group in const ['albums', 'singles', 'compilations']) {
    final block = discography[group];
    final items = block is Map<String, dynamic> ? block['items'] : null;
    if (items is! List) continue;
    for (final entry in items.whereType<Map<String, dynamic>>()) {
      // Two levels, not one. Each entry of `albums.items` is a release GROUP
      // carrying `releases.items` — the editions of one record — rather than a
      // release. Reading `entry` directly, which is what the flat shape
      // elsewhere in this response invites, yields nothing at all: no uri, no
      // name, and a silently empty discography.
      final releases = entry['releases'];
      final editions = releases is Map<String, dynamic>
          ? releases['items']
          : null;
      if (editions is! List) continue;
      for (final release in editions.whereType<Map<String, dynamic>>()) {
        take(release);
      }
    }
  }

  final ordered = byUri.values.toList()
    ..sort((a, b) => (dates[b.uri] ?? 0).compareTo(dates[a.uri] ?? 0));
  return ordered;
}

int? _releaseYear(Object? date) {
  if (date is! Map<String, dynamic>) return null;
  final year = date['year'];
  return year is num ? year.toInt() : null;
}

/// A release date flattened into one comparable number.
///
/// Missing parts count as zero, which sorts an undated release to the bottom of
/// its year rather than to the top of the list — the honest place for something
/// Spotify would not date.
int _releaseSortKey(Object? date) {
  if (date is! Map<String, dynamic>) return 0;
  int part(String key) {
    final value = date[key];
    return value is num ? value.toInt() : 0;
  }

  return part('year') * 10000 + part('month') * 100 + part('day');
}

/// The account's saved tracks — what the "Liked Songs" tile opens.
///
/// It has no header of its own to fetch: the tile already carries the name and
/// the art Spotify serves for it, and this query answers with tracks and
/// nothing else. The screen keeps showing what the tile gave it.
Future<SpotifyContainerDetail> _fetchSavedTracks({
  required SpotifyAuth notifier,
  required int offset,
  http.Client? client,
}) async {
  final data = await spotifyGqlQuery(
    notifier: notifier,
    operationName: 'fetchLibraryTracks',
    sha256Hash: spotifyFetchLibraryTracksHash,
    variables: {'offset': offset, 'limit': _pageLimit},
    client: client,
  );

  final me = _blockOf(data['me'], 'me');
  final library = me['library'];
  final tracks = library is Map<String, dynamic> ? library['tracks'] : null;
  final items = tracks is Map<String, dynamic> ? tracks['items'] : null;

  return SpotifyContainerDetail(
    totalCount: _totalOf(tracks, offset, items),
    tracks: _parseTracks(
      items,
      unwrap: (entry) => entry['track'],
      // The saved-track payload sits under `track.data` and — unlike every
      // other shape here — carries no `uri` of its own; the URI is on the
      // wrapper as `_uri`. Reading it off the payload would leave every row
      // without an id, and an id is what the ISRC lookup and therefore all of
      // playback is keyed on.
      wrapped: true,
    ),
  );
}

/// How many tracks the container holds, off whichever block carries the count.
///
/// `totalCount` sits next to `items` in all three paging shapes — a playlist's
/// `content`, an album's `tracksV2`, the saved-tracks `tracks` — so one reader
/// serves them all.
///
/// The fallback is `offset + what came back`, deliberately not zero and not the
/// page size. It is the smallest number that is certainly true, so a Spotify
/// answer that omits the count leaves the screen showing everything it has and
/// simply not asking for more, rather than either looping forever or blanking a
/// listing it already holds.
int _totalOf(Object? block, int offset, Object? items) {
  final total = block is Map<String, dynamic> ? block['totalCount'] : null;
  if (total is num) return total.toInt();
  return offset + (items is List ? items.length : 0);
}

/// The `data.<name>` block, or a reported failure.
///
/// A missing block is upstream rather than "empty container": an empty album is
/// a real thing and prints as such, and printing it over a rotated query hash
/// would send somebody looking for a listing Spotify never sent.
Map<String, dynamic> _blockOf(Object? block, String name) {
  if (block is Map<String, dynamic>) return block;
  commonPrint.log('spotify detail answered without data.$name');
  throw const SpotifyGqlException(SpotifyGqlFailure.upstream);
}

/// Turns a list of container entries into tracks, dropping what it cannot read.
///
/// Dropped rather than thrown, for the reason the library parser gives: one
/// unfamiliar row — an episode in a playlist, a local file, a track pulled from
/// the catalogue — must not be able to blank an entire listing for whoever
/// happens to have saved it.
List<SpotifyTrack> _parseTracks(
  Object? items, {
  required Object? Function(Map<String, dynamic> entry) unwrap,
  Uri? fallbackImage,
  bool wrapped = false,
}) {
  if (items is! List) return const [];
  final tracks = <SpotifyTrack>[];
  for (final entry in items.whereType<Map<String, dynamic>>()) {
    final raw = unwrap(entry);
    if (raw is! Map<String, dynamic>) continue;
    final payload = wrapped ? raw['data'] : raw;
    if (payload is! Map<String, dynamic>) continue;
    final parsed = spotifyTrackOf(
      payload,
      wrapperUri: wrapped ? spotifyStringOf(raw['_uri']) : null,
      fallbackImage: fallbackImage,
    );
    if (parsed != null) tracks.add(parsed);
  }
  return tracks;
}

/// One track payload turned into a [SpotifyTrack], or null when it is not one.
///
/// Public, and shared with `search.dart`, because a track is a track whichever
/// document it arrived in: the two duration field names, the artist join and
/// the cover choice below are the same three traps for a search hit as for a
/// playlist row. A second copy of this over there would be a second place for
/// the `trackDuration`/`duration` split to be got wrong — and that one fails
/// silently, printing a screen of 0:00 rows that still play.
///
/// [wrapperUri] is the URI off the enclosing `ResponseWrapper`, for the shapes
/// whose payload carries none of its own; see the saved-tracks note above.
SpotifyTrack? spotifyTrackOf(
  Map<String, dynamic> payload, {
  String? wrapperUri,
  Uri? fallbackImage,
}) {
  final uri = spotifyStringOf(payload['uri']) ?? wrapperUri;
  final title = spotifyStringOf(payload['name']);
  if (uri == null || title == null) return null;

  final album = payload['albumOfTrack'];
  return SpotifyTrack(
    uri: uri,
    title: title,
    artists: spotifyArtistNames(payload['artists']),
    duration: _parseDuration(payload),
    image: (album is Map<String, dynamic>
            ? spotifyArtOf(album['coverArt'])
            : null) ??
        fallbackImage,
  );
}

/// The track's length, under whichever of its two names this query used.
///
/// Not a defensive nicety — the field genuinely differs by document. A playlist
/// track carries `trackDuration` and has no `duration` key at all; album,
/// artist and saved tracks carry `duration`. Reading only one of them yields a
/// listing of 0:00 rows that still plays perfectly, which is the worst kind of
/// bug: nothing fails, so nothing gets reported until somebody squints at the
/// screen. Both are read and whichever is present wins.
Duration _parseDuration(Map<String, dynamic> payload) {
  for (final key in const ['trackDuration', 'duration']) {
    final block = payload[key];
    if (block is! Map<String, dynamic>) continue;
    final millis = block['totalMilliseconds'];
    if (millis is num) return Duration(milliseconds: millis.toInt());
  }
  return Duration.zero;
}
