import 'dart:async';
import 'dart:convert';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/state.dart';
import 'package:dropweb/views/meowzic/spotify/profile.dart';
import 'package:dropweb/views/meowzic/spotify/session.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/spotify.g.dart';

/// What the library tab has to show.
enum SpotifyPhase { signedOut, working, signedIn, failed }

/// The library tab's whole visible state.
///
/// Immutable and replaced wholesale rather than patched, for the same reason
/// `MeowzicSearchState` is: there are four transitions and naming every field
/// on each of them is cheaper to read than a `copyWith` that has to say
/// whether it is keeping or clearing the failure.
class SpotifyAuthState {
  const SpotifyAuthState({
    this.phase = SpotifyPhase.signedOut,
    this.displayName,
    this.failure,
  });

  final SpotifyPhase phase;

  /// Who is signed in, as the screen prints it. Held here rather than derived
  /// from the session because it does not come from the session — the profile
  /// call is allowed to fail, and then this is a fallback label.
  final String? displayName;
  final SpotifyAuthFailure? failure;
}

/// Everything an authenticated Spotify request needs, and nothing else.
///
/// Handed out instead of the [SpotifySession] itself so the GraphQL layer never
/// gets hold of the object the refresh machinery mutates. A caller holding a
/// session could read `expiresAt`, decide for itself whether the token is still
/// good, and quietly grow a second copy of the rule that lives in [
/// SpotifyAuth.credentials] — and the two would disagree the first time the
/// margin changed. This carries only the two header values, so there is nothing
/// to reason about downstream.
class SpotifyCredentials {
  const SpotifyCredentials({
    required this.accessToken,
    required this.cookieHeader,
  });

  final String accessToken;

  /// The whole jar as a `Cookie:` header value. The GraphQL endpoint wants all
  /// of it, not just `sp_dc` — see the note on [SpotifySession.cookies].
  final String cookieHeader;
}

/// Where the session is kept between launches.
///
/// The secure store, not the Config blob: this holds `sp_dc`, which is a
/// bearer credential for somebody's Spotify account for as long as it lives.
/// SharedPreferences is readable through an ADB backup, which is the exact
/// reason subscription URLs were moved out of it — see `secure_profile_store`.
const _sessionKey = 'spotify_session_v1';

/// Spotify sign-in, held above the route.
///
/// keepAlive for the reason `AppUpdate` has it and the meowzic search does:
/// an auto-disposing provider is torn down the moment the last route watching
/// it pops, and this exists to survive exactly that — the library tab is
/// inside a pushed route, and a sign-in that had to be repeated on every
/// visit would not be a sign-in.
@Riverpod(keepAlive: true)
class SpotifyAuth extends _$SpotifyAuth {
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  SpotifySession? _session;

  /// Guards against two mints racing. `credentials` is called from every
  /// authenticated path, so a screen that fires three requests at once would
  /// otherwise run three handshakes and keep whichever finished last.
  Future<SpotifySession?>? _inFlight;

  @override
  SpotifyAuthState build() {
    unawaited(_restore());
    return const SpotifyAuthState();
  }

