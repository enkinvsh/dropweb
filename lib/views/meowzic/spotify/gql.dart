import 'dart:async';
import 'dart:convert';
import 'dart:io';

// The narrow import rather than the `providers` barrel, matching `bridge.dart`
// and `session.dart` next door: the barrel exports notifiers that reach back
// into this directory, and a library cycle through a barrel is a needless
// thing to leave lying around.
import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/spotify.dart';
import 'package:dropweb/views/meowzic/spotify/session.dart';
import 'package:http/http.dart' as http;

/// The one endpoint the web player talks to.
///
/// Every operation — library, playlist contents, search, artist pages — is a
/// POST to this URL distinguished only by `operationName` and the persisted
/// hash. There is no per-feature path to get wrong.
const _spotifyGqlEndpoint =
    'https://api-partner.spotify.com/pathfinder/v2/query';

/// Comfortably longer than a healthy round trip, short enough that a censored
/// `api-partner.spotify.com` does not leave the tab spinning. Matched to the
/// profile call next door rather than to the bridge's thirty seconds: this is
/// a plain API read, not a cold catalogue lookup.
const _spotifyGqlTimeout = Duration(seconds: 15);

/// Why an authenticated Spotify query failed, in the terms the screen has to
/// explain.
///
/// Shaped after [SpotifyAuthFailure] and `MeowzicFailure`, and for the same
/// reason: the screen must not be handed an exception message to render. Note
/// that [signedOut] is not a fault — it is the honest answer when there is no
/// session left to query with, and the library tab renders it as the sign-in
/// prompt rather than as an error.
enum SpotifyGqlFailure {
  /// There is no session. Either nobody ever linked an account, or the refresh
  /// underneath us gave up and signed this one out.
  signedOut,

  /// Nothing answered. Spotify is reached over the open internet, so this is
  /// "no connectivity" — or a censor — rather than "the VPN is off".
  unreachable,

  /// Spotify refused the credentials, and refused them again after a fresh
  /// token was minted. Only a new login fixes it.
  rejected,

  /// Spotify answered with something this code cannot use — a non-200, a body
  /// that is not JSON, or a `data` block that is not there. A rotated
  /// persisted-query hash lands here; see `queries.dart`.
  upstream,
}

/// The sentence a [SpotifyGqlFailure] is shown as.
///
/// Kept here, next to the enum, rather than as a private switch on each screen.
/// The library grid and the detail screen sit one tap apart and can hit the
/// same fault a second apart; two private copies of this switch is how they
/// would end up giving that one fault two different names — the same reason
/// `MeowzicSearch._explain` insists one screen must not give two verdicts on
/// one fault depending on which button reached it.
///
/// [SpotifyGqlFailure.signedOut] and [SpotifyGqlFailure.rejected] end at the
/// same instruction — link the account again — and both say so, because the
/// difference between "there is no session" and "Spotify would not take it" is
/// ours to act on, not the listener's to understand.
String spotifyGqlFailureLabel(SpotifyGqlFailure failure) => switch (failure) {
      SpotifyGqlFailure.signedOut => appLocalizations.meowzicLibrarySignedOut,
      SpotifyGqlFailure.rejected => appLocalizations.meowzicLibraryRejected,
      SpotifyGqlFailure.unreachable =>
        appLocalizations.meowzicSpotifyUnreachable,
      SpotifyGqlFailure.upstream => appLocalizations.meowzicSpotifyUpstream,
    };

class SpotifyGqlException implements Exception {
  const SpotifyGqlException(this.failure);

  final SpotifyGqlFailure failure;

  @override
  String toString() => 'SpotifyGqlException(${failure.name})';
}

