import 'dart:async';
import 'dart:ui';

import 'package:dropweb/common/common.dart';

extension CompleterExt<T> on Completer<T> {
  Future<Object?> safeFuture({
    Duration? timeout,
    VoidCallback? onLast,
    FutureOr<T> Function()? onTimeout,
    required String functionName,
  }) {
    final realTimeout = timeout ?? const Duration(seconds: 30);
    Timer(realTimeout + commonDuration, () {
      if (onLast != null) {
        onLast();
      }
    });
    return future.withTimeout(
      timeout: realTimeout,
      functionName: functionName,
      onTimeout: onTimeout,
    );
  }
}

extension FutureExt<T> on Future<T> {
  Future<T> withTimeout({
    required Duration timeout,
    required String functionName,
    FutureOr<T> Function()? onTimeout,
  }) => this.timeout(
      timeout,
      onTimeout: () async {
        if (onTimeout != null) {
          return onTimeout();
        } else {
          throw TimeoutException('$functionName timeout');
        }
      },
    );

  /// Races this future against [timeout]. On expiry, runs [onTimeout] (e.g.
  /// disposing a wedged resource that the pending work still holds) and then
  /// throws [message] — a readable error so the caller fails loudly instead of
  /// hanging. Unlike [withTimeout], the timed-out work is abandoned (not
  /// substituted with a fallback value), so this fits cases where the only safe
  /// recovery is to tear the resource down.
  Future<T> guardWithTimeout({
    required Duration timeout,
    required String message,
    void Function()? onTimeout,
  }) async {
    try {
      return await this.timeout(timeout);
    } on TimeoutException {
      onTimeout?.call();
      throw message;
    }
  }
}
