import 'dart:async';

import 'package:dropweb/common/package.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cabinet_home_adapter.dart';
import 'cabinet_home_data.dart';

/// Allowed host for the zencab WebView shell. ONLY this host may load the
/// main frame, run JavaScript, and call native bridge handlers.
const String _zencabHost = 'cab.dropweb.org';

/// Stable user-agent marker that keeps zencab in app mode after internal
/// navigations that lose the `?surface=dropweb_android` query parameter.
/// Detector on the zencab side recognises this token; do not rename.
const String _dropwebUaMarker = 'DropwebApp/Android';

/// Required query parameter that initially flips zencab into app mode.
/// Caller-supplied query parameters MUST NOT override this.
const String _surfaceParam = 'surface';
const String _surfaceValue = 'dropweb_android';

/// Root for support routes. Only `/support` and `/support/...` are accepted
/// for the `openSupport` bridge handler.
const String _supportRoot = '/support';

/// Allowed payment/top-up/checkout route prefixes mirroring the existing
/// zencab `App.tsx` routes. Absolute URLs and any path outside this list
/// MUST be rejected. Keep this list conservative — every entry below maps
/// to a real `<Route>` in zencab; never broaden without confirming a real
/// route exists.
const List<String> _safePaymentExactPaths = <String>[
  '/balance',
  '/subscription/purchase',
];

/// Allowed prefixes for payment routes. A path is accepted when it equals
/// `prefix` or starts with `prefix/`.
const List<String> _safePaymentPrefixes = <String>[
  '/balance/',
  '/buy/',
];

/// Suffix-based match for renew routes shaped like `/subscriptions/{id}/renew`.
const String _renewPathPrefix = '/subscriptions/';
const String _renewPathSuffix = '/renew';

/// Required prefix for the Telegram bot login `start` payload. The Telegram
/// Login bot ignores any other prefix, so accepting only `webauth_...` keeps
/// the external handoff scoped to the auth flow we control.
const String _telegramLoginStartPrefix = 'webauth_';

/// Charset for the bot username (`domain` query) on `tg://resolve`. Telegram
/// usernames are 5–32 ASCII alphanumerics or underscores; we widen to 1–64
/// purely defensively — anything else is rejected so we cannot be tricked
/// into encoding a path or scheme inside the domain.
final RegExp _telegramDomainPattern = RegExp(r'^[A-Za-z0-9_]{1,64}$');

/// Charset for the bot `start` token suffix after `webauth_`. Matches the
/// token shape zencab issues (URL-safe base64-ish: alphanumerics, `_`, `-`).
final RegExp _telegramStartTokenPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// Reusable hardened WebView container for zencab pages.
///
/// Use cases (opened internally from native flows, never as a top tab):
/// - `/login` (default) — account login/auth.
/// - existing payment / top-up / checkout pages.
/// - `/support` — support page.
/// - fallback routes when native does not have a dedicated surface yet.
///
/// This is NOT the cabinet home. Native Flutter owns the ongoing FOCUS
/// cabinet home; this WebView is one reusable infrastructure surface.
class CabinetWebView extends StatefulWidget {
  const CabinetWebView({
    super.key,
    this.initialPath = '/login',
    this.queryParameters,
  });

  /// Relative app path starting with `/` (e.g. `/login`, `/support`,
  /// `/subscriptions/123/topup`). Absolute URLs, protocol-relative paths,
  /// and unsafe inputs are rejected and replaced with `/login`.
  final String initialPath;

  /// Optional extra query parameters merged with the surface marker.
  final Map<String, String>? queryParameters;

  @override
  State<CabinetWebView> createState() => _CabinetWebViewState();
}

