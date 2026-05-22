/// Counts rapid consecutive taps used to unlock developer / advanced mode
/// from the Settings screen header.
///
/// The trigger is `threshold` taps within a sliding `window`. Once the
/// threshold is reached the counter automatically resets so the next tap
/// starts a fresh run. A tap that lands more than `window` after the
/// previous one also resets the run — i.e. only RAPID consecutive taps
/// on the same target count.
///
/// This replaces the legacy module-level counter that hung off the bottom
/// navigation tap in `lib/pages/home.dart`. The 5-taps-in-3-seconds
/// semantics are preserved.
///
/// The class accepts an injectable `clock` so tests can advance time
/// deterministically without `Future.delayed`.
class DevUnlockCounter {
  DevUnlockCounter({
    this.threshold = 5,
    this.window = const Duration(seconds: 3),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int threshold;
  final Duration window;
  final DateTime Function() _clock;

  int _count = 0;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// Records a tap. Returns `true` exactly on the tap that reaches the
  /// threshold; the internal counter is reset on that tap so a follow-up
  /// tap does not immediately re-trigger.
  bool registerTap() {
    final now = _clock();
    if (now.difference(_last) > window) {
      _count = 0;
    }
    _last = now;
    _count++;
    if (_count >= threshold) {
      _count = 0;
      return true;
    }
    return false;
  }

  /// Clears the counter without changing configuration.
  void reset() {
    _count = 0;
    _last = DateTime.fromMillisecondsSinceEpoch(0);
  }
}
