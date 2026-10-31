import 'dart:async';

import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/screens/m3e_empty_home.dart';
import 'package:dropweb/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_path_provider.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';
import 'support/surface.dart';

/// Регрессия чёрного экрана: `CommonScaffold(fullBleed)` отдавал телу размер 0x0.
/// Golden M3E-экранов рисуют их без обвязки приложения и этого не ловят.
const _bodyKey = ValueKey<String>('full-bleed-body');

Future<void> _pump(
  WidgetTester tester,
  Widget body, {
  GlobalKey<CommonScaffoldState>? scaffoldKey,
}) async {
  final h = parseDropwebTheme(kBoardProviders[0].theme);
  await pumpM3eBoard(
    tester,
    m3eBoardApp(
      seed: h.accent,
      filter: h.filter,
      brightness: Brightness.dark,
      child: CommonScaffold(
        key: scaffoldKey,
        // assert в build() требует заголовок даже у fullBleed.
        title: '',
        fullBleed: true,
        body: body,
      ),
    ),
  );
}

void main() {
  // commonPrint.log пишет в файловый журнал, которому нужен appPath. Без подмены на Linux
  // `getDownloadsDirectory()` бросает UnsupportedError раньше канала, и ошибка падает на
  // тест, который первым вывел плашку или строку журнала.
  useFakePathProvider();
  testWidgets('тело fullBleed занимает весь экран', (tester) async {
    await _pump(tester, const SizedBox.expand(key: _bodyKey));
    expect(tester.getSize(find.byKey(_bodyKey)), kM3eBoardSize);
    expect(tester.takeException(), isNull);
  });

  testWidgets('настоящий M3eEmptyView в fullBleed: весь экран, без исключений',
      (tester) async {
    await _pump(
      tester,
      KeyedSubtree(
        key: _bodyKey,
        child: M3eEmptyView(
          onSettings: () {},
          onPaste: () {},
          onScan: () {},
        ),
      ),
    );
    expect(tester.getSize(find.byKey(_bodyKey)), kM3eBoardSize);
    expect(tester.getSize(find.byKey(kM3eEmptyKey)).height, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'во время loadingRun полосы нет, тело на весь экран, задача выполнена',
      (tester) async {
    final key = GlobalKey<CommonScaffoldState>();
    await _pump(tester, const SizedBox.expand(key: _bodyKey), scaffoldKey: key);

    final done = Completer<int>();
    final run = key.currentState!.loadingRun<int>(() => done.future);
    await tester.pump();
    // Решение владельца: у M3E-главной нет полосы загрузки под строкой состояния.
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.getSize(find.byKey(_bodyKey)), kM3eBoardSize);

    done.complete(42);
    expect(await run, 42);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.getSize(find.byKey(_bodyKey)), kM3eBoardSize);
  });
}
