// Главная целиком: один connect — один индикатор в слоте IP и одно появление итогового
// адреса (владелец 2026-10-29: «обновление ip дважды при подключении»).

import 'package:dropweb/ui/m3e/home/m3e_home_model.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_providers.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sub_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gate_support.dart';
import 'support/golden.dart';

const _before = '95.24.118.7';
const _vpn = '185.107.56.12';

final _on = StateProvider<bool>((ref) => false);
final _addr = StateProvider<String?>((ref) => _before);
final _signal = StateProvider<(int, bool)>((ref) => (0, false));
final _route = StateProvider<String?>((ref) => null);

const _loading = ValueKey<String>('loading');

class _Flow {
  _Flow(this.tester, this.answers);

  final WidgetTester tester;
  final List<String> answers;
  int checks = 0;
  int resets = 0;

  ProviderContainer? _c;

  /// Контейнер доступен только после монтирования: сессия читает адрес уже в `initState`.
  ProviderContainer get c =>
      _c ??= ProviderScope.containerOf(tester.element(find.byType(M3eHome)));

  Future<void> mount() => pumpM3eBoard(
        tester,
        gateHomeApp(
          'home-on',
          tickClock: tester.binding.clock.now,
          extra: [
            m3eHomeInputProvider.overrideWith((ref) {
              final on = ref.watch(_on);
              return M3eHomeInput(
                vpnOn: on,
                runTime: on ? const Duration(seconds: 5) : null,
                ipAddress: ref.watch(_addr),
                ipCountryCode: 'NL',
                subscription: const M3eHomeSubscription(),
                providerName: 'dropweb',
                announce: 'dropweb.org',
              );
            }),
            m3eIpCheckSignalProvider.overrideWith((ref) => ref.watch(_signal)),
            m3eRouteNodeProvider.overrideWith((ref) => ref.watch(_route)),
            m3eIpLogProvider.overrideWithValue((_) {}),
            m3eIpRefreshProvider.overrideWithValue(
              M3eIpRefresh(
                read: () => _c == null ? _before : c.read(_addr),
                reset: () {
                  resets++;
                  c.read(_addr.notifier).state = null;
                },
                checkQuiet: () async {
                  final i =
                      checks < answers.length ? checks : answers.length - 1;
                  checks++;
                  c.read(_addr.notifier).state = answers[i];
                },
              ),
            ),
          ],
        ),
      );

  void signal(int n, {required bool on}) {
    c.read(_on.notifier).state = on;
    c.read(_signal.notifier).state = (n, on);
  }

  /// Шагами по 50 мс, как идут кадры: одним большим `pump` анимация перехода, начавшаяся
  /// в его последнем кадре, не успевает сдвинуться.
  Future<void> wait(int ms) async {
    for (var left = ms; left > 0; left -= 50) {
      await tester.pump(Duration(milliseconds: left < 50 ? left : 50));
    }
  }

  Finder get slot => find.byKey(M3eCardKeys.statValue(0));
  Finder get indicator =>
      find.descendant(of: slot, matching: find.byKey(_loading));
}

void main() {
  testWidgets(
      'connect: адрес не показывается до итога, итоговый появляется один раз',
      (tester) async {
    final f = _Flow(tester, [_before, _vpn]);
    await f.mount();
    await f.wait(300);
    expect(find.text(_before), findsOneWidget,
        reason: 'до подключения — свой адрес');
    expect(f.indicator, findsNothing);

    // T: туннель поднят.
    f.signal(0, on: true);
    await f.wait(200);
    expect(f.resets, 1);
    expect(f.indicator, findsOneWidget);
    expect(find.text(_before), findsNothing);

    // T+1,33 с: переприменение профиля подставило узел и сообщило о готовности.
    await f.wait(700);
    f.c.read(_route.notifier).state = 'NL';
    await f.wait(400);
    f.c.read(_route.notifier).state = 'DE';
    await f.wait(30);
    f.signal(1, on: true);
    await f.wait(400);
    // Первая проверка вернула прежний адрес (туннель ещё не маршрутизирует): в слоте
    // всё ещё индикатор, прежний адрес не мигает.
    expect(f.checks, 1);
    expect(f.indicator, findsOneWidget);
    expect(find.text(_before), findsNothing);
    expect(find.text(_vpn), findsNothing);

    // Повтор через 2 с даёт итоговый адрес.
    await f.wait(2100);
    expect(f.checks, 2);
    await f.wait(400);
    expect(f.indicator, findsNothing);
    expect(find.text(_vpn), findsOneWidget);
    expect(f.resets, 1, reason: 'адрес сброшен один раз');

    // Дальше ничего не перерисовывается: ни сброса, ни индикатора.
    await f.wait(10000);
    expect(f.resets, 1);
    expect(f.indicator, findsNothing);
    expect(find.text(_vpn), findsOneWidget);
  });

  testWidgets('сигнал контроллера после появления адреса не гасит значение',
      (tester) async {
    final f = _Flow(tester, [_vpn]);
    await f.mount();
    f.signal(0, on: true);
    await f.wait(3100);
    await f.wait(400);
    expect(find.text(_vpn), findsOneWidget);
    // Поздний сигнал: тихая сверка с тем же адресом.
    f.signal(1, on: true);
    await f.wait(30);
    expect(f.indicator, findsNothing);
    expect(find.text(_vpn), findsOneWidget);
    await f.wait(500);
    expect(f.resets, 1);
    expect(find.text(_vpn), findsOneWidget);
  });

  testWidgets(
      'выключение VPN: индикатор вместо старого адреса, потом настоящий',
      (tester) async {
    final f = _Flow(tester, [_vpn, _before]);
    await f.mount();
    f.signal(0, on: true);
    await f.wait(3500);
    expect(find.text(_vpn), findsOneWidget);
    f.signal(0, on: false);
    await f.wait(200);
    expect(f.resets, 2);
    expect(find.text(_vpn), findsNothing);
    expect(f.indicator, findsOneWidget);
    await f.wait(1000);
    expect(f.indicator, findsNothing);
    expect(find.text(_before), findsOneWidget);
  });
}
