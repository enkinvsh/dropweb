import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Top-level page shown for the `Кабинет` navigation tab when the current
/// profile declares a cabinet URL via the `dropweb-cabinet` provider header.
///
/// The page does NOT embed a WebView. Instead, it opens the supplied URL
/// through the system browser surface (Android Custom Tabs / iOS in-app
/// browser via `url_launcher`'s `LaunchMode.inAppBrowserView`).
/// A small fallback card is rendered so the tab is never blank if the
/// launch fails or the user returns to it.
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
        _open();
      }
    });
  }

  Future<void> _open() async {
    try {
      final ok = await launchUrl(
        widget.url,
        mode: LaunchMode.inAppBrowserView,
        browserConfiguration: const BrowserConfiguration(showTitle: true),
      );
      if (ok) return;
    } catch (_) {
      // fall through to external browser
    }
    try {
      await launchUrl(
        widget.url,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // swallow – fallback UI remains visible
    }
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
                    onPressed: _open,
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
