// Что карточка главной показывает вместо IP-адреса: страна выхода или замаскированный адрес.
//
// Решение владельца 30.10: полный IP на главной не показываем, он попадает на скриншоты и в
// запись экрана. Страна говорит пользователю то же самое (куда он вышел) и не раскрывает адрес.
// Слой общий для карточек Android (M3E) и iOS, чтобы названия не расходились между платформами.

import 'package:dropweb/common/country_names.g.dart';

/// Название страны по коду ISO 3166-1 alpha-2 на языке [locale] (`ru`, `en`, `ja`, `zh_CN`).
///
/// Порядок: точная локаль, затем язык без региона, затем английский, затем сам код: у новой
/// страны в таблице может не быть имени, а пустая строка на карточке хуже кода.
String countryDisplayName(String code, String? locale) {
  final upper = code.trim().toUpperCase();
  final normalized = (locale ?? 'en').replaceAll('-', '_');
  final language = normalized.split('_').first;
  for (final key in <String>{normalized, language, 'en'}) {
    final name = kCountryNames[key]?[upper];
    if (name != null) {
      return name;
    }
  }
  return upper;
}

/// Адрес без хвоста: «94.183.•••.•••» для IPv4, «2a0e:97c0:•••» для IPv6.
///
/// Нужен только когда страна неизвестна, но адрес есть: пользователь видит, что проверка
/// прошла, а полный адрес на экране не светится. Незнакомая форма адреса скрывается целиком.
String maskIpAddress(String ip) {
  final v4 = ip.split('.');
  if (v4.length == 4 && v4.every((p) => int.tryParse(p) != null)) {
    return '${v4[0]}.${v4[1]}.•••.•••';
  }
  if (ip.contains(':')) {
    final groups = ip.split(':').where((g) => g.isNotEmpty).toList();
    if (groups.length >= 2) {
      return '${groups[0]}:${groups[1]}:•••';
    }
  }
  return '•••';
}
