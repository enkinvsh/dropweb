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
