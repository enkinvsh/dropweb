/// Strips sensitive parts from URL-like substrings in log text.
///
/// Subscription links, deep-link imports (`clash://install-config?url=...`,
/// `dropweb://install-config?url=...`), and arbitrary `http(s)://` URLs
/// frequently carry tokens in userinfo, query, or fragment. Those must
/// never reach `debugPrint`, the file logger, or the in-app log viewer
/// in clear text.
///
/// Scheme / host / port are preserved so logs stay debuggable; the path
/// keeps AT MOST its first segment (the rest becomes `/[REDACTED]`) because
/// subscription tokens often live in the path itself
/// (`https://panel.example/api/sub/<token>`). A dropweb subscription link is
/// `https://sub.dropweb.org/<token>` — a SINGLE segment that is itself the
/// credential — so single-segment paths are redacted too whenever they look
/// like a secret rather than a route name (see [_redactPath]). Credentials,
/// the entire query, and the fragment are replaced with `[REDACTED]`. URLs
/// that fail to parse fall back to `[URL_REDACTED]`.
///
/// `Authorization` and `Cookie` header lines are redacted as well: the same
/// credentials reach the log through request/response dumps, where they are
/// not part of any URL.
library;

// Match plausible URL substrings up to whitespace or common quote/angle
// delimiters. We do NOT attempt to strip trailing punctuation: in practice
// the call sites embed `Uri` values whose `toString()` never contains
// whitespace, quotes, or angles, so the match is exactly the URL.
final RegExp _urlPattern = RegExp(
  r'''(?:https?|clash|dropweb)://[^\s<>"']+''',
  caseSensitive: false,
);

// Matches the shape that `_sanitizeUrl` produces, anchored end-to-end. Used
// so a second sanitization pass on already-redacted output is a true no-op
// WITHOUT trusting the dangerous "raw substring contains [REDACTED]"
// shortcut — which an attacker can trivially trigger by injecting the marker
// into a query value (`?note=[REDACTED]&token=secret`) to bypass redaction.
//
// Components correspond 1:1 to `_sanitizeUrl`'s output: optional redacted
// userinfo (`[REDACTED]@`), a plain host (no brackets — IPv6 literals would
// fall through to a full re-sanitize), optional port, a path (empty, a single
// segment, or `/<segment>/[REDACTED]` — a deep path like `/api/sub/SECRET`
// deliberately does NOT match so it gets redacted), optional redacted query
// (`?[REDACTED]` and nothing else), and optional redacted fragment.
//
// The path is only SHAPE-checked here; whether it is genuinely safe is
// decided by [_redactPath] in [_isAlreadyRedacted], because a bare
// `https://sub.dropweb.org/<token>` fits this shape exactly.
final RegExp _alreadyRedactedShape = RegExp(
  r'^'
  r'(?:https?|clash|dropweb)://'
  r'(?:\[REDACTED\]@)?'
  r'[^\s/?#@\[\]]+'
  r'(?::\d+)?'
  r'(?<path>(?:/[^/?#\s]*(?:/\[REDACTED\])?)?)'
  r'(?:\?\[REDACTED\])?'
  r'(?:#\[REDACTED\])?'
  r'$',
  caseSensitive: false,
);

/// The literal marker emitted by this library. Recognising it is what keeps
/// a second sanitization pass a no-op instead of re-redacting our own output.
const String _redactedMarker = '[REDACTED]';

/// Single path segments that are never credentials and that support genuinely
/// needs to read in a diagnostics bundle. Compared case-insensitively.
const Set<String> _pathSegmentAllowlist = {
  'version',
  'manifest.json',
  'favicon.ico',
  'health',
};

/// Longest single path segment still assumed to be a route name rather than a
/// credential. Chosen so real diagnostic paths survive — `generate_204` (12,
/// the connectivity probe), `dns-query` (9), `downloads` (9) — while dropweb
/// and Remnawave subscription tokens (16+) do not.
const int _maxBenignSegmentLength = 12;

/// Credential-shaped segments that slip under [_maxBenignSegmentLength]: hex
/// and UUID fragments from 8 characters up. The second alternative is the
/// explicit opaque-token rule; it is subsumed by the length check today and
/// kept so the policy stays readable if that threshold ever moves.
final RegExp _tokenShapedSegment = RegExp(
  r'^[0-9a-fA-F-]{8,}$|^[A-Za-z0-9_-]{16,}$',
);

