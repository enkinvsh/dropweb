import 'dart:convert';
import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/views/meowzic/spotify/queries.dart';
import 'package:dropweb/views/meowzic/spotify/session.dart';
import 'package:http/http.dart' as http;

/// Who is signed in, as far as the screen needs to say it.
class SpotifyProfile {
  const SpotifyProfile({required this.name, this.username, this.avatarUrl});

  /// The display name, or whatever stood in for it.
  final String name;
  final String? username;
  final Uri? avatarUrl;
}

const _profileTimeout = Duration(seconds: 15);

/// Asks Spotify who the session belongs to, or null when it will not say.
///
/// Null is a normal answer, not an error, and the caller must treat it as one.
/// The query hash in `queries.dart` is a build artifact of Spotify's web player
/// that we do not control; the day they rotate it, this call breaks. If
/// authentication hung off it, a cosmetic detail — the name under "signed in"
/// — would be able to sign every user out. The token minted in `session.dart`
/// is the proof of life; this is only the label on it.
Future<SpotifyProfile?> fetchSpotifyProfile(
  SpotifySession session, {
  http.Client? client,
}) async {
  final borrowed = client != null;
  final transport = client ?? http.Client();
  try {
    final response = await transport
        .post(
          Uri.parse('https://api-partner.spotify.com/pathfinder/v2/query'),
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Cookie': session.cookieHeader,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': spotifyUserAgent,
          },
          body: jsonEncode({
            'variables': const <String, dynamic>{},
            'operationName': 'profileAttributes',
            'extensions': {
              'persistedQuery': {
                'version': 1,
                'sha256Hash': spotifyProfileAttributesHash,
              },
            },
          }),
        )
        .timeout(_profileTimeout);

    if (response.statusCode != HttpStatus.ok) {
      commonPrint.log('spotify profile answered ${response.statusCode}');
      return null;
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    final me = data is Map<String, dynamic> ? data['me'] : null;
    final profile = me is Map<String, dynamic> ? me['profile'] : null;
    if (profile is! Map<String, dynamic>) {
      commonPrint.log('spotify profile answered without data.me.profile');
      return null;
    }

    final name = profile['name'];
    final username = profile['username'];
    if (name is! String || name.isEmpty) return null;

    return SpotifyProfile(
      name: name,
      username: username is String && username.isNotEmpty ? username : null,
      avatarUrl: _firstAvatar(profile['avatar']),
    );
  } catch (error) {
    // Logged and swallowed. Nothing above this line changes its mind about
    // being signed in because a display name could not be fetched.
    commonPrint.log('spotify profile failed: $error');
    return null;
  } finally {
    if (!borrowed) transport.close();
  }
}

/// The first avatar Spotify offers.
///
/// Not the largest: the sources are ordered smallest-first and this is drawn
/// at avatar size, so anything past the first is bytes spent on pixels that
/// get scaled away.
Uri? _firstAvatar(Object? avatar) {
  if (avatar is! Map<String, dynamic>) return null;
  final sources = avatar['sources'];
  if (sources is! List) return null;
  for (final source in sources.whereType<Map<String, dynamic>>()) {
    final url = source['url'];
    if (url is String && url.isNotEmpty) return Uri.tryParse(url);
  }
  return null;
}