  /// Reads back whatever the last launch left.
  ///
  /// The stored token is very likely already expired — tokens last an hour and
  /// phones sit overnight — and that is fine: it is restored anyway, marked
  /// signed in, and re-minted the first time anything asks for it. Refusing to
  /// restore an expired token would sign the user out every morning while the
  /// cookie that can fix it sits right there in the same record.
  Future<void> _restore() async {
    final raw = await _read();
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      _session = SpotifySession.fromJson(decoded);
      state = SpotifyAuthState(
        phase: SpotifyPhase.signedIn,
        displayName: decoded['displayName'] as String?,
      );
    } catch (error) {
      commonPrint.log('spotify session restore failed: $error');
      await _storage.delete(key: _sessionKey);
    }
  }

  Future<String?> _read() async {
    try {
      return await _storage.read(key: _sessionKey);
    } catch (error) {
      commonPrint.log('spotify session read failed: $error');
      return null;
    }
  }

  Future<void> _persist(String? displayName) async {
    final session = _session;
    if (session == null) return;
    try {
      await _storage.write(
        key: _sessionKey,
        value: jsonEncode({...session.toJson(), 'displayName': displayName}),
      );
    } catch (error) {
      // Not fatal. The in-memory session still works for this run; only the
      // next launch pays, and it pays by asking for a sign-in rather than by
      // breaking.
      commonPrint.log('spotify session write failed: $error');
    }
  }

  /// Takes the cookies a completed webview login left and turns them into a
  /// session.
  ///
  /// The webview itself is the screen's to open — it needs a `BuildContext`,
  /// which a notifier has no business holding, the same split `MeowzicSearch`
  /// keeps with its failure messages.
  Future<void> signIn(Map<String, String> cookies) async {
    state = const SpotifyAuthState(phase: SpotifyPhase.working);
    try {
      final session = await mintSpotifySession(
        cookies: cookies,
        bridge: ref.read(meowzicBridgeProvider),
      );
      _session = session;
      final name = await _identify(session);
      await _persist(name);
      state = SpotifyAuthState(phase: SpotifyPhase.signedIn, displayName: name);
    } on SpotifyAuthException catch (error) {
      _session = null;
      state = SpotifyAuthState(
        phase: SpotifyPhase.failed,
        failure: error.failure,
      );
    }
  }

  /// The name to print under "signed in".
  ///
  /// Falls back through the profile call, then the account the cookie belongs
  /// to, then a plain label. The profile query is pinned to a hash Spotify
  /// rotates at will (see `profile.dart`), and the day it rotates this must
  /// degrade to a duller label rather than to a sign-out.
  Future<String?> _identify(SpotifySession session) async {
    final profile = await fetchSpotifyProfile(session);
    return profile?.name ?? profile?.username;
  }

  /// The headers an authenticated call has to carry, minting a new token when
  /// the one we hold is missing, expired, or about to be. Null means there is
  /// no session at all — the caller is signed out, not merely unlucky.
  ///
  /// Every authenticated call goes through here rather than reading the token
  /// off the session directly. A timer that re-mints on schedule may exist as
  /// an optimisation, but it must never be the only thing keeping the session
  /// alive: a backgrounded phone does not run timers on time, and when it wakes
  /// the first thing it does is fire the requests that were queued — which is
  /// precisely the moment a missed timer turns into a screen full of 401s.
  ///
  /// [forceRefresh] skips the "still usable" check entirely and re-mints. It
  /// exists because expiry is not the only way a token dies: revoking the
  /// session from another device, or a password change, kills it while our copy
  /// still looks minutes fresh. Only the caller that has actually been handed a
  /// 401 knows that happened, so only it may ask for this — re-minting on
  /// spec would run a full handshake before every request.
  Future<SpotifyCredentials?> credentials({bool forceRefresh = false}) async {
    final session = _session;
    if (session == null) return null;
    if (!forceRefresh && isSpotifySessionUsable(session)) {
      return _credentialsOf(session);
    }

    // Joined rather than started again, so concurrent callers share one
    // handshake instead of each running their own. A forced refresh joins a
    // handshake that is already running for the same reason it would start
    // one: whatever it produces is newer than what we were just refused.
    final inFlight = _inFlight ??= _remint(session);
    try {
      final minted = await inFlight;
      return minted == null ? null : _credentialsOf(minted);
    } finally {
      _inFlight = null;
    }
  }

  SpotifyCredentials _credentialsOf(SpotifySession session) =>
      SpotifyCredentials(
        accessToken: session.accessToken,
        cookieHeader: session.cookieHeader,
      );

  Future<SpotifySession?> _remint(SpotifySession stale) async {
    try {
      final session = await mintSpotifySession(
        cookies: stale.cookies,
        bridge: ref.read(meowzicBridgeProvider),
      );
      _session = session;
      await _persist(state.displayName);
      return session;
    } on SpotifyAuthException catch (error) {
      // Unreachable is not a reason to sign anybody out — the cookie is
      // probably still good and the network is not. Anything else means
      // Spotify itself rejected what we hold, and only a new login fixes it.
      if (error.failure == SpotifyAuthFailure.unreachable) {
        state = SpotifyAuthState(
          phase: SpotifyPhase.failed,
          displayName: state.displayName,
          failure: error.failure,
        );
        return null;
      }
      await signOut();
      state = SpotifyAuthState(
        phase: SpotifyPhase.failed,
        failure: error.failure,
      );
      return null;
    }
  }

  /// Forgets the session, on this device and in the webview.
  ///
  /// Clearing the webview's cookie jar is the half that is easy to skip and
  /// expensive to skip: Spotify's login page reads its own cookies, so with
  /// the jar left behind the next "sign in" lands straight back on `/status`
  /// as the previous account, without ever showing a form. Somebody handing
  /// the phone over would be signing in as the person before them.
  Future<void> signOut() async {
    _session = null;
    _inFlight = null;
    state = const SpotifyAuthState();
    try {
      await _storage.delete(key: _sessionKey);
    } catch (error) {
      commonPrint.log('spotify session delete failed: $error');
    }
    try {
      await CookieManager.instance().deleteAllCookies();
      await WebStorageManager.instance().deleteAllData();
    } catch (error) {
      commonPrint.log('spotify webview cookie clear failed: $error');
    }
  }
}
