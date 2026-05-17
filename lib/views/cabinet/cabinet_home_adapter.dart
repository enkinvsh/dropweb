import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cabinet_home_data.dart';

/// SharedPreferences key for the persisted display-only snapshot. The
/// `_v1` suffix lets us invalidate stored blobs by bumping the version
/// when the on-disk shape changes incompatibly.
@visibleForTesting
const String cabinetHomeSnapshotPrefsKey = 'cabinet_home_snapshot_v1';

/// Holds the latest valid [CabinetHomeData] snapshot received over the
/// zencab WebView bridge. Native cabinet UI listens on [snapshot]; the
/// bridge handler is the only writer through [update] / [clear].
///
/// The snapshot is mirrored to [SharedPreferences] so the cabinet home
/// can re-render the last known display data after a cold restart,
/// before zencab gets a chance to republish over the bridge. Only the
/// already display-only fields exposed by [CabinetHomeData] are stored,
/// and the stored blob is re-validated through
/// [CabinetHomeData.fromBridgePayload] on every restore.
///
/// SECURITY: this adapter stores display-only fields. It MUST NOT be
/// extended with zencab tokens, cookies, session state, or anything that
/// could grant native code authenticated access to the cabinet backend.
class CabinetHomeAdapter {
  CabinetHomeAdapter({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
            preferencesProvider ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferencesProvider;

  final ValueNotifier<CabinetHomeData?> snapshot =
      ValueNotifier<CabinetHomeData?>(null);

  /// Updates the in-memory snapshot and asynchronously mirrors it to
  /// local storage. Persistence is best-effort: failures are swallowed
  /// because the UI must never be blocked on disk I/O.
  void update(CabinetHomeData data) {
    snapshot.value = data;
    unawaited(_persist(data));
  }

  /// Clears the in-memory snapshot and removes the persisted blob so a
  /// signed-out session does not "come back" after a restart.
  void clear() {
    snapshot.value = null;
    unawaited(_clearPersisted());
  }

  /// Loads the last persisted snapshot from local storage into
  /// [snapshot]. Called once during app startup. Safe to call multiple
  /// times: if the bridge has already published a fresher snapshot,
  /// restore is a no-op so we never clobber live data with stale data.
  /// Invalid/corrupt stored blobs are dropped silently so a bad write
  /// can never crash the app at startup.
  Future<void> restore() async {
    if (snapshot.value != null) return;
    try {
      final prefs = await _preferencesProvider();
      final raw = prefs.getString(cabinetHomeSnapshotPrefsKey);
      if (raw == null) return;

      dynamic decoded;
      try {
        decoded = json.decode(raw);
      } catch (_) {
        await prefs.remove(cabinetHomeSnapshotPrefsKey);
        return;
      }

      final data = CabinetHomeData.fromBridgePayload(decoded);
      if (data == null) {
        // Stored payload no longer passes validation (older shape,
        // tampered file, unknown enum value). Drop it so a future
        // successful update can replace it cleanly.
        await prefs.remove(cabinetHomeSnapshotPrefsKey);
        return;
      }

      // A bridge update may have arrived while we were awaiting disk;
      // never overwrite a fresher in-memory snapshot with a stale one.
      if (snapshot.value != null) return;
      snapshot.value = data;
    } catch (_) {
      // Disk/IPC errors must not crash startup.
    }
  }

  Future<void> _persist(CabinetHomeData data) async {
    try {
      final prefs = await _preferencesProvider();
      await prefs.setString(
        cabinetHomeSnapshotPrefsKey,
        json.encode(data.toJson()),
      );
    } catch (_) {
      // Best-effort: persistence failures only cost us one cold-start
      // restoration, never a live UI update.
    }
  }

  Future<void> _clearPersisted() async {
    try {
      final prefs = await _preferencesProvider();
      await prefs.remove(cabinetHomeSnapshotPrefsKey);
    } catch (_) {
      // Best-effort clear.
    }
  }
}

/// Process-wide adapter. Single instance because zencab publishes one
/// active snapshot per authenticated session.
///
/// Restore is kicked off lazily on first access of the singleton so the
/// cached display snapshot from the previous run reappears as soon as
/// possible after a cold start, without requiring callers to plumb a
/// `restore()` call through app init. [CabinetHomeAdapter.restore] is
/// idempotent and never clobbers a fresher in-memory snapshot, so this
/// is safe even when the WebView bridge wins the race.
final CabinetHomeAdapter cabinetHomeAdapter = _buildCabinetHomeAdapter();

CabinetHomeAdapter _buildCabinetHomeAdapter() {
  final adapter = CabinetHomeAdapter();
  unawaited(adapter.restore());
  return adapter;
}
