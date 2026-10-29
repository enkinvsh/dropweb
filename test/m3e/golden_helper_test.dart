import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'support/golden.dart';

/// Ширина и высота PNG из заголовка IHDR (байты 16..23, big-endian).
(int, int) _pngSize(Uint8List b) {
  final d = ByteData.sublistView(b);
  return (d.getUint32(16), d.getUint32(20));
}

void main() {
  test('все golden в test/m3e/goldens имеют размер доски 822x1828', () {
    final files = Directory('test/m3e/goldens')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .toList();
    expect(files, isNotEmpty);
    for (final f in files) {
      expect(
        _pngSize(f.readAsBytesSync()),
        (kM3eGoldenWidth, kM3eGoldenHeight),
        reason: f.path,
      );
    }
  });
}
