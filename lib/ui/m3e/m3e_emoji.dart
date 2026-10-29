// Эмодзи в начале имени группы или узла: на доске оно становится аватаром строки, а из
// подписи убирается (`lead()` в android.js). Флаги (пара региональных индикаторов)
// сюда не входят: их рисует отдельный режим аватара, см. `common/country.dart`.

/// Один эмодзи-элемент: символ + вариационный селектор или тон кожи.
const String _unit = r'\p{Extended_Pictographic}[\uFE0F\u{1F3FB}-\u{1F3FF}]?';

/// Ведущий эмодзи: keycap (`1️⃣`) либо пиктограмма с ZWJ-хвостом (`🏳️‍🌈`, `👨‍👩‍👧`)
/// и тегами подфлагов. Цифры, буквы и знаки вроде «·» не совпадают: у них нет
/// свойства Extended_Pictographic, а keycap требует U+20E3.
final RegExp _leadEmoji = RegExp(
  '^((?:[0-9#*]\\uFE0F?\\u20E3)|(?:$_unit(?:\\u200D$_unit)*[\\u{E0020}-\\u{E007F}]*))',
  unicode: true,
);

/// Эмодзи из начала [name] (пробелы слева не мешают) или `null`.
String? extractLeadEmoji(String name) =>
    _leadEmoji.firstMatch(name.trimLeft())?.group(1);

/// [name] без ведущего эмодзи и пробелов за ним; если ничего не осталось — имя целиком.
String stripLeadEmoji(String name) {
  final trimmed = name.trimLeft();
  final m = _leadEmoji.firstMatch(trimmed);
  if (m == null) return name;
  final rest = trimmed.substring(m.end).trimLeft();
  return rest.isEmpty ? name : rest;
}
