import 'package:dropweb/common/windows_conflict.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ourHelper = r'C:\Program Files\dropweb\DropwebHelperService.exe';

  group('helper service ownership', () {
    test('quoted owned binPath with arguments allows destructive operation',
        () async {
      const scQcOutput = r'''
[SC] QueryServiceConfig SUCCESS

SERVICE_NAME: DropwebHelperService
        TYPE               : 10  WIN32_OWN_PROCESS
        START_TYPE         : 2   AUTO_START
        BINARY_PATH_NAME   : "C:\Program Files\dropweb\DropwebHelperService.exe" --run-service
        DISPLAY_NAME       : DropwebHelperService
''';
      var destructiveInvocations = 0;

      final ownership = WindowsConflict.helperServiceOwnership(
        scQcOutput: scQcOutput,
        ourHelperPath: ourHelper,
      );
      final result = await WindowsConflict.runOwnedHelperDestructiveOperation(
        ownership: ownership,
        operation: () async {
          destructiveInvocations++;
          return true;
        },
      );

      expect(ownership, HelperServiceOwnership.owned);
      expect(result.value, isTrue);
      expect(result.conflict, isNull);
      expect(destructiveInvocations, 1);

      const quotedRegOutput = r'''
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DropwebHelperService
    ImagePath    REG_EXPAND_SZ    "C:\Program Files\dropweb\DropwebHelperService.exe" --run-service
''';
      const unquotedRegOutput =
          'HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\DropwebHelperService\n'
          '\tImagePath\t REG_SZ   C:\\Program Files\\dropweb\\DropwebHelperService.exe\n';
      const russianScQcOutput = r'''
[SC] QueryServiceConfig SUCCESS
        ИМЯ_ДВОИЧНОГО_ФАЙЛА   : "C:\Program Files\dropweb\DropwebHelperService.exe"
''';
      const foreignRegOutput = r'''
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DropwebHelperService
    ImagePath    REG_SZ    C:\Other\foo.exe
''';

      expect(
        WindowsConflict.serviceImagePathFromRegQuery(quotedRegOutput),
        r'"C:\Program Files\dropweb\DropwebHelperService.exe" --run-service',
      );
      expect(
        WindowsConflict.helperServiceOwnership(
          regQueryOutput: quotedRegOutput,
          scQcOutput: '',
          ourHelperPath: ourHelper,
        ),
        HelperServiceOwnership.owned,
      );
      expect(
        WindowsConflict.serviceImagePathFromRegQuery(unquotedRegOutput),
        ourHelper,
      );
      expect(
        WindowsConflict.helperServiceOwnership(
          regQueryOutput: unquotedRegOutput,
          scQcOutput: '',
          ourHelperPath: ourHelper,
        ),
        HelperServiceOwnership.owned,
      );
      expect(WindowsConflict.serviceBinPath(russianScQcOutput), isNull);
      expect(
        WindowsConflict.helperServiceOwnership(
          regQueryOutput: quotedRegOutput,
          scQcOutput: russianScQcOutput,
          ourHelperPath: ourHelper,
        ),
        HelperServiceOwnership.owned,
      );

      for (final (regQueryOutput, scQcOutput, expectedOwnership) in [
        (foreignRegOutput, russianScQcOutput, HelperServiceOwnership.foreign),
        (
          'unparseable registry',
          russianScQcOutput,
          HelperServiceOwnership.unknown
        ),
      ]) {
        var blockedInvocations = 0;
        final blockedOwnership = WindowsConflict.helperServiceOwnership(
          regQueryOutput: regQueryOutput,
          scQcOutput: scQcOutput,
          ourHelperPath: ourHelper,
        );
        final blockedResult =
            await WindowsConflict.runOwnedHelperDestructiveOperation(
          ownership: blockedOwnership,
          operation: () async {
            blockedInvocations++;
            return true;
          },
        );

        expect(blockedOwnership, expectedOwnership);
        expect(blockedResult.conflict, isA<HelperServiceConflictException>());
        expect(blockedInvocations, 0);
      }
    });

    test('foreign binPath returns specific conflict and invokes no operation',
        () async {
      const scQcOutput = r'''
[SC] QueryServiceConfig SUCCESS
        BINARY_PATH_NAME   : C:\Other\foo.exe
''';
      var destructiveInvocations = 0;

      final ownership = WindowsConflict.helperServiceOwnership(
        scQcOutput: scQcOutput,
        ourHelperPath: ourHelper,
      );
      final result = await WindowsConflict.runOwnedHelperDestructiveOperation(
        ownership: ownership,
        operation: () async {
          destructiveInvocations++;
          return true;
        },
      );

      expect(ownership, HelperServiceOwnership.foreign);
      expect(result.value, isNull);
      expect(result.conflict, isA<HelperServiceConflictException>());
      expect(result.conflict.toString(), contains('helper service conflict'));
      expect(destructiveInvocations, 0);
    });

    test('malformed or empty sc qc output is unknown and blocks destruction',
        () async {
      for (final scQcOutput in [
        '',
        '[SC] malformed output',
        r'BINARY_PATH_NAME_OLD : "C:\Program Files\dropweb\DropwebHelperService.exe"',
      ]) {
        var destructiveInvocations = 0;

        final ownership = WindowsConflict.helperServiceOwnership(
          scQcOutput: scQcOutput,
          ourHelperPath: ourHelper,
        );
        final result = await WindowsConflict.runOwnedHelperDestructiveOperation(
          ownership: ownership,
          operation: () async {
            destructiveInvocations++;
            return true;
          },
        );

        expect(ownership, HelperServiceOwnership.unknown);
        expect(result.conflict, isA<HelperServiceConflictException>());
        expect(destructiveInvocations, 0);
      }
    });
  });
}
