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
/// A separate document from `libraryV3` even though the tile that opens it
/// arrives inside one: the library query returns the pseudo-playlist as a name
/// and a count, never its contents.
const spotifyLibraryTracksHash =
    '087278b20b743578a6262c2b0b4bcd20d879c503cc359a2285baf083ef944240';

/// `profileAttributes` — who the session belongs to.
///
/// Nothing upstream depends on this one: `fetchSpotifyProfile` treats a failure
/// as "no display name" rather than "no session", precisely because this hash
/// can rotate. See the doc comment there.
const spotifyProfileAttributesHash =
    '53bcb064f6cd18c23f752bc324a791194d20df612d8e1239c735144ab0399ced';
