import 'package:flutter_test/flutter_test.dart';

import '../setup.dart' as setup;

void main() {
  group('setup.dart iOS core build', () {
    test('ios tags drop with_gvisor and keep the mesh no_* tags', () {
      final tags = setup.Build.tagsFor(setup.Target.ios).split(',');
      expect(tags, isNot(contains('with_gvisor')));
      expect(tags, containsAll(['no_tailscale', 'no_zerotier', 'no_easytier']));
    });

    test('ios core is built for low memory', () {
      final tags = setup.Build.tagsFor(setup.Target.ios).split(',');
      expect(tags, contains('with_low_memory'));
    });

    test('ios core leaves out rarely used protocols', () {
      final tags = setup.Build.tagsFor(setup.Target.ios).split(',');
      expect(tags, contains('no_extra_protocols'));
    });

    test('android and macos tags still include with_gvisor', () {
      for (final target in [setup.Target.android, setup.Target.macos]) {
        expect(
          setup.Build.tagsFor(target),
          'with_gvisor,no_tailscale,no_zerotier,no_easytier',
        );
      }
    });

    test('ios builds a c-archive, android a c-shared library', () {
      expect(
        setup.Build.buildModeFlag(setup.Target.ios),
        '-buildmode=c-archive',
      );
      expect(
        setup.Build.buildModeFlag(setup.Target.android),
        '-buildmode=c-shared',
      );
    });

    test('iosCc targets arm64 with iOS 13.0 minimum', () {
      expect(
        setup.Build.iosCc(clang: '/x/clang', sdkPath: '/sdk'),
        '/x/clang -isysroot /sdk -arch arm64 -miphoneos-version-min=13.0',
      );
    });

    test('ios library extension is .a', () {
      expect(setup.Target.ios.dynamicLibExtensionName, '.a');
    });

    group('iosRuntimePatch', () {
      const spanSet = '''
const (
	spanSetBlockEntries = 512 // 4KB on 64-bit
	spanSetInitSpineCap = 256 // Enough for 1GB heap on 64-bit
)
''';
      const debugVars = '''
	debug.cgocheck = 1
	debug.invalidptr = 1
	debug.adaptivestackstart = 1 // set this to 0 to turn larger initial goroutine stacks off
''';

      test('shrinks the span set block and the initial spine', () {
        final patched = setup.Build.iosRuntimePatch('mspanset.go', spanSet);
        expect(patched, contains('spanSetBlockEntries = 64'));
        expect(patched, contains('spanSetInitSpineCap = 16'));
        expect(patched, isNot(contains('= 512')));
        expect(patched, isNot(contains('= 256')));
      });

      test('starts goroutines with the minimum stack', () {
        final patched = setup.Build.iosRuntimePatch('runtime1.go', debugVars);
        expect(patched, contains('debug.adaptivestackstart = 0'));
        expect(patched, contains('debug.invalidptr = 1'));
      });

      test('fails loudly when the Go runtime changed', () {
        expect(
          () => setup.Build.iosRuntimePatch(
            'mspanset.go',
            spanSet.replaceFirst('= 512', '= 1024'),
          ),
          throwsA(isA<String>()),
        );
        expect(
          () => setup.Build.iosRuntimePatch(
            'runtime1.go',
            debugVars.replaceFirst(
                'adaptivestackstart = 1', 'adaptivestackstart = 2'),
          ),
          throwsA(isA<String>()),
        );
      });
    });

    test('buildItems has exactly one ios item, arm64', () {
      final ios = setup.Build.buildItems
          .where((item) => item.target == setup.Target.ios)
          .toList();
      expect(ios, hasLength(1));
      expect(ios.single.arch, setup.Arch.arm64);
      expect(ios.single.archName, isNull);
    });
  });
}
