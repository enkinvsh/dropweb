import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openCabinetBrowser(Uri url) async {
  try {
    final ok = await launchUrl(
      url,
      mode: LaunchMode.inAppBrowserView,
      browserConfiguration: const BrowserConfiguration(showTitle: true),
    );
    if (ok) return true;
  } catch (_) {
    // fall through to external browser
  }
  try {
    return await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

/// Fallback page for opening a cabinet URL declared by the current profile's
/// `dropweb-cabinet` provider header.
///
/// The page does NOT embed a WebView. Instead, it opens the supplied URL
/// through the system browser surface (Android Custom Tabs / iOS in-app
/// browser via `url_launcher`'s `LaunchMode.inAppBrowserView`).
/// A small fallback card is rendered if the launch fails or the user returns
/// to it.
class CabinetBrowserEntry extends StatefulWidget {
  const CabinetBrowserEntry({super.key, required this.url});

  final Uri url;

  @override
  State<CabinetBrowserEntry> createState() => _CabinetBrowserEntryState();
}

class _CabinetBrowserEntryState extends State<CabinetBrowserEntry> {
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_autoOpened && mounted) {
        _autoOpened = true;
        openCabinetBrowser(widget.url);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Кабинет',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  widget.url.toString(),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => openCabinetBrowser(widget.url),
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Открыть кабинет'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
