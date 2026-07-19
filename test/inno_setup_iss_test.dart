import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Deterministic source-level guardrails on the Windows Inno installer script.
// ISCC (the Inno compiler) is Windows-only, so instead of compiling we assert
// the invariants W4.1 requires directly against the .iss source. These fail
// fast in ANY CI (macOS/Linux) if a future edit reintroduces the hostile
// behaviours we deliberately removed.
void main() {
  final iss =
      File('windows/packaging/exe/inno_setup.iss').readAsStringSync();
  final lower = iss.toLowerCase();

  // The .iss source with `//` line-comments stripped, so guardrails inspect
  // ACTUAL code and cannot be tripped (or satisfied) by prose in comments.
  final code = iss
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        return i >= 0 ? l.substring(0, i) : l;
      })
      .join('\n');
  final codeLower = code.toLowerCase();

  // Extract a function/procedure body by its header up to the next top-level
  // `function `/`procedure ` declaration. Shared across groups so guardrails
  // are SCOPED to the relevant routine (finding #7) instead of matching prose
  // or an unrelated part of the file.
  String bodyOf(String header) {
    final start = iss.indexOf(header);
    expect(start, greaterThan(-1), reason: '$header not found');
    final rest = iss.substring(start + header.length);
    final next = RegExp(r'\n(?:function |procedure )').firstMatch(rest);
    return rest.substring(0, next?.start ?? rest.length);
  }

  // The [Files] section text (between the [Files] and [Icons] headers).
  String filesSection() {
    final start = iss.indexOf('\n[Files]');
    expect(start, greaterThan(-1), reason: '[Files] section not found');
    final end = iss.indexOf('\n[Icons]', start);
    return iss.substring(start, end > start ? end : iss.length);
  }

  group('no name-based process kill (ownership gap #2/#3)', () {
    test('there is NO taskkill by image name (/im) anywhere', () {
      expect(codeLower.contains('taskkill'), isFalse,
          reason: 'taskkill kills by image name and can hit a foreign '
              'same-name binary outside {app} — forbidden');
      expect(code.contains('/im'), isFalse,
          reason: 'no /im image-name kill is allowed');
      expect(code.contains('/f /im'), isFalse);
    });

    test('the KillProcesses procedure is gone entirely', () {
      expect(code.contains('procedure KillProcesses'), isFalse,
          reason: 'KillProcesses (name-based) must be removed');
      expect(code.contains('KillProcesses;'), isFalse,
          reason: 'no call sites to KillProcesses may remain');
    });

    test('Restart Manager closes only apps locking files under {app}', () {
      expect(iss, contains('CloseApplications=yes'));
      expect(iss, contains('RestartApplications=no'));
    });
  });

  group('no unconditional service stop (ownership gap #1)', () {
    test('InitializeSetup never stops the service', () {
      final body = bodyOf('function InitializeSetup');
      expect(body.toLowerCase().contains('sc.exe'), isFalse,
          reason: 'InitializeSetup must be detection-only, no sc stop');
      expect(body.contains('DropwebHelperService'), isFalse);
    });

    test('every sc stop/delete/config sits behind a ServiceBelongsToApp gate',
        () {
      // Each raw `sc.exe`, `stop "DropwebHelperService"` at the CurStep level is
      // gated. Assert the ssInstall stop is immediately guarded by the gate.
      final gateIdx = iss.indexOf(
          "if ServiceBelongsToApp('DropwebHelperService') then");
      expect(gateIdx, greaterThan(-1),
          reason: 'ssInstall stop must be ownership-gated');
      final afterGate = iss.substring(gateIdx, gateIdx + 220);
      expect(afterGate, contains('stop "DropwebHelperService"'),
          reason: 'the only raw ssInstall stop must be inside the gate');
    });

    test('the literal ssInstall stop appears exactly once and is gated', () {
      final count =
          RegExp(r'stop "DropwebHelperService"').allMatches(iss).length;
      expect(count, 1,
          reason: 'only the gated ssInstall stop uses the raw literal; '
              'EnsureHelperService/RemoveServiceIfOurs use the ServiceName var');
    });
  });

  group('com.follow / clashx user data is never deleted', () {
    test('no DelTree / prompt against the com.follow\\clashx data dir', () {
      // The FlClashX user-data deletion prompt (DelTree of
      // %APPDATA%\com.follow\clashx — real FlClashX data we cannot prove we
      // own) must be gone entirely.
      expect(lower.contains(r'com.follow\clashx'.toLowerCase()), isFalse,
          reason: 'must not reference/delete the FlClashX user data dir');
      // No DelTree may target com.follow at all.
      final delTrees = RegExp(r'DelTree\(([^)]*)\)').allMatches(iss);
      for (final m in delTrees) {
        expect(m.group(1)!.toLowerCase().contains('com.follow'), isFalse,
            reason: 'DelTree must never touch com.follow data');
      }
      // NOTE: a bare "com.follow" may still appear as an ours-gated autostart
      // Run-VALUE name (RemoveRunValueIfOurs only deletes a Run entry whose
      // DATA points into {app} — it never touches %APPDATA%). Deleting OUR OWN
      // {userappdata}\dropweb\dropweb (with a prompt) on uninstall is fine.
    });
  });

  group('helper install runs in the FATAL [Files] AfterInstall hook '
      '(findings #1/#2)', () {
    test('helper is EXCLUDED from the wildcard [Files] entry', () {
      final files = filesSection();
      final wildcard = RegExp(r'Source: "\{\{SOURCE_DIR\}\}\\\\\*";[^\n]*')
          .firstMatch(files);
      expect(wildcard, isNotNull, reason: 'wildcard Source entry not found');
      expect(wildcard!.group(0), contains('Excludes: "DropwebHelperService.exe"'),
          reason: 'the helper must be excluded from the wildcard so the '
              'explicit AfterInstall entry owns it');
    });

    test('explicit helper entry is LAST and carries AfterInstall: '
        'EnsureHelperService', () {
      final files = filesSection();
      final helperIdx =
          files.indexOf(r'Source: "{{SOURCE_DIR}}\\DropwebHelperService.exe"');
      final wildcardIdx = files.indexOf(r'Source: "{{SOURCE_DIR}}\\*"');
      expect(helperIdx, greaterThan(-1),
          reason: 'explicit helper [Files] entry missing');
      expect(wildcardIdx, greaterThan(-1));
      expect(helperIdx, greaterThan(wildcardIdx),
          reason: 'helper entry must come AFTER the wildcard so all other '
              'files are already installed when EnsureHelperService runs');
      // No further Source: entry after the helper (it is the last one).
      expect(files.indexOf('Source:', helperIdx + 10), -1,
          reason: 'helper must be the LAST [Files] Source entry');
      final helperLine = files.substring(
          helperIdx, files.indexOf('\n', helperIdx) < 0
              ? files.length
              : files.indexOf('\n', helperIdx));
      expect(helperLine, contains('AfterInstall: EnsureHelperService'),
          reason: 'the fatal validation hook must be on the helper entry');
    });

    test('ssPostInstall NO LONGER calls EnsureHelperService (finding #1)', () {
      // ssPostInstall exceptions are swallowed by Inno (non-fatal), so the
      // validation must NOT live there anymore. Strip `//` comments first — the
      // block legitimately MENTIONS EnsureHelperService in prose explaining why
      // it moved to the AfterInstall hook.
      final curStep = bodyOf('procedure CurStepChanged');
      final postIdx = curStep.indexOf('ssPostInstall');
      expect(postIdx, greaterThan(-1));
      final postCode = curStep
          .substring(postIdx)
          .split('\n')
          .map((l) {
            final i = l.indexOf('//');
            return i >= 0 ? l.substring(0, i) : l;
          })
          .join('\n');
      expect(postCode.contains('EnsureHelperService'), isFalse,
          reason: 'EnsureHelperService must run via [Files] AfterInstall, '
              'not the non-fatal ssPostInstall step');
    });
  });

  group('EnsureHelperService fatal vs non-fatal semantics (finding #3)', () {
    test('exactly the 4 hard failures raise (missing/foreign/create/config)',
        () {
      final body = bodyOf('procedure EnsureHelperService');
      final raises = RegExp(r'RaiseException').allMatches(body).length;
      expect(raises, 4,
          reason: 'fatal raises: missing helper, foreign service, sc create '
              'failure, sc config failure — and nothing else');
    });

    test('the RUNNING-timeout path LOGS a warning and does NOT raise', () {
      final body = bodyOf('procedure EnsureHelperService');
      expect(body, contains("Log('WARNING"),
          reason: 'a registered-but-not-yet-running service must warn+continue, '
              'not fail a fully-registered install');
      // The final ServiceIsRunning guard must be followed by Log(, not raise.
      final guardIdx = body.lastIndexOf('if not ServiceIsRunning(ServiceName)');
      expect(guardIdx, greaterThan(-1));
      final tail = body.substring(guardIdx);
      expect(tail, contains('Log('),
          reason: 'RUNNING timeout logs');
      expect(tail.contains('RaiseException'), isFalse,
          reason: 'RUNNING timeout must NOT raise (false-negative on slow AV)');
    });
  });

  group('verified helper ping readiness wait (Wave 3)', () {
    test('imports GetTickCount from kernel32 for bounded polling', () {
      expect(
        iss,
        contains(
          "function GetTickCount: DWORD; external 'GetTickCount@kernel32.dll stdcall';",
        ),
        reason: 'GetTickCount is a WinAPI function, not an Inno Pascal built-in',
      );
    });

    test('verifies /ping against the installed core SHA-256', () {
      final probe = bodyOf('function HelperPingMatchesToken');
      final wait = bodyOf('procedure WaitForVerifiedHelperPing');

      expect(probe, contains('WinHttp.WinHttpRequest.5.1'));
      expect(probe, contains('http://127.0.0.1:47896/ping'));
      expect(probe, contains('Response.Status = 200'));
      expect(probe, contains('Response.ResponseText'));
      expect(wait,
          contains(r"GetSHA256OfFile(ExpandConstant('{app}\DropwebCore.exe'))"),
          reason: 'the installer must use the same core-hash token as the app');
    });

    test('poll is bounded to 15 seconds and exceptions remain non-fatal', () {
      final wait = bodyOf('procedure WaitForVerifiedHelperPing');

      expect(iss, contains('HELPER_PING_TIMEOUT_MS = 15000'));
      expect(iss, contains('HELPER_PING_POLL_MS = 300'));
      expect(wait, contains('GetTickCount'));
      expect(wait, contains('Sleep(HELPER_PING_POLL_MS)'));
      expect(wait, contains('except'));
      expect(wait, contains('helper ping timeout'));
      expect(wait, contains('proceeding with app launch'));
      expect(wait.contains('RaiseException'), isFalse,
          reason: 'ping timeout/errors must never fail installation');
    });

    test('runs after the SCM wait and before the unchanged app launch', () {
      final ensure = bodyOf('procedure EnsureHelperService');
      final runningGuard =
          ensure.lastIndexOf('if not ServiceIsRunning(ServiceName)');
      final pingWait = ensure.indexOf('WaitForVerifiedHelperPing;');
      final runSection = iss.indexOf('\n[Run]');

      expect(runningGuard, greaterThan(-1));
      expect(pingWait, greaterThan(runningGuard),
          reason: 'verified HTTP readiness follows the existing SCM wait');
      expect(runSection, greaterThan(iss.indexOf('procedure EnsureHelperService')),
          reason: 'the [Run] launch remains after helper setup code');
      expect(iss.substring(runSection), contains(
          r'Filename: "{app}\\{{EXECUTABLE_NAME}}"'));
    });
  });

  group('path-boundary ownership uses AddBackslash (finding #4)', () {
    for (final fn in const [
      'function ServiceBelongsToApp',
      'procedure RemoveRunValueIfOurs',
      'function TaskBelongsToApp',
    ]) {
      test('$fn compares against the {app}\\ boundary, no raw prefix', () {
        final body = bodyOf(fn);
        expect(body, contains("AddBackslash(ExpandConstant('{app}'))"),
            reason: '$fn must use the trailing-separator boundary to avoid a '
                'dropweb / dropweb2 prefix false positive');
        expect(body.contains("AppDir := ExpandConstant('{app}');"), isFalse,
            reason: '$fn must not keep the raw (un-boundaried) prefix compare');
      });
    }
  });

  group('service create/config quoting', () {
    test('creates the service with a correctly quoted binPath under {app}', () {
      // binPath must be quoted for the "Program Files" space. The .iss builds
      // it as:  BinPathArg := 'binPath= "' + HelperExe + '"';
      expect(iss, contains('binPath= "'));
      expect(iss, contains("HelperExe := ExpandConstant('{app}\\DropwebHelperService.exe')"));
      expect(iss, contains('start= auto'));
      expect(iss, contains("'create \"' + ServiceName + '\" ' + BinPathArg"));
      expect(iss, contains('sc.exe'));
    });

    test('foreign same-name service aborts instead of overwrite/delete', () {
      // The present-but-not-ours branch must RaiseException, not sc delete.
      expect(iss, contains('RaiseException'));
      expect(iss, contains('ServiceBelongsToApp'));
    });

    test('irrecoverable failure raises (nonzero silent exit)', () {
      expect(iss, contains('RaiseException'));
    });

    test('upgrade path checks ServiceBelongsToApp BEFORE sc config (ordering)',
        () {
      final ensureIdx = iss.indexOf('procedure EnsureHelperService');
      expect(ensureIdx, greaterThan(-1));
      final endIdx = iss.indexOf('procedure RemoveServiceIfOurs');
      final body = iss.substring(ensureIdx, endIdx);
      final gateIdx = body.indexOf('ServiceBelongsToApp(ServiceName)');
      final configIdx = body.indexOf("'config \"'");
      expect(gateIdx, greaterThan(-1),
          reason: 'EnsureHelperService must gate on ServiceBelongsToApp');
      expect(configIdx, greaterThan(-1), reason: 'sc config must be present');
      expect(gateIdx, lessThan(configIdx),
          reason: 'ownership must be proven before reconfiguring the service');
    });
  });

  group('uninstall never deletes a foreign service', () {
    test('service teardown is ownership-gated via RemoveServiceIfOurs', () {
      final uninstallIdx = iss.indexOf('usUninstall:');
      expect(uninstallIdx, greaterThan(0));
      final postIdx = iss.indexOf('usPostUninstall:');
      final uninstallBlock = iss.substring(uninstallIdx, postIdx);
      // Must gate on ownership, must NOT unconditionally `sc delete`.
      expect(uninstallBlock, contains("RemoveServiceIfOurs('DropwebHelperService')"));
      expect(uninstallBlock.contains("'delete \"DropwebHelperService\"'"),
          isFalse,
          reason: 'uninstall must not unconditionally delete the service');
    });
  });

  group('unique identity values unchanged', () {
    test('service name / port stay the dropweb values', () {
      expect(iss, contains('DropwebHelperService'));
    });
  });
}