/// Validates `initialPath` is a safe relative app path.
///
/// Rules: starts with `/`, does not start with `//`, ≤2048 chars, no
/// scheme or backslash anywhere. Query parameters travel separately.
@visibleForTesting
bool isSafeCabinetPath(String path) {
  if (path.isEmpty || path.length > 2048) return false;
  if (!path.startsWith('/')) return false;
  if (path.startsWith('//')) return false;
  if (path.contains(r'\')) return false;
  // The path component itself must never carry a scheme; rejecting `:`
  // collapses every `javascript:`, `data:`, `file:` smuggling attempt.
  if (path.contains(':')) return false;
  return true;
}

/// Validates a URL string handed to the native subscription import path.
@visibleForTesting
bool isSafeImportUrl(String? raw) {
  if (raw == null) return false;
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed.length > 4096) return false;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  if (!uri.hasScheme || uri.scheme != 'https') return false;
  if (uri.host.isEmpty) return false;
  return true;
}

/// Returns true when the supplied page URL is the trusted zencab origin.
/// Bridge handlers MUST refuse calls from any other origin.
@visibleForTesting
bool isTrustedBridgeOrigin(Uri? current) {
  if (current == null) return false;
  if (current.scheme != 'https') return false;
  if (current.host != _zencabHost) return false;
  return true;
}

/// Returns true if any path segment is `.` or `..` or empty (which would
/// produce a double slash). Path traversal segments MUST be rejected at
/// the bridge boundary; resolving them on the server side could escape
/// the intended route allowlist.
bool _hasUnsafePathSegments(String path) {
  // Split off any query/fragment that a future caller might smuggle in.
  // The current validators already block `:`/`\` so this is defence in
  // depth — never trust the path string verbatim.
  final pathOnly = path.split('?').first.split('#').first;
  // Strip the leading slash so the first split entry isn't an empty
  // segment by definition; everything after that must be non-empty and
  // not a dot-segment.
  final body = pathOnly.startsWith('/') ? pathOnly.substring(1) : pathOnly;
  // Allow a single trailing slash (`/support/`); the empty final segment
  // it produces is benign. Any other empty segment means `//` inside the
  // path, which we reject.
  final segments = body.split('/');
  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];
    if (segment == '.' || segment == '..') return true;
    if (segment.isEmpty && i != segments.length - 1) return true;
  }
  return false;
}

/// Validates a support route path. Only `/support` or `/support/...` are
/// accepted. Reuses [isSafeCabinetPath] to reject absolute URLs, schemes,
/// protocol-relative inputs, backslashes, and oversized strings, and
/// additionally rejects `.`/`..` path traversal segments.
@visibleForTesting
bool isSafeSupportPath(String path) {
  if (!isSafeCabinetPath(path)) return false;
  if (_hasUnsafePathSegments(path)) return false;
  if (path == _supportRoot) return true;
  return path.startsWith('$_supportRoot/');
}

/// Validates a payment/top-up/checkout route path against the conservative
/// allowlist mirrored from zencab `App.tsx`. Reuses [isSafeCabinetPath] so
/// schemes, absolute URLs, and protocol-relative inputs are rejected, and
/// additionally rejects `.`/`..` path traversal segments.
@visibleForTesting
bool isSafePaymentPath(String path) {
  if (!isSafeCabinetPath(path)) return false;
  if (_hasUnsafePathSegments(path)) return false;
  if (_safePaymentExactPaths.contains(path)) return true;
  for (final prefix in _safePaymentPrefixes) {
    if (path.startsWith(prefix)) return true;
  }
  // `/subscriptions/{id}/renew`: must contain a non-empty id segment with no
  // additional slashes between the id and `/renew`. Reject `/subscriptions//renew`
  // and deeper nested paths.
  if (path.startsWith(_renewPathPrefix) && path.endsWith(_renewPathSuffix)) {
    final id = path.substring(
      _renewPathPrefix.length,
      path.length - _renewPathSuffix.length,
    );
    if (id.isNotEmpty && !id.contains('/')) return true;
  }
  return false;
}

