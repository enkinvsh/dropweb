import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Подпись конфига, с которым запущено расширение PacketTunnel (iOS).
///
/// Расширение читает `setup.json` один раз при старте, поэтому смена маршрута,
/// не сводящаяся к выбору узла в селекторе, доходит до него только перезапуском.
/// Подпись отвечает на вопрос «изменился ли конфиг настолько, что нужен
/// перезапуск». Из неё нарочно исключено то, что расширение принимает налету или
/// что не влияет на маршрут:
///   * `selected-map` — выбор узла в группах переносится действием `changeProxy`;
///   * `config.mixed-port` и `config.authentication` — случайные данные сеанса
///     локального прокси (`GlobalState.currentProxyCredentials`), они пересоздаются
///     при подключении и не меняют, куда идёт трафик.
/// Порядок ключей карт не важен, порядок списков — важен (правила).
String iosTunnelSignature({
  required Map<String, dynamic> setup,
  required String init,
  required String state,
}) {
  final config = Map<String, dynamic>.from(
    (setup['config'] as Map?)?.cast<String, dynamic>() ?? const {},
  )
    ..remove('mixed-port')
    ..remove('authentication');
  final payload = <String, dynamic>{
    'init': init,
    'state': state,
    'test-url': setup['test-url'],
    'config': config,
  };
  return md5.convert(utf8.encode(jsonEncode(_canonical(payload)))).toString();
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}
