import 'dart:async';
import 'dart:convert';

import 'package:dropweb/common/ios_tunnel_signature.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/plugins/ios_tunnel.dart';
import 'package:dropweb/plugins/ios_tunnel_forwarder.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('dropweb/ios_tunnel');

/// Мок канала `dropweb/ios_tunnel`: пишет все вызовы и отвечает по сценарию.
class _FakeChannel {
  final calls = <MethodCall>[];
  int? status = 3;
  bool statusHangs = false;
  Future<Object?> Function(MethodCall call)? onSend;
  Future<Object?> Function()? onStop;

  /// Сколько `send` сейчас в полёте и максимум за тест.
  int inFlight = 0;
  int maxInFlight = 0;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'status':
          // Зависший ответ Swift: future, который не завершается.
          if (statusHangs) return Completer<Object?>().future;
          return status;
        case 'stop':
          if (onStop != null) return onStop!();
          status = 1;
          return null;
        case 'send':
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          try {
            return await (onSend?.call(call) ??
                Future.value('{"method":"changeProxy","data":"","code":0}'));
          } finally {
            inFlight--;
          }
      }
      return null;
    });
  }

  List<String> get methods => calls.map((c) => c.method).toList();
}

String _changeProxyAction(String id, String proxy) => json.encode(
      Action(
        id: id,
        method: ActionMethod.changeProxy,
        data: json.encode(
          ChangeProxyParams(groupName: '🌍 VPN', proxyName: proxy),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeChannel fake;
  late List<String> logs;

  setUp(() {
    fake = _FakeChannel()..install();
    logs = [];
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  IosTunnelForwarder forwarder({Duration? timeout}) => IosTunnelForwarder(
        log: logs.add,
        enabled: true,
        timeout: timeout ?? const Duration(seconds: 5),
      );

  group('IosTunnelForwarder', () {
    test('туннель поднят: в расширение уходит ровно JSON действия ядра',
        () async {
      final action = _changeProxyAction('changeProxy#1', '🇩🇪 Германия');

      final outcome = await forwarder().forward(action);

      expect(outcome, IosForwardOutcome.sent);
      expect(fake.methods, ['status', 'send']);
      expect(fake.calls.last.arguments, action);
      expect(logs.single, '[ios-tunnel] changeProxy forwarded');
    });

    test('туннель не поднят: send не вызывается', () async {
      fake.status = 1;

      final outcome =
          await forwarder().forward(_changeProxyAction('changeProxy#2', 'A'));

      expect(outcome, IosForwardOutcome.notConnected);
      expect(fake.methods, ['status']);
      expect(logs.single, startsWith('[ios-tunnel] changeProxy not forwarded'));
    });

    test('сбой канала не бросает в UI и пишется в журнал', () async {
      fake.onSend =
          (_) async => throw PlatformException(code: 'send', message: 'boom');

      final outcome =
          await forwarder().forward(_changeProxyAction('changeProxy#3', 'A'));

      expect(outcome, IosForwardOutcome.failed);
      expect(logs.single, '[ios-tunnel] changeProxy forward failed: send boom');
    });

    test('расширение не ответило (null): не бросает, пишется в журнал',
        () async {
      fake.onSend = (_) async => null;

      final outcome =
          await forwarder().forward(_changeProxyAction('changeProxy#4', 'A'));

      expect(outcome, IosForwardOutcome.notConnected);
      expect(logs.single, contains('extension did not reply'));
    });

    test('ответ дольше таймаута: failed, без исключения', () async {
      final never = Completer<Object?>();
      fake.onSend = (_) => never.future;

      final outcome = await forwarder(
        timeout: const Duration(milliseconds: 50),
      ).forward(_changeProxyAction('changeProxy#5', 'A'));

      expect(outcome, IosForwardOutcome.failed);
      expect(logs.single, contains('timed out'));
      never.complete(null);
    });

    test('ядро расширения вернуло ошибку: failed и текст ошибки в журнале',
        () async {
      fake.onSend = (_) async =>
          '{"method":"changeProxy","data":"Not found group","code":0}';

      final outcome =
          await forwarder().forward(_changeProxyAction('changeProxy#6', 'A'));

      expect(outcome, IosForwardOutcome.failed);
      expect(logs.single, contains('Not found group'));

      fake.onSend = (_) async => '{"code":-1,"data":"invalid params"}';
      expect(
        await forwarder().forward(_changeProxyAction('changeProxy#7', 'A')),
        IosForwardOutcome.failed,
      );
    });

    test('сообщения идут по одному и в порядке постановки', () async {
      final gates = <Completer<Object?>>[];
      fake.onSend = (_) {
        final gate = Completer<Object?>();
        gates.add(gate);
        return gate.future;
      };
      final f = forwarder();
      final first = f.forward(_changeProxyAction('changeProxy#a', 'A'));
      final second = f.forward(json.encode(const Action(
        id: 'closeConnections#b',
        method: ActionMethod.closeConnections,
        data: null,
      )));

      // Первое висит в send — второе ещё не отправлено.
      await pumpEventQueue();
      expect(fake.methods.where((m) => m == 'send').length, 1);

      gates.first.complete('{"data":"","code":0}');
      await first;
      await pumpEventQueue();
      gates.last.complete('{"data":true,"code":0}');
      await second;

      final sent = fake.calls
          .where((c) => c.method == 'send')
          .map((c) => json.decode(c.arguments as String)['id'])
          .toList();
      expect(sent, ['changeProxy#a', 'closeConnections#b']);
      expect(fake.maxInFlight, 1);
    });

    test('не iOS (Android, десктоп): канал не вызывается вовсе', () async {
      // Без `enabled` берётся Platform.isIOS — на хосте теста это false.
      final f = IosTunnelForwarder(log: logs.add);
      final explicit = IosTunnelForwarder(log: logs.add, enabled: false);

      expect(
        await f.forward(_changeProxyAction('changeProxy#8', 'A')),
        IosForwardOutcome.disabled,
      );
      expect(
        await explicit.forward(_changeProxyAction('changeProxy#9', 'A')),
        IosForwardOutcome.disabled,
      );
      expect(fake.calls, isEmpty);
      expect(logs, isEmpty);
    });

    test('пересылаются только changeProxy и закрытие соединений', () {
      String action(ActionMethod method, [Object? data]) => json
          .encode(Action(id: '${method.name}#1', method: method, data: data));

      expect(
        IosTunnelForwarder.forwardedMethodOf(
            _changeProxyAction('changeProxy#1', 'A')),
        'changeProxy',
      );
      expect(
        IosTunnelForwarder.forwardedMethodOf(
            action(ActionMethod.closeConnections)),
        'closeConnections',
      );
      expect(
        IosTunnelForwarder.forwardedMethodOf(
            action(ActionMethod.resetConnections)),
        'resetConnections',
      );
      for (final method in [
        ActionMethod.setupConfig,
        ActionMethod.updateConfig,
        ActionMethod.getProxies,
        ActionMethod.asyncTestDelay,
        ActionMethod.getConfig,
      ]) {
        expect(
            IosTunnelForwarder.forwardedMethodOf(action(method, '{}')), isNull,
            reason: method.name);
      }
      // Большое сообщение не разбирается вовсе (setupConfig — мегабайты).
      expect(
        IosTunnelForwarder.forwardedMethodOf(
          action(ActionMethod.changeProxy, 'x' * 5000),
        ),
        isNull,
      );
      expect(IosTunnelForwarder.forwardedMethodOf('not json'), isNull);
    });
  });

  group('IosTunnelRestarter', () {
    IosTunnelRestarter restarter() => IosTunnelRestarter(
          log: logs.add,
          tunnel: IosTunnel.instance,
          stopTimeout: const Duration(milliseconds: 200),
          pollInterval: const Duration(milliseconds: 10),
          statusTimeout: const Duration(milliseconds: 30),
        );

    test('stop дважды не довёл до ≤ 1: failed, start НЕ вызван', () async {
      var stops = 0;
      fake.onStop = () async {
        stops++;
        fake.status = 5; // так и висит в disconnecting
        return null;
      };
      var started = 0;

      final outcome = await restarter().restart(start: () async {
        started++;
        return true;
      });

      expect(outcome, IosRestartOutcome.failed);
      expect(stops, 2);
      expect(started, 0);
      expect(logs.where((l) => l.contains('not disconnected')), hasLength(2));
    });

    test('status() завис после stop: таймаут, считается не остановленным',
        () async {
      fake.onStop = () async {
        fake.statusHangs = true;
        return null;
      };
      var started = 0;

      final outcome = await restarter().restart(start: () async {
        started++;
        return true;
      });

      expect(outcome, IosRestartOutcome.failed);
      expect(started, 0);
      expect(logs, contains('[ios-tunnel] restart: status() timed out'));
    });

    test('второй stop довёл до остановки: start вызывается', () async {
      var stops = 0;
      fake.onStop = () async {
        stops++;
        fake.status = stops == 1 ? 3 : 1;
        return null;
      };

      final outcome = await restarter().restart(start: () async => true);

      expect(outcome, IosRestartOutcome.restarted);
      expect(stops, 2);
    });

    test('туннель не поднят: ни stop, ни start', () async {
      fake.status = 1;
      var started = 0;

      final outcome = await restarter().restart(start: () async {
        started++;
        return true;
      });

      expect(outcome, IosRestartOutcome.notConnected);
      expect(started, 0);
      expect(fake.methods, ['status']);
    });

    test('туннель поднят: stop, ожидание остановки, затем start', () async {
      final order = <String>[];
      fake.onStop = () async {
        order.add('stop');
        fake.status = 5; // disconnecting
        Timer(const Duration(milliseconds: 30), () => fake.status = 1);
        return null;
      };

      final outcome = await restarter().restart(start: () async {
        order.add('start:status=${fake.status}');
        return true;
      });

      expect(outcome, IosRestartOutcome.restarted);
      expect(order, ['stop', 'start:status=1']);
    });

    test('stop упал: start не вызывается, итог failed', () async {
      fake.onStop = () async => throw PlatformException(code: 'stop');
      var started = 0;

      final outcome = await restarter().restart(start: () async {
        started++;
        return true;
      });

      expect(outcome, IosRestartOutcome.failed);
      expect(started, 0);
      expect(logs.single, contains('stop failed'));
    });

    test('новый старт не поднялся: failed', () async {
      final outcome = await restarter().restart(start: () async => false);

      expect(outcome, IosRestartOutcome.failed);
      expect(logs.last, '[ios-tunnel] restart failed');
    });
  });

  group('iosTunnelSignature', () {
    Map<String, dynamic> setup({
      Map<String, String> selected = const {'🌍 VPN': 'A'},
      int port = 41000,
      String auth = 'u:p',
      List<String> rules = const ['MATCH,🌍 VPN'],
      Map<String, dynamic>? extra,
    }) =>
        {
          'config': {
            'mixed-port': port,
            'authentication': [auth],
            'rule': rules,
            'proxy-groups': [
              {
                'name': '🌍 VPN',
                'type': 'select',
                'proxies': ['A', 'B']
              },
            ],
            ...?extra,
          },
          'selected-map': selected,
          'test-url': 'https://www.gstatic.com/generate_204',
        };

    String sig(Map<String, dynamic> s, {String state = '{}'}) =>
        iosTunnelSignature(setup: s, init: '{"home-dir":"/g"}', state: state);

    test('выбор узла и данные сеанса прокси перезапуск не требуют', () {
      expect(
        sig(setup(selected: {'🌍 VPN': 'B'}, port: 42000, auth: 'x:y')),
        sig(setup()),
      );
    });

    test('порядок ключей не важен', () {
      final a = setup(extra: {'a': 1, 'b': 2});
      final b = setup(extra: {'b': 2, 'a': 1});
      expect(sig(a), sig(b));
    });

    test('правила, группы и state меняют подпись', () {
      expect(sig(setup(rules: ['MATCH,DIRECT'])), isNot(sig(setup())));
      expect(
        sig(setup(extra: {
          'proxy-groups': [
            {
              'name': 'Страна DE',
              'type': 'url-test',
              'proxies': ['A']
            },
          ],
        })),
        isNot(sig(setup())),
      );
      expect(sig(setup(), state: '{"x":1}'), isNot(sig(setup())));
    });
  });
}
