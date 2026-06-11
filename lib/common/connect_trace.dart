import 'package:dropweb/common/print.dart';

/// Lightweight tap-to-traffic tracing. One log line per mark via commonPrint.
/// Stays enabled in release builds (cheap; makes field issues diagnosable).
class ConnectTrace {
  ConnectTrace._();

  static DateTime? _tapAt;

  static void start() {
    _tapAt = DateTime.now();
    commonPrint.log('[trace] connect tap');
  }

  static void mark(String label) {
    final tapAt = _tapAt;
    if (tapAt == null) return;
    commonPrint.log(
        '[trace] $label +${DateTime.now().difference(tapAt).inMilliseconds}ms');
  }

  static void end(String label) {
    mark(label);
    _tapAt = null;
  }
}
