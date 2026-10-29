// Разбор заголовка `dropweb-theme` так, как это делает доска (`parseTheme` в app.js).
//
// Готовый разбор в приложении (`ProfileService._applyDropwebTheme`) не годится: он приватный,
// пишет в провайдер темы и знает только значения enum DynamicSchemeVariant, а доске нужен
// сырой фильтр-строка (в том числе `fidelity` -> CMF) и акцент с запасным значением.

/// Запасной акцент, если провайдер прислал пустое или неверное поле (как на доске).
const String m3eFallbackSeed = '#29FF76';

/// Разобранный заголовок `dropweb-theme`: `<filter>,<accent>,<orb1>,<orb2>,<blur>`.
class DropwebThemeHeader {
  const DropwebThemeHeader({
    required this.filter,
    required this.accent,
    required this.orb1,
    required this.orb2,
    required this.blur,
  });

  /// Первое поле как есть (без регистра не приводится: доска сравнивает точно).
  final String filter;

  /// `#RRGGBB` в верхнем регистре.
  final String accent;

  /// Цвет первого орба; пустой или неверный следует за акцентом.
  final String orb1;

  /// Цвет второго орба; пустой или неверный следует за акцентом.
  final String orb2;

  /// Размытие 1..5; по умолчанию 3.
  final double blur;
}

final RegExp _hex =
    RegExp(r'^#?([0-9a-f]{6})([0-9a-f]{2})?$', caseSensitive: false);

String _hexOr(String? v, String fallback) {
  if (v == null || !_hex.hasMatch(v)) return fallback;
  return '#${v.replaceFirst('#', '').substring(0, 6).toUpperCase()}';
}

/// Разбор [header] один в один с `parseTheme` из app.js. Отличие от приложения описано выше.
DropwebThemeHeader parseDropwebTheme(String header) {
  final p = header.split(',').map((x) => x.trim()).toList();
  String? at(int i) => i < p.length ? p[i] : null;
  final accent = _hexOr(at(1), m3eFallbackSeed);
  // JS: Number(b) || 3 -- нечисло и ноль дают 3, затем зажим 1..5.
  final raw = double.tryParse(at(4) ?? '');
  final blur =
      (raw == null || raw == 0 || raw.isNaN) ? 3.0 : raw.clamp(1, 5).toDouble();
  return DropwebThemeHeader(
    filter: p.isEmpty ? '' : p[0],
    accent: accent,
    orb1: _hexOr(at(2), accent),
    orb2: _hexOr(at(3), accent),
    blur: blur,
  );
}
