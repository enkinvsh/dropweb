import 'package:dropweb/clash/message.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the listener callbacks it receives so tests can assert that valid
/// core messages still reach registered listeners even after a malformed one.
class _RecordingListener with AppMessageListener {
  int logCount = 0;
  int delayCount = 0;
  int tunCount = 0;
  Delay? lastDelay;
  Map<String, dynamic>? lastTun;

  @override
  void onLog(Log log) => logCount++;

  @override
  void onDelay(Delay delay) {
    delayCount++;
    lastDelay = delay;
  }

  @override
  void onTun(Map<String, dynamic> data) {
    tunCount++;
    lastTun = data;
  }
}

/// A listener whose handlers throw — simulates a buggy/exceptional listener
/// that must NOT be able to starve the other listeners in the loop.
class _ThrowingListener with AppMessageListener {
  @override
  void onDelay(Delay delay) => throw StateError('listener boom');
}

/// Registers [listener] and schedules its removal so the shared singleton's
/// listener list does not leak across tests.
void _useListener(AppMessageListener listener) {
  clashMessage.addListener(listener);
  addTearDown(() => clashMessage.removeListener(listener));
}

const _validDelayMessage = <String, Object?>{
  'type': 'delay',
  'data': <String, Object?>{'name': 'node-a', 'url': 'http://t', 'value': 42},
};

void main() {
  group('ClashMessage.dispatch hardening', () {
    test('malformed message (undecodable type) does not throw and does not '
        'block delivery of a subsequent valid message', () {
      final rec = _RecordingListener();
      _useListener(rec);

      // Bad shape: `type` is not a member of AppMessageType -> AppMessage
      // .fromJson throws today. Must be swallowed.
      expect(
        () => clashMessage.dispatch(const {'type': 'not-a-real-type'}),
        returnsNormally,
        reason: 'a malformed core message must not throw out of dispatch',
      );

      // A valid message right after must still reach the listener.
      clashMessage.dispatch(_validDelayMessage);
      expect(rec.delayCount, 1);
      expect(rec.lastDelay?.name, 'node-a');
    });

    test('tun message whose data is NOT a Map is skipped without throwing, '
        'and later valid messages still flow', () {
      final rec = _RecordingListener();
      _useListener(rec);

      // Hard cast `m.data as Map` blows up today on a non-Map payload.
      expect(
        () => clashMessage.dispatch(const {'type': 'tun', 'data': 'not-a-map'}),
        returnsNormally,
        reason: 'non-Map tun payload must be skipped, not crash dispatch',
      );
      expect(rec.tunCount, 0, reason: 'malformed tun must not be delivered');

      clashMessage.dispatch(_validDelayMessage);
      expect(rec.delayCount, 1);
    });

    test('a throwing listener does not starve other listeners', () {
      final throwing = _ThrowingListener();
      final rec = _RecordingListener();
      // Order matters: the throwing listener is iterated FIRST.
      _useListener(throwing);
      _useListener(rec);

      expect(
        () => clashMessage.dispatch(_validDelayMessage),
        returnsNormally,
        reason: 'one throwing listener must not propagate out of dispatch',
      );
      expect(rec.delayCount, 1,
          reason: 'the second listener must still receive the message');
    });

    test('a valid tun message with a Map payload is delivered', () {
      final rec = _RecordingListener();
      _useListener(rec);

      clashMessage.dispatch(const {
        'type': 'tun',
        'data': <String, Object?>{'fd': 7, 'name': 'tun0'},
      });
      expect(rec.tunCount, 1);
      expect(rec.lastTun?['name'], 'tun0');
    });
  });
}
