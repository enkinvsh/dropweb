import 'dart:convert';
import 'dart:io';

import 'package:dropweb/providers/state.dart';
import 'package:http/http.dart' as http;

/// The secret and version Spotify's web player currently signs tokens with.
///
/// Both halves travel together and neither is useful alone: the OTP is
/// computed from [secret], and `totpVer` tells Spotify which secret it was
/// computed from. Pairing them in one object is what stops a retry from
/// mixing a fresh secret with a stale version, which fails as an unhelpful
/// HTTP 400.
class SpotifyNuance {
  const SpotifyNuance({required this.secret, required this.version});

  /// Base32, fed to `spotifyTotp` as-is.
  final String secret;

  /// Sent as `totpVer`. Spotify rotates it; the newest is the one that works.
  final int version;
}

/// The community-maintained feed the reference plugin reads.
///
/// Load-bearing, not decorative: our own mirror is written but not deployed,
/// so on a device today this is the branch that actually runs.
const _gistUrl =
    'https://gist.githubusercontent.com/raw/22ed9c6ba463899e933427f7de1f0eef/nuances.json';

/// Short on purpose. This is one small JSON document standing between a tap
/// on "sign in" and any visible progress, and there is a second source to try
/// — waiting out a full-length timeout on the first would read as a hang.
const _nuanceTimeout = Duration(seconds: 10);

/// Fetches the current nuance: our mirror first, the public gist second.
///
/// Throws rather than returning null, and deliberately does not collapse the
/// reason into a `SpotifyAuthFailure`. That mapping belongs to the caller,
/// which
/// is the only place that knows whether the tunnel was up — the same division
/// `searchMeowzic` and `MeowzicSearch._explain` already keep.
///
/// [fresh] is passed through to both sources as a cache-buster.
Future<SpotifyNuance> fetchSpotifyNuance({
  MeowzicBridge? bridge,
  bool fresh = false,
  http.Client? client,
}) async {
  final borrowed = client != null;
  final transport = client ?? http.Client();
  try {
    if (bridge != null) {
      // The mirror is allowed to be absent or broken without taking sign-in
      // with it. It is an optimisation over the gist, not a prerequisite —
      // and while it is undeployed, every call here is expected to fail.
      final mirrored = await _tryMirror(transport, bridge, fresh: fresh);
      if (mirrored != null) return mirrored;
    }
    return await _fetchGist(transport, fresh: fresh);
  } finally {
    if (!borrowed) transport.close();
  }
}

Future<SpotifyNuance?> _tryMirror(
  http.Client transport,
  MeowzicBridge bridge, {
  required bool fresh,
}) async {
  try {
    final response = await transport
        .get(bridge.nuanceUri(fresh: fresh), headers: bridge.headers)
        .timeout(_nuanceTimeout);
    if (response.statusCode != HttpStatus.ok) return null;
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded is Map<String, dynamic> ? _parse(decoded) : null;
  } catch (error) {
    // Swallowed, not logged as a failure: the gist runs next and the user
    // sees nothing. `commonPrint` is skipped here for the same reason — until
    // the mirror is deployed this line would fire on every single sign-in,
    // and a log entry that is always present carries no information.
    return null;
  }
}

Future<SpotifyNuance> _fetchGist(
  http.Client transport, {
  required bool fresh,
}) async {
  final url = Uri.parse(_gistUrl);
  final response = await transport
      .get(
        fresh
            ? url.replace(queryParameters: {
                't': '${DateTime.now().millisecondsSinceEpoch}',
              })
            : url,
      )
      .timeout(_nuanceTimeout);
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('nuance gist answered ${response.statusCode}', uri: url);
  }

  final decoded = jsonDecode(utf8.decode(response.bodyBytes));
  if (decoded is! List) {
    throw const FormatException('nuance gist is not a list');
  }

  // Highest version wins. The file keeps its history, so the first entry is
  // the oldest — reading it would sign every request with a secret Spotify
  // retired months ago.
  SpotifyNuance? newest;
  for (final entry in decoded.whereType<Map<String, dynamic>>()) {
    final candidate = _parse(entry);
    if (candidate == null) continue;
    if (newest == null || candidate.version > newest.version) {
      newest = candidate;
    }
  }
  if (newest == null) {
    throw const FormatException('nuance gist held no usable entry');
  }
  return newest;
}

SpotifyNuance? _parse(Map<String, dynamic> json) {
  final secret = json['s'];
  final version = json['v'];
  if (secret is! String || secret.isEmpty || version is! num) return null;
  return SpotifyNuance(secret: secret, version: version.toInt());
}
