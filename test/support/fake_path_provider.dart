// Hermetic path_provider for the test host VM. Measured in a native
// linux/arm64 container, not assumed.
//
// Under `flutter test` the Dart plugin registrant never runs, so
// `PathProviderPlatform.instance` stays the default `MethodChannelPathProvider`
// on EVERY host OS — macOS included. That default carries a hard-coded platform
// branch (path_provider_platform_interface-2.1.2, method_channel_path_provider
// .dart:91): `getDownloadsPath()` does `if (!_platform.isMacOS) throw
// UnsupportedError(...)` BEFORE touching the method channel. So on macOS the
// guard passes and a test's `plugins.flutter.io/path_provider` channel mock
// answers; on Linux — which is what CI runs — it throws synchronously and the
// channel mock is bypassed entirely. Mocking the channel cannot fix Linux.
//
// `AppPath._internal()` (lib/common/path.dart) fires `getDownloadsDirectory()`
// as a bare `.then(...)` with no error handler, so that rejection escapes as an
// unhandled async error attributed to whichever test first touched the lazy
// top-level `appPath`, and `appPath.downloadDir` never completes — a test
// awaiting it deadlocks for the full 10-minute timeout.
//
// Replacing the platform implementation is the only fix that sits below that
// branch. No production defect is being papered over: `path_provider_android`
// implements `getDownloadsPath` natively, so shipping builds never take this
// path. It is strictly a `flutter test` host-VM artifact.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// A [PathProviderPlatform] that answers every query with a real directory
/// inside one disposable temp tree.
///
/// Extends (rather than implements) [PathProviderPlatform] so the platform
/// interface token check in `PathProviderPlatform.instance=` passes without
/// needing a mock mixin.
class FakePathProvider extends PathProviderPlatform {
  FakePathProvider()
      : root = Directory.systemTemp.createTempSync('dropweb_fake_path_provider');

  /// The temp tree that backs every path this fake hands out.
  final Directory root;

  @override
  Future<String?> getApplicationCachePath() async => _dir('cache');

  @override
  Future<String?> getApplicationDocumentsPath() async => _dir('documents');

  @override
  Future<String?> getApplicationSupportPath() async => _dir('support');

  @override
  Future<String?> getDownloadsPath() async => _dir('downloads');

  @override
  Future<List<String>?> getExternalCachePaths() async => [_dir('external_cache')];

  @override
  Future<String?> getExternalStoragePath() async => _dir('external');

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async =>
      [_dir('external_storage_${type?.name ?? 'default'}')];

  @override
  Future<String?> getLibraryPath() async => _dir('library');

  @override
  Future<String?> getTemporaryPath() async => _dir('temp');

  /// Removes the temp tree. Safe to call more than once.
  void dispose() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  }

  String _dir(String name) {
    final dir = Directory(p.join(root.path, name))..createSync(recursive: true);
    return dir.path;
  }
}

/// Installs a [FakePathProvider] as the process-wide path_provider
/// implementation and registers a `tearDownAll` that deletes its temp tree.
///
/// Call this at the VERY TOP of `main()`, before any `setUpAll`/`setUp`/test
/// body can run. `AppPath` caches a `static AppPath? _instance` and the
/// top-level `appPath` is a lazy `final`, so once `AppPath._internal()` has run
/// against the real platform implementation the broken `Completer`s are cached
/// for the life of the isolate and installing the fake later changes nothing.
///
/// The previous implementation is deliberately NOT restored afterwards:
/// `flutter test` gives each test file its own isolate, and restoring would
/// only re-arm the deadlock for later teardown code.
FakePathProvider useFakePathProvider() {
  final fake = FakePathProvider();
  PathProviderPlatform.instance = fake;
  tearDownAll(fake.dispose);
  return fake;
}
