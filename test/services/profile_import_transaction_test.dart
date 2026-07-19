import 'dart:async';
import 'dart:io';

import 'package:dropweb/services/profile_import_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProfileImportTransaction<String> buildTransaction({
    required List<String> events,
    Future<void> Function()? ensureUiReady,
    Future<bool> Function()? ensureCoreReady,
    Future<String?> Function()? downloadAndValidate,
    Future<void> Function(String)? commitProfile,
    Future<void> Function(String)? applyHeaderSettings,
    Future<void> Function(String)? handleHwidHeaders,
    Future<void> Function(String)? applyProfile,
    Future<void> Function(String)? reportSuccess,
    Future<void> Function(Object, StackTrace)? reportFailure,
  }) {
    return ProfileImportTransaction<String>(
      ensureUiReady: ensureUiReady ?? () async => events.add('ui-ready'),
      ensureCoreReady: ensureCoreReady ??
          () async {
            events.add('core-ready');
            return true;
          },
      downloadAndValidate: downloadAndValidate ??
          () async {
            events.add('download');
            return 'profile';
          },
      commitProfile: commitProfile ??
          (profile) async {
            events.add('commit:$profile');
          },
      applyHeaderSettings: applyHeaderSettings ??
          (profile) async {
            events.add('headers:$profile');
          },
      handleHwidHeaders: handleHwidHeaders ??
          (profile) async {
            events.add('hwid:$profile');
          },
      applyProfile: applyProfile ??
          (profile) async {
            events.add('apply:$profile');
          },
      reportSuccess: reportSuccess ??
          (profile) async {
            events.add('success:$profile');
          },
      reportFailure: reportFailure ??
          (error, stackTrace) async {
            events.add('error:$error');
          },
      log: events.add,
    );
  }

  test('case 6: import waits for core readiness before download and commit',
      () async {
    final events = <String>[];
    final readiness = Completer<void>();
    final transaction = buildTransaction(
      events: events,
      ensureCoreReady: () async {
        events.add('core-wait');
        await readiness.future;
        events.add('core-ready');
        return true;
      },
    );

    final running = transaction.run();
    await Future<void>.delayed(Duration.zero);

    expect(events, ['ui-ready', 'core-wait']);
    readiness.complete();
    await running;

    expect(
      events,
      [
        'ui-ready',
        'core-wait',
        'core-ready',
        '[import] validate',
        'download',
        'commit:profile',
        'headers:profile',
        'hwid:profile',
        '[import] profile-apply',
        'apply:profile',
        'success:profile',
      ],
    );
  });

  test('case 6: readiness failure reports error and cleanly aborts commit',
      () async {
    final events = <String>[];
    final transaction = buildTransaction(
      events: events,
      ensureCoreReady: () async => throw StateError('VPN core did not answer'),
    );

    await transaction.run();

    expect(events, ['ui-ready', contains('VPN core did not answer')]);
    expect(events.where((event) => event.startsWith('commit:')), isEmpty);
  });

  test('case 6: readiness error already surfaced by UI aborts without commit',
      () async {
    final events = <String>[];
    final transaction = buildTransaction(
      events: events,
      ensureCoreReady: () async => false,
    );

    await transaction.run();

    expect(events, ['ui-ready']);
    expect(events.where((event) => event.startsWith('error:')), isEmpty);
    expect(events.where((event) => event.startsWith('commit:')), isEmpty);
  });

  test('case 7: commit and apply run once and success awaits apply completion',
      () async {
    final events = <String>[];
    final applyCompletion = Completer<void>();
    var commitCount = 0;
    var applyCount = 0;
    final transaction = buildTransaction(
      events: events,
      commitProfile: (profile) async {
        commitCount++;
        events.add('commit:$profile');
      },
      applyProfile: (profile) async {
        applyCount++;
        events.add('apply-start:$profile');
        await applyCompletion.future;
        events.add('apply-done:$profile');
      },
    );

    final running = transaction.run();
    await Future<void>.delayed(Duration.zero);

    expect(commitCount, 1);
    expect(applyCount, 1);
    expect(events.where((event) => event.startsWith('success:')), isEmpty);

    applyCompletion.complete();
    await running;

    expect(commitCount, 1);
    expect(applyCount, 1);
    expect(
      events.indexOf('apply-done:profile'),
      lessThan(events.indexOf('success:profile')),
    );
    expect(
        events.where((event) => event == '[import] profile-apply').length, 1);
  });

  test(
      'case 8: cosmetic header and HWID failures are logged and apply continues',
      () async {
    final events = <String>[];
    var profileCommitted = false;
    var applyCount = 0;
    final transaction = buildTransaction(
      events: events,
      commitProfile: (profile) async {
        profileCommitted = true;
        events.add('commit:$profile');
      },
      applyHeaderSettings: (_) async => throw StateError('custom-view'),
      handleHwidHeaders: (_) async => throw StateError('hwid'),
      applyProfile: (profile) async {
        applyCount++;
        events.add('apply:$profile');
      },
    );

    await transaction.run();

    expect(profileCommitted, isTrue);
    expect(applyCount, 1);
    expect(
      events,
      contains(
          contains('[import] header-settings failed: Bad state: custom-view')),
    );
    expect(
      events,
      contains(contains('[import] hwid failed: Bad state: hwid')),
    );
    expect(events, contains('success:profile'));
    expect(events.where((event) => event.startsWith('error:')), isEmpty);
  });

  test('case 9: commit failure reports error and never applies or succeeds',
      () async {
    final events = <String>[];
    final transaction = buildTransaction(
      events: events,
      commitProfile: (_) async => throw StateError('commit failed'),
    );

    await transaction.run();

    expect(events, contains(contains('error:Bad state: commit failed')));
    expect(events.where((event) => event.startsWith('apply:')), isEmpty);
    expect(events.where((event) => event.startsWith('success:')), isEmpty);
  });

  test('case 9: apply failure keeps commit but never reports success',
      () async {
    final events = <String>[];
    var profileCommitted = false;
    final transaction = buildTransaction(
      events: events,
      commitProfile: (profile) async {
        profileCommitted = true;
        events.add('commit:$profile');
      },
      applyProfile: (_) async => throw StateError('apply failed'),
    );

    await transaction.run();

    expect(profileCommitted, isTrue);
    expect(events, contains(contains('error:Bad state: apply failed')));
    expect(events.where((event) => event.startsWith('success:')), isEmpty);
  });

  test('case 9: unmounted scaffold reports explicit ui-not-ready error',
      () async {
    final events = <String>[];
    final transaction = buildTransaction(
      events: events,
      ensureUiReady: () async => throw const UiNotReadyException(),
    );

    await transaction.run();

    expect(events, ['error:ui-not-ready']);
    expect(events.where((event) => event == '[import] validate'), isEmpty);
    expect(events.where((event) => event.startsWith('commit:')), isEmpty);
  });

  test('URL and file imports share switch side effects and success cleanup',
      () {
    final source = File('lib/controller.dart').readAsStringSync();

    expect(
      RegExp(r'_importProfileSideEffects\(resetTheme: true\);')
          .allMatches(source)
          .length,
      2,
    );
    expect(
      RegExp(r'_importSuccessCleanup\(\);').allMatches(source).length,
      2,
    );

    final sideEffectsStart = source.indexOf(
      'void _importProfileSideEffects({required bool resetTheme})',
    );
    final cleanupStart =
        source.indexOf('void _importSuccessCleanup()', sideEffectsStart);
    final importStart =
        source.indexOf('Future<void> addProfileFormURL', cleanupStart);

    expect(sideEffectsStart, greaterThanOrEqualTo(0));
    expect(cleanupStart, greaterThan(sideEffectsStart));
    expect(importStart, greaterThan(cleanupStart));

    final sideEffects = source.substring(sideEffectsStart, cleanupStart);
    expect(sideEffects, contains('_connectService.resetCoreRealignBudget()'));
    expect(sideEffects, contains('applySubscriptionTheme'));
    expect(sideEffects, contains('_resetSubscriptionTheme()'));
    expect(sideEffects, contains('_lastSetupHash = null'));
    expect(sideEffects, contains('delayDataSourceProvider.notifier'));
    expect(sideEffects, contains('_connectService.initForegroundCache()'));

    final cleanup = source.substring(cleanupStart, importStart);
    expect(cleanup, contains('logsProvider.notifier'));
    expect(cleanup, contains('requestsProvider.notifier'));
    expect(cleanup, contains('cacheHeightMap = {}'));
    expect(cleanup, contains('cacheScrollPosition = {}'));
    expect(cleanup,
        contains('_updateGeoFilesAfterProfileUpdate(forceUpdate: true)'));
  });
}
