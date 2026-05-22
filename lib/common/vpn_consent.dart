import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has accepted the in-app VPN disclosure.
///
/// The flag is *versioned* (`vpn_disclosure_accepted_v1`) so that meaningful
/// changes to the disclosure copy can require a fresh consent by bumping the
/// version suffix in a future build, without losing prior history.
///
/// This helper is intentionally minimal — no network, no analytics. It is the
/// single source of truth consulted before changing the VPN status from
/// "stopped" to "started" for the first time.
class VpnConsent {
  const VpnConsent();

  /// Current disclosure version. Bump the `v` suffix in a future release if
  /// the disclosure copy changes in a way that requires re-consenting.
  static const String currentVersion = 'v1';

  /// Storage key for the accepted flag. Public so callers/tests can inspect it.
  static const String storageKey = 'vpn_disclosure_accepted_$currentVersion';

  /// Returns true when the user has previously accepted the disclosure for the
  /// current version. Returns false when SharedPreferences cannot be reached
  /// (treated as "not yet accepted" so the dialog is shown).
  Future<bool> isAccepted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(storageKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Persists the accepted flag for the current disclosure version.
  /// Returns true on success.
  Future<bool> markAccepted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(storageKey, true);
    } catch (_) {
      return false;
    }
  }

  /// Removes the accepted flag. Intended for debug/reset flows and tests.
  Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {
      // Best-effort reset.
    }
  }
}

/// Default instance — use this everywhere except in tests that need isolation.
const vpnConsent = VpnConsent();
