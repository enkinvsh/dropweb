// Impure I/O loader for the «Игровой» (gaming) work mode descriptor.
//
// This is the fetch/cache glue between the pure `game_descriptor.dart`
// (parse + origin pin + last-good resolve) and the build-path wiring in
// `state.dart`. It is the ONLY gaming module allowed to do network/File I/O —
// `game_descriptor.dart` and `gaming_patch.dart` stay pure.
//
// Strategy (fail-closed, never throws): bounded fetch → parse → on success
// write the raw text to a last-good cache file; on ANY failure fall back to
// the cached file. A bad/slow remote payload must NEVER crash config build.

import 'dart:io';

import 'package:dropweb/common/game_descriptor.dart';
import 'package:dropweb/common/path.dart';
import 'package:dropweb/common/print.dart';
import 'package:dropweb/common/request.dart';

/// Bound for the descriptor fetch. The underlying `_clashDio` has NO timeout,
/// so an unbounded fetch could hang config build / connect — this cap is
/// MANDATORY.
const _gamingFetchTimeout = Duration(seconds: 6);

/// Loads (fetch-with-fallback-to-cache) the gaming [GameDescriptor] for [url].
///
/// Reuses the existing provider-cache infra: the raw descriptor text is cached
/// under the profile's providers dir in a `game` subdir keyed by the URL. On a
/// successful bounded fetch + parse the cache is refreshed; on ANY fetch/parse
/// failure the last-good cached text is parsed instead. Returns the resolved
/// descriptor (fresh preferred, else cached, else `null`). NEVER throws.
Future<GameDescriptor?> loadGameDescriptor({
  required Uri url,
  required String profileId,
}) async {
  final cachePath =
      await appPath.getProvidersFilePath(profileId, 'game', url.toString());

  GameDescriptor? fresh;
  try {
    final response = await request
        .getTextResponseForUrl(url.toString())
        .timeout(_gamingFetchTimeout);
    final body = (response.data as String?) ?? '';
    fresh = parseGameDescriptor(body);
    if (fresh != null) {
      try {
        final file = File(cachePath);
        await file.parent.create(recursive: true);
        await file.writeAsString(body);
      } catch (e) {
        commonPrint.log('[gaming] descriptor cache write failed: $e');
      }
    } else {
      commonPrint.log('[gaming] descriptor fetch parsed to null (bad payload)');
    }
  } catch (e) {
    commonPrint.log('[gaming] descriptor fetch failed: $e');
  }

  GameDescriptor? cached;
  if (fresh == null) {
    try {
      final file = File(cachePath);
      if (await file.exists()) {
        cached = parseGameDescriptor(await file.readAsString());
      }
    } catch (e) {
      commonPrint.log('[gaming] descriptor cache read failed: $e');
    }
  }

  return resolveGameDescriptor(fresh: fresh, cached: cached);
}
