import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpinyin/lpinyin.dart';

class Utils {
  Color? getDelayColor(int? delay) {
    if (delay == null) return null;
    if (delay < 0) return Colors.red;
    if (delay < 600) return Colors.green;
    return Lumina.latencyWarn;
  }

  /// Short label for a latency badge.
  /// Returns null when there is nothing to show yet (no measurement / loading),
  /// "n/a" for an unavailable node (timeout, delay < 0), and "$delay ms" for a
  /// real measurement (delay > 0).
  String? delayBadgeLabel(int? delay) {
    if (delay == null || delay == 0) return null;
    if (delay < 0) return 'n/a';
    return '$delay ms';
  }

  String get id {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = Random();
    final randomStr =
        String.fromCharCodes(List.generate(8, (_) => random.nextInt(26) + 97));
    return "$timestamp$randomStr";
  }

  String get uuidV4 {
    final random = Random();
    final bytes = List.generate(16, (_) => random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  Locale? getLocaleForString(String? localString) {
    if (localString == null) return null;
    final localSplit = localString.split("_");
    if (localSplit.length == 1) {
      return Locale(localSplit[0]);
    }
    if (localSplit.length == 2) {
      return Locale(localSplit[0], localSplit[1]);
    }
    if (localSplit.length == 3) {
      return Locale.fromSubtags(
          languageCode: localSplit[0],
          scriptCode: localSplit[1],
          countryCode: localSplit[2]);
    }
    return null;
  }

  int sortByChar(String a, String b) {
    if (a.isEmpty && b.isEmpty) {
      return 0;
    }
    if (a.isEmpty) {
      return -1;
    }
    if (b.isEmpty) {
      return 1;
    }
    final charA = a[0];
    final charB = b[0];

    if (charA == charB) {
      return sortByChar(a.substring(1), b.substring(1));
    } else {
      return charA.compareToLower(charB);
    }
  }

  String getOverwriteLabel(String label) {
    final reg = RegExp(r'\((\d+)\)$');
    final matches = reg.allMatches(label);
    if (matches.isNotEmpty) {
      final match = matches.last;
      final number = int.parse(match[1] ?? '0') + 1;
      return label.replaceFirst(reg, '($number)', label.length - 3 - 1);
    } else {
      return "$label(1)";
    }
  }

  String getTrayIconPath({
    required Brightness brightness,
    bool isRunning = false,
  }) {
    if (Platform.isMacOS) {
      // macOS always uses white icon for menu bar
      return "assets/images/icon_white.png";
    }

    // When running - use colored icon
    if (isRunning) {
      return "assets/images/icon.ico";
    }

    // When stopped - use inactive icon (black bg, gray db)
    return "assets/images/icon_inactive.ico";
  }

  /// Compares two semver-ish version strings without throwing.
  ///
  /// Forgiving rules:
  /// - leading `v` / `V` is stripped (only at start, not mid-token)
  /// - `+build` metadata is ignored for ordering
  /// - `-prerelease` suffix is honored: a stable release ranks above a
  ///   matching prerelease (`0.6.8` > `0.6.8-beta2`); two prereleases
  ///   with the same base are compared lexicographically
  /// - missing minor / patch parts default to 0 (`1` == `1.0.0`)
  /// - non-numeric segments fall back to 0 instead of throwing
  /// - any unexpected error yields `0` (treated as "equal / unknown")
  int compareVersions(String version1, String version2) {
    try {
      final (base1, pre1) = _splitVersion(version1);
      final (base2, pre2) = _splitVersion(version2);

      for (var i = 0; i < 3; i++) {
        final a = i < base1.length ? base1[i] : 0;
        final b = i < base2.length ? base2[i] : 0;
        if (a != b) return a.compareTo(b);
      }

      // Equal base. Stable (no prerelease) ranks above prerelease.
      if (pre1.isEmpty && pre2.isEmpty) return 0;
      if (pre1.isEmpty) return 1;
      if (pre2.isEmpty) return -1;
      return pre1.compareTo(pre2);
    } catch (_) {
      return 0;
    }
  }

  /// Returns ([major, minor, patch], prerelease) for a forgiving version
  /// string. Strips a single leading `v` / `V`, drops `+build` metadata,
  /// splits prerelease after the first `-`, and defaults non-numeric
  /// segments to 0.
  (List<int>, String) _splitVersion(String version) {
    var v = version.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    final plusIdx = v.indexOf('+');
    if (plusIdx >= 0) v = v.substring(0, plusIdx);

    var prerelease = '';
    final dashIdx = v.indexOf('-');
    if (dashIdx >= 0) {
      prerelease = v.substring(dashIdx + 1);
      v = v.substring(0, dashIdx);
    }

    final parts = v.isEmpty ? <String>[] : v.split('.');
    final nums = parts.map((p) => int.tryParse(p) ?? 0).toList();
    return (nums, prerelease);
  }

  String getPinyin(String value) => value.isNotEmpty
      ? PinyinHelper.getFirstWordPinyin(value.substring(0, 1))
      : "";

  String? getFileNameForDisposition(String? disposition) {
    if (disposition == null) return null;
    final parseValue = HeaderValue.parse(disposition);
    final parameters = parseValue.parameters;
    final fileNamePointKey = parameters.keys
        .firstWhere((key) => key == "filename*", orElse: () => "");
    if (fileNamePointKey.isNotEmpty) {
      final res = parameters[fileNamePointKey]?.split("''") ?? [];
      if (res.length >= 2) {
        return Uri.decodeComponent(res[1]);
      }
    }
    final fileNameKey = parameters.keys
        .firstWhere((key) => key == "filename", orElse: () => "");
    if (fileNameKey.isEmpty) return null;
    return parameters[fileNameKey];
  }

  List<String> parseReleaseBody(String? body) {
    if (body == null) return [];
    const pattern = r'- \s*(.*)';
    final regex = RegExp(pattern);
    return regex
        .allMatches(body)
        .map((match) => match.group(1) ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  ViewMode getViewMode(double viewWidth) {
    // Product requirement: always use mobile layout mode, regardless of screen width.
    // This ensures a consistent bottom mobile nav + connect button UX across all devices.
    // Desktop/laptop enum values retained for compatibility (no downstream cleanup needed).
    return ViewMode.mobile;
  }

  int getProxiesColumns(double viewWidth, ProxiesLayout proxiesLayout) {
    final columns = max((viewWidth / 300).ceil(), 2);
    return switch (proxiesLayout) {
      ProxiesLayout.tight => columns + 1,
      ProxiesLayout.standard => columns,
      ProxiesLayout.loose => columns - 1,
    };
  }

  int getProfilesColumns(double viewWidth) => max((viewWidth / 320).floor(), 1);

  String get logFile => "${appName}_${DateTime.now().show}.log";

  Future<String?> getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
    )
      ..sort((a, b) {
        if (a.isWifi && !b.isWifi) return -1;
        if (!a.isWifi && b.isWifi) return 1;
        if (a.includesIPv4 && !b.includesIPv4) return -1;
        if (!a.includesIPv4 && b.includesIPv4) return 1;
        return 0;
      });
    for (final interface in interfaces) {
      final addresses = interface.addresses;
      if (addresses.isEmpty) {
        continue;
      }
      addresses.sort((a, b) {
        if (a.isIPv4 && !b.isIPv4) return -1;
        if (!a.isIPv4 && b.isIPv4) return 1;
        return 0;
      });
      return addresses.first.address;
    }
    return "";
  }

  SingleActivator controlSingleActivator(LogicalKeyboardKey trigger) {
    final control = Platform.isMacOS ? false : true;
    return SingleActivator(
      trigger,
      control: control,
      meta: !control,
    );
  }

  FutureOr<T> handleWatch<T>(FutureOr<T> Function() function) async {
    if (kDebugMode) {
      final stopwatch = Stopwatch()..start();
      final res = await function();
      stopwatch.stop();
      commonPrint.log('Elapsed: ${stopwatch.elapsedMilliseconds} ms');
      return res;
    }
    return await function();
  }
}

final utils = Utils();
