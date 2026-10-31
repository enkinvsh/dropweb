// Общая настройка всех тестов каталога `test/` (подхватывается `flutter test` сама).
import 'dart:async';

import 'support/golden_policy.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Golden рисуются на macOS; вне него pixel-сравнение отключено (подробно в golden_policy).
  installGoldenPolicy();
  await testMain();
}
