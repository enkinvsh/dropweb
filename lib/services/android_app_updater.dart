import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dropweb/common/constant.dart';

/// IO + pure helpers for the Android in-app updater. The orchestration (state
/// machine) lives in `lib/providers/app_update.dart`; this file holds the
/// single-responsibility, unit-testable pieces so the Notifier stays thin and
/// every branch here is covered without a network or a device.
///
/// See docs/plans/2026-06-25-auto-update.md.

/// Download sources to try, in order: YC primary first (RU-reliable), GitHub
/// release asset second (the fallback). An empty/absent fallback yields a
/// single-source list.
List<String> downloadSourcesInOrder({
  required String primaryUrl,
  String? fallbackUrl,
}) =>
    [
      primaryUrl,
      if (fallbackUrl != null && fallbackUrl.isNotEmpty) fallbackUrl,
    ];

/// Whether a check should run now: a manual check always runs; a scheduled one
/// only once the [kUpdateCheckInterval] cadence has elapsed since [lastCheck].
bool shouldRunScheduledCheck({
  required bool manual,
  required DateTime lastCheck,
  required DateTime now,
}) =>
    manual || now.difference(lastCheck) >= kUpdateCheckInterval;

/// Corruption guard only. A null [expected] passes (integrity unverified — the
/// REAL gate is the native fail-closed signing-cert pin); otherwise compare the
/// hex digests case-insensitively.
bool sha256Matches({required String? expected, required String actual}) =>
    expected == null || expected.toLowerCase() == actual.toLowerCase();

/// Streaming sha256 of [file] as lowercase hex. Never loads the whole APK into
/// memory — hashes the file in chunks off [File.openRead].
Future<String> streamFileSha256(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}
