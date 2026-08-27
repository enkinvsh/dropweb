import 'dart:async';
import 'dart:convert';
import 'dart:io';

// The narrow import rather than the `providers` barrel, matching `bridge.dart`
// next door: the barrel exports the spotify notifier, which imports this file.
import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/state.dart';
import 'package:dropweb/views/meowzic/spotify/nuance.dart';
import 'package:dropweb/views/meowzic/spotify/totp.dart';
import 'package:http/http.dart' as http;

/// The browser Spotify is told it is talking to.
///
/// A fixed, real Chrome string, and the same one for every request in this
/// directory. The reference plugin assembles its User-Agent out of
/// `Date.now()` and random digits, which produces a run of numerals that is
/// not a User-Agent at all — it is unique per launch, so it identifies the
/// client more precisely than an honest one would, which is the opposite of
/// what a VPN client should be sending.
const spotifyUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

/// Why a Spotify sign-in failed, in the terms the screen has to explain.
///
/// Shaped after `MeowzicFailure` in `bridge.dart`, and for the same reason:
/// the screen must not be handed an exception message to render. These are
/// the four distinct things a user can actually do something about.
enum SpotifyAuthFailure {
  /// Nothing answered. Unlike the music bridge, Spotify is reached over the
  /// open internet, so this is "no connectivity" — or a censor — rather than
  /// "the VPN is off".
  unreachable,

  /// Spotify refused the cookie we hold. It expires, and it is also dropped
  /// when the password changes or the session is revoked from another device.
  /// Only signing in again fixes it.
  cookieExpired,

  /// Spotify minted a token, but an anonymous one — see [_mintToken].
  anonymous,

  /// Spotify answered with something this code cannot use.
  upstream,
}

class SpotifyAuthException implements Exception {
  const SpotifyAuthException(this.failure);

  final SpotifyAuthFailure failure;

  @override
  String toString() => 'SpotifyAuthException(${failure.name})';
}

/// A live Spotify web-player session.
///
/// The cookie jar is kept whole, not reduced to `sp_dc`. Minting a token needs
/// only that one, but the GraphQL endpoint is sent the lot, and a jar that has
/// been filtered down once cannot be un-filtered when the next endpoint turns
/// out to want `sp_t` as well.
class SpotifySession {
  const SpotifySession({
    required this.accessToken,
    required this.expiresAt,
    required this.cookies,
    this.clientId,
  });

  factory SpotifySession.fromJson(Map<String, dynamic> json) => SpotifySession(
        accessToken: json['accessToken'] as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          (json['expiresAt'] as num).toInt(),
        ),
        cookies: {
          for (final entry in (json['cookies'] as Map).entries)
            '${entry.key}': '${entry.value}',
        },
        clientId: json['clientId'] as String?,
      );

  final String accessToken;
  final DateTime expiresAt;

  /// Every cookie the webview held for `spotify.com`, by name.
  final Map<String, String> cookies;
  final String? clientId;

  String? get spDc => cookies['sp_dc'];

  /// The jar as a `Cookie:` header value.
  String get cookieHeader =>
      cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
        'cookies': cookies,
        'clientId': clientId,
      };
}

/// How early a token is considered spent.
///
/// The reference plugin schedules a timer for the exact expiry instant and
/// treats the token as good until then. On a phone that is wrong twice over:
/// the timer does not fire on time once the process is backgrounded or dozing,
/// and even when it does, a request that leaves at expiry-minus-one-second
/// arrives after it. Both were seen here as a session that looked signed in
/// and 401'd on everything. Five minutes is comfortably longer than any doze
/// wake-up delay this path can be caught by.
const spotifyRefreshMargin = Duration(minutes: 5);

/// Long enough for a cold TLS handshake to a censored-adjacent host, short
/// enough that a dead network does not hold the sign-in button hostage.
const _spotifyTimeout = Duration(seconds: 20);

/// Whether [session] still has a token worth sending.
bool isSpotifySessionUsable(SpotifySession? session) =>
    session != null &&
    session.expiresAt.subtract(spotifyRefreshMargin).isAfter(DateTime.now());

/// Mints a fresh access token for [cookies].
///
/// The retry is the reference plugin's, kept because it earns its keep: the
/// nuance rotates, and the copy we just read may already be the previous one.
/// A refused mint is therefore first assumed to be a stale secret and tried
/// once more against a cache-busted fetch, before it is reported as a dead
/// cookie.
Future<SpotifySession> mintSpotifySession({
  required Map<String, String> cookies,
  MeowzicBridge? bridge,
  http.Client? client,
}) async {
  final spDc = cookies['sp_dc'];
  if (spDc == null || spDc.isEmpty) {
    throw const SpotifyAuthException(SpotifyAuthFailure.cookieExpired);
  }

  final borrowed = client != null;
  final transport = client ?? http.Client();
  try {
    try {
      return await _attempt(
        transport,
        cookies: cookies,
        spDc: spDc,
        bridge: bridge,
        fresh: false,
      );
    } on SpotifyAuthException catch (error) {
      // Only a refusal is worth a second nuance. An unreachable host or an
      // anonymous token would fail exactly the same way again, and retrying
      // those would double the wait before the user is told anything.
      if (error.failure != SpotifyAuthFailure.cookieExpired) rethrow;
      return await _attempt(
        transport,
        cookies: cookies,
        spDc: spDc,
        bridge: bridge,
        fresh: true,
      );
    }
  } finally {
    if (!borrowed) transport.close();
  }
}

