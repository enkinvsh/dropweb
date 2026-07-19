/// Pure parsing + ownership helpers for Windows helper-port conflict
/// resolution (fixed port 47896).
///
/// Deliberately contains NO `dart:ffi` / `win32` / `Process` imports so every
/// function here is unit-testable on any host (macOS/Linux CI) without a
/// Windows box. The impure orchestration (running netstat/sc/taskkill and
/// acting on the decision) lives in `windows.dart`.
///
/// The whole point: decide whether the process squatting our helper port is a
/// STALE COPY OF OUR OWN helper (safe to kill) or a FOREIGN process — e.g. a
/// separately-installed FlClashX or an unrelated app that merely happens to
/// hold the port. We only ever kill on proof of ownership; a foreign holder is
/// left completely alone.
library;

/// Outcome of `resolveHelperPortConflict`, surfaced so callers do NOT assume
/// the port was freed.
enum HelperPortConflictResult {
  /// The port is held by our own healthy helper (identity ping matched our
  /// core hash). Nothing to do — the port is effectively ours.
  healthy,

  /// Nobody is LISTENING on the port. It is free for our helper to bind.
  free,

  /// A stale copy of OUR helper (proven by executable path and/or our service
  /// binPath) held the port; we killed it. The port should now be free.
  freedOurs,

  /// A FOREIGN process holds the port and we left it untouched. The port is
  /// NOT free — the caller must fall back (spawn the core directly) instead of
  /// assuming our helper can bind.
  foreignHeld,
}

enum HelperServiceOwnership { owned, foreign, unknown }

final class HelperServiceConflictException implements Exception {
  const HelperServiceConflictException(this.ownership);

  final HelperServiceOwnership ownership;

  @override
  String toString() =>
      'helper service conflict: service ownership is ${ownership.name}';
}

final class HelperDestructiveOperationResult<T> {
  const HelperDestructiveOperationResult.allowed(this.value) : conflict = null;

  const HelperDestructiveOperationResult.blocked(this.conflict) : value = null;

  final T? value;
  final HelperServiceConflictException? conflict;

  bool get isAllowed => conflict == null;
}

class WindowsConflict {
  const WindowsConflict._();

  /// Extract the PIDs that are LISTENING on [port] from `netstat -ano` output.
  ///
  /// A LISTENING TCP row looks like:
  ///   `  TCP    127.0.0.1:47896    0.0.0.0:0    LISTENING    12345`
  /// We match strictly on the LOCAL-address column ending in `:<port>` and the
  /// `LISTENING` state so a remote/foreign address that merely ends in the
  /// same digits (or an ESTABLISHED connection) is never mistaken for a
  /// port holder.
  static List<int> listeningPids(String netstatOutput, int port) {
    final pids = <int>[];
    for (final raw in netstatOutput.split('\n')) {
      final parts = raw.trim().split(RegExp(r'\s+'));
      // Proto  Local  Foreign  State  PID  → at least 5 columns.
      if (parts.length < 5) continue;
      final proto = parts[0].toUpperCase();
      if (proto != 'TCP' && proto != 'TCP6') continue;
      if (parts[3].toUpperCase() != 'LISTENING') continue;
      if (!parts[1].endsWith(':$port')) continue;
      final pid = int.tryParse(parts[parts.length - 1]);
      if (pid != null && pid > 0) pids.add(pid);
    }
    return pids;
  }

  /// Parse the `BINARY_PATH_NAME` value out of `sc qc <service>` output.
  /// Returns null when the field is absent (service missing / query failed).
  static String? serviceBinPath(String scQcOutput) {
    for (final raw in scQcOutput.split('\n')) {
      final line = raw.trim();
      final field = RegExp(
        r'^BINARY_PATH_NAME\s*:',
        caseSensitive: false,
      ).firstMatch(line);
      if (field == null) continue;
      final value = line.substring(field.end).trim();
      return value.isEmpty ? null : value;
    }
    return null;
  }

  /// Parse the locale-stable `ImagePath` value out of `reg query` output.
  /// The value may be `REG_EXPAND_SZ` or `REG_SZ`; everything after that type
  /// token is the service command line and is normalized by [exePathIsOurs].
  static String? serviceImagePathFromRegQuery(String regQueryOutput) {
    final field = RegExp(
      r'\bImagePath\b\s+(?:REG_EXPAND_SZ|REG_SZ)\s+(.+)$',
      caseSensitive: false,
    );
    for (final raw in regQueryOutput.split('\n')) {
      final match = field.firstMatch(raw);
      if (match == null) continue;
      final value = match.group(1)!.trim();
      return value.isEmpty ? null : value;
    }
    return null;
  }

