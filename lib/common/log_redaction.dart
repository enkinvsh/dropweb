/// Strips sensitive parts from URL-like substrings in log text.
///
/// Subscription links, deep-link imports (`clash://install-config?url=...`,
/// `dropweb://install-config?url=...`), and arbitrary `http(s)://` URLs
/// frequently carry tokens in userinfo, query, or fragment. Those must
/// never reach `debugPrint`, the file logger, or the in-app log viewer
/// in clear text.
///
/// Scheme / host / port / path are preserved so logs stay debuggable
/// (e.g. `https://api.github.com/repos/.../releases/latest` remains
/// readable); credentials, the entire query, and the fragment are
/// replaced with `[REDACTED]`. URLs that fail to parse fall back to
/// `[URL_REDACTED]`.
library;

// Match plausible URL substrings up to whitespace or common quote/angle
// delimiters. We do NOT attempt to strip trailing punctuation: in practice
// the call sites embed `Uri` values whose `toString()` never contains
// whitespace, quotes, or angles, so the match is exactly the URL.
final RegExp _urlPattern = RegExp(
  r'''(?:https?|clash|dropweb)://[^\s<>"']+''',
  caseSensitive: false,
);

// Matches the EXACT shape that `_sanitizeUrl` produces, anchored end-to-end.
// Used so a second sanitization pass on already-redacted output is a true
// no-op WITHOUT trusting the dangerous "raw substring contains [REDACTED]"
// shortcut — which an attacker can trivially trigger by injecting the marker
// into a query value (`?note=[REDACTED]&token=secret`) to bypass redaction.
//
// Components correspond 1:1 to `_sanitizeUrl`'s output: optional redacted
// userinfo (`[REDACTED]@`), a plain host (no brackets — IPv6 literals would
// fall through to a full re-sanitize), optional port, optional path,
// optional redacted query (`?[REDACTED]` and nothing else), and optional
// redacted fragment (`#[REDACTED]` and nothing else).
final RegExp _alreadyRedactedShape = RegExp(
  r'^'
  r'(?:https?|clash|dropweb)://'
  r'(?:\[REDACTED\]@)?'
  r'[^\s/?#@\[\]]+'
  r'(?::\d+)?'
  r'(?:/[^?#\s]*)?'
  r'(?:\?\[REDACTED\])?'
  r'(?:#\[REDACTED\])?'
  r'$',
  caseSensitive: false,
);

/// Returns [text] with any URL substring of a known sensitive scheme
/// (`http`, `https`, `clash`, `dropweb`) rewritten so userinfo, query,
/// and fragment never appear in clear text.
String redactUrls(String text) =>
    text.replaceAllMapped(_urlPattern, (match) => _sanitizeUrl(match.group(0)!));

String _sanitizeUrl(String raw) {
  // Idempotency: only short-circuit when the entire URL substring matches
  // the sanitizer's own exact output shape. A loose `contains('[REDACTED]')`
  // check would let an attacker bypass redaction by stuffing the marker
  // into a query value (`?note=[REDACTED]&token=secret`).
  if (_alreadyRedactedShape.hasMatch(raw)) {
    return raw;
  }
  Uri uri;
  try {
    uri = Uri.parse(raw);
  } catch (_) {
    return '[URL_REDACTED]';
  }
  if (!uri.hasScheme) {
    return '[URL_REDACTED]';
  }

  final buffer = StringBuffer()
    ..write(uri.scheme)
    ..write('://');
  if (uri.userInfo.isNotEmpty) {
    buffer.write('[REDACTED]@');
  }
  buffer.write(uri.host);
  if (uri.hasPort) {
    buffer
      ..write(':')
      ..write(uri.port);
  }
  buffer.write(uri.path);
  if (uri.hasQuery) {
    buffer.write('?[REDACTED]');
  }
  if (uri.hasFragment) {
    buffer.write('#[REDACTED]');
  }
  return buffer.toString();
}
