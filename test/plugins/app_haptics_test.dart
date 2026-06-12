import 'package:dropweb/plugins/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app');
  const platformChannel = SystemChannels.platform;
  final messenger = binding.defaultBinaryMessenger;

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(channel, null)
      ..setMockMethodCallHandler(platformChannel, null);
  });

  group('App.performHapticFeedback', () {
    test('invokes native channel with stable method name + cue payload',
        () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });

      await App().performHapticFeedback(DropwebHapticCue.gestureStart);
      await App().performHapticFeedback(DropwebHapticCue.confirm);
      await App().performHapticFeedback(DropwebHapticCue.success);

      expect(calls, hasLength(3));
      expect(calls[0].method, 'performHapticFeedback');
      expect(calls[0].arguments, {'cue': 'gestureStart'});
      expect(calls[1].method, 'performHapticFeedback');
      expect(calls[1].arguments, {'cue': 'confirm'});
      expect(calls[2].method, 'performHapticFeedback');
      expect(calls[2].arguments, {'cue': 'success'});
    });

    test('falls back to Flutter HapticFeedback on MissingPluginException',
        () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException('no impl');
      });
      final platformCalls = <MethodCall>[];
      messenger.setMockMethodCallHandler(platformChannel, (call) async {
        platformCalls.add(call);
        return null;
      });

      // Must not throw — wrapper swallows the missing-plugin error and
      // routes to the SystemChannels.platform HapticFeedback shim.
      await App().performHapticFeedback(DropwebHapticCue.gestureStart);

      expect(
        platformCalls.any((c) => c.method == 'HapticFeedback.vibrate'),
        isTrue,
        reason: 'Expected fallback to HapticFeedback.* on platform channel',
      );
    });

    test('falls back to Flutter HapticFeedback on PlatformException',
        () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'boom');
      });
      final platformCalls = <MethodCall>[];
      messenger.setMockMethodCallHandler(platformChannel, (call) async {
        platformCalls.add(call);
        return null;
      });

      await App().performHapticFeedback(DropwebHapticCue.confirm);

      expect(
        platformCalls.any((c) => c.method == 'HapticFeedback.vibrate'),
        isTrue,
      );
    });

    test('does not call fallback when native succeeds', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => true);
      final platformCalls = <MethodCall>[];
      messenger.setMockMethodCallHandler(platformChannel, (call) async {
        platformCalls.add(call);
        return null;
      });

      await App().performHapticFeedback(DropwebHapticCue.gestureStart);

      expect(platformCalls, isEmpty);
    });
  });
}
