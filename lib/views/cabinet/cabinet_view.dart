import 'package:dropweb/common/package.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Allowed host for the zencab WebView shell. ONLY this host may load the
/// main frame, run JavaScript, and call native bridge handlers.
const String _zencabHost = 'cab.dropweb.org';

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

class _CabinetWebViewState extends State<CabinetWebView> {
  InAppWebViewController? _controller;
  bool _loading = true;

  WebUri _buildInitialUri() {
    final path = isSafeCabinetPath(widget.initialPath)
        ? widget.initialPath
        : '/login';
    final qp = <String, String>{
      'surface': 'dropweb_android',
      ...?widget.queryParameters,
    };
    final uri = Uri.https(_zencabHost, path, qp);
    return WebUri.uri(uri);
  }

  String? _resolveUserAgent() {
    try {
      // packageInfo is initialised in GlobalState.init(); guard so the
      // WebView never throws if it somehow opens before app init.
      return globalState.packageInfo.ua;
    } catch (_) {
      return null;
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

    final url = args.isNotEmpty ? args.first as String? : null;
    if (!isSafeImportUrl(url)) return false;

    try {
      await globalState.appController.addProfileFormURL(url!.trim());
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: 'importSubscription',
      callback: _handleImportSubscription,
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
