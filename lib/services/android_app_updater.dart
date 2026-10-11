import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dropweb/common/constant.dart';
import 'package:dropweb/models/app_update.dart';

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

/// Запускать ли проверку сейчас: ручная идёт всегда, автоматическая (старт и
/// возврат в foreground) — только когда с [lastCheck] прошёл
/// [kUpdateCheckInterval], чтобы частые сворачивания не дёргали манифест.
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

/// Предлагать ли шит обновления после АВТОМАТИЧЕСКОЙ проверки. Предлагаем только
/// готовое к действию обновление (available / readyToInstall): в остальных
/// статусах юзеру нечего нажать. «Позже» откладывает именно эту версию до
/// [snoozedUntilMs] — более новая версия предлагается сразу, иначе отложенный
/// 0.9.0 спрятал бы и вышедший следом 0.9.1. Обязательное обновление snooze не
/// признаёт (в шите для него и нет «Позже»).
bool shouldAutoOfferUpdate({
  required AppUpdateInfo? info,
  required AppUpdateStatus status,
  required String snoozedVersion,
  required int snoozedUntilMs,
  required DateTime now,
}) {
  if (info == null) return false;
  if (status != AppUpdateStatus.available &&
      status != AppUpdateStatus.readyToInstall) {
    return false;
  }
  if (info.mandatory) return true;
  final snoozed = snoozedVersion == info.version &&
      now.millisecondsSinceEpoch < snoozedUntilMs;
  return !snoozed;
}

/// Состояние после успешной проверки. [previous] — состояние ДО перехода в
/// checking: если APK этой же версии уже скачан и проверен (readyToInstall),
/// проверка при возврате в приложение не должна откатывать «Установить»
/// обратно к «Обновить» и заставлять качать заново.
AppUpdateState applyCheckResult(AppUpdateState previous, AppUpdateInfo? info) {
  if (info == null) {
    return previous.copyWith(
      status: AppUpdateStatus.upToDate,
      info: null,
      error: null,
    );
  }
  if (previous.status == AppUpdateStatus.readyToInstall &&
      previous.info?.version == info.version) {
    return previous.copyWith(info: info);
  }
  return previous.copyWith(
    status: AppUpdateStatus.available,
    info: info,
    error: null,
    dismissed: false,
  );
}
