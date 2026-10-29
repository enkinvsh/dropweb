import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/ui/m3e/home/m3e_actions.dart';
import 'package:dropweb/ui/m3e/home/m3e_home_providers.dart';
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_scenes.dart';
import 'support/golden.dart';

/// `RunTime` читает `globalState.appState`, в тесте его заменяет заглушка.
class _RunTime extends RunTime {
  _RunTime(this.value);
  final int? value;
  @override
  int? build() => value;

  // Базовый `onUpdate` пишет в `globalState`, а в тесте его нет.
  @override
  void onUpdate(int? value) {}

  // ignore: use_setters_to_change_properties
  void set(int? v) => state = v;
}

Group _group(String name, {String? now, String? testUrl}) => Group(
      type: GroupType.Selector,
      name: name,
      now: now,
      testUrl: testUrl,
    );

Profile _profile({Map<String, String> headers = const {}}) => Profile(
      id: 'p',
      autoUpdateDuration: const Duration(hours: 1),
      providerHeaders: headers,
    );

/// Узел маршрута при заданных группах.
ProviderContainer _container({
  required List<Group> groups,
  Map<String, String> headers = const {},
  int? runTime = 1000,
}) =>
    ProviderContainer(
      overrides: [
        runTimeProvider.overrideWith(() => _RunTime(runTime)),
        currentProfileProvider.overrideWithValue(_profile(headers: headers)),
        currentGroupsStateProvider
            .overrideWithValue(GroupsState(value: groups)),
        for (final g in groups)
          getProxyNameProvider(g.name).overrideWithValue(null),
      ],
    );

