import 'dart:io';

import 'package:flutter/services.dart';

// Без загруженных шрифтов flutter_test рисует Ahem (квадраты), и golden теряют смысл.
// Здесь только то, что есть в iOS-приложении: Onest и Twemoji (R4 плана). SF Pro и Roboto
// не грузим намеренно: на устройстве Apple их не подставит система под Flutter-текст, а если
// в кадре появится чужой шрифт, golden должен это показать, а не спрятать.

Future<void>? _loading;

/// Загружает Onest (все начертания) и Twemoji один раз на тестовый файл.
Future<void> loadIos27Fonts() => _loading ??= _load();

Future<void> _load() async {
  Future<void> family(String name, List<String> paths) async {
    final loader = FontLoader(name);
    for (final path in paths) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
      );
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
  await family('Onest', onest);
  await family('Twemoji', ['assets/fonts/Twemoji.Mozilla.ttf']);
}
