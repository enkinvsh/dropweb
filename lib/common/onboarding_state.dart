import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has seen the one-time first-run «tap the lens to
/// add a subscription» coach hint (T29 onboarding).
///
/// Modelled 1:1 on [VpnConsent] (`vpn_consent.dart`): a *versioned*
/// `SharedPreferences` bool so the hint can be re-shown in a future build by
/// bumping the version suffix. No network, no analytics — a single local flag.
///
/// In addition to the async API, a [hintSeenListenable] exposes a reactive
/// snapshot so the synchronous overlay gate in `home.dart` can show/hide the
/// hint without a `FutureBuilder`, and so the Add sheet can dismiss the hint
/// the instant it opens (optimistic flip in [markHintSeen]).
class OnboardingState {
  const OnboardingState();

  /// Current hint version. Bump the `v` suffix to re-surface the hint.
  static const String currentVersion = 'v1';

  /// Storage key for the seen flag. Public so callers/tests can inspect it.
  static const String storageKey = 'onboarding_add_hint_seen_$currentVersion';

  /// Reactive snapshot of the seen flag.
  ///   * `null`  → not yet loaded; the overlay stays hidden so a returning
  ///               user never sees a flash of the hint before prefs resolve.
  ///   * `false` → not seen; the overlay may show (subject to the other gates).
  ///   * `true`  → seen; the overlay never shows again.
  static final ValueNotifier<bool?> hintSeenListenable =
      ValueNotifier<bool?>(null);

  /// Returns true when the hint has previously been marked seen. Returns false
  /// when SharedPreferences cannot be reached (treated as "not yet seen").
  Future<bool> isHintSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(storageKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Loads the persisted flag into [hintSeenListenable]. Safe to call multiple
  /// times; the overlay host calls it once on mount.
  Future<void> load() async {
    final seen = await isHintSeen();
    if (hintSeenListenable.value != seen) {
      hintSeenListenable.value = seen;
    }
  }

  /// Marks the hint as seen. Flips [hintSeenListenable] optimistically (so the
  /// overlay hides immediately when the Add sheet opens) then persists.
  /// Returns true on a successful write.
  Future<bool> markHintSeen() async {
    hintSeenListenable.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(storageKey, true);
    } catch (_) {
      return false;
    }
  }

  /// Clears the seen flag. Intended for debug/reset flows and tests.
  Future<void> reset() async {
    hintSeenListenable.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {
      // Best-effort reset.
    }
  }
}

/// Default instance — use this everywhere except in tests that need isolation.
const onboardingState = OnboardingState();
