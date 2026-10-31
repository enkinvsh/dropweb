// Замок книжной ориентации iOS-главной: вызывается только на iOS, снимается при уходе, счётчик
// переживает смену главной на пустую главную в одном кадре.

import 'package:dropweb/ui/ios27/home/ios27_portrait_lock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Вызовы `SystemChrome.setPreferredOrientations`: список ориентаций на каждый вызов.
List<List<String>> _record(WidgetTester tester) {
  final calls = <List<String>>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        calls.add(List<String>.from(call.arguments as List));
      }
      return null;
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    Ios27PortraitLock.debugReset();
  });
  return calls;
}

Widget _lock([Key? key]) =>
    Ios27PortraitLock(key: key, child: const SizedBox.shrink());

/// Тест на подменённой платформе: переменную нужно вернуть до проверки инвариантов Flutter,
/// `addTearDown` для этого поздно.
void _platformTest(
  String name,
  TargetPlatform platform,
  Future<void> Function(WidgetTester tester, List<List<String>> calls) body,
) {
  testWidgets(name, (tester) async {
    final calls = _record(tester);
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body(tester, calls);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  _platformTest(
      'iOS: ставит portraitUp и снимает замок при уходе', TargetPlatform.iOS,
      (tester, calls) async {
    await tester.pumpWidget(_lock());
    expect(calls, [
      ['DeviceOrientation.portraitUp'],
    ]);
    expect(Ios27PortraitLock.holders, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    // Пустой список — ориентации по умолчанию из Info.plist.
    expect(calls.last, isEmpty);
    expect(calls, hasLength(2));
    expect(Ios27PortraitLock.holders, 0);
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    _platformTest('${platform.name}: ориентация не трогается', platform,
        (tester, calls) async {
      await tester.pumpWidget(_lock());
      await tester.pumpWidget(const SizedBox.shrink());
      expect(calls, isEmpty);
      expect(Ios27PortraitLock.holders, 0);
    });
  }

  _platformTest('главная → пустая главная в одном кадре: замок остаётся',
      TargetPlatform.iOS, (tester, calls) async {
    await tester.pumpWidget(_lock(const ValueKey('home')));
    // Новый виджет получает initState раньше, чем старый — dispose.
    await tester.pumpWidget(_lock(const ValueKey('empty')));
    expect(
        calls,
        [
          ['DeviceOrientation.portraitUp'],
        ],
        reason: 'ни лишней установки, ни преждевременного снятия');
    expect(Ios27PortraitLock.holders, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(calls.last, isEmpty);
    expect(Ios27PortraitLock.holders, 0);
  });

  _platformTest('два одновременных экземпляра: снимается только последний',
      TargetPlatform.iOS, (tester, calls) async {
    await tester.pumpWidget(Column(
      textDirection: TextDirection.ltr,
      children: [_lock(const ValueKey('a')), _lock(const ValueKey('b'))],
    ));
    expect(calls, hasLength(1));
    await tester.pumpWidget(Column(
      textDirection: TextDirection.ltr,
      children: [_lock(const ValueKey('a'))],
    ));
    expect(calls, hasLength(1), reason: 'один держатель остался');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(calls, hasLength(2));
    expect(calls.last, isEmpty);
  });
}