Future<SpotifySession> _attempt(
  http.Client transport, {
  required Map<String, String> cookies,
  required String spDc,
  required MeowzicBridge? bridge,
  required bool fresh,
}) async {
  final SpotifyNuance nuance;
  try {
    nuance = await fetchSpotifyNuance(
      bridge: bridge,
      fresh: fresh,
      client: transport,
    );
  } on FormatException catch (error) {
    throw _authFailure('nuance', error, SpotifyAuthFailure.upstream);
  } catch (error) {
    throw _authFailure('nuance', error, SpotifyAuthFailure.unreachable);
  }

  final otp = spotifyTotp(
    nuance.secret,
    timestampSeconds: await _serverTime(transport),
  );
  return _mintToken(
    transport,
    cookies: cookies,
    spDc: spDc,
    otp: otp,
    version: nuance.version,
  );
}

/// Spotify's own clock, in seconds.
///
/// Asked for rather than read off the device, because the OTP is validated
/// against this clock and a handset whose time is minutes out will produce a
/// perfectly well-formed code for the wrong window. That is not a rare edge:
/// a phone that has been powered off for a while is exactly the one somebody
/// opens the app on, and the resulting HTTP 400 is indistinguishable from an
/// expired cookie.
Future<int> _serverTime(http.Client transport) async {
  try {
    final response = await transport.get(
      Uri.parse('https://open.spotify.com/api/server-time'),
      headers: const {'User-Agent': spotifyUserAgent},
    ).timeout(_spotifyTimeout);
    if (response.statusCode != HttpStatus.ok) {
      throw _authFailure(
        'server-time',
        HttpException('status ${response.statusCode}'),
        SpotifyAuthFailure.upstream,
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final seconds = decoded is Map<String, dynamic> ? decoded['serverTime'] : null;
    if (seconds is! num) {
      throw _authFailure(
        'server-time',
        const FormatException('no serverTime'),
        SpotifyAuthFailure.upstream,
      );
    }
    return seconds.toInt();
  } on SpotifyAuthException {
    rethrow;
  } catch (error) {
    throw _authFailure('server-time', error, SpotifyAuthFailure.unreachable);
  }
}

/// The token call itself.
///
/// `totp` and `totpServer` carry the same value, and there is no `sTime` or
/// `cTime` — the shape was read off a live request, and Spotify rejects the
/// older four-parameter form.
Future<SpotifySession> _mintToken(
  http.Client transport, {
  required Map<String, String> cookies,
  required String spDc,
  required String otp,
  required int version,
}) async {
  final http.Response response;
  try {
    response = await transport.get(
      Uri.https('open.spotify.com', '/api/token', {
        'reason': 'transport',
        'productType': 'web-player',
        'totp': otp,
        'totpServer': otp,
        'totpVer': '$version',
      }),
      headers: {
        'Cookie': 'sp_dc=$spDc;',
        'User-Agent': spotifyUserAgent,
      },
    ).timeout(_spotifyTimeout);
  } catch (error) {
    throw _authFailure('token', error, SpotifyAuthFailure.unreachable);
  }

  // 400 "Unauthorized request" is what both a rotated nuance and a dead
  // cookie look like. Reported as the cookie, because the caller has already
  // spent its one retry on the nuance by the time this is final.
  if (response.statusCode != HttpStatus.ok) {
    throw _authFailure(
      'token',
      HttpException('status ${response.statusCode}'),
      SpotifyAuthFailure.cookieExpired,
    );
  }

  final decoded = jsonDecode(utf8.decode(response.bodyBytes));
  if (decoded is! Map<String, dynamic>) {
    throw const SpotifyAuthException(SpotifyAuthFailure.upstream);
  }

  // The improvement over the reference, and the reason this branch exists at
  // all: with no cookie — or a dead one — Spotify still answers 200 with a
  // working token, flagged anonymous. It plays previews and has no library,
  // so ignoring the flag buys a session that looks signed in and whose
  // library is permanently empty, with nothing on screen to explain why. We
  // presented a cookie; anonymous means it was not accepted.
  if (decoded['isAnonymous'] == true) {
    throw _authFailure(
      'token',
      const HttpException('200 with isAnonymous'),
      SpotifyAuthFailure.anonymous,
    );
  }

  final accessToken = decoded['accessToken'];
  final expiry = decoded['accessTokenExpirationTimestampMs'];
  if (accessToken is! String || accessToken.isEmpty || expiry is! num) {
    throw const SpotifyAuthException(SpotifyAuthFailure.upstream);
  }

  return SpotifySession(
    accessToken: accessToken,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(expiry.toInt()),
    cookies: cookies,
    clientId: decoded['clientId'] as String?,
  );
}

/// Writes down what actually went wrong before collapsing it into [failure].
///
/// The same trade `_transportFailure` makes in `bridge.dart`: the enum has
/// four values and this flow has three network hops, a JSON parse and a
/// signing step, so several genuinely different faults arrive at the user as
/// one sentence. Without this line a report of "просит войти заново" cannot
/// be told apart from a censored `open.spotify.com`, and the first such
/// report would be answered by guessing.
///
/// [stage] is named and not the URL: the token request carries the OTP and
/// the cookie header carries `sp_dc`, and neither belongs in a log the
/// support bundle collects — the same reasoning already written above
/// `searchMeowzic`.
SpotifyAuthException _authFailure(
  String stage,
  Object error,
  SpotifyAuthFailure failure,
) {
  commonPrint.log('spotify auth failed at $stage (${failure.name}): $error');
  return SpotifyAuthException(failure);
}
