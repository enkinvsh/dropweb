// Regression (A1-3): AppController.changeProxyDebounce debounces PER GROUP via
// KeyedDebouncer keyed by (FunctionTag.changeProxy, groupName). A pick in
// group B within the 600 ms window must NOT drop group A's pending core write;
// repeated picks in the SAME group still collapse to the last one.
import 'package:dropweb/controller.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('picks in two groups within the window both reach the core', () async {
    final debouncer = KeyedDebouncer();
    final coreWrites = <String>[];

    void changeProxyDebounce(String groupName, String proxyName) {
      // Same key shape as AppController.changeProxyDebounce.
      debouncer.call((FunctionTag.changeProxy, groupName), () {
        coreWrites.add('$groupName=$proxyName');
      });
    }

    changeProxyDebounce('🎬 YouTube', 'nl-1');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    changeProxyDebounce('🌍 VPN', 'de-2');
    await Future<void>.delayed(const Duration(milliseconds: 900));

    expect(coreWrites, ['🎬 YouTube=nl-1', '🌍 VPN=de-2']);
  });

  test('repeated picks in the same group collapse to the last one', () async {
    final debouncer = KeyedDebouncer();
    final coreWrites = <String>[];

    void changeProxyDebounce(String groupName, String proxyName) {
      debouncer.call((FunctionTag.changeProxy, groupName), () {
        coreWrites.add('$groupName=$proxyName');
      });
    }

    changeProxyDebounce('🌍 VPN', 'nl-1');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    changeProxyDebounce('🌍 VPN', 'de-2');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(coreWrites, isEmpty, reason: 'debounce window restarted');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(coreWrites, ['🌍 VPN=de-2']);
  });
}