/// Runs one persisted query and returns its `data` block.
///
/// [notifier] rather than a [SpotifySession]: the token has to be re-mintable
/// mid-call (see below), and only the notifier owns the machinery that can do
/// that without racing a second one.
Future<Map<String, dynamic>> spotifyGqlQuery({
  required SpotifyAuth notifier,
  required String operationName,
  required String sha256Hash,
  required Map<String, dynamic> variables,
  http.Client? client,
}) async {
  final borrowed = client != null;
  final transport = client ?? http.Client();
  final body = jsonEncode({
    'variables': variables,
    'operationName': operationName,
    'extensions': {
      'persistedQuery': {'version': 1, 'sha256Hash': sha256Hash},
    },
  });

  try {
    var credentials = await notifier.credentials();
    if (credentials == null) {
      throw const SpotifyGqlException(SpotifyGqlFailure.signedOut);
    }

    var response = await _send(transport, credentials, body);

    // The one retry, and it is not a retry for flakiness. A token dies two
    // ways: it expires, which the refresh margin already covers, and it is
    // revoked — from another device, by a password change, by Spotify itself —
    // which nothing on this handset can predict. In that second case our copy
    // still looks minutes fresh, so without this branch the library would sit
    // there refusing to load with a token the app is convinced is good, until
    // the clock happened to run out. One forced re-mint answers it. Exactly
    // one: if a freshly minted token is refused too, the cookie behind it is
    // dead and looping would only spend handshakes on the way to the same
    // sentence.
    if (_isRefusal(response.statusCode)) {
      commonPrint.log(
        'spotify gql $operationName refused ${response.statusCode}, re-minting',
      );
      credentials = await notifier.credentials(forceRefresh: true);
      if (credentials == null) {
        throw const SpotifyGqlException(SpotifyGqlFailure.signedOut);
      }
      response = await _send(transport, credentials, body);
      if (_isRefusal(response.statusCode)) {
        throw _gqlFailure(
          operationName,
          HttpException('status ${response.statusCode} after refresh'),
          SpotifyGqlFailure.rejected,
        );
      }
    }

    if (response.statusCode != HttpStatus.ok) {
      throw _gqlFailure(
        operationName,
        HttpException('status ${response.statusCode}'),
        SpotifyGqlFailure.upstream,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    if (data is! Map<String, dynamic>) {
      // GraphQL answers 200 with `errors` and no `data` for a rotated hash,
      // which is the single most likely way this breaks — so the error list is
      // worth writing down rather than collapsing silently. It carries query
      // names and messages, never credentials.
      final errors = decoded is Map<String, dynamic> ? decoded['errors'] : null;
      throw _gqlFailure(
        operationName,
        FormatException('no data block${errors == null ? '' : ': $errors'}'),
        SpotifyGqlFailure.upstream,
      );
    }
    return data;
  } on SpotifyGqlException {
    rethrow;
  } on SocketException catch (error) {
    throw _gqlFailure(operationName, error, SpotifyGqlFailure.unreachable);
  } on TimeoutException catch (error) {
    throw _gqlFailure(operationName, error, SpotifyGqlFailure.unreachable);
  } on http.ClientException catch (error) {
    throw _gqlFailure(operationName, error, SpotifyGqlFailure.unreachable);
  } on FormatException catch (error) {
    throw _gqlFailure(operationName, error, SpotifyGqlFailure.upstream);
  } finally {
    if (!borrowed) transport.close();
  }
}

/// Whether [status] means "these credentials are no good".
///
/// 403 counts alongside 401 because Spotify uses it for a token that is
/// structurally valid and no longer entitled — an anonymous token that lost
/// its account, most of all — and that is exactly the state a re-mint fixes.
bool _isRefusal(int status) =>
    status == HttpStatus.unauthorized || status == HttpStatus.forbidden;

Future<http.Response> _send(
  http.Client transport,
  SpotifyCredentials credentials,
  String body,
) =>
    transport
        .post(
          Uri.parse(_spotifyGqlEndpoint),
          headers: {
            'Authorization': 'Bearer ${credentials.accessToken}',
            'Cookie': credentials.cookieHeader,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': spotifyUserAgent,
          },
          body: body,
        )
        .timeout(_spotifyGqlTimeout);

/// Writes down what actually went wrong before collapsing it into [failure].
///
/// The same trade `_authFailure` makes in `session.dart` and `_transportFailure`
/// in `bridge.dart`: four enum values have to cover a rotated query hash, a
/// censored host, a dead cookie and a malformed body, so several genuinely
/// different faults reach the user as one sentence. Without this line a report
/// of "Spotify ответил чем-то непонятным" cannot be told apart from a hash
/// rotation, and the first such report would be answered by guessing.
///
/// [operation] is the GraphQL operation name and nothing else. The bearer, the
/// cookie header and the request body stay out of it deliberately — a support
/// bundle collects these logs, and one of those three is a working key to
/// somebody's account.
SpotifyGqlException _gqlFailure(
  String operation,
  Object error,
  SpotifyGqlFailure failure,
) {
  commonPrint.log('spotify gql $operation failed (${failure.name}): $error');
  return SpotifyGqlException(failure);
}
