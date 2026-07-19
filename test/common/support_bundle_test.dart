import 'dart:convert';
import 'dart:io';

import 'package:dropweb/common/file_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory logsDirectory;
  late FileLogger logger;

  setUp(() {
    logsDirectory = Directory.systemTemp.createTempSync('dropweb_bundle_test');
    logger = FileLogger.testing(logsDirectory: logsDirectory.path);
  });

  tearDown(() async {
    await logger.dispose();
    if (logsDirectory.existsSync()) {
      logsDirectory.deleteSync(recursive: true);
    }
  });

  test('returns the required header and sections when no log files exist',
      () async {
    final bundle = await logger.buildSupportBundle(
      appVersion: '0.8.6+2050000001',
      operatingSystem: 'test-os',
      phase: null,
      inAppLines: const [],
    );

    expect(bundle, startsWith('dropweb diagnostics / '));
    expect(
      bundle.split('\n').first,
      contains('/ 0.8.6+2050000001 / test-os / phase: unknown'),
    );
    expect(bundle, contains('---- file tail ----'));
    expect(bundle, contains('---- in-app tail ----'));
  });

  test('caps the complete bundle at 32 KiB with huge inputs', () async {
    final fileLines = List<String>.generate(
      400,
      (index) => 'file-$index ${'файл-данные-' * 30}',
    );
    await _todaySegment(logsDirectory).writeAsString(fileLines.join('\n'));
    final inAppLines = List<String>.generate(
      300,
      (index) => 'app-$index ${'событие-🧪-' * 30}',
    );

    final bundle = await logger.buildSupportBundle(
      appVersion: '0.8.6',
      operatingSystem: 'test-os',
      phase: 'core-init',
      inAppLines: inAppLines,
    );

    expect(utf8.encode(bundle).length, lessThanOrEqualTo(32 * 1024));
    expect(bundle, contains(inAppLines.last));
    expect(bundle, contains(fileLines.last));
  });

  test('keeps only complete UTF-8 lines at both tail boundaries', () async {
    final fileLines = List<String>.generate(
      300,
      (index) => 'файл-$index 🧪 ${'я' * 80}',
    );
    final inAppLines = List<String>.generate(
      200,
      (index) => 'приложение-$index 🚀 ${'ж' * 80}',
    );
    await _todaySegment(logsDirectory).writeAsString(fileLines.join('\n'));

    final bundle = await logger.buildSupportBundle(
      appVersion: '0.8.6',
      operatingSystem: 'test-os',
      phase: 'bootstrap',
      inAppLines: inAppLines,
    );
    final keptFileLines = _sectionLines(
      bundle,
      '---- file tail ----',
      '---- in-app tail ----',
    );
    final keptInAppLines = _sectionLines(
      bundle,
      '---- in-app tail ----',
      null,
    );

    expect(keptFileLines.first, isIn(fileLines));
    expect(keptInAppLines.first, isIn(inAppLines));
    expect(keptFileLines, everyElement(isIn(fileLines)));
    expect(keptInAppLines, everyElement(isIn(inAppLines)));
    expect(bundle, isNot(contains('\uFFFD')));
  });

  test('redacts URLs again after assembling the final text', () async {
    const token = 'super-secret-token';
    await _todaySegment(logsDirectory).writeAsString(
      'raw https://panel.example/api/sub/$token?auth=$token',
    );

    final bundle = await logger.buildSupportBundle(
      appVersion: '0.8.6',
      operatingSystem: 'test-os',
      phase: 'profile-import',
      inAppLines: const [
        'app https://user:password@example.com/install?token=secret',
      ],
    );

    expect(bundle, isNot(contains(token)));
    expect(bundle, isNot(contains('password')));
    expect(bundle, contains('https://panel.example/api/[REDACTED]?[REDACTED]'));
    expect(
        bundle, contains('https://[REDACTED]@example.com/install?[REDACTED]'));
  });

  test('concatenates all daily segments in numeric order', () async {
    await _todaySegment(logsDirectory).writeAsString('base-oldest');
    await _todaySegment(logsDirectory, 1).writeAsString('segment-one');
    await _todaySegment(logsDirectory, 2).writeAsString('segment-two-newest');
    await _todaySegment(logsDirectory, 10).writeAsString('segment-ten-newest');

    final bundle = await logger.buildSupportBundle(
      appVersion: '0.8.6',
      operatingSystem: 'test-os',
      phase: 'segment-test',
      inAppLines: const [],
    );
    final fileTail = _sectionLines(
      bundle,
      '---- file tail ----',
      '---- in-app tail ----',
    );

    expect(
      fileTail,
      equals([
        'base-oldest',
        'segment-one',
        'segment-two-newest',
        'segment-ten-newest',
      ]),
    );
  });

  test('awaits queued writes before taking the file snapshot', () async {
    logger.log('queued-before-bundle');

    final bundle = await logger.buildSupportBundle(
      appVersion: '0.8.6',
      operatingSystem: 'test-os',
      phase: 'queue-barrier',
      inAppLines: const [],
    );

    expect(bundle, contains('queued-before-bundle'));
  });
}

File _todaySegment(Directory directory, [int index = 0]) {
  final now = DateTime.now();
  final date = '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  final suffix = index == 0 ? '' : '_$index';
  return File(p.join(directory.path, 'dropweb_$date$suffix.log'));
}

List<String> _sectionLines(String bundle, String start, String? end) {
  final lines = bundle.split('\n');
  final startIndex = lines.indexOf(start) + 1;
  final endIndex = end == null ? lines.length : lines.indexOf(end);
  return lines.sublist(startIndex, endIndex);
}
