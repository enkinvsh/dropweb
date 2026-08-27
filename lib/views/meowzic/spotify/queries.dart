/// Spotify's persisted-query hashes, gathered in one file.
///
/// These are not ours and they are not stable. Spotify's web player ships its
/// GraphQL documents pre-registered, so a client sends a SHA-256 of the query
/// text instead of the query itself — and every time they redeploy a document
/// its hash changes and ours starts answering `PersistedQueryNotFound`. This is
/// routine maintenance for them and a broken screen for us: the reference
/// plugin's most recent commit is literally
/// `fix: update sha256Hash values for libraryV3 operations`.
///
/// Scattering them next to the calls that use them would mean hunting through
/// the directory on the day it happens, with no way to tell which of the
/// constants are stale and which were simply never touched. Gathered here, the
/// repair is one file and one diff, and anyone reading it can see the whole
/// surface Spotify can rotate out from under us.
///
/// The next step, when this starts costing releases, is to serve these from
/// the ytbridge mirror the way `nuance.dart` already serves the TOTP secret —
/// the hash is public build output, not a secret, so mirroring it is cheap and
/// would let a rotation be fixed without shipping an APK. Deliberately NOT
/// built yet: one file to patch is enough until a rotation actually bites, and
/// a remote fetch adds a failure mode to every call that has none today.
library;

/// `libraryV3` — the user's saved playlists, albums and artists.
///
/// One hash for all three. The filter that decides which of them comes back is
/// a variable (`filters: ["Playlists" | "Albums" | "Artists"]`), not a separate
/// document, so there is nothing here to split.
const spotifyLibraryV3Hash =
    '390c78e5b951029bad359785e69b07b536a509c581cbcd0aded5e5067f187455';

/// `fetchPlaylist` — a playlist's header and the first page of its contents.
const spotifyFetchPlaylistHash =
    'cd2275433b29f7316176e7b5b5e098ae7744724e1a52d63549c76636b3257749';

/// `getAlbum` — an album's header and its track listing.
const spotifyGetAlbumHash =
    'b9bfabef66ed756e5e13f68a942deb60bd4125ec1f1be8cc42769dc0259b4b10';

/// `queryArtistOverview` — an artist's header and their ten top tracks.
///
/// The whole overview comes back for those ten tracks: discography, related
/// content, merchandise, reputation. Asking for less would mean a different
/// persisted document, and we do not get to write those — Spotify registers
/// them. The waste is theirs to fix, not ours.
const spotifyArtistOverviewHash =
    '7f86ff63e38c24973a2842b672abe44c910c1973978dc8a4a0cb648edef34527';

/// `fetchLibraryTracks` — the account's saved tracks, behind "Liked Songs".
///
/// A DIFFERENT operation from `libraryV3`, and the sentence that used to stand
/// here got the relationship between them wrong at a cost. It said the tile
/// that opens this "arrives inside" the library answer — so the Сохранённые tab
/// was built to hunt for a `PseudoPlaylist` row in the Playlists filter, read
/// its uri, and open it as a container. Measured on a live account: that row is
/// not there. The Плейлисты grid comes back holding real playlists and nothing
/// else, the hunt found nothing, and a tab over an account full of saved tracks
/// shipped reading «Здесь пока пусто».
///
/// Saved tracks are not a playlist and are not a slice of the library. They are
/// their own document, reached with no uri at all — `{offset, limit}` is the
/// whole of its variables, because "whose" is already answered by the session.
/// Anything that needs them asks THIS, directly; nothing may make it wait on a
/// library page first. See `saved_tracks.dart`.
const spotifyFetchLibraryTracksHash =
    '087278b20b743578a6262c2b0b4bcd20d879c503cc359a2285baf083ef944240';

/// `searchTracks` — the catalogue, narrowed to tracks.
///
/// `searchDesktop` is the operation the web player actually sends and it was
/// the obvious candidate; it is not used here. It answers with every facet at
/// once — albums, artists, playlists, episodes, podcasts, users — and this
/// screen plays tracks. Everything else in that answer is bytes through the
/// tunnel that end in a discarded branch of a parser we would have to write
/// first.
///
/// The deciding difference is `offset`. `searchTracks` takes one, so results
/// can be paged for the first time in this app: the ytbridge `/s` endpoint has
/// no cursor at all and a hard ceiling of 20, which is why search has always
/// stopped dead at twenty rows with nothing on screen to say there was more.
/// A paged search is not a nicety here — it is the difference between "Spotify
/// has your track and we did not show it" and finding it.
const spotifySearchTracksHash =
    'bc1ca2fcd0ba1013a0fc88e6cc4f190af501851e3dafd3e1ef85840297694428';

/// `profileAttributes` — who the session belongs to.
///
/// Nothing upstream depends on this one: `fetchSpotifyProfile` treats a failure
/// as "no display name" rather than "no session", precisely because this hash
/// can rotate. See the doc comment there.
const spotifyProfileAttributesHash =
    '53bcb064f6cd18c23f752bc324a791194d20df612d8e1239c735144ab0399ced';

// The hashes below drive writes, and one thing about them looks like a
// copy-paste slip and is not: sibling operations share a hash. `addToLibrary`
// and `removeFromLibrary` are one hash, as are `addToPlaylist` and
// `removeFromPlaylist`. A persisted hash addresses the whole registered GraphQL
// *document*, and `operationName` picks the operation inside it — our transport
// always sends both, so the right one runs. Nobody needs to go looking for the
// "missing" second hash, and nobody should "fix" this by inventing one.

/// `addToLibrary` — puts a track into the account's Liked Songs.
const spotifyAddToLibraryHash =
    'a3c1ff58e6a36fec5fe1e3a193dc95d9071d96b9ba53c5ba9c1494fb1ee73915';

/// `applyCurations` — takes a track back out of Liked Songs.
const spotifyApplyCurationsHash =
    '05b739a3a73091c213385233b9d3ed8a857c2ca29d2eebadb3d04ed12e288697';

/// `isCurated` — whether each of a batch of tracks is in Liked Songs.
const spotifyIsCuratedHash =
    'e4ed1f91a2cc5415befedb85acf8671dc1a4bf3ca1a5b945a6386101a22e28a6';

/// `addItemsToRootlist` — saves a playlist into the user's own library.
const spotifyAddItemsToRootlistHash =
    'bd9c5cae1ee80ebca05d7ed12fd394216f49a20ce72d9dc762868df0f14522ea';

/// `removeItemsFromRootlist` — drops a saved playlist from the library.
const spotifyRemoveItemsFromRootlistHash =
    '3422f1866532820a1d8d0560f88542dbdbd35d0377ee5ecd49593590f5f1e86b';

/// `areEntitiesInLibrary` — whether each of a batch of playlists is saved.
const spotifyAreEntitiesInLibraryHash =
    '134337999233cc6fdd6b1e6dbf94841409f04a946c5c7b744b09ba0dfe5a85ed';