void main() {
  group('узел маршрута', () {
    test('без заголовка берётся первая группа', () {
      final c = _container(
        groups: [_group('VPN', now: 'Auto'), _group('Другая', now: 'X')],
      );
      addTearDown(c.dispose);
      expect(c.read(m3eRouteNodeProvider), 'Auto');
    });

    test('заголовок serverinfo выигрывает у первой группы', () {
      final c = _container(
        groups: [_group('VPN', now: 'Auto'), _group('Серверы', now: 'NL')],
        headers: {'dropweb-serverinfo': 'Серверы'},
      );
      addTearDown(c.dispose);
      expect(c.read(m3eRouteNodeProvider), 'NL');
    });

    test('заголовок с несуществующей группой откатывается на первую', () {
      final c = _container(
        groups: [_group('VPN', now: 'Auto')],
        headers: {'dropweb-serverinfo': 'Нет такой'},
      );
      addTearDown(c.dispose);
      expect(c.read(m3eRouteNodeProvider), 'Auto');
    });

    test('VPN выключен — узла нет', () {
      final c = _container(
        groups: [_group('VPN', now: 'Auto')],
        runTime: null,
      );
      addTearDown(c.dispose);
      expect(c.read(m3eRouteNodeProvider), isNull);
    });

    test('групп нет — null', () {
      final c = _container(groups: const []);
      addTearDown(c.dispose);
      expect(c.read(m3eRouteNodeProvider), isNull);
    });
  });

  group('проверка внешнего адреса', () {
    /// Стенд: [answers] — адреса, которые вернёт каждая следующая проверка (`null` —
    /// проверка не удалась); `shown` — что сейчас «висит» на карточке.
    Future<
        ({
          List<String> log,
          StateProvider<(int, bool)> signal,
          StateProvider<String?> target,
          String? Function() shown,
        })> mount(
      WidgetTester tester, {
      required String? before,
      required List<String?> answers,
    }) async {
      final log = <String>[];
      var shown = before;
      var i = 0;
      final signal = StateProvider<(int, bool)>((ref) => (0, false));
      final target = StateProvider<String?>((ref) => null);
      await pumpM3eBoard(
        tester,
        m3eBoardApp(
          seed: '#2CFF7E',
          filter: 'tonalSpot',
          brightness: Brightness.light,
          overrides: [
            m3eHomeInputProvider.overrideWithValue(homeInputFor('home-off')),
            m3eHomeClockProvider.overrideWithValue(() => kHomeNow),
            m3eIpCheckSignalProvider.overrideWith((ref) => ref.watch(signal)),
            m3eRouteNodeProvider.overrideWith((ref) => ref.watch(target)),
            m3eIpLogProvider.overrideWithValue((_) {}),
            m3eIpRefreshProvider.overrideWithValue(
              M3eIpRefresh(
                read: () => shown,
                reset: () {
                  shown = null;
                  log.add('reset');
                },
                checkQuiet: () async {
                  final a = i < answers.length ? answers[i] : answers.last;
                  i++;
                  shown = a;
                  log.add('check:$a');
                },
              ),
            ),
          ],
          child: const M3eHome(),
        ),
      );
      final started = List<String>.of(log);
      log.clear();
      expect(started, isEmpty);
      return (log: log, signal: signal, target: target, shown: () => shown);
    }

    Future<void> setSignal(
      WidgetTester tester,
      StateProvider<(int, bool)> s,
      int num, {
      required bool on,
    }) async {
      final c = ProviderScope.containerOf(tester.element(find.byType(M3eHome)));
      c.read(s.notifier).state = (num, on);
      await tester.pump();
    }

    Future<void> setTarget(
      WidgetTester tester,
      StateProvider<String?> t,
      String? value,
    ) async {
      final c = ProviderScope.containerOf(tester.element(find.byType(M3eHome)));
      c.read(t.notifier).state = value;
      await tester.pump();
    }

    List<String> checks(List<String> log) =>
        log.where((e) => e.startsWith('check')).toList();

    testWidgets('экран появился без адреса: один тихий запрос, без сброса',
        (tester) async {
      final log = <String>[];
      String? shown;
      await pumpM3eBoard(
        tester,
        m3eBoardApp(
          seed: '#2CFF7E',
          filter: 'tonalSpot',
          brightness: Brightness.light,
          overrides: [
            m3eHomeInputProvider.overrideWithValue(homeInputFor('home-off')),
            m3eHomeClockProvider.overrideWithValue(() => kHomeNow),
            m3eIpCheckSignalProvider.overrideWithValue((0, false)),
            m3eRouteNodeProvider.overrideWithValue(null),
            m3eIpLogProvider.overrideWithValue((_) {}),
            m3eIpRefreshProvider.overrideWithValue(
              M3eIpRefresh(
                read: () => shown,
                reset: () => log.add('reset'),
                checkQuiet: () async {
                  shown = '1.2.3.4';
                  log.add('check');
                },
              ),
            ),
          ],
          child: const M3eHome(),
        ),
      );
      expect(log, ['check']);
    });

    testWidgets('экран появился с известным адресом: проверки нет',
        (tester) async {
      final t =
          await mount(tester, before: '95.24.118.7', answers: ['1.1.1.1']);
      await tester.pump(const Duration(seconds: 10));
      expect(t.log, isEmpty);
    });

    testWidgets(
        'включение VPN: переприменение профиля — один сброс и одна проверка',
        (tester) async {
      final t =
          await mount(tester, before: '95.24.118.7', answers: ['185.1.1.1']);
      await setSignal(tester, t.signal, 0, on: true);
      expect(t.log, ['reset'], reason: 'сброс в тот же кадр');
      expect(t.shown(), isNull);
      await tester.pump(const Duration(milliseconds: 650));
      // Профиль переприменяется и подставляет узел: это не смена маршрута.
      await setTarget(tester, t.target, 'NL');
      await setTarget(tester, t.target, 'DE');
      await tester.pump(const Duration(milliseconds: 650));
      expect(t.log, ['reset'], reason: 'до сигнала контроллера проверки нет');
      await setSignal(tester, t.signal, 1, on: true);
      await tester.pump(const Duration(milliseconds: 250));
      expect(t.log, ['reset']);
      await tester.pump(const Duration(milliseconds: 100));
      expect(t.log, ['reset', 'check:185.1.1.1']);
      await tester.pump(const Duration(seconds: 10));
      expect(t.log, ['reset', 'check:185.1.1.1'],
          reason: 'ровно один сброс и один запрос');
    });

    testWidgets('сигнала контроллера нет: проверка по потолку ожидания',
        (tester) async {
      final t =
          await mount(tester, before: '95.24.118.7', answers: ['185.1.1.1']);
      await setSignal(tester, t.signal, 0, on: true);
      await tester.pump(const Duration(milliseconds: 2900));
      expect(t.log, ['reset']);
      await tester.pump(const Duration(milliseconds: 200));
      expect(t.log, ['reset', 'check:185.1.1.1']);
    });

    testWidgets('выключение VPN: сброс и проверка через паузу', (tester) async {
      final t =
          await mount(tester, before: '185.1.1.1', answers: ['95.24.118.7']);
      await setSignal(tester, t.signal, 0, on: true);
      await tester.pump(const Duration(seconds: 4));
      t.log.clear();
      await setSignal(tester, t.signal, 0, on: false);
      expect(t.log, ['reset']);
      await tester.pump(const Duration(milliseconds: 800));
      expect(t.log, ['reset', 'check:95.24.118.7']);
    });

    testWidgets('смена узла при включённом VPN вне подключения: один цикл',
        (tester) async {
      final t = await mount(tester, before: '185.1.1.1', answers: ['91.2.2.2']);
      await setTarget(tester, t.target, 'NL');
      expect(t.log, isEmpty, reason: 'появление цели — не смена узла');
      await setTarget(tester, t.target, 'DE');
      expect(t.log, ['reset']);
      expect(t.shown(), isNull);
      // Сигнал контроллера от смены узла схлопывается в тот же цикл.
      await tester.pump(const Duration(milliseconds: 400));
      await setSignal(tester, t.signal, 1, on: false);
      await tester.pump(const Duration(seconds: 2));
      expect(t.log, ['reset', 'check:91.2.2.2']);
    });

    testWidgets('сигнал контроллера в покое: тихая сверка без сброса',
        (tester) async {
      final t =
          await mount(tester, before: '185.1.1.1', answers: ['185.1.1.1']);
      await setSignal(tester, t.signal, 1, on: false);
      await tester.pump();
      expect(t.log, ['check:185.1.1.1'], reason: 'сброса нет');
    });

    testWidgets('тот же адрес: два повтора с паузой, потом остановка',
        (tester) async {
      final t = await mount(tester, before: '1.1.1.1', answers: ['1.1.1.1']);
      await setSignal(tester, t.signal, 0, on: true);
      await setSignal(tester, t.signal, 1, on: true);
      await tester.pump(const Duration(milliseconds: 400));
      expect(checks(t.log), hasLength(1));
      await tester.pump(const Duration(seconds: 2));
      expect(checks(t.log), hasLength(2));
      await tester.pump(const Duration(seconds: 2));
      expect(checks(t.log), hasLength(3));
      await tester.pump(const Duration(seconds: 20));
      expect(checks(t.log), hasLength(3), reason: 'повторов ровно два');
    });

    testWidgets('повтор останавливается, как только адрес сменился',
        (tester) async {
      final t = await mount(tester,
          before: '1.1.1.1', answers: [null, '1.1.1.1', '2.2.2.2']);
      await setSignal(tester, t.signal, 0, on: true);
      await setSignal(tester, t.signal, 1, on: true);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(checks(t.log), ['check:null', 'check:1.1.1.1', 'check:2.2.2.2']);
      expect(t.shown(), '2.2.2.2');
    });

    testWidgets('новое событие обрывает цикл повторов прежнего',
        (tester) async {
      final t = await mount(tester, before: '1.1.1.1', answers: ['1.1.1.1']);
      await setSignal(tester, t.signal, 0, on: true);
      await tester.pump(const Duration(seconds: 3, milliseconds: 100));
      await setSignal(tester, t.signal, 0, on: false);
      t.log.clear();
      await tester.pump(const Duration(milliseconds: 800));
      // Прежний цикл не шлёт повторов, живёт только новый: одна проверка.
      expect(t.log, ['check:1.1.1.1']);
    });
  });

  group('неудачный запуск (error)', () {
    late StateProvider<bool> conn;
    late ProviderContainer c;

    ProviderContainer make() {
      conn = StateProvider<bool>((ref) => false);
      final container = ProviderContainer(
        overrides: [
          m3eConnectingProvider.overrideWith((ref) => ref.watch(conn)),
          runTimeProvider.overrideWith(() => _RunTime(null)),
          m3eStartSettleProvider.overrideWithValue(
            const Duration(milliseconds: 10),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Держим провайдер живым: он не autoDispose, но слушатель нужен для `listen`.
      container.listen(m3eStartFailureProvider, (_, __) {});
      return container;
    }

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 60));

    // Провайдеры обновляются асинхронно: без паузы слушатель увидит только итог
    // подряд идущих записей.
    Future<void> flush() => Future<void>.delayed(Duration.zero);

    Future<void> failedStart(ProviderContainer c) async {
      c.read(m3eStartFailureProvider.notifier).requested();
      c.read(conn.notifier).state = true;
      await flush();
      c.read(conn.notifier).state = false;
      await flush();
    }

    test('запрошенный запуск, который закончился без VPN, — ошибка', () async {
      c = make();
      await failedStart(c);
      expect(c.read(m3eStartFailureProvider), isFalse, reason: 'ждём паузу');
      await settle();
      expect(c.read(m3eStartFailureProvider), isTrue);
    });

    test('без запрошенного запуска ошибки нет', () async {
      c = make();
      c.read(conn.notifier).state = true;
      await flush();
      c.read(conn.notifier).state = false;
      await flush();
      await settle();
      expect(c.read(m3eStartFailureProvider), isFalse);
    });

    test('запуск, который не дошёл до isConnecting, ошибкой не считается',
        () async {
      c = make();
      c.read(m3eStartFailureProvider.notifier).requested();
      await settle();
      expect(c.read(m3eStartFailureProvider), isFalse);
    });

    test('VPN поднялся до конца паузы — ошибки нет', () async {
      c = make();
      c.read(m3eStartFailureProvider.notifier).requested();
      c.read(conn.notifier).state = true;
      await flush();
      (c.read(runTimeProvider.notifier) as _RunTime).set(5);
      await flush();
      c.read(conn.notifier).state = false;
      await flush();
      await settle();
      expect(c.read(m3eStartFailureProvider), isFalse);
    });

    test('ошибка держится до следующего нажатия и сбрасывается им', () async {
      c = make();
      final n = c.read(m3eStartFailureProvider.notifier);
      await failedStart(c);
      await settle();
      expect(c.read(m3eStartFailureProvider), isTrue);
      await settle();
      expect(c.read(m3eStartFailureProvider), isTrue, reason: 'сама не гаснет');
      n.requested();
      expect(c.read(m3eStartFailureProvider), isFalse);
    });

    test('ошибка сбрасывается включением VPN', () async {
      c = make();
      await failedStart(c);
      await settle();
      expect(c.read(m3eStartFailureProvider), isTrue);
      (c.read(runTimeProvider.notifier) as _RunTime).set(1);
      await flush();
      expect(c.read(m3eStartFailureProvider), isFalse);
    });

    testWidgets('кнопка: запуск запрошен → попытка идёт, отмена окна → нет',
        (tester) async {
      var started = false;
      late WidgetRef captured;
      conn = StateProvider<bool>((ref) => false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            m3eConnectingProvider.overrideWith((ref) => ref.watch(conn)),
            runTimeProvider.overrideWith(() => _RunTime(null)),
            m3eStartSettleProvider
                .overrideWithValue(const Duration(milliseconds: 10)),
            startButtonSelectorStateProvider.overrideWithValue(
              const StartButtonSelectorState(
                isInit: true,
                hasProfile: true,
                hasProxiesInit: true,
              ),
            ),
            m3eStartVpnProvider.overrideWithValue(
              (context, {required currentlyRunning}) async => started,
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                captured = ref;
                return TextButton(
                  onPressed: () => m3eToggleVpn(context, ref),
                  child: const Text('go'),
                );
              },
            ),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TextButton)),
      )..listen(m3eStartFailureProvider, (_, __) {});

      // Окно раскрытия отменено: toggleVpn вернул false.
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      captured.read(conn.notifier).state = true;
      await tester.pump();
      captured.read(conn.notifier).state = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(container.read(m3eStartFailureProvider), isFalse);

      // Запуск запрошен и закончился без VPN.
      started = true;
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      captured.read(conn.notifier).state = true;
      await tester.pump();
      captured.read(conn.notifier).state = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(container.read(m3eStartFailureProvider), isTrue);
    });
  });

  group('сеть (offline)', () {
    test('none → offline, wifi/mobile/vpn → online, пустой список → offline',
        () {
      expect(m3eIsOnline([ConnectivityResult.none]), isFalse);
      expect(m3eIsOnline(const []), isFalse);
      expect(m3eIsOnline([ConnectivityResult.wifi]), isTrue);
      expect(m3eIsOnline([ConnectivityResult.mobile]), isTrue);
      expect(m3eIsOnline([ConnectivityResult.vpn]), isTrue);
      expect(
        m3eIsOnline([ConnectivityResult.none, ConnectivityResult.mobile]),
        isTrue,
      );
    });

    test('проверка при старте и далее поток изменений', () async {
      final changes = StreamController<List<ConnectivityResult>>();
      final c = ProviderContainer(
        overrides: [
          m3eConnectivitySourceProvider.overrideWithValue(
            M3eConnectivitySource(
              check: () async => [ConnectivityResult.none],
              changes: changes.stream,
            ),
          ),
        ],
      );
      addTearDown(() async {
        c.dispose();
        await changes.close();
      });
      final seen = <bool>[];
      c.listen<AsyncValue<bool>>(m3eOnlineProvider, (_, next) {
        final v = next.valueOrNull;
        if (v != null) seen.add(v);
      });
      Future<void> tick() => Future<void>.delayed(Duration.zero);
      await tick();
      changes.add([ConnectivityResult.wifi]);
      await tick();
      changes.add([ConnectivityResult.none]);
      await tick();
      expect(seen, [false, true, false]);
    });

    test('сбой канала связи не прячет главную: считаем, что сеть есть',
        () async {
      final c = ProviderContainer(
        overrides: [
          m3eConnectivitySourceProvider.overrideWithValue(
            M3eConnectivitySource(
              check: () async => throw StateError('нет канала'),
              changes: const Stream.empty(),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      final seen = <bool>[];
      c.listen<AsyncValue<bool>>(m3eOnlineProvider, (_, next) {
        final v = next.valueOrNull;
        if (v != null) seen.add(v);
      });
      await Future<void>.delayed(Duration.zero);
      expect(seen, [true]);
    });
  });
}
