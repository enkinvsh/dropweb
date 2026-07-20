import 'package:dropweb/common/windows_conflict.dart';
import 'package:flutter_test/flutter_test.dart';

// Pure unit tests for the Windows helper-port (47896) conflict ownership
// logic. These run on any host (no Windows / ffi needed) because the parsers
// and the decision function are side-effect free.
void main() {
  const ourHelper = r'C:\Program Files\dropweb\DropwebHelperService.exe';

  group('listeningPids', () {
    test('extracts the PID LISTENING on our port only', () {
      const netstat = '''
Active Connections

  Proto  Local Address          Foreign Address        State           PID
  TCP    127.0.0.1:47896        0.0.0.0:0              LISTENING       4242
  TCP    127.0.0.1:7890         0.0.0.0:0              LISTENING       999
  TCP    127.0.0.1:47896        93.184.216.34:443     ESTABLISHED     5000
''';
      expect(WindowsConflict.listeningPids(netstat, 47896), [4242]);
    });

    test('ignores a foreign remote address that ends in the port digits', () {
      const netstat = '''
  TCP    10.0.0.5:51000         203.0.113.9:47896     ESTABLISHED     7777
''';
      expect(WindowsConflict.listeningPids(netstat, 47896), isEmpty);
    });

    test('matches IPv6 TCP6 listeners', () {
      const netstat = '''
  TCP6   [::1]:47896            [::]:0                 LISTENING       3311
''';
      expect(WindowsConflict.listeningPids(netstat, 47896), [3311]);
    });

    test('returns empty when nobody listens', () {
      expect(WindowsConflict.listeningPids('', 47896), isEmpty);
    });
  });

  group('serviceBinPath', () {
    test('parses the quoted binary path', () {
      const qc = '''
[SC] QueryServiceConfig SUCCESS

SERVICE_NAME: DropwebHelperService
        TYPE               : 10  WIN32_OWN_PROCESS
        START_TYPE         : 2   AUTO_START
        BINARY_PATH_NAME   : "C:\\Program Files\\dropweb\\DropwebHelperService.exe"
        DISPLAY_NAME       : DropwebHelperService
''';
      expect(
        WindowsConflict.serviceBinPath(qc),
        r'"C:\Program Files\dropweb\DropwebHelperService.exe"',
      );
    });

    test('returns null when the field is absent', () {
      expect(WindowsConflict.serviceBinPath('[SC] OpenService FAILED 1060'),
          isNull);
    });

    test('parses sc qc output with Windows CRLF line endings', () {
      const qc = '[SC] QueryServiceConfig SUCCESS\r\n'
          'SERVICE_NAME: DropwebHelperService\r\n'
          '        BINARY_PATH_NAME   : '
          '"C:\\Program Files\\dropweb\\DropwebHelperService.exe"\r\n';

      expect(
        WindowsConflict.serviceBinPath(qc),
        r'"C:\Program Files\dropweb\DropwebHelperService.exe"',
      );
    });
  });

  group('serviceImagePathFromRegQuery', () {
    test('parses the exact field reg query head with CRLF line endings', () {
      const reg = '\r\n'
          'HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\'
          'DropwebHelperService\r\n'
          '    ImagePath    REG_EXPAND_SZ    '
          'C:\\Program Files\\dropweb\\DropwebHelperService.exe\r\n';

      expect(WindowsConflict.serviceImagePathFromRegQuery(reg), ourHelper);
      expect(
        WindowsConflict.helperServiceOwnership(
          regQueryOutput: reg,
          scQcOutput: '',
          ourHelperPath: ourHelper,
        ),
        HelperServiceOwnership.owned,
      );
    });

    test('parses a quoted ImagePath with arguments and CRLF line endings', () {
      const reg = 'HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\'
          'DropwebHelperService\r\n'
          '    ImagePath    REG_SZ    '
          '"C:\\Program Files\\dropweb\\DropwebHelperService.exe" '
          '--run-service\r\n';

      expect(
        WindowsConflict.serviceImagePathFromRegQuery(reg),
        r'"C:\Program Files\dropweb\DropwebHelperService.exe" --run-service',
      );
      expect(
        WindowsConflict.helperServiceOwnership(
          regQueryOutput: reg,
          scQcOutput: '',
          ourHelperPath: ourHelper,
        ),
        HelperServiceOwnership.owned,
      );
    });
  });

  group('serviceQueryexPid', () {
    test('parses a running service PID', () {
      const qex = '''
SERVICE_NAME: DropwebHelperService
        TYPE               : 10  WIN32_OWN_PROCESS
        STATE              : 4  RUNNING
        PID                : 4242
        FLAGS              :
''';
      expect(WindowsConflict.serviceQueryexPid(qex), 4242);
    });

    test('treats PID 0 (stopped) as null', () {
      const qex = '''
        STATE              : 1  STOPPED
        PID                : 0
''';
      expect(WindowsConflict.serviceQueryexPid(qex), isNull);
    });
  });

  group('exePathIsOurs', () {
    test('matches case / slash / quote insensitively', () {
      expect(
        WindowsConflict.exePathIsOurs(
          r'"c:\program files\dropweb\dropwebhelperservice.exe"',
          ourHelper,
        ),
        isTrue,
      );
    });

    test('rejects a foreign FlClashX path', () {
      expect(
        WindowsConflict.exePathIsOurs(
          r'C:\Program Files\FlClashX\FlClashHelperService.exe',
          ourHelper,
        ),
        isFalse,
      );
    });

    test('rejects null', () {
      expect(WindowsConflict.exePathIsOurs(null, ourHelper), isFalse);
    });
  });

  group('normalizePath / binPath-with-args (finding #5)', () {
    test('a QUOTED binPath with trailing args resolves to the bare exe', () {
      // sc qc BINARY_PATH_NAME for our installer-created service is quoted:
      //   "C:\Program Files\dropweb\DropwebHelperService.exe"
      // and may carry service args after the closing quote — only the exe
      // inside the quotes is compared, so it still matches ours.
      expect(
        WindowsConflict.exePathIsOurs(
          r'"C:\Program Files\dropweb\DropwebHelperService.exe" --run-service',
          ourHelper,
        ),
        isTrue,
      );
      expect(
        WindowsConflict.normalizePath(
            r'"C:\Program Files\dropweb\DropwebHelperService.exe" --run-service'),
        r'c:\program files\dropweb\dropwebhelperservice.exe',
      );
    });

    test(
        'an UNQUOTED binPath with args does NOT match ours '
        '(conservative — never widen kill ownership)', () {
      // Without wrapping quotes we cannot safely split exe from args, so the
      // trailing args stay in the normalized value and it will NOT equal our
      // clean helper path. That is deliberate: ambiguous evidence must fall to
      // "not ours" (leave it alone) rather than risk killing a foreign process.
      expect(
        WindowsConflict.exePathIsOurs(
          r'C:\Program Files\dropweb\DropwebHelperService.exe --run-service',
          ourHelper,
        ),
        isFalse,
      );
    });

    test('an UNQUOTED clean binPath (no args) still matches ours', () {
      expect(
        WindowsConflict.exePathIsOurs(
          r'C:\Program Files\dropweb\DropwebHelperService.exe',
          ourHelper,
        ),
        isTrue,
      );
    });
  });

  group('holderIsOurStaleHelper', () {
    test('OURS by executable path -> kill', () {
      expect(
        WindowsConflict.holderIsOurStaleHelper(
          pidExePath: ourHelper,
          ourHelperPath: ourHelper,
          serviceBinPathValue: null,
          servicePid: null,
          holderPid: 4242,
        ),
        isTrue,
      );
    });

    test('OURS by our service owning the holder PID -> kill', () {
      expect(
        WindowsConflict.holderIsOurStaleHelper(
          pidExePath: null, // exe path unreadable
          ourHelperPath: ourHelper,
          serviceBinPathValue: '"$ourHelper"',
          servicePid: 4242,
          holderPid: 4242,
        ),
        isTrue,
      );
    });

    test('FOREIGN FlClashX helper -> leave alone', () {
      expect(
        WindowsConflict.holderIsOurStaleHelper(
          pidExePath: r'C:\Program Files\FlClashX\FlClashHelperService.exe',
          ourHelperPath: ourHelper,
          serviceBinPathValue:
              r'"C:\Program Files\FlClashX\FlClashHelperService.exe"',
          servicePid: 4242,
          holderPid: 4242,
        ),
        isFalse,
      );
    });

    test('unknown exe + our service points elsewhere / different PID -> leave',
        () {
      expect(
        WindowsConflict.holderIsOurStaleHelper(
          pidExePath: null,
          ourHelperPath: ourHelper,
          serviceBinPathValue: '"$ourHelper"',
          servicePid: 111, // our service is a DIFFERENT pid than the holder
          holderPid: 4242,
        ),
        isFalse,
      );
    });

    test('unidentifiable foreign holder (no evidence at all) -> leave alone',
        () {
      expect(
        WindowsConflict.holderIsOurStaleHelper(
          pidExePath: null,
          ourHelperPath: ourHelper,
          serviceBinPathValue: null,
          servicePid: null,
          holderPid: 4242,
        ),
        isFalse,
      );
    });
  });
}
