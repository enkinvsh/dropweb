import 'dart:async';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/manager/message_manager.dart';
import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_model.dart';
import 'package:dropweb/ui/m3e/screens/m3e_empty_home.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_path_provider.dart';
import 'home_scenes.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';

const _toastKey = ValueKey<String>('m3e.toast');

/// Окно заданной ширины и верхним отступом [topPadding] (у Pixel 10 около 65,9).
Future<MessageManagerState> _pump(
  WidgetTester tester, {
  required double width,
  required double topPadding,
  required Widget Function(BuildContext) screen,
}) async {
  final h = parseDropwebTheme(kBoardProviders[0].theme);
  await pumpM3eBoard(
    tester,
    m3eBoardApp(
      seed: h.accent,
      filter: h.filter,
      brightness: Brightness.light,
      overrides: [
        m3eThemeSourceProvider.overrideWithValue(
          M3eThemeSource(seed: h.accent, filter: h.filter),
        ),
      ],
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            size: Size(width, 914),
            padding: EdgeInsets.only(top: topPadding, bottom: 24),
            viewPadding: EdgeInsets.only(top: topPadding, bottom: 24),
          ),
          child: MessageManager(useM3e: true, child: Builder(builder: screen)),
        ),
      ),
    ),
  );
  tester.view.physicalSize = Size(width * 2, 914 * 2);
  await tester.pump();
  return tester.state<MessageManagerState>(find.byType(MessageManager));
}

void main() {
  // commonPrint.log пишет в файловый журнал, которому нужен appPath. Без подмены на Linux
  // `getDownloadsDirectory()` бросает UnsupportedError раньше канала, и ошибка падает на
  // тест, который первым вывел плашку или строку журнала.
  useFakePathProvider();
  setUp(() => debugDisableShadows = true);

  final screens = <String, Widget Function(BuildContext)>{
    'главная': (context) => M3eHomeScreen(
          view: buildM3eHomeView(
            AppLocalizations.of(context),
            homeInputFor('home-on'),
            now: kHomeNow,
          ),
        ),
    'пустой экран': (_) =>
        M3eEmptyView(onSettings: () {}, onPaste: () {}, onScan: () {}),
  };

  for (final entry in screens.entries) {
    for (final width in [320.0, 411.0, 600.0]) {
      for (final top in [44.0, 66.0]) {
        testWidgets(
            '${entry.key}: центр тоста на линии кнопки настроек '
            '(ширина $width, отступ $top)', (tester) async {
          final manager = await _pump(
            tester,
            width: width,
            topPadding: top,
            screen: entry.value,
          );
          unawaited(manager.message('Подписка обновлена'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          final toast = tester.getRect(find.byKey(_toastKey));
          final nav = tester.getRect(find.byKey(
            entry.key == 'главная' ? kM3eNavBtnKey : kM3eNavButtonKey,
          ));
          expect(toast.center.dy, closeTo(nav.center.dy, 0.5));
          // По горизонтали плашка не накрывает кнопку.
          expect(toast.overlaps(nav), isFalse);
          await tester.pump(const Duration(seconds: 3));
          await tester.pump();
        });
      }
    }
  }
}
