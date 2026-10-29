import 'package:dropweb/services/account/account_gate.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openCabinetBrowser(Uri url) async {
  // Магазинная сборка не открывает кабинет вовсе (решение владельца
  // 2026-10-29): последний рубеж, если вызов обошёл гейты выше.
  if (accountStoreBlocked) return false;
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
