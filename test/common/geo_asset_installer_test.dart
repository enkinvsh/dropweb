// Regression lock for W3.4-B: bundled geodata extraction must be ATOMIC,
// self-repairing, and cheap on the hot path. Before this guard,
// `ClashCore.initGeo` skipped any file that merely EXISTED (regardless of a
// zero/truncated/wrong-length body) and wrote the ~24 MB seed DIRECTLY to the
// final destination, so a power/process loss mid-write left a permanently
// poisoned GeoIP.dat / GeoSite.dat.
//
// `GeoAssetInstaller` fixes this: the caller supplies the expected byte length
// as metadata, so a GOOD destination is validated by a cheap stat WITHOUT ever
// loading the ~24 MB asset. Only when a repair is needed are the bytes loaded,
// re-checked against the expected length, staged in a same-dir temp file,
// flushed, length-validated, and atomically renamed over the destination.
// These tests exercise the real filesystem with temp dirs and an injected
// byte loader — no rootBundle, no device.

import 'dart:io';
import 'dart:typed_data';

import 'package:dropweb/common/constant.dart';
import 'package:dropweb/common/geo_asset_installer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  const asset = 'GeoIP.dat';
  const goodLen = 4096;
  final goodBytes =
      Uint8List.fromList(List<int>.generate(goodLen, (i) => i % 256));

  String destPath() => p.join(dir.path, asset);
  String tempPath() => '${destPath()}.tmp';

  /// Installer whose loader records how many times it was invoked, so tests can
  /// prove a good destination is validated WITHOUT loading the asset bytes.
  ({GeoAssetInstaller installer, int Function() loadCount}) counting(
    List<int> bundled, {
    GeoTempWriter? writeTemp,
  }) {
    var calls = 0;
    final installer = GeoAssetInstaller(
      loadAsset: (name) async {
        calls++;
        return bundled;
      },
      writeTemp: writeTemp,
    );
    return (installer: installer, loadCount: () => calls);
  }

  GeoAssetInstaller installerFor(
    List<int> bundled, {
    GeoTempWriter? writeTemp,
  }) =>
      counting(bundled, writeTemp: writeTemp).installer;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dropweb_geo_test');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('missing destination is created from the bundled bytes', () async {
    final installer = installerFor(goodBytes);

    final repaired = await installer.ensureInstalled(
      asset,
      destPath(),
      expectedLength: goodLen,
    );

    expect(repaired, isTrue, reason: 'a missing file must be written');
    expect(File(destPath()).readAsBytesSync(), goodBytes);
    expect(File(tempPath()).existsSync(), isFalse, reason: 'temp cleaned up');
  });

  test('correct existing file is untouched AND never loads the asset',
      () async {
    File(destPath()).writeAsBytesSync(goodBytes, flush: true);
    final beforeMtime = File(destPath()).statSync().modified;

    final probe = counting(goodBytes);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final repaired = await probe.installer.ensureInstalled(
      asset,
      destPath(),
      expectedLength: goodLen,
    );

    expect(repaired, isFalse, reason: 'length already matches → no repair');
    expect(probe.loadCount(), 0,
        reason: 'a good file is validated by stat only — never load ~24 MB');
    expect(File(destPath()).statSync().modified, beforeMtime,
        reason: 'good file must not be rewritten');
  });

  test('a loader that throws is never called for a good destination', () async {
    File(destPath()).writeAsBytesSync(goodBytes, flush: true);
    final installer = GeoAssetInstaller(
      loadAsset: (_) async => throw StateError('must not load a good file'),
    );

    final repaired = await installer.ensureInstalled(
      asset,
      destPath(),
      expectedLength: goodLen,
    );

    expect(repaired, isFalse);
  });

  test('zero-length destination is repaired (and does load)', () async {
    File(destPath()).writeAsBytesSync(const <int>[], flush: true);
    final probe = counting(goodBytes);

    final repaired = await probe.installer.ensureInstalled(
      asset,
      destPath(),
      expectedLength: goodLen,
    );

    expect(repaired, isTrue);
    expect(probe.loadCount(), 1, reason: 'load only when a repair is needed');
    expect(File(destPath()).readAsBytesSync(), goodBytes);
  });

  test('truncated destination (shorter than expected) is repaired', () async {
    File(destPath()).writeAsBytesSync(goodBytes.sublist(0, 100), flush: true);

    final repaired = await installerFor(goodBytes).ensureInstalled(
      asset,
      destPath(),
      expectedLength: goodLen,
    );

    expect(repaired, isTrue);
    expect(File(destPath()).readAsBytesSync(), goodBytes);
  });

  test('wrong-length destination (longer than expected) is repaired', () async {
    File(destPath()).writeAsBytesSync(
      Uint8List.fromList([...goodBytes, ...goodBytes]),
      flush: true,
    );

    final repaired = await installerFor(goodBytes).ensureInstalled(
      asset,
      destPath(),
      expectedLength: goodLen,
    );

    expect(repaired, isTrue);
    expect(File(destPath()).readAsBytesSync(), goodBytes);
  });

  test('expectedLength <= 0 is rejected — never overwrite with an empty asset',
      () async {
    // A good file on disk must survive even if the caller passes a bad/zero
    // expected length (e.g. a stat that returned 0). No load, no write.
    File(destPath()).writeAsBytesSync(goodBytes, flush: true);
    final probe = counting(const <int>[]);

    await expectLater(
      probe.installer.ensureInstalled(asset, destPath(), expectedLength: 0),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      probe.installer.ensureInstalled(asset, destPath(), expectedLength: -1),
      throwsA(isA<ArgumentError>()),
    );

    expect(probe.loadCount(), 0, reason: 'reject before loading anything');
    expect(File(destPath()).readAsBytesSync(), goodBytes,
        reason: 'good destination never clobbered');
  });

  test('loaded bytes whose length != expected abort without touching dest',
      () async {
    // Simulated asset/metadata drift: the bundled bytes are a different length
    // than the caller declared. Must throw and leave the prior good file.
    final priorGood = Uint8List.fromList(List<int>.generate(2000, (_) => 7));
    File(destPath()).writeAsBytesSync(priorGood, flush: true);

    // dest length 2000 != expected 4096 → repair path → load returns 3000 bytes
    // → mismatch vs expected 4096 → abort.
    final installer = installerFor(
      Uint8List.fromList(List<int>.generate(3000, (_) => 9)),
    );

    await expectLater(
      installer.ensureInstalled(asset, destPath(), expectedLength: goodLen),
      throwsA(isA<StateError>()),
    );

    expect(File(destPath()).readAsBytesSync(), priorGood,
        reason: 'drifted asset must not replace a good file');
    expect(File(tempPath()).existsSync(), isFalse);
  });

  test('stale temp from a prior crash is replaced, not appended', () async {
    File(tempPath()).writeAsBytesSync(const [1, 2, 3], flush: true);

    final repaired = await installerFor(goodBytes).ensureInstalled(
      asset,
      destPath(),
      expectedLength: goodLen,
    );

    expect(repaired, isTrue);
    expect(File(destPath()).readAsBytesSync(), goodBytes);
    expect(File(tempPath()).existsSync(), isFalse,
        reason: 'temp consumed by the atomic rename');
  });

  test('a bad temp write preserves the prior good destination', () async {
    final priorGood = Uint8List.fromList(List<int>.generate(2000, (_) => 7));
    File(destPath()).writeAsBytesSync(priorGood, flush: true);

    Future<void> truncatedWriter(File tmp, List<int> bytes) =>
        tmp.writeAsBytes(bytes.sublist(0, bytes.length ~/ 2), flush: true);

    final installer = installerFor(goodBytes, writeTemp: truncatedWriter);

    await expectLater(
      installer.ensureInstalled(asset, destPath(), expectedLength: goodLen),
      throwsA(isA<Exception>()),
      reason: 'a temp that fails length validation must abort the install',
    );

    expect(File(destPath()).readAsBytesSync(), priorGood,
        reason: 'good destination survives a failed repair');
  });

  test('bad temp write on a missing destination leaves no partial dest',
      () async {
    Future<void> truncatedWriter(File tmp, List<int> bytes) =>
        tmp.writeAsBytes(bytes.sublist(0, 10), flush: true);

    final installer = installerFor(goodBytes, writeTemp: truncatedWriter);

    await expectLater(
      installer.ensureInstalled(asset, destPath(), expectedLength: goodLen),
      throwsA(isA<Exception>()),
    );

    expect(File(destPath()).existsSync(), isFalse,
        reason: 'never publish a partial destination');
  });

  // CI guard: the declared expected lengths MUST match the real bundled assets.
  // If someone replaces GeoIP.dat / GeoSite.dat without updating
  // `geoAssetExpectedLengths`, the installer would treat every device's good
  // file as wrong-length (endless repair) — this test fails first instead.
  group('bundled asset lengths match declared constants', () {
    for (final entry in geoAssetExpectedLengths.entries) {
      test('${entry.key} on disk == ${entry.value} bytes', () {
        final file = File(p.join('assets', 'data', entry.key));
        expect(file.existsSync(), isTrue,
            reason: 'bundled seed asset missing from the repo');
        expect(file.lengthSync(), entry.value,
            reason: 'asset replaced without updating geoAssetExpectedLengths');
      });
    }
  });
}
