/// Проверяет, включён ли в заголовках подписки закрытый мультиплексированный
/// транспорт drophaul (`dropweb-haul: 1` или `true`).
bool isHaulHeaderEnabled(Map<String, String>? providerHeaders) {
  if (providerHeaders == null || providerHeaders.isEmpty) {
    return false;
  }
  final raw = providerHeaders['dropweb-haul']?.trim().toLowerCase();
  return raw == '1' || raw == 'true';
}

/// Помечает VLESS+Reality узлы в разобранном конфиге флагом `haul: true`,
/// если панель прислала заголовок `dropweb-haul: 1`.
///
/// Не модифицирует не-VLESS узлы, узлы без `reality-opts.public-key` и
/// узлы с альтернативным транспортом (`xhttp`, `ws`, `grpc`, `h2`).
Map<String, dynamic> applyHaulPatch(
  Map<String, dynamic> rawConfig,
  Map<String, String>? providerHeaders,
) {
  if (!isHaulHeaderEnabled(providerHeaders)) {
    return rawConfig;
  }
  final proxies = rawConfig['proxies'];
  if (proxies is! List) {
    return rawConfig;
  }
  for (final item in proxies) {
    if (item is! Map) continue;
    final type = item['type']?.toString().toLowerCase();
    if (type != 'vless') continue;
    final network = item['network']?.toString().toLowerCase();
    if (network != null && network.isNotEmpty && network != 'tcp') {
      continue;
    }
    final realityOpts = item['reality-opts'];
    if (realityOpts is! Map) continue;
    final pubKey = realityOpts['public-key']?.toString().trim() ?? '';
    if (pubKey.isEmpty) continue;
    item['haul'] = true;
  }
  return rawConfig;
}