// HTTP credential headers reach the log through request/response dumps, not
// only through URLs. The value is consumed to the end of the LINE, not to the
// first whitespace: an `Authorization` value is `<scheme> <credentials>` and a
// `Cookie` value is a `;`-separated list, so stopping at whitespace would
// leave the secret itself in clear text. Consuming to the line break can
// swallow trailing diagnostics on a packed line — a deliberate trade, since a
// leaked bearer token is a credential and a lost `status=200` is a nuisance.
final RegExp _authorizationHeader = RegExp(
  r'(authorization:[ \t]*)[^\r\n]+',
  caseSensitive: false,
);

final RegExp _cookieHeader = RegExp(
  r'(cookie:[ \t]*)[^\r\n]+',
  caseSensitive: false,
);

/// Returns [text] with any URL substring of a known sensitive scheme
/// (`http`, `https`, `clash`, `dropweb`) rewritten so userinfo, path tokens,
/// query, and fragment never appear in clear text, and with `Authorization` /
/// `Cookie` header values replaced by `[REDACTED]`.
String redactUrls(String text) => _redactCredentialHeaders(
      text.replaceAllMapped(
        _urlPattern,
        (match) => _sanitizeUrl(match.group(0)!),
      ),
    );

String _redactCredentialHeaders(String text) => text
    .replaceAllMapped(
      _authorizationHeader,
      (match) => '${match.group(1)}$_redactedMarker',
    )
    .replaceAllMapped(
      _cookieHeader,
      (match) => '${match.group(1)}$_redactedMarker',
    );

/// True when [raw] is already exactly what [_sanitizeUrl] would emit.
///
/// The shape regex proves userinfo, query, and fragment are redacted; the
/// path is validated against the live policy instead of a hand-written
/// pattern, so the two can never drift apart. A false negative is harmless
/// (the URL is simply re-sanitized to the identical string); a false positive
/// would leak, which is exactly how `https://sub.dropweb.org/<token>` used to
/// slip through.
bool _isAlreadyRedacted(String raw) {
  final match = _alreadyRedactedShape.firstMatch(raw);
  if (match == null) {
    return false;
  }
  final path = match.namedGroup('path') ?? '';
  return _redactPath(path) == path;
}

String _sanitizeUrl(String raw) {
  // Idempotency: only short-circuit when the entire URL substring matches
  // the sanitizer's own exact output shape. A loose `contains('[REDACTED]')`
  // check would let an attacker bypass redaction by stuffing the marker
  // into a query value (`?note=[REDACTED]&token=secret`).
  if (_isAlreadyRedacted(raw)) {
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
  buffer.write(_redactPath(uri.path));
  if (uri.hasQuery) {
    buffer.write('?[REDACTED]');
  }
  if (uri.hasFragment) {
    buffer.write('#[REDACTED]');
  }
  return buffer.toString();
}

/// Redacts the sensitive tail of a URL path while keeping enough for
/// debuggability.
///
/// Remnawave-style subscription panels embed the secret token directly in
/// the PATH (`https://panel.example/api/sub/<token>`), so writing the path
/// verbatim leaks it. Policy for a MULTI-segment path: keep the first segment
/// and replace the remainder with `/[REDACTED]`.
///
/// A dropweb subscription link is `https://sub.dropweb.org/<token>` — one
/// segment, and that segment IS the user's credential. So a single-segment
/// path is redacted too unless [_isBenignSegment] clears it. Erring towards
/// keeping short route names is deliberate: this redactor feeds the support
/// bundle, and blinding `/version` or `/generate_204` would cost us the
/// diagnostics we ask users for.
///
/// The injected `[REDACTED]` stays within the path shape recognised by
/// [_alreadyRedactedShape], so a second sanitization pass is a true no-op.
String _redactPath(String path) {
  if (path.isEmpty || path == '/') {
    return path;
  }
  final meaningful = path.split('/').where((s) => s.isNotEmpty).toList();
  final leading = path.startsWith('/') ? '/' : '';
  if (meaningful.length <= 1) {
    final segment = meaningful.isEmpty ? '' : meaningful.first;
    return _isBenignSegment(segment) ? path : '$leading$_redactedMarker';
  }
  return '$leading${meaningful.first}/$_redactedMarker';
}

/// True when a lone path segment is a route name rather than a credential.
bool _isBenignSegment(String segment) =>
    segment == _redactedMarker ||
    _pathSegmentAllowlist.contains(segment.toLowerCase()) ||
    (segment.length <= _maxBenignSegmentLength &&
        !_tokenShapedSegment.hasMatch(segment));
