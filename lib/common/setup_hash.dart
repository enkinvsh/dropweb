import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Computes a stable content hash over the inputs that actually affect the
/// expensive core config setup pipeline (Go YAML read → JSON → Dart map patch →
/// JSON → Go ParseRawConfig/ApplyConfig).
///
/// The hash lets `AppController.setupClashConfig` skip a redundant full setup
/// when nothing relevant changed. It deliberately excludes:
///   * `selectedMap` — proxy selection is applied separately via `changeProxy`
///     and must not invalidate the full-setup cache.
///   * theme / UI state — noise that would defeat the cache.
///
/// The hash is order-insensitive: maps with the same entries in any insertion
/// order produce the same hash (keys are sorted recursively before encoding).
String computeSetupHash({
  required String profileId,
  required DateTime? profileFileLastModified,
  required int profileFileLength,
  required Map<String, dynamic> patchConfigJson,
  required Map<String, dynamic> overrideDataJson,
  required Map<String, dynamic> appFlagsJson,
}) {
  final payload = <String, dynamic>{
    'profileId': profileId,
    'profileFileLastModified':
        profileFileLastModified?.microsecondsSinceEpoch,
    'profileFileLength': profileFileLength,
    'patchConfigJson': patchConfigJson,
    'overrideDataJson': overrideDataJson,
    'appFlagsJson': appFlagsJson,
  };
  final canonical = jsonEncode(_canonicalize(payload));
  return md5.convert(utf8.encode(canonical)).toString();
}

/// Recursively sorts map keys so that logically-equal structures encode to an
/// identical byte sequence regardless of insertion order. Lists preserve order
/// (sequence is semantically significant, e.g. rule ordering).
Object? _canonicalize(Object? value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
    return {
      for (final key in sortedKeys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalize).toList();
  }
  return value;
}
