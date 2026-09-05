import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';

double get listHeaderHeight {
  final measure = globalState.measure;
  return 20 + measure.titleMediumHeight + 4 + measure.bodyMediumHeight;
}

double getItemHeight(ProxyCardType proxyCardType) {
  final measure = globalState.measure;
  final baseHeight =
      16 + measure.bodyMediumHeight * 2 + measure.bodySmallHeight + 8 + 4;
  return switch (proxyCardType) {
    ProxyCardType.expand => baseHeight + measure.labelSmallHeight + 6,
    ProxyCardType.shrink => baseHeight,
    ProxyCardType.min => baseHeight - measure.bodyMediumHeight,
    ProxyCardType.oneline => 16 + measure.bodyMediumHeight + 4,
  };
}

Future<void> proxyDelayTest(Proxy proxy, [String? testUrl]) async {
  final appController = globalState.appController;
  final state = appController.getProxyCardState(proxy.name);
  // `getRealTestUrl` is hoisted into a local so the diagnostics below can name
  // the fallback that `getSafeValue` may or may not have used. Still called
  // exactly once, exactly where it was called before.
  final fallbackUrl = appController.getRealTestUrl(testUrl);
  final url = state.testUrl.getSafeValue(fallbackUrl);
  if (state.proxyName.isEmpty) {
    // DELAY_DIAG (handoff §4, `stopReason`): the resolver produced no name, so
    // NOTHING is ever written for this card and its badge stays blank forever.
    // Silence here reads identically to "the test ran and found nothing".
    commonPrint.log(
      '[DELAY_DIAG] TEST_SKIP '
      'writeKey=${formatDelayKey(url, state.proxyName)} '
      'resolvedFrom=${proxy.name} reason=EMPTY_RESOLVED_NAME',
    );
    return;
  }
  commonPrint.log(
    '[DELAY_DIAG] TEST_START '
    'writeKey=${formatDelayKey(url, state.proxyName)} '
    'resolvedFrom=${proxy.name} '
    'declaredUrl=${state.testUrl ?? '<null>'} fallbackUrl=$fallbackUrl '
    'urlFrom=${state.testUrl.getSafeValue('').isEmpty ? 'fallback' : 'cardState'} '
    'src=proxyDelayTest',
  );
  appController.setDelay(
    Delay(
      url: url,
      name: state.proxyName,
      value: 0,
    ),
  );
  final reply = await clashCore.getDelay(
    url,
    state.proxyName,
  );
  // DELAY_DIAG (handoff §4, V7): the map key is taken from the REPLY, not from
  // the pair we asked for. If the core drops `url`/`name` (its nil-proxy and
  // panic paths do) the measurement lands under `("", "")` and the badge that
  // reads `writeKey` never sees it. One line, both keys, so the mismatch does
  // not have to be reconstructed from two.
  commonPrint.log(
    '[DELAY_DIAG] TEST_REPLY '
    'writeKey=${formatDelayKey(url, state.proxyName)} '
    'replyKey=${formatDelayKey(reply.url, reply.name)} '
    'value=${reply.value} '
    'match=${reply.url == url && reply.name == state.proxyName ? 'SAME' : 'MISMATCH!'}',
  );
  appController.setDelay(reply);
}

Future<void> delayTest(List<Proxy> proxies, [String? testUrl]) async {
  final appController = globalState.appController;
  final proxyNames = proxies.map((proxy) => proxy.name).toSet().toList();

  final delayProxies = proxyNames.map<Future>((proxyName) async {
    final state = appController.getProxyCardState(proxyName);
    // Hoisted for the diagnostics below; still exactly one call, same place.
    final fallbackUrl = appController.getRealTestUrl(testUrl);
    final url = state.testUrl.getSafeValue(fallbackUrl);
    final name = state.proxyName;
    if (name.isEmpty) {
      // DELAY_DIAG (handoff §4, `stopReason`): nothing is written for this
      // name, so its badge can never fill in. See `proxyDelayTest`.
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
    // DELAY_DIAG (handoff §4, V7): key actually written == the REPLY's pair.
    // See the matching comment in `proxyDelayTest`.
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

double getScrollToSelectedOffset({
  required String groupName,
  required List<Proxy> proxies,
}) {
  final appController = globalState.appController;
  final columns = appController.getProxiesColumns();
  final proxyCardType = globalState.config.proxiesStyle.cardType;
  final selectedProxyName = appController.getSelectedProxyName(groupName);
  final findSelectedIndex = proxies.indexWhere(
    (proxy) => proxy.name == selectedProxyName,
  );
  final selectedIndex = findSelectedIndex != -1 ? findSelectedIndex : 0;
  final rows = (selectedIndex / columns).floor();
  return rows * getItemHeight(proxyCardType) + (rows - 1) * 8;
}
