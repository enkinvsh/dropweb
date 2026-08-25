import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dropweb/providers/providers.dart';
import 'package:http/http.dart' as http;

/// One track, as the bridge describes it.
class MeowzicTrack {
  const MeowzicTrack({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    this.thumbnail,
  });

  factory MeowzicTrack.fromJson(Map<String, dynamic> json) => MeowzicTrack(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '',
        author: (json['author'] as String?) ?? '',
        duration: Duration(seconds: (json['duration'] as num?)?.toInt() ?? 0),
        thumbnail: switch (json['thumbnail']) {
          final String raw when raw.isNotEmpty => Uri.tryParse(raw),
          _ => null,
        },
      );

  /// The YouTube id — and what `MediaItem.id` carries, deliberately in place
  /// of the audio URL.
  final String id;
  final String title;
  final String author;
  final Duration duration;

  /// Cover art, served straight from YouTube's CDN rather than through the
  /// bridge. It therefore loads only while the tunnel is up, which is also
  /// the only time anything here is playable.
  final Uri? thumbnail;
}

/// Why a bridge call failed, in the terms the screen has to explain.
enum MeowzicFailure {
  /// Nothing answered. The bridge is reachable only through the tunnel, so
  /// this is overwhelmingly "the VPN is off" rather than "the bridge is down".
  unreachable,

  /// The bridge refused the token. It rotates on the panel, and a client
  /// learns the new one only when its subscription refreshes.
  rejected,

  /// The bridge answered, but not with anything usable.
  upstream,
}

class MeowzicException implements Exception {
  const MeowzicException(this.failure);

  final MeowzicFailure failure;

  @override
  String toString() => 'MeowzicException(${failure.name})';
}

/// Longer than a normal API call on purpose: the bridge caches results for
/// six hours, but a cold query runs a live YT Music lookup and can fall
/// through to yt-dlp on the open catalogue.
const _searchTimeout = Duration(seconds: 30);

/// Asks the bridge for tracks matching [query].
///
/// The token rides in a header, so the request URI holds no secret and is
/// safe to log or surface in an error.
Future<List<MeowzicTrack>> searchMeowzic(
  MeowzicBridge bridge,
  String query, {
  http.Client? client,
}) async {
  final borrowed = client != null;
  final transport = client ?? http.Client();
  try {
    final response = await transport
        .get(bridge.searchUri(query), headers: bridge.headers)
        .timeout(_searchTimeout);

    if (response.statusCode == HttpStatus.forbidden) {
      throw const MeowzicException(MeowzicFailure.rejected);
    }
    if (response.statusCode != HttpStatus.ok) {
      throw const MeowzicException(MeowzicFailure.upstream);
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const MeowzicException(MeowzicFailure.upstream);
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .where((json) => json['id'] is String)
        .map(MeowzicTrack.fromJson)
        .toList();
  } on MeowzicException {
    rethrow;
  } on SocketException {
    throw const MeowzicException(MeowzicFailure.unreachable);
  } on TimeoutException {
    throw const MeowzicException(MeowzicFailure.unreachable);
  } on http.ClientException {
    throw const MeowzicException(MeowzicFailure.unreachable);
  } on FormatException {
    throw const MeowzicException(MeowzicFailure.upstream);
  } finally {
    if (!borrowed) transport.close();
  }
}
