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