/// Validates a `tg://resolve?domain=<bot>&start=webauth_<token>` URI from
/// the WebView. ONLY this exact shape is treated as a trusted handoff to the
/// Telegram app: scheme `tg`, host `resolve`, no path/fragment, and exactly
/// the two expected query parameters with safe charsets. Every other
/// `tg://` deep link is rejected so the WebView cannot be coerced into
/// opening arbitrary Telegram intents (joinchat, msg, share, etc.).
@visibleForTesting
bool isSafeTelegramLoginUri(Uri uri) {
  if (uri.scheme != 'tg') return false;
  if (uri.host != 'resolve') return false;
  // `tg://resolve` has no path/fragment in the canonical login link; reject
  // anything else so attackers cannot smuggle extra routing information.
  if (uri.path.isNotEmpty && uri.path != '/') return false;
  if (uri.hasFragment) return false;
  // Use queryParametersAll so duplicate keys (e.g. `?domain=a&domain=b`)
  // are caught — `queryParameters` would silently keep only the last value.
  final params = uri.queryParametersAll;
  if (params.length != 2) return false;
  final domains = params['domain'];
  final starts = params['start'];
  if (domains == null || domains.length != 1) return false;
  if (starts == null || starts.length != 1) return false;
  final domain = domains.first;
  final start = starts.first;
  if (!_telegramDomainPattern.hasMatch(domain)) return false;
  if (!start.startsWith(_telegramLoginStartPrefix)) return false;
  final token = start.substring(_telegramLoginStartPrefix.length);
  if (!_telegramStartTokenPattern.hasMatch(token)) return false;
  return true;
}

class _CabinetWebViewState extends State<CabinetWebView> {
  InAppWebViewController? _controller;
  bool _loading = true;

  WebUri _buildInitialUri() {
    final path = isSafeCabinetPath(widget.initialPath)
        ? widget.initialPath
        : '/login';
    // Spread caller-supplied parameters FIRST so the required surface
    // marker always wins. Callers must not be able to switch the WebView
    // out of app mode by passing `surface: 'web'` or similar.
    final qp = <String, String>{
      ...?widget.queryParameters,
      _surfaceParam: _surfaceValue,
    };
    final uri = Uri.https(_zencabHost, path, qp);
    return WebUri.uri(uri);
  }

  String _resolveUserAgent() {
    // App-mode detection on the zencab side falls back to the UA marker
    // whenever the `?surface` query gets dropped by an internal redirect,
    // so the marker must always be present — never null.
    try {
      // packageInfo is initialised in GlobalState.init(); guard so the
      // WebView never throws if it somehow opens before app init.
      return '${globalState.packageInfo.ua} $_dropwebUaMarker';
    } catch (_) {
      return _dropwebUaMarker;
    }
  }

