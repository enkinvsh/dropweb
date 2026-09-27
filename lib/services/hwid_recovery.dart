import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:flutter/widgets.dart';

/// Recovers a subscription from a panel HWID device-limit block.
///
/// Panels signal the block via the `x-hwid-limit: true` response header on a
/// subscription fetch (plus a human-readable `announce`). The user then frees
/// a device slot in their cabinet and the NEXT fetch registers this device —
/// so recovery is simply "retry the profile update until the header clears".
///
/// Episode model (one flagged profile at a time, in-memory only):
///  * [onHwidLimit]   — opens an episode; returns true exactly once so the
///    caller shows the actionable dialog ONCE (later signals stay silent —
///    no dialog stacking while the poll keeps failing).
///  * retry channels  — foreground poll every [pollInterval] (capped at
///    [episodeCap]: covers "freeing the slot from a PC while the phone lies
///    open") and [onAppResumed] (covers "tapped the dialog's device-management
///    deep link, freed a slot in the cabinet, came back" — the common case).
///  * [onRecovered]   — the caller reports a clean fetch; returns true when
///    that closes the active episode so the caller can celebrate (notifier).
///
/// Only the ACTIVE profile is tracked (`isCurrentProfile`): the 20-min
/// auto-update refreshes every subscription, and another provider's device
/// limit must not pop a dialog over the one the user actually uses, nor be
/// polled in the background. Switching away from the flagged profile ends the
/// episode; the limit resurfaces on that profile's next fetch once active.
///
/// Provider-neutral by construction: header-driven, no panel API calls. The
/// actual update is injected ([retryProfileUpdate]) to keep this class free of
/// controller/провайдер imports (same layering as ClashService callbacks).
class HwidRecoveryService {
  HwidRecoveryService({
    required Future<void> Function(String profileId) retryProfileUpdate,
    bool Function()? isForeground,
    bool Function(String profileId)? isCurrentProfile,
    this.pollInterval = const Duration(seconds: 30),
    this.episodeCap = const Duration(minutes: 10),
  })  : _retryProfileUpdate = retryProfileUpdate,
        _isForeground = isForeground ?? _defaultIsForeground,
        _isCurrentProfile = isCurrentProfile ?? _anyProfile;

  final Future<void> Function(String profileId) _retryProfileUpdate;
  final bool Function() _isForeground;
  final bool Function(String profileId) _isCurrentProfile;

  /// Polite retry cadence — each attempt re-fetches the subscription (and
  /// thereby re-attempts HWID registration), so hammering the panel is rude.
  final Duration pollInterval;

  /// Hard stop for the background poll: after this the user has clearly moved
  /// on; manual update / app resume still recover the profile later.
  final Duration episodeCap;

  String? _profileId;
  Timer? _pollTimer;
  int _ticks = 0;
  bool _retryInFlight = false;

  /// Poll budget per episode, derived from [episodeCap] (tick COUNT, not wall
  /// clock: deterministic under fake_async and unaffected by resume retries).
  int get _maxTicks =>
      episodeCap.inMilliseconds ~/ pollInterval.inMilliseconds;

  /// Desktop `lifecycleState` may be null — treat unknown as foreground
  /// (desktop windows have no meaningful paused state for our purposes).
  static bool _defaultIsForeground() {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  static bool _anyProfile(String _) => true;

  bool get isActive => _profileId != null;

  /// Ends the episode when the user switched to another profile meanwhile.
  bool _abandonIfInactive() {
    final profileId = _profileId;
    if (profileId == null || _isCurrentProfile(profileId)) return false;
    commonPrint.log('[hwid] $profileId no longer active, episode dropped');
    _endEpisode();
    return true;
  }

  /// Panel flagged [profileId]. Returns true when this OPENS a new episode
  /// (show the dialog); false when the episode is already running (silent).
  bool onHwidLimit(String profileId) {
    if (!_isCurrentProfile(profileId)) {
      commonPrint.log('[hwid] device limit on inactive $profileId, ignored');
      return false;
    }
    if (_profileId == profileId) return false;
    _endEpisode();
    _profileId = profileId;
    _pollTimer = Timer.periodic(pollInterval, (_) => _tick());
    commonPrint.log('[hwid] device-limit episode started for $profileId');
    return true;
  }

  /// A fetch for [profileId] came back without the limit header (or the
  /// profile is gone). Returns true when this closes the active episode.
  bool onRecovered(String profileId) {
    if (_profileId != profileId) return false;
    commonPrint.log('[hwid] device-limit episode resolved for $profileId');
    _endEpisode();
    return true;
  }

  /// App returned to foreground — the user likely just freed a slot in the
  /// cabinet. Retry immediately instead of waiting out the poll interval.
  void onAppResumed() {
    if (!isActive || _abandonIfInactive()) return;
    unawaited(_retry());
  }

  void _tick() {
    if (_profileId == null || _abandonIfInactive()) return;
    if (++_ticks > _maxTicks) {
      commonPrint.log('[hwid] recovery poll capped, stopping');
      _endEpisode();
      return;
    }
    if (!_isForeground()) return;
    unawaited(_retry());
  }

  Future<void> _retry() async {
    final profileId = _profileId;
    if (profileId == null || _retryInFlight) return;
    _retryInFlight = true;
    try {
      await _retryProfileUpdate(profileId);
    } catch (e) {
      // Expected while the panel still refuses / network blips — the episode
      // machinery (poll/resume/manual) simply tries again later.
      commonPrint.log('[hwid] recovery retry failed: $e');
    } finally {
      _retryInFlight = false;
    }
  }

  void _endEpisode() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _profileId = null;
    _ticks = 0;
  }
}
