/// Pure, I/O-free detector for a subscription URL pasted into the clipboard.
///
/// The «дурачок» onboarding path (T29) reads the clipboard once when the Add
/// sheet opens and offers a one-tap import when the clipboard holds a
/// subscription string. This helper decides whether a given clipboard string
/// IS such a subscription and, if so, returns the plain `http`/`https` URL that
/// [AppController.addProfileFormURL] accepts.
///
/// Accepted shapes (mirrors [LinkManager] deep-link parsing in `link.dart`):
///   * `http(s)://host/...`                         → returned as-is (trimmed)
///   * `clash://install-config?url=<inner>`          → the inner URL, if it is
///   * `dropweb://install-config?url=<inner>`         itself a valid http(s) URL
///
/// Everything else (random text, bare tokens, `vmess://…`, an install-config
/// wrapper with no/invalid `url`) returns `null` so the UI never makes a false
/// offer. The wrapper schemes must be unwrapped here because
/// `addProfileFormURL` only accepts `http`/`https` and rejects the wrapper.
String? extractSubscriptionUrl(String? clip) {
  if (clip == null) return null;
  final trimmed = clip.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;

  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'http' || scheme == 'https') {
    return uri.host.isNotEmpty ? trimmed : null;
  }

  if ((scheme == 'clash' || scheme == 'dropweb') &&
      uri.host == 'install-config') {
    final inner = uri.queryParameters['url'];
    if (inner == null || inner.trim().isEmpty) return null;
    // The inner URL must itself be a plain http(s) subscription; recurse so a
    // wrapper carrying garbage (e.g. `?url=vmess://…`) makes no false offer.
    return extractSubscriptionUrl(inner);
  }

  return null;
}