  static HelperServiceOwnership helperServiceOwnership({
    String regQueryOutput = '',
    required String scQcOutput,
    required String ourHelperPath,
  }) {
    final servicePath = serviceImagePathFromRegQuery(regQueryOutput) ??
        serviceBinPath(scQcOutput);
    if (servicePath == null) return HelperServiceOwnership.unknown;
    return exePathIsOurs(servicePath, ourHelperPath)
        ? HelperServiceOwnership.owned
        : HelperServiceOwnership.foreign;
  }

  static Future<HelperDestructiveOperationResult<T>>
      runOwnedHelperDestructiveOperation<T>({
    required HelperServiceOwnership ownership,
    required Future<T> Function() operation,
  }) async {
    if (ownership != HelperServiceOwnership.owned) {
      return HelperDestructiveOperationResult.blocked(
        HelperServiceConflictException(ownership),
      );
    }
    return HelperDestructiveOperationResult.allowed(await operation());
  }

  /// Parse the `PID` value out of `sc queryex <service>` output.
  /// Returns null when absent or zero (a stopped service reports PID 0).
  static int? serviceQueryexPid(String scQueryexOutput) {
    for (final raw in scQueryexOutput.split('\n')) {
      final line = raw.trim();
      if (!line.toUpperCase().startsWith('PID')) continue;
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      final pid = int.tryParse(line.substring(colon + 1).trim());
      if (pid != null && pid > 0) return pid;
      return null;
    }
    return null;
  }

  /// Normalise a Windows executable path for comparison: strip wrapping
  /// quotes, unify slashes, collapse to lower-case (Windows paths are
  /// case-insensitive). A service binPath may carry trailing CLI args after
  /// the quoted exe — only the exe itself is compared.
  static String normalizePath(String? path) {
    if (path == null) return '';
    var p = path.trim();
    if (p.isEmpty) return '';
    // `"C:\...\Helper.exe" --flag`  → keep only the quoted exe.
    if (p.startsWith('"')) {
      final close = p.indexOf('"', 1);
      if (close > 0) p = p.substring(1, close);
    }
    return p.replaceAll('/', r'\').toLowerCase().trim();
  }

  /// True when [candidate] refers to the SAME executable as our installed
  /// helper [ourHelperPath]. Case/quote/slash-insensitive.
  static bool exePathIsOurs(String? candidate, String ourHelperPath) {
    final a = normalizePath(candidate);
    final b = normalizePath(ourHelperPath);
    return a.isNotEmpty && a == b;
  }

  /// The core ownership decision for a single port-holding PID, given the
  /// evidence gathered by the caller. Kept pure so the foreign-vs-ours branch
  /// is unit-tested without touching a real machine.
  ///
  /// * [pidExePath] — executable path of the process holding the port.
  /// * [ourHelperPath] — `{app}\DropwebHelperService.exe` for THIS install.
  /// * [serviceBinPathValue] — binPath of the installed DropwebHelperService
  ///   (null if the service does not exist).
  /// * [servicePid] — PID the SCM reports for DropwebHelperService (null/0 if
  ///   stopped or absent).
  /// * [holderPid] — the PID actually holding the port.
  ///
  /// Returns true ONLY when there is positive proof the holder is a stale copy
  /// of our own helper. Absence of evidence ⇒ foreign ⇒ false (leave alone).
  static bool holderIsOurStaleHelper({
    required String? pidExePath,
    required String ourHelperPath,
    required String? serviceBinPathValue,
    required int? servicePid,
    required int holderPid,
  }) {
    // Evidence 1: the holder's own executable IS our installed helper binary.
    if (exePathIsOurs(pidExePath, ourHelperPath)) return true;

    // Evidence 2: our DropwebHelperService points at our helper binary AND the
    // SCM says that service is the process holding the port.
    final serviceIsOurs = exePathIsOurs(serviceBinPathValue, ourHelperPath);
    if (serviceIsOurs && servicePid != null && servicePid == holderPid) {
      return true;
    }

    return false;
  }
}