  Future<NavigationActionPolicy> _shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    // Sub-frames are constrained by the page's own CSP / same-origin
    // policy on the zencab side. We only police the main frame.
    final isMainFrame = action.isForMainFrame == true;
    if (!isMainFrame) {
      return NavigationActionPolicy.ALLOW;
    }
    final uri = action.request.url;
    if (uri == null) return NavigationActionPolicy.CANCEL;
    // Telegram app handoff for the login deep link. zencab issues
    // `tg://resolve?domain=<bot>&start=webauth_<token>` only in app mode;
    // hand it off to the Telegram app and keep the WebView on the current
    // page. CANCEL is returned regardless of launch result so the WebView
    // never tries to render the `tg://` URL itself.
    if (isSafeTelegramLoginUri(uri)) {
      unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
      return NavigationActionPolicy.CANCEL;
    }
    if (uri.scheme != 'https') return NavigationActionPolicy.CANCEL;
    if (uri.host != _zencabHost) return NavigationActionPolicy.CANCEL;
    return NavigationActionPolicy.ALLOW;
  }

  Future<bool> _handleImportSubscription(List<dynamic> args) async {
    // Origin gate — only the trusted zencab page may import.
    Uri? current;
    try {
      final webUri = await _controller?.getUrl();
      current = webUri == null ? null : Uri.tryParse(webUri.toString());
    } catch (_) {
      current = null;
    }
    if (!isTrustedBridgeOrigin(current)) return false;

    // Defensive arg handling — JS can pass anything (null, numbers,
    // objects). Bridge misuse must resolve `false`, never throw.
    if (args.isEmpty) return false;
    final first = args.first;
    if (first is! String) return false;
    if (!isSafeImportUrl(first)) return false;

    try {
      await globalState.appController.addProfileFormURL(first.trim());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _handleReceiveCabinetHomeData(List<dynamic> args) async {
    if (!await _isCurrentOriginTrusted()) return false;
    if (args.isEmpty) return false;
    final data = CabinetHomeData.fromBridgePayload(args.first);
    if (data == null) return false;
    cabinetHomeAdapter.update(data);
    return true;
  }

  /// Origin gate shared by every bridge handler. `addJavaScriptHandler` is
  /// unauthenticated; re-reading `getUrl()` is the only way to confirm the
  /// caller frame is still the trusted zencab origin.
  Future<bool> _isCurrentOriginTrusted() async {
    Uri? current;
    try {
      final webUri = await _controller?.getUrl();
      current = webUri == null ? null : Uri.tryParse(webUri.toString());
    } catch (_) {
      current = null;
    }
    return isTrustedBridgeOrigin(current);
  }

  /// Loads `path` inside the existing WebView, preserving the surface
  /// marker query parameter. Caller is responsible for validating `path`.
  Future<bool> _loadCabinetPath(String path) async {
    final controller = _controller;
    if (controller == null) return false;
    final uri = Uri.https(_zencabHost, path, <String, String>{
      _surfaceParam: _surfaceValue,
    });
    try {
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(uri)));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _handleOpenSupport(List<dynamic> args) async {
    if (!await _isCurrentOriginTrusted()) return false;
    final path = args.isEmpty ? _supportRoot : args.first;
    if (path is! String) return false;
    if (!isSafeSupportPath(path)) return false;
    return _loadCabinetPath(path);
  }

  Future<bool> _handleOpenPayment(List<dynamic> args) async {
    if (!await _isCurrentOriginTrusted()) return false;
    if (args.isEmpty) return false;
    final path = args.first;
    if (path is! String) return false;
    if (!isSafePaymentPath(path)) return false;
    return _loadCabinetPath(path);
  }

  Future<bool> _handleCloseCabinet(List<dynamic> args) async {
    if (!await _isCurrentOriginTrusted()) return false;
    if (!mounted) return false;
    try {
      return await Navigator.of(context).maybePop();
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _handleGetAppContext(List<dynamic> args) async {
    if (!await _isCurrentOriginTrusted()) return null;
    if (!mounted) return null;
    var appVersion = '';
    try {
      appVersion = globalState.packageInfo.version;
    } catch (_) {
      appVersion = '';
    }
    final brightness = Theme.of(context).brightness;
    String locale;
    try {
      locale = Localizations.localeOf(context).toLanguageTag();
    } catch (_) {
      locale = 'en';
    }
    return <String, dynamic>{
      'platform': 'android',
      'appVersion': appVersion,
      'surface': _surfaceValue,
      'theme': brightness == Brightness.dark ? 'dark' : 'light',
      'locale': locale,
    };
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    controller
      ..addJavaScriptHandler(
        handlerName: 'importSubscription',
        callback: _handleImportSubscription,
      )
      ..addJavaScriptHandler(
        handlerName: 'receiveCabinetHomeData',
        callback: _handleReceiveCabinetHomeData,
      )
      ..addJavaScriptHandler(
        handlerName: 'openSupport',
        callback: _handleOpenSupport,
      )
      ..addJavaScriptHandler(
        handlerName: 'openPayment',
        callback: _handleOpenPayment,
      )
      ..addJavaScriptHandler(
        handlerName: 'closeCabinet',
        callback: _handleCloseCabinet,
      )
      ..addJavaScriptHandler(
        handlerName: 'getAppContext',
        callback: _handleGetAppContext,
      );
  }

  @override
  Widget build(BuildContext context) {
    final ua = _resolveUserAgent();
    return Scaffold(
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: _buildInitialUri()),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                useShouldOverrideUrlLoading: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
                allowFileAccess: false,
                allowFileAccessFromFileURLs: false,
                allowUniversalAccessFromFileURLs: false,
                allowContentAccess: false,
                javaScriptCanOpenWindowsAutomatically: false,
                supportMultipleWindows: false,
                transparentBackground: true,
                userAgent: ua,
              ),
              onWebViewCreated: _onWebViewCreated,
              shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
              onLoadStart: (_, __) {
                if (!mounted) return;
                setState(() => _loading = true);
              },
              onLoadStop: (_, __) {
                if (!mounted) return;
                setState(() => _loading = false);
              },
              onReceivedError: (_, __, ___) {
                if (!mounted) return;
                setState(() => _loading = false);
              },
            ),
            if (_loading)
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}
