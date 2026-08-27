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
/// a plain API read, not a cold catalogue lookup. The same ceiling covers the
/// `spclient.wg.spotify.com` calls, which are the same kind of read against the
/// same kind of host.
const _spotifyTimeout = Duration(seconds: 15);

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
/// mid-call (see [_sendAuthorized]), and only the notifier owns the machinery
/// that can do that without racing a second one.
///
/// [mutation] tightens what counts as an answer, and is off by default because
/// the read callers depend on it being off — see [_readMutationResult].
Future<Map<String, dynamic>> spotifyGqlQuery({
  required SpotifyAuth notifier,
  required String operationName,
  required String sha256Hash,
  required Map<String, dynamic> variables,
  bool mutation = false,
  http.Client? client,
}) async {
  final decoded = await _sendAuthorized(
    notifier: notifier,
    operation: 'gql $operationName',
    uri: Uri.parse(_spotifyGqlEndpoint),
    body: jsonEncode({
      'variables': variables,
      'operationName': operationName,
      'extensions': {
        'persistedQuery': {'version': 1, 'sha256Hash': sha256Hash},
      },
    }),
    client: client,
  );

  final envelope =
      decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
  final data = envelope['data'];
  if (data is! Map<String, dynamic>) {
    // GraphQL answers 200 with `errors` and no `data` for a rotated hash,
    // which is the single most likely way this breaks — so the error list is
    // worth writing down rather than collapsing silently. It carries query
    // names and messages, never credentials.
    final errors = envelope['errors'];
    throw _gqlFailure(
      'gql $operationName',
      FormatException('no data block${errors == null ? '' : ': $errors'}'),
      SpotifyGqlFailure.upstream,
    );
  }

  if (mutation) _readMutationResult(operationName, envelope);
  return data;
}

/// Fetches an authenticated Spotify REST endpoint and returns the decoded body.
///
/// The internal `spclient.wg.spotify.com` services — track radio, most of all —
/// are plain GETs rather than pathfinder operations, but they sit behind the
/// same web token, go down with the same censored connection and die with the
/// same revoked cookie. They therefore run through the same envelope as
/// [spotifyGqlQuery]: the same headers, the same single forced re-mint, the
/// same four [SpotifyGqlFailure] verdicts.
///
/// The body comes back as decoded JSON rather than a `Map`, because these
/// endpoints are not one shape — the caller checks what it got, the way the
/// parsers in this directory already do.
Future<Object?> spotifyRestGet({
  required SpotifyAuth notifier,
  required Uri uri,
  http.Client? client,
}) =>
    _sendAuthorized(
      notifier: notifier,
      operation: 'rest ${uri.path}',
      uri: uri,
      client: client,
    );

/// Refuses a mutation that only *looks* like it worked.
///
/// A read can live with a partial answer: `libraryV3` losing one facet still
/// fills the grid, and failing the whole screen over it would be worse than
/// showing what came back. A mutation cannot. Spotify reports a rotated hash or
/// a rejected write as HTTP 200 carrying an `errors` list beside a `data` whose
/// own result node is null, so tolerating that here means the heart fills in,
/// the listener believes the track is saved, and nothing was written to their
/// account. That silent lie is the whole reason this check exists, and the
/// reason it is opt-in rather than applied to every call: the read callers ship
/// today against the tolerant behaviour and must keep it.
///
/// `errors` is the ONLY thing checked, and that is a correction paid for on a
/// live device: the first version of this also demanded a result node named
/// after the operation, and it rejected a like that Spotify had actually
/// accepted — `spotify gql addToLibrary failed (upstream): mutation returned no
/// result node`, with an empty `errors` beside it.
///
/// There is no result-node contract to lean on. Spotify's own recorded
/// responses disagree with each other for the SAME operation name:
///   addToLibrary on a track    -> {"data": {"addToLibrary": {...}}}
///   addToLibrary on an artist  -> {"data": {"addLibraryItems": {...}}}
///   removeFromLibrary          -> {"data": {"removeLibraryItems": {...}}}
///   addToPlaylist              -> {"data": {"addItemsToPlaylist": {...}}}
///   saving an album            -> {}                     — no `data` at all
/// The node is a field of the registered document, which Spotify rotates
/// independently of the operation name we send, so any table of expected names
/// is a future false failure waiting for a rotation. A rotated or unknown hash
/// is reported the honest way regardless — as a non-empty `errors` — which is
/// exactly the case this guard exists to catch.
void _readMutationResult(
  String operationName,
  Map<String, dynamic> envelope,
) {
  final errors = envelope['errors'];
  if (errors is List && errors.isNotEmpty) {
    throw _gqlFailure(
      'gql $operationName',
      FormatException('mutation returned errors: $errors'),
      SpotifyGqlFailure.upstream,
    );
  }
}

