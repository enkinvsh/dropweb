/// Minimal native cabinet snapshot received over the zencab WebView bridge.
///
/// The producer is the authenticated zencab frontend running on
/// `https://cab.dropweb.org`. Every field is treated as untrusted input —
/// the bridge handler runs [CabinetHomeData.fromBridgePayload] and the
/// origin check before exposing this snapshot to the native UI.
///
/// SECURITY: this model intentionally carries display-only data. It MUST
/// NOT be extended with bearer tokens, refresh tokens, cookies, auth
/// headers, raw user/profile objects, or raw backend responses.
library;

const int _maxLabelLength = 128;
const int _maxUrlLength = 4096;

enum CabinetImportState { ready, imported, unavailable }

class CabinetHomeData {
  const CabinetHomeData({
    required this.tariffName,
    required this.tariffCostLabel,
    required this.balanceLabel,
    required this.balanceAmountKopeks,
    required this.referralLink,
    required this.subscriptionUrl,
    required this.importState,
    required this.statusLabel,
  });

  final String? tariffName;
  final String? tariffCostLabel;
  final String? balanceLabel;
  final int? balanceAmountKopeks;
  final Uri? referralLink;
  final Uri? subscriptionUrl;
  final CabinetImportState importState;
  final String? statusLabel;

  /// Validates and normalises a payload coming from the WebView bridge.
  /// Returns `null` when the payload is structurally invalid; callers
  /// MUST treat that as "unavailable" and not fabricate data.
  static CabinetHomeData? fromBridgePayload(dynamic raw) {
    if (raw is! Map) return null;
    final state = _parseImportState(raw['importState']);
    if (state == null) return null;
    return CabinetHomeData(
      tariffName: _boundedLabel(raw['tariffName']),
      tariffCostLabel: _boundedLabel(raw['tariffCostLabel']),
      balanceLabel: _boundedLabel(raw['balanceLabel']),
      balanceAmountKopeks: _safeInteger(raw['balanceAmountKopeks']),
      referralLink: _safeHttpsUri(raw['referralLink']),
      subscriptionUrl: _safeHttpsUri(raw['subscriptionUrl']),
      importState: state,
      statusLabel: _boundedLabel(raw['statusLabel']),
    );
  }

  /// JSON representation used ONLY for local persistence of the
  /// display-only snapshot. The shape mirrors the bridge payload so the
  /// same [fromBridgePayload] validator can re-hydrate the value on
  /// startup without trusting the stored blob.
  ///
  /// SECURITY: `subscriptionUrl` is intentionally EXCLUDED — it carries
  /// an embedded import token and must never land in plaintext
  /// SharedPreferences (which is readable via ADB backup and on rooted
  /// devices). On cold restart the restored snapshot has
  /// `subscriptionUrl == null` and the native UI falls back to opening
  /// the cabinet WebView, which republishes the URL over the bridge
  /// once authentication completes. Never extend this map with
  /// auth/session/cookie/token data or any other URL that bears a
  /// token.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'tariffName': tariffName,
        'tariffCostLabel': tariffCostLabel,
        'balanceLabel': balanceLabel,
        'balanceAmountKopeks': balanceAmountKopeks,
        'referralLink': referralLink?.toString(),
        'importState': switch (importState) {
          CabinetImportState.ready => 'ready',
          CabinetImportState.imported => 'imported',
          CabinetImportState.unavailable => 'unavailable',
        },
        'statusLabel': statusLabel,
      };
}

CabinetImportState? _parseImportState(dynamic value) {
  if (value is! String) return null;
  switch (value) {
    case 'ready':
      return CabinetImportState.ready;
    case 'imported':
      return CabinetImportState.imported;
    case 'unavailable':
      return CabinetImportState.unavailable;
  }
  return null;
}

String? _boundedLabel(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.length > _maxLabelLength) {
    return trimmed.substring(0, _maxLabelLength);
  }
  return trimmed;
}

int? _safeInteger(dynamic value) {
  if (value is int) return value;
  if (value is double && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  return null;
}

Uri? _safeHttpsUri(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > _maxUrlLength) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (!uri.hasScheme || uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return uri;
}
