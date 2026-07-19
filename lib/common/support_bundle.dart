import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dropweb/common/log_redaction.dart';
import 'package:path/path.dart' as p;

class SupportBundleBuilder {
  SupportBundleBuilder({required this.logsDirectory});

  static const maxBundleBytes = 32 * 1024;
  static const maxFileTailBytes = 24 * 1024;
  static const maxInAppTailBytes = 8 * 1024;
  static const _fileMarker = '---- file tail ----';
  static const _inAppMarker = '---- in-app tail ----';

  final Directory logsDirectory;

  Future<String> build({
    required String appVersion,
    required List<String> inAppLines,
    String? phase,
    String? operatingSystem,
  }) async {
    final now = DateTime.now();
    final header = 'dropweb diagnostics / ${now.toIso8601String()} / '
        '$appVersion / ${operatingSystem ?? Platform.operatingSystem} / '
        'phase: ${_phaseLabel(phase)}';
    final fixedBytes =
        utf8.encode('$header\n$_fileMarker\n$_inAppMarker').length;
    final availableBytes = math.max(0, maxBundleBytes - fixedBytes);
    final inAppTail = _tailLines(
      inAppLines,
      math.min(maxInAppTailBytes, availableBytes),
    );
    final fileBudget = math.min(
      maxFileTailBytes,
      availableBytes - _lineContributionBytes(inAppTail),
    );
    final fileTail = _tailLines(await _readTodayLines(now), fileBudget);
    final bundle = [
      header,
      _fileMarker,
      ...fileTail,
      _inAppMarker,
      ...inAppTail,
    ].join('\n');
    return redactUrls(bundle);
  }

  Future<List<String>> _readTodayLines(DateTime now) async {
    if (!logsDirectory.existsSync()) {
      return const [];
    }
    final date = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final pattern = RegExp(
      '^dropweb_${RegExp.escape(date)}(?:_(\\d+))?\\.log\$',
    );
    final segments = <({File file, int index})>[];
    await for (final entity in logsDirectory.list()) {
      if (entity is! File) continue;
      final match = pattern.firstMatch(p.basename(entity.path));
      if (match == null) continue;
      segments.add((
        file: entity,
        index: int.tryParse(match.group(1) ?? '') ?? 0,
      ));
    }
    segments.sort((left, right) => left.index.compareTo(right.index));

    final lines = <String>[];
    for (final segment in segments) {
      try {
        lines.addAll(await segment.file.readAsLines());
      } on FileSystemException {
        continue;
      }
    }
    return lines;
  }

  List<String> _tailLines(List<String> lines, int byteBudget) {
    final tail = <String>[];
    var usedBytes = 0;
    for (var index = lines.length - 1; index >= 0; index--) {
      final line = redactUrls(lines[index]);
      final lineBytes = utf8.encode(line).length + 1;
      if (usedBytes + lineBytes > byteBudget) break;
      usedBytes += lineBytes;
      tail.add(line);
    }
    return tail.reversed.toList(growable: false);
  }

  int _lineContributionBytes(List<String> lines) => lines.fold(
        0,
        (total, line) => total + utf8.encode(line).length + 1,
      );

  String _phaseLabel(String? phase) {
    final value = phase?.trim();
    return value == null || value.isEmpty ? 'unknown' : value;
  }
}
