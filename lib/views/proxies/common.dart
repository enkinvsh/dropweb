import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';

Future<void> delayTest(List<Proxy> proxies, [String? testUrl]) async {
  final appController = globalState.appController;
  final proxyNames = proxies.map((proxy) => proxy.name).toSet().toList();

  final delayProxies = proxyNames.map<Future>((proxyName) async {
    final state = appController.getProxyCardState(proxyName);
    // Вынесено в переменную ради диагностики ниже; вызов по-прежнему один.
    final fallbackUrl = appController.getRealTestUrl(testUrl);
    final url = state.testUrl.getSafeValue(fallbackUrl);
    final name = state.proxyName;
    if (name.isEmpty) {
      // DELAY_DIAG: для этого имени ничего не записывается, поэтому значок
      // задержки так и остаётся пустым.
      commonPrint.log(
        '[DELAY_DIAG] TEST_SKIP '
        'writeKey=${formatDelayKey(url, name)} '
        'resolvedFrom=$proxyName reason=EMPTY_RESOLVED_NAME',
      );
      return;
    }
    commonPrint.log(
      '[DELAY_DIAG] TEST_START '
      'writeKey=${formatDelayKey(url, name)} '
      'resolvedFrom=$proxyName '
      'declaredUrl=${state.testUrl ?? '<null>'} fallbackUrl=$fallbackUrl '
      'urlFrom=${state.testUrl.getSafeValue('').isEmpty ? 'fallback' : 'cardState'} '
      'src=delayTest',
    );
    appController.setDelay(
      Delay(
        url: url,
        name: name,
        value: 0,
      ),
    );
    final reply = await clashCore.getDelay(
      url,
      name,
    );
    // DELAY_DIAG: ключ записи берётся из ОТВЕТА ядра, а не из запрошенной
    // пары; при расхождении замер ложится под другой ключ и значок его не видит.
    commonPrint.log(
      '[DELAY_DIAG] TEST_REPLY '
      'writeKey=${formatDelayKey(url, name)} '
      'replyKey=${formatDelayKey(reply.url, reply.name)} '
      'value=${reply.value} '
      'match=${reply.url == url && reply.name == name ? 'SAME' : 'MISMATCH!'}',
    );
    appController.setDelay(reply);
  }).toList();

  final batchesDelayProxies = delayProxies.batch(100);
  for (final batchDelayProxies in batchesDelayProxies) {
    await Future.wait(batchDelayProxies);
  }
  appController.addSortNum();
}
