import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// The URL Spotify lands on once a login has actually succeeded.
///
/// Matched instead of watching for a redirect back to some callback of ours,
/// because there is no callback: this is not OAuth, it is the web player's own
/// session. The locale sits in the path — `/en/status`, `/ru/status` — hence
/// the `[^/]+` segment.
final _loggedInUrl =
    RegExp(r'^https://accounts\.spotify\.com/[^/]+/status($|\?.*)$');

/// Where the cookies are read from.
///
/// The apex domain, not `accounts.spotify.com`: `sp_dc` is set for
/// `.spotify.com` so that `open.spotify.com` can see it, and asking the
/// narrower host back returns a jar without it.
const _cookieOrigin = 'https://spotify.com';

/// Opens Spotify's own login page and returns the cookies it leaves behind.
///
/// The password is typed into Spotify's page inside a webview; this app never
/// sees it, never proxies the form, and holds nothing afterwards but the
/// session cookies. That is the whole reason the flow is a webview rather than
/// a native form, and it is worth not quietly "improving" later.
///
/// Returns null when the user backed out.
Future<Map<String, String>?> showSpotifyLogin(BuildContext context) =>
    Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(builder: (_) => const _SpotifyLoginPage()),
    );

class _SpotifyLoginPage extends StatefulWidget {
  const _SpotifyLoginPage();

  @override
  State<_SpotifyLoginPage> createState() => _SpotifyLoginPageState();
}

class _SpotifyLoginPageState extends State<_SpotifyLoginPage> {
  /// Spotify's status page can be reached more than once — it is a normal page
  /// and the webview reports every navigation to it. Without this latch the
  /// route would be popped twice, and the second pop takes the screen the user
  /// was sent back to with it.
  bool _harvested = false;

  bool _loading = true;

  Future<void> _harvest() async {
    if (_harvested) return;
    _harvested = true;

    final cookies = await CookieManager.instance().getCookies(
      url: WebUri(_cookieOrigin),
    );
    final jar = <String, String>{
      for (final cookie in cookies) cookie.name: '${cookie.value}',
    };
    if (!mounted) return;
    Navigator.of(context).pop(jar);
  }

  void _onUrl(WebUri? url) {
    if (url == null) return;
    // The trailing slash is stripped before matching: the webview reports
    // `.../status` and `.../status/` for the same page depending on how it was
    // reached, and only one of those matches the pattern.
    final raw = url.toString();
    final trimmed =
        raw.length > 1 && raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    if (_loggedInUrl.hasMatch(trimmed)) unawaited(_harvest());
  }

  @override
  Widget build(BuildContext context) => CommonScaffold(
        title: appLocalizations.meowzicSpotifyTitle,
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('https://accounts.spotify.com/'),
              ),
              // The device's own User-Agent, deliberately left alone.
              //
              // This once carried `spotifyUserAgent` — the desktop Chrome
              // string the API calls send — on the theory that a page serves
              // a webview badly. It cost an afternoon: the captcha was solved
              // and then Spotify's own challenge orchestrator answered
              // `/v1/invoke-challenge-command` with 400 and the page said
              // "Something went wrong".
              //
              // Overriding `userAgent` rewrites the header and nothing else.
              // `navigator.userAgentData` still reports Android, as do the
              // touch stack and a phone-shaped viewport, so the page was told
              // "Windows" by the header and "Android" by everything it can
              // measure. Anti-abuse does not need to be clever to fail a
              // client that contradicts itself, and it did.
              //
              // The header is honest here and forged only on the plain API
              // calls in `session.dart`, where there is no script to disagree
              // with it. This is also what the reference plugin does.
              initialSettings: InAppWebViewSettings(
                transparentBackground: true,
              ),
              onLoadStart: (_, url) {
                if (mounted) setState(() => _loading = true);
                _onUrl(url);
              },
              onLoadStop: (_, url) {
                if (mounted) setState(() => _loading = false);
                _onUrl(url);
              },
              // Watched as well as the load callbacks: Spotify's login is a
              // single-page app after the first paint, so the hop to /status
              // can happen without a load ever starting.
              onUpdateVisitedHistory: (_, url, __) => _onUrl(url),
              onReceivedError: (_, __, ___) {
                if (mounted) setState(() => _loading = false);
              },
            ),
            if (_loading)
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      );
}
