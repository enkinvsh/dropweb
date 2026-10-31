// Название страны и маска адреса для карточек главной: короткие разговорные названия, цепочка
// запасных языков и скрытие хвоста IP. Чистые функции, без виджетов.

import 'package:dropweb/common/country_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('countryDisplayName', () {
    test('США коротко, а не официальным названием CLDR', () {
      expect(countryDisplayName('US', 'ru'), 'США');
      expect(countryDisplayName('US', 'en'), 'United States');
      expect(countryDisplayName('US', 'ja'), 'アメリカ');
      expect(countryDisplayName('US', 'zh_CN'), '美国');
    });

    test('короткие формы Кореи, Китая и ОАЭ', () {
      expect(countryDisplayName('KR', 'ru'), 'Южная Корея');
      expect(countryDisplayName('KP', 'ru'), 'Северная Корея');
      expect(countryDisplayName('CN', 'ru'), 'Китай');
      expect(countryDisplayName('CN', 'en'), 'China');
      expect(countryDisplayName('AE', 'en'), 'UAE');
      expect(countryDisplayName('AE', 'zh_CN'), '阿联酋');
    });

    test('обычная страна берётся из CLDR на языке приложения', () {
      expect(countryDisplayName('NL', 'ru'), 'Нидерланды');
      expect(countryDisplayName('NL', 'en'), 'Netherlands');
      expect(countryDisplayName('NL', 'ja'), 'オランダ');
    });

    test('регистр и пробелы в коде не мешают', () {
      expect(countryDisplayName(' nl ', 'en'), 'Netherlands');
    });

    test('локаль с регионом, дефисом и незнакомый язык идут по цепочке', () {
      // zh_CN есть в таблице целиком; ru_RU и ru-RU падают на язык ru.
      expect(countryDisplayName('NL', 'ru_RU'), 'Нидерланды');
      expect(countryDisplayName('NL', 'ru-RU'), 'Нидерланды');
      expect(countryDisplayName('NL', 'zh-CN'), isNot('NL'));
      // Язык без таблицы и пустая локаль — английский.
      expect(countryDisplayName('NL', 'de'), 'Netherlands');
      expect(countryDisplayName('NL', null), 'Netherlands');
    });

    test('неизвестный код возвращается как есть, в верхнем регистре', () {
      expect(countryDisplayName('zz', 'ru'), 'ZZ');
      expect(countryDisplayName('XX', 'en'), 'XX');
    });
  });

  group('maskIpAddress', () {
    test('IPv4 оставляет две первые группы', () {
      expect(maskIpAddress('94.183.12.34'), '94.183.•••.•••');
    });

    test('IPv6 оставляет две первые группы', () {
      expect(maskIpAddress('2a0e:97c0:3e3:4f1::1c'), '2a0e:97c0:•••');
    });

    test('незнакомая форма скрывается целиком, полный адрес не проходит', () {
      expect(maskIpAddress('not-an-ip'), '•••');
      expect(maskIpAddress('1.2.3'), '•••');
      expect(maskIpAddress('::1'), '•••');
      expect(maskIpAddress('94.183.12.34'), isNot(contains('12.34')));
    });
  });
}
