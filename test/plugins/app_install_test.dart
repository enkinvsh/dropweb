import 'package:dropweb/plugins/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app');
  final messenger = binding.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('App in-app-update install wrappers', () {
    test('installApk forwards method + path payload, returns native bool',
        () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });

      final ok =
          await App().installApk('/data/cache/updates/dropweb-0.8.2.apk');

      expect(ok, isTrue);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'installApk');
      expect(calls.single.arguments,
          {'path': '/data/cache/updates/dropweb-0.8.2.apk'});
    });

    test('canInstallUnknownApps forwards method, returns native bool',
        () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return false;
      });

      final ok = await App().canInstallUnknownApps();

      expect(ok, isFalse);
      expect(calls.single.method, 'canInstallUnknownApps');
      expect(calls.single.arguments, isNull);
    });

    test('openUnknownSourcesSettings forwards method', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });

      final ok = await App().openUnknownSourcesSettings();

      expect(ok, isTrue);
      expect(calls.single.method, 'openUnknownSourcesSettings');
    });

    test('installApk swallows MissingPluginException => false', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException('no impl');
      });

      expect(await App().installApk('/x.apk'), isFalse);
    });

    test('installApk swallows PlatformException => false', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'boom');
      });

      expect(await App().installApk('/x.apk'), isFalse);
    });

    test('canInstallUnknownApps swallows MissingPluginException => false',
        () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException('no impl');
      });

      expect(await App().canInstallUnknownApps(), isFalse);
    });
  });
}
