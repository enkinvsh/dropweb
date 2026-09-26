/// Pure diagnostics core for the developer screen and the adb remote.
///
/// Everything here is side-effect free and takes its inputs as parameters (no
/// globals), so the redaction contract is locked by
/// `test/common/diagnostics_test.dart`. File IO lives in
/// `lib/services/diagnostics_service.dart`.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dropweb/common/log_redaction.dart';

const String diagnosticsRedacted = '[REDACTED]';

/// Keys whose VALUE is a credential at any depth of a mihomo config. Compared
/// case-insensitively; the whole value (scalar, list or map) is replaced.
const Set<String> diagnosticsSecretKeys = {
  'uuid',
  'password',
  'private-key',
  'pre-shared-key',
  'auth',
  'auth-str',
  'auth_str',
  'obfs-password',
  'psk',
  'token',
  'short-id',
  'public-key',
  'username',
  'secret',
  'authentication',
  'certificate',
  'private-key-passphrase',
};

/// Stable short token for a proxy `server` value: the same host always maps to
/// the same token (within and across runs), distinct hosts almost surely
/// differ. Lets support correlate nodes without learning the address.
String diagnosticsServerToken(String server) {
  final digest = sha1.convert(utf8.encode(server.trim().toLowerCase()));
  return 'srv-${digest.toString().substring(0, 6)}';
}

/// Deep-copied, redacted view of the effective core config. The input is NOT
/// mutated. See [diagnosticsSecretKeys] for what is blanked; `server` values
/// anywhere under top-level `proxies` are hashed via [diagnosticsServerToken];
/// every string goes through [redactUrls]; everything else is kept verbatim.
Map<String, dynamic> redactConfigForDiagnostics(Map<String, dynamic> config) {
  final out = <String, dynamic>{};
  config.forEach((key, value) {
    out[key] = _redactEntry(key, value, inProxies: key == 'proxies');
  });
  return out;
}

dynamic _redactEntry(String key, dynamic value, {required bool inProxies}) {
  if (diagnosticsSecretKeys.contains(key.toLowerCase())) {
    return diagnosticsRedacted;
  }
  if (inProxies && key == 'server' && value is String) {
    return diagnosticsServerToken(value);
  }
  return _redactValue(value, inProxies: inProxies);
}

dynamic _redactValue(dynamic value, {required bool inProxies}) {
  if (value is Map) {
    final out = <String, dynamic>{};
    value.forEach((k, v) {
      final key = k.toString();
      out[key] = _redactEntry(key, v, inProxies: inProxies);
    });
    return out;
  }
  if (value is List) {
    return value.map((v) => _redactValue(v, inProxies: inProxies)).toList();
  }
  if (value is String) {
    return redactUrls(value);
  }
  return value;
}

/// Bare API keys in header values (e.g. `dropweb-music: <32 hex>,<url>`).
final RegExp _bareHexKey = RegExp(r'\b[0-9a-fA-F]{32,}\b');

/// Subscription response headers with URL tokens and bare hex keys redacted;
/// keys kept.
Map<String, String> redactHeadersForDiagnostics(Map<String, String> headers) =>
    {
      for (final entry in headers.entries)
        entry.key: redactUrls(entry.value)
            .replaceAll(_bareHexKey, diagnosticsRedacted),
    };

class DiagnosticsMember {
  const DiagnosticsMember({required this.name, this.delay});

  final String name;

  /// Last known delay: null/0 = not measured, < 0 = timeout, > 0 = ms.
  final int? delay;
}

class DiagnosticsGroup {
  const DiagnosticsGroup({
    required this.name,
    required this.type,
    this.now,
    this.members = const [],
  });

  final String name;
  final String type;
  final String? now;
  final List<DiagnosticsMember> members;
}

/// `name: 120 ms` / `name: timeout` / `name: -`.
String formatDiagnosticsDelay(int? delay) {
  if (delay == null || delay == 0) return '-';
  if (delay < 0) return 'timeout';
  return '$delay ms';
}

String _encodePretty(Object? value) =>
    JsonEncoder.withIndent('  ', (o) => o.toString()).convert(value);

/// Full plain-text diagnostics report. Every free-form string is passed
/// through [redactUrls]; the config through [redactConfigForDiagnostics].
String buildDiagnosticsText({
  required DateTime now,
  required String appVersion,
  required bool isPlayBuild,
  required bool isDebug,
  int? androidSdk,
  required Map<String, Object?> status,
  required List<DiagnosticsGroup> groups,
  required Map<String, String> headers,
  String? profileUrl,
  DateTime? lastSetupAt,
  Map<String, dynamic>? effectiveConfig,
  required List<String> logLines,
}) {
  final b = StringBuffer()
    ..writeln('=== dropweb diagnostics ===')
    ..writeln('time: ${now.toIso8601String()}')
    ..writeln('app: $appVersion')
    ..writeln('isPlayBuild: $isPlayBuild')
    ..writeln('isDebug: $isDebug');
  if (androidSdk != null) b.writeln('androidSdk: $androidSdk');
  b
    ..writeln()
    ..writeln('--- status ---')
    ..writeln(redactUrls(_encodePretty(status)))
    ..writeln()
    ..writeln('--- groups ---');
  if (groups.isEmpty) b.writeln('(none)');
  for (final group in groups) {
    b.writeln(redactUrls(
      '${group.name} [${group.type}] now=${group.now ?? '-'} '
      'members=${group.members.length}',
    ));
    for (final member in group.members) {
      b.writeln(redactUrls(
        '  ${member.name}: ${formatDiagnosticsDelay(member.delay)}',
      ));
    }
  }
  b
    ..writeln()
    ..writeln('--- subscription headers (redacted) ---');
  final redactedHeaders = redactHeadersForDiagnostics(headers);
  if (redactedHeaders.isEmpty) b.writeln('(none)');
  for (final entry in redactedHeaders.entries) {
    b.writeln('${entry.key}: ${entry.value}');
  }
  b
    ..writeln()
    ..writeln('profileUrl: ${redactUrls(profileUrl ?? '-')}')
    ..writeln('lastSetupAt: ${lastSetupAt?.toIso8601String() ?? '-'}')
    ..writeln()
    ..writeln('--- effective config (redacted) ---');
  if (effectiveConfig == null) {
    b.writeln('(no core setup yet)');
  } else {
    b.writeln(_encodePretty(redactConfigForDiagnostics(effectiveConfig)));
  }
  b
    ..writeln()
    ..writeln('--- last 300 logs ---');
  final tail = logLines.length > 300
      ? logLines.sublist(logLines.length - 300)
      : logLines;
  for (final line in tail) {
    b.writeln(redactUrls(line));
  }
  return b.toString();
}

String _two(int v) => v.toString().padLeft(2, '0');

/// `yyyyMMdd-HHmmss` in the given [time]'s own zone.
String diagnosticsTimestamp(DateTime time) =>
    '${time.year.toString().padLeft(4, '0')}${_two(time.month)}'
    '${_two(time.day)}-${_two(time.hour)}${_two(time.minute)}'
    '${_two(time.second)}';

final RegExp _timestampedDiag = RegExp(r'^diag-\d{8}-\d{6}\.txt$');

/// Timestamped `diag-*.txt` names to delete so at most [keep] remain (oldest
/// first). `diag-latest.txt` and other files are never returned.
List<String> diagFilesToPrune(List<String> names, {int keep = 5}) {
  final stamped = names.where(_timestampedDiag.hasMatch).toList()..sort();
  if (stamped.length <= keep) return const [];
  return stamped.sublist(0, stamped.length - keep);
}
