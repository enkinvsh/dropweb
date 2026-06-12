import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/input.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class System {
  factory System() {
    _instance ??= System._internal();
    return _instance!;
  }

  System._internal();
  static System? _instance;
  List<String>? originDns;

  /// SharedPreferences key for the persisted pre-injection macOS DNS. Persisting
  /// the TRUE origin survives a crash/force-kill while the VPN is connected — a
  /// later launch must NOT read the already-poisoned live DNS (containing the
  /// injected 1.1.1.1) as "origin". Stored as a `List<String>`; an empty list is
  /// a valid "no DNS set" state, distinct from the key being absent.
  static const _macosOriginDnsKey = 'macos_origin_dns';

  /// Serializes every set/restore so rapid VPN toggles can't run parallel
  /// `networksetup` invocations and capture the injected DNS as the origin.
  Future<void> _dnsOp = Future.value();

  bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool get isMobile => Platform.isAndroid || Platform.isIOS;

  /// Whether decoding a QR code from a gallery image is supported.
  ///
  /// `mobile_scanner`'s `analyzeImage` only has a native implementation on
  /// Android, iOS and macOS. On Windows/Linux it throws
  /// MissingPluginException, so callers must gate the feature on this.
  bool get supportsQrFromImage => !Platform.isWindows && !Platform.isLinux;

  Future<bool> get isAndroidTV async {
    if (!Platform.isAndroid) return false;
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    return deviceInfo.systemFeatures.contains('android.software.leanback');
  }

  Future<int> get version async {
    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    return switch (Platform.operatingSystem) {
      "macos" => (deviceInfo as MacOsDeviceInfo).majorVersion,
      "android" => (deviceInfo as AndroidDeviceInfo).version.sdkInt,
      "windows" => (deviceInfo as WindowsDeviceInfo).majorVersion,
      String() => 0
    };
  }

  Future<bool> checkIsAdmin() async {
    final corePath = appPath.corePath.replaceAll(' ', r'\\ ');
    if (Platform.isWindows) {
      final result = await windows?.checkService();
      return result == WindowsHelperServiceStatus.running;
    } else if (Platform.isMacOS) {
      final result = await Process.run('stat', ['-f', '%Su:%Sg %Sp', corePath]);
      final output = result.stdout.trim();
      if (output.startsWith('root:admin') && output.contains('rws')) {
        return true;
      }
      return false;
    } else if (Platform.isLinux) {
      final result = await Process.run('stat', ['-c', '%U:%G %A', corePath]);
      final output = result.stdout.trim();
      if (output.startsWith('root:') && output.contains('rws')) {
        return true;
      }
      return false;
    }
    return true;
  }

  Future<AuthorizeCode> authorizeCore() async {
    if (Platform.isAndroid) {
      return AuthorizeCode.error;
    }

    if (Platform.isMacOS) {
      return AuthorizeCode.none;
    }

    final isAdmin = await checkIsAdmin();
    if (isAdmin) {
      return AuthorizeCode.none;
    }

    if (Platform.isWindows) {
      // First, try to start existing service without UAC
      final startedWithoutUac = await windows?.tryStartExistingService();
      if (startedWithoutUac == true) {
        return AuthorizeCode.success;
      }

      // Service not installed or couldn't start - need to install with UAC
      final result = await windows?.installService();
      if (result == true) {
        return AuthorizeCode.success;
      }
      return AuthorizeCode.error;
    } else if (Platform.isLinux) {
      final password = await globalState.showCommonDialog<String>(
        child: InputDialog(
          title: appLocalizations.pleaseInputAdminPassword,
          value: '',
        ),
      );
      if (password == null || password.isEmpty) {
        return AuthorizeCode.error;
      }

      // SECURITY: password via stdin, not shell interpolation (injection risk).
      final corePathRaw = appPath.corePath;

      Future<int> runSudo(List<String> cmd) async {
        final process = await Process.start(
          'sudo',
          ['-S', '--prompt=', ...cmd],
          runInShell: false,
        );
        process.stdin.writeln(password);
        await process.stdin.flush();
        await process.stdin.close();
        return process.exitCode;
      }

      final chownCode = await runSudo(['chown', 'root:root', corePathRaw]);
      if (chownCode != 0) return AuthorizeCode.error;
      final chmodCode = await runSudo(['chmod', '+sx', corePathRaw]);
      if (chmodCode != 0) return AuthorizeCode.error;
      return AuthorizeCode.success;
    }
    return AuthorizeCode.error;
  }

  Future<String?> getMacOSDefaultServiceName() async {
    if (!Platform.isMacOS) {
      return null;
    }
    final result = await Process.run('route', ['-n', 'get', 'default']);
    final output = result.stdout.toString();
    final deviceLine = output
        .split('\n')
        .firstWhere((s) => s.contains('interface:'), orElse: () => "");
    final lineSplits = deviceLine.trim().split(' ');
    if (lineSplits.length != 2) {
      return null;
    }
    final device = lineSplits[1];
    final serviceResult = await Process.run(
      'networksetup',
      ['-listnetworkserviceorder'],
    );
    final serviceResultOutput = serviceResult.stdout.toString();
    final currentService = serviceResultOutput.split('\n\n').firstWhere(
          (s) => s.contains("Device: $device"),
          orElse: () => "",
        );
    if (currentService.isEmpty) {
      return null;
    }
    final currentServiceNameLine = currentService.split("\n").firstWhere(
        (line) => RegExp(r'^\(\d+\).*').hasMatch(line),
        orElse: () => "");
    // Service names can contain spaces ("Thunderbolt Ethernet",
    // "USB 10/100/1000 LAN"), so a naive split(' ')[1] truncates them and the
    // subsequent -getdnsservers/-setdnsservers calls hit the wrong service or
    // fail. Strip only the leading "(N) " index and keep the full remainder.
    final trimmedLine = currentServiceNameLine.trim();
    final serviceName = trimmedLine.replaceFirst(RegExp(r'^\(\d+\)\s*'), '');
    // When the regex didn't match (no "(N)" prefix) the string is unchanged —
    // preserve the old "couldn't parse" semantics and bail out.
    if (serviceName.isEmpty || serviceName == trimmedLine) {
      return null;
    }
    return serviceName;
  }

  Future<List<String>?> getMacOSOriginDns() async {
    if (!Platform.isMacOS) {
      return null;
    }
    final deviceServiceName = await getMacOSDefaultServiceName();
    if (deviceServiceName == null) {
      return null;
    }
    final result = await Process.run(
      'networksetup',
      ['-getdnsservers', deviceServiceName],
    );
    final output = result.stdout.toString().trim();
    if (output.startsWith("There aren't any DNS Servers set on")) {
      originDns = [];
    } else {
      originDns = output.split("\n");
    }
    return originDns;
  }

  /// Reads the persisted pre-injection DNS. Returns null when the key is absent
  /// (no unclean-exit recovery needed); an empty list means "origin had no DNS".
  Future<List<String>?> _readPersistedOriginDns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_macosOriginDnsKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistOriginDns(List<String> dns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_macosOriginDnsKey, dns);
    } catch (_) {
      // Best-effort: failure to persist degrades crash recovery, not the
      // live inject/restore which still works off in-memory [originDns].
    }
  }

  Future<void> _clearPersistedOriginDns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_macosOriginDnsKey);
    } catch (_) {
      // Best-effort.
    }
  }

  /// Public entry point — signature is unchanged for callers. Every set/restore
  /// is chained onto [_dnsOp] so they run strictly one-at-a-time; this prevents
  /// a concurrent restore from re-reading the injected DNS as the new origin.
  Future<void> setMacOSDns(bool restore) {
    final next = _dnsOp.then((_) => _setMacOSDnsInner(restore)).catchError((_) {});
    _dnsOp = next;
    return next;
  }

  Future<void> _setMacOSDnsInner(bool restore) async {
    if (!Platform.isMacOS) {
      return;
    }
    final serviceName = await getMacOSDefaultServiceName();
    if (serviceName == null) {
      return;
    }
    List<String>? nextDns;
    if (restore) {
      // Restore target: in-memory origin if this session captured it, else the
      // persisted list — which covers restoring after a crash on next launch.
      nextDns = originDns ?? await _readPersistedOriginDns();
    } else {
      // Establish the TRUE pre-injection DNS. If a persisted origin already
      // exists, a previous session injected 1.1.1.1 but never restored (unclean
      // exit) — the live DNS is poisoned, so trust the persisted origin instead
      // of re-reading. Otherwise read the live DNS and persist it BEFORE the
      // inject so a crash mid-session is still recoverable on next launch.
      final persisted = await _readPersistedOriginDns();
      List<String>? origin;
      if (persisted != null) {
        origin = persisted;
        originDns = persisted;
      } else {
        origin = await system.getMacOSOriginDns();
        if (origin == null) {
          return;
        }
        await _persistOriginDns(origin);
      }
      const needAddDns = "1.1.1.1"; // Cloudflare DNS
      if (origin.contains(needAddDns)) {
        return;
      }
      nextDns = List.from(origin)..add(needAddDns);
    }
    if (nextDns == null) {
      return;
    }
    await Process.run(
      'networksetup',
      [
        '-setdnsservers',
        serviceName,
        if (nextDns.isNotEmpty) ...nextDns,
        if (nextDns.isEmpty) "Empty",
      ],
    );
    if (restore) {
      // Clean state after a successful restore: drop the persisted origin so the
      // next inject reads fresh live DNS rather than a stale recovery value.
      await _clearPersistedOriginDns();
    }
  }

  Future<void> back() async {
    await app?.moveTaskToBack();
    await window?.hide();
  }

  Future<void> exit() async {
    if (Platform.isAndroid) {
      await SystemNavigator.pop();
    }
    await window?.close();
  }
}

final system = System();