/// One authorized round trip to Spotify, decoded, with the retry and the
/// verdicts that every call to them needs.
///
/// [body] decides the method: `null` sends a GET, anything else a POST of that
/// string. [operation] is a label for the log and nothing more.
Future<Object?> _sendAuthorized({
  required SpotifyAuth notifier,
  required String operation,
  required Uri uri,
  String? body,
  http.Client? client,
}) async {
  final borrowed = client != null;
  final transport = client ?? http.Client();

  try {
    var credentials = await notifier.credentials();
    if (credentials == null) {
      throw const SpotifyGqlException(SpotifyGqlFailure.signedOut);
    }

    var response = await _send(transport, credentials, uri, body);

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
        'spotify $operation refused ${response.statusCode}, re-minting',
      );
      credentials = await notifier.credentials(forceRefresh: true);
      if (credentials == null) {
        throw const SpotifyGqlException(SpotifyGqlFailure.signedOut);
      }
      response = await _send(transport, credentials, uri, body);
      if (_isRefusal(response.statusCode)) {
        throw _gqlFailure(
          operation,
          HttpException('status ${response.statusCode} after refresh'),
          SpotifyGqlFailure.rejected,
        );
      }
    }

    if (response.statusCode != HttpStatus.ok) {
      throw _gqlFailure(
        operation,
        HttpException('status ${response.statusCode}'),
        SpotifyGqlFailure.upstream,
      );
    }

    return jsonDecode(utf8.decode(response.bodyBytes));
  } on SpotifyGqlException {
    rethrow;
  } on SocketException catch (error) {
    throw _gqlFailure(operation, error, SpotifyGqlFailure.unreachable);
  } on TimeoutException catch (error) {
    throw _gqlFailure(operation, error, SpotifyGqlFailure.unreachable);
  } on http.ClientException catch (error) {
    throw _gqlFailure(operation, error, SpotifyGqlFailure.unreachable);
  } on FormatException catch (error) {
    throw _gqlFailure(operation, error, SpotifyGqlFailure.upstream);
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
  Uri uri,
  String? body,
) {
  final headers = {
    'Authorization': 'Bearer ${credentials.accessToken}',
    'Cookie': credentials.cookieHeader,
    'Accept': 'application/json',
    'User-Agent': spotifyUserAgent,
  };
  // The bearer and the cookie are what `spclient.wg.spotify.com` wants too —
  // only the content type is specific to sending a GraphQL body, so it is added
  // rather than declared on a request that carries nothing.
  final sent = body == null
      ? transport.get(uri, headers: headers)
      : transport.post(
          uri,
          headers: {...headers, 'Content-Type': 'application/json'},
          body: body,
        );
  return sent.timeout(_spotifyTimeout);
}

/// Writes down what actually went wrong before collapsing it into [failure].
///
/// The same trade `_authFailure` makes in `session.dart` and `_transportFailure`
/// in `bridge.dart`: four enum values have to cover a rotated query hash, a
/// censored host, a dead cookie and a malformed body, so several genuinely
/// different faults reach the user as one sentence. Without this line a report
/// of "Spotify ответил чем-то непонятным" cannot be told apart from a hash
/// rotation, and the first such report would be answered by guessing.
///
/// [operation] is the operation label and nothing else — `gql <operationName>`
/// or `rest <path>`. The bearer, the cookie header and the request body stay
/// out of it deliberately — a support bundle collects these logs, and one of
/// those three is a working key to somebody's account.
SpotifyGqlException _gqlFailure(
  String operation,
  Object error,
  SpotifyGqlFailure failure,
) {
  commonPrint.log('spotify gql $operation failed (${failure.name}): $error');
  return SpotifyGqlException(failure);
}
