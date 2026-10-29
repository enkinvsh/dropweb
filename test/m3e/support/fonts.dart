import 'dart:io';

import 'package:flutter/services.dart';

// Без загруженных шрифтов flutter_test рисует Ahem (квадраты), и golden теряют смысл.
// Семейства те же, что в pubspec.yaml и в коде темы: Onest, RobotoFlex, Twemoji. Roboto
// в приложение не входит (на Android он системный), для тестов лежит рядом в fonts/.

Future<void>? _loading;

/// Загружает Roboto Flex, Onest, Roboto и Twemoji один раз на тестовый файл.
Future<void> loadM3eFonts() => _loading ??= _load();

Future<void> _load() async {
  Future<void> family(String name, List<String> paths) async {
    final loader = FontLoader(name);
    for (final path in paths) {
      loader.addFont(
          Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
    }
    await loader.load();
  }

  final onest = Directory('assets/fonts')
      .listSync()
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.contains('Onest-'))
      .toList()
    ..sort();
  await family('RobotoFlex', ['assets/fonts/RobotoFlex.ttf']);
  await family('Onest', onest);
  await family('Roboto', ['test/m3e/support/fonts/Roboto.ttf']);
  await family('Twemoji', ['assets/fonts/Twemoji.Mozilla.ttf']);
}
