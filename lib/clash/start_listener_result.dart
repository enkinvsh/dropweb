import 'dart:async';
import 'dart:convert';

class StartListenerTimeoutException extends TimeoutException {
  StartListenerTimeoutException(Duration duration)
      : super('TUN listener start timed out', duration);
}

sealed class StartListenerOutcome {
  const StartListenerOutcome();
}

final class StartListenerOk extends StartListenerOutcome {
  const StartListenerOk();
}

final class StartListenerTunError extends StartListenerOutcome {
  const StartListenerTunError(this.cause);

  final String cause;
}

final class StartListenerProtocolException implements Exception {
  const StartListenerProtocolException(this.message);

  final String message;

  @override
  String toString() => 'start listener protocol error: $message';
}

final class TunStartException implements Exception {
  const TunStartException(this.cause);

  final String cause;

  @override
  String toString() => 'tun listener start failed: $cause';
}

StartListenerOutcome parseStartListenerResult(String payload) {
  final Object? decoded;
  try {
    decoded = jsonDecode(payload);
  } on FormatException {
    throw const StartListenerProtocolException('payload is not JSON');
  }
  if (decoded is! Map<String, dynamic> || !decoded.containsKey('ok')) {
    throw const StartListenerProtocolException(
        'payload is not a result object');
  }
  final ok = decoded['ok'];
  if (ok is! bool) {
    throw const StartListenerProtocolException('ok is not a boolean');
  }
  final tunError = decoded['tunError'];
  if (ok) {
    if (tunError != null) {
      throw const StartListenerProtocolException(
        'ok result carries a tun error',
      );
    }
    return const StartListenerOk();
  }
  if (tunError is! String || tunError.isEmpty) {
    throw const StartListenerProtocolException(
      'failure result has no tun cause',
    );
  }
  return StartListenerTunError(tunError);
}
