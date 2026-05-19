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

  group('App.playUiSound', () {
    test(
      'invokes native channel with stable method name + cue payload for every cue',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });

        await App().playUiSound(DropwebSoundCue.powerOn);
        await App().playUiSound(DropwebSoundCue.powerOff);
        await App().playUiSound(DropwebSoundCue.subscriptionRefresh);
        await App().playUiSound(DropwebSoundCue.importSuccess);
        await App().playUiSound(DropwebSoundCue.importError);

        expect(calls, hasLength(5));
        expect(calls[0].method, 'playUiSound');
        expect(calls[0].arguments, {'cue': 'powerOn'});
        expect(calls[1].method, 'playUiSound');
        expect(calls[1].arguments, {'cue': 'powerOff'});
        expect(calls[2].method, 'playUiSound');
        expect(calls[2].arguments, {'cue': 'subscriptionRefresh'});
        expect(calls[3].method, 'playUiSound');
        expect(calls[3].arguments, {'cue': 'importSuccess'});
        expect(calls[4].method, 'playUiSound');
        expect(calls[4].arguments, {'cue': 'importError'});
      },
    );

    test('powerPress cue is no longer part of the public contract', () {
      // Compile-time guard: the cue was removed (user feedback — "лишний").
      // If anyone re-adds it, this test goes stale and the failure points
      // straight at the regression. Enum membership is checked by name to
      // avoid coupling to ordinal values.
      final cueNames =
          DropwebSoundCue.values.map((c) => c.name).toSet();
      expect(cueNames.contains('powerPress'), isFalse);
      expect(
        cueNames,
        equals({
          'powerOn',
          'powerOff',
          'subscriptionRefresh',
          'importSuccess',
          'importError',
        }),
      );
    });

    test('falls back to SystemSound.click on MissingPluginException',
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
      // routes to SystemSound.play(SystemSoundType.click) so taps still
      // produce audible feedback when the native bridge is absent.
      await App().playUiSound(DropwebSoundCue.powerOn);

      expect(
        platformCalls.any(
          (c) =>
              c.method == 'SystemSound.play' &&
              c.arguments == 'SystemSoundType.click',
        ),
        isTrue,
        reason: 'Expected fallback to SystemSound.click on platform channel',
      );
    });

    test('falls back to SystemSound.click on PlatformException', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'boom');
      });
      final platformCalls = <MethodCall>[];
      messenger.setMockMethodCallHandler(platformChannel, (call) async {
        platformCalls.add(call);
        return null;
      });

      await App().playUiSound(DropwebSoundCue.importError);

      expect(
        platformCalls.any(
          (c) =>
              c.method == 'SystemSound.play' &&
              c.arguments == 'SystemSoundType.click',
        ),
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

      await App().playUiSound(DropwebSoundCue.importSuccess);

      expect(platformCalls, isEmpty);
    });

    test('falls back when native returns false (e.g. sample not loaded)',
        () async {
      // Native side reports actual failure (sample not yet decoded, unknown
      // cue, asset missing). Wrapper must route to the Flutter SystemSound
      // shim so the call site never needs to branch. Note: system-touch-
      // sounds-disabled is NOT a false case — native consumes it as true.
      messenger.setMockMethodCallHandler(channel, (call) async => false);
      final platformCalls = <MethodCall>[];
      messenger.setMockMethodCallHandler(platformChannel, (call) async {
        platformCalls.add(call);
        return null;
      });

      await App().playUiSound(DropwebSoundCue.subscriptionRefresh);

      expect(
        platformCalls.any(
          (c) =>
              c.method == 'SystemSound.play' &&
              c.arguments == 'SystemSoundType.click',
        ),
        isTrue,
      );
    });
  });
}
