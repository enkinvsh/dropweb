// Разбор и печать hex-цветов с теми же правилами, что у argbFromHex/hexFromArgb в MCU TS:
// доска сравнивает цвета строками, поэтому форма записи (нижний регистр) важна.

/// ARGB (альфа всегда 0xFF) из `#rgb`, `#rrggbb` или `#aarrggbb` (альфа отбрасывается),
/// `#` необязателен. Вернёт `null`, если длина не 3/6/8 — на этом месте в TS бросается
/// исключение, а доска откатывается на запасной цвет.
int? argbFromHexOrNull(String hex) {
  final h = hex.replaceFirst('#', '');
  String pair(int from, int to) => h.substring(from, to);
  int byte(String s) => int.tryParse(s, radix: 16) ?? 0;

  int r;
  int g;
  int b;
  switch (h.length) {
    case 3:
      r = byte(pair(0, 1) * 2);
      g = byte(pair(1, 2) * 2);
      b = byte(pair(2, 3) * 2);
    case 6:
      r = byte(pair(0, 2));
      g = byte(pair(2, 4));
      b = byte(pair(4, 6));
    case 8:
      r = byte(pair(2, 4));
      g = byte(pair(4, 6));
      b = byte(pair(6, 8));
    default:
      return null;
  }
  return 0xFF000000 | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF);
}

/// `#rrggbb` в нижнем регистре, как hexFromArgb в MCU (альфа игнорируется).
String hexFromArgb(int argb) {
  String two(int v) => (v & 0xFF).toRadixString(16).padLeft(2, '0');
  return '#${two(argb >> 16)}${two(argb >> 8)}${two(argb)}';
}
