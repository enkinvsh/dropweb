import 'dart:async';

import 'package:dropweb/models/profile.dart';
import 'package:dropweb/services/hwid_recovery.dart';
import 'package:dropweb/services/ios_connect_hwid_gate.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_path_provider.dart';

const _hwid = 'AAAAAAAAAAAAAAAA';
const _otherHwid = 'BBBBBBBBBBBBBBBB';
const _secretUrl = 'https://panel.example/sub/SECRET-TOKEN';

Profile _profile({String? fetchedHwid}) => Profile.normal(label: 'p').copyWith(
      id: 'p1',
      fetchedHwid: fetchedHwid,
    );

/// Гейт с подставленными зависимостями; по умолчанию всё «включено».
class _GateHarness {
  _GateHarness({this.profile, this.send = true, this.url = _secretUrl});

  Profile? profile;
  bool send;
  String? url;
  String? hwid = _hwid;
  bool hwidThrows = false;
  Future<HwidVerdict> Function(Profile) onRefresh =
      (_) async => HwidVerdict.clean;

  final logs = <String>[];
  int refreshCalls = 0;

  IosConnectHwidGate build() => IosConnectHwidGate(
        sendDeviceHeaders: () async => send,
        currentProfile: () => profile,
        resolveUrl: (_) async => url,
        currentHwid: () async {
          if (hwidThrows) throw StateError('keychain locked');
          return hwid;
        },
        refresh: (p) {
          refreshCalls++;
          return onRefresh(p);
        },
        log: logs.add,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useFakePathProvider();

  group('IosConnectHwidGate', () {
    test('профиль скачан с этим же HWID: подписку не трогаем', () async {
      final h = _GateHarness(profile: _profile(fetchedHwid: _hwid));

      final result = await h.build().run();

      expect(result.outcome, IosHwidGateOutcome.proceed);
      expect(h.refreshCalls, 0);
    });

    test(
        'профиль скачан с другим HWID и панель отказала по лимиту: '
        'подключаться нельзя', () async {
      final h = _GateHarness(profile: _profile(fetchedHwid: _otherHwid))
        ..onRefresh = (_) async => HwidVerdict.limited;

      final result = await h.build().run();

      expect(result.outcome, IosHwidGateOutcome.limited);
      expect(h.refreshCalls, 1);
    });

    for (final verdict in [HwidVerdict.clean, HwidVerdict.recovered]) {
      test('другой HWID, панель приняла ($verdict): подключение продолжается',
          () async {
        final h = _GateHarness(profile: _profile(fetchedHwid: _otherHwid))
          ..onRefresh = (_) async => verdict;

        final result = await h.build().run();

        expect(result.outcome, IosHwidGateOutcome.proceed);
        expect(h.refreshCalls, 1);
      });
    }

    test(
        'профиль ни разу не сверялся (fetchedHwid пуст): подписку '
        'скачиваем заново', () async {
      final h = _GateHarness(profile: _profile());

      final result = await h.build().run();

      expect(result.outcome, IosHwidGateOutcome.proceed);
      expect(h.refreshCalls, 1);
    });

    test('fetchedHwid пуст и нет сети: подключаемся (мягкий режим)', () async {
      final h = _GateHarness(profile: _profile())
        ..onRefresh = (_) async => throw TimeoutException('offline');

      final result = await h.build().run();

      expect(result.outcome, IosHwidGateOutcome.proceed);
    });

    test('другой HWID и нет сети: заведомо чужое устройство, отказ', () async {
      final h = _GateHarness(profile: _profile(fetchedHwid: _otherHwid))
        ..onRefresh = (_) async => throw TimeoutException('offline');

      final result = await h.build().run();

      expect(result.outcome, IosHwidGateOutcome.unverified);
      expect(result.error, isA<TimeoutException>());
    });

    group('проверка не нужна', () {
      test('отправка заголовков устройства выключена', () async {
        final h = _GateHarness(profile: _profile(), send: false);
        expect((await h.build().run()).outcome, IosHwidGateOutcome.proceed);
        expect(h.refreshCalls, 0);
      });

      test('нет текущего профиля', () async {
        final h = _GateHarness();
        expect((await h.build().run()).outcome, IosHwidGateOutcome.proceed);
        expect(h.refreshCalls, 0);
      });

      test('профиль не подписка по ссылке (файл)', () async {
        final h = _GateHarness(profile: _profile(), url: null);
        expect((await h.build().run()).outcome, IosHwidGateOutcome.proceed);
        expect(h.refreshCalls, 0);
      });

      test('HWID этого устройства неизвестен', () async {
        final h = _GateHarness(profile: _profile())..hwid = null;
        expect((await h.build().run()).outcome, IosHwidGateOutcome.proceed);
        expect(h.refreshCalls, 0);
      });

      test('локальный сбой при чтении HWID не мешает подключению', () async {
        final h = _GateHarness(profile: _profile())..hwidThrows = true;
        expect((await h.build().run()).outcome, IosHwidGateOutcome.proceed);
        expect(h.refreshCalls, 0);
      });
    });

    test('в журнал не попадают ни HWID, ни ссылка подписки', () async {
      final h = _GateHarness(profile: _profile(fetchedHwid: _otherHwid))
        ..onRefresh = (_) async => throw StateError('$_secretUrl $_hwid');

      await h.build().run();

      expect(h.logs, isNotEmpty);
      for (final line in h.logs) {
        expect(line, isNot(contains(_hwid)));
        expect(line, isNot(contains(_otherHwid)));
        expect(line, isNot(contains('SECRET-TOKEN')));
      }
    });
  });

  group('GlobalState.handleStart на iOS', () {
    late Completer<IosHwidGateResult>? pendingGate;
    late IosHwidGateResult gateResult;
    late int gateCalls;
    late int tunnelStarts;
    late bool tunnelStartResult;
    late List<String> notifications;

    IosStartHooks hooks() => IosStartHooks(
          gate: () {
            gateCalls++;
            return pendingGate?.future ?? Future.value(gateResult);
          },
          startTunnel: () async {
            tunnelStarts++;
            return tunnelStartResult;
          },
          notify: notifications.add,
        );

    setUp(() {
      pendingGate = null;
      gateResult = const IosHwidGateResult(IosHwidGateOutcome.proceed);
      gateCalls = 0;
      tunnelStarts = 0;
      tunnelStartResult = true;
      notifications = [];
      globalState
        ..iosStartHooks = hooks()
        ..startTime = null;
      globalState.isConnecting.value = false;
    });

    tearDown(() {
      globalState
        ..iosStartHooks = null
        ..startTime = null
        ..stopUpdateTasks();
      globalState.isConnecting.value = false;
    });

    test('проверка прошла: туннель стартует один раз', () async {
      final started = await globalState.handleStart([]);

      expect(started, isTrue);
      expect(gateCalls, 1);
      expect(tunnelStarts, 1);
      expect(globalState.startTime, isNotNull);
      expect(globalState.isConnecting.value, isFalse);
      expect(notifications, isEmpty);
    });

    test(
        'панель отказала по лимиту: туннель не стартует, без тоста '
        'и без «ложной» ошибки запуска (null, не false)', () async {
      gateResult = const IosHwidGateResult(IosHwidGateOutcome.limited);

      final started = await globalState.handleStart([]);

      expect(started, isNull);
      expect(tunnelStarts, 0);
      expect(notifications, isEmpty);
      expect(globalState.startTime, isNull);
      expect(globalState.isConnecting.value, isFalse);
    });

    test(
        'чужое устройство и нет сети: туннель не стартует, один короткий '
        'тост', () async {
      gateResult = IosHwidGateResult(
        IosHwidGateOutcome.unverified,
        error: TimeoutException('offline'),
      );

      final started = await globalState.handleStart([]);

      expect(started, isNull);
      expect(tunnelStarts, 0);
      expect(notifications, hasLength(1));
      expect(notifications.single.length, lessThanOrEqualTo(45));
      expect(globalState.isConnecting.value, isFalse);
    });

    test('во время проверки главная показывает «Подключение…»', () async {
      pendingGate = Completer<IosHwidGateResult>();

      final start = globalState.handleStart([]);
      await Future<void>.delayed(Duration.zero);
      expect(globalState.isConnecting.value, isTrue);

      pendingGate!.complete(gateResult);
      await start;
      expect(globalState.isConnecting.value, isFalse);
    });

    test('стоп во время проверки: туннель после неё не стартует', () async {
      pendingGate = Completer<IosHwidGateResult>();

      final start = globalState.handleStart([]);
      await Future<void>.delayed(Duration.zero);
      final stopped = await globalState.handleStop();
      pendingGate!.complete(gateResult);
      final started = await start;

      expect(stopped, isTrue);
      expect(started, isNull);
      expect(tunnelStarts, 0);
      expect(globalState.startTime, isNull);
      expect(globalState.isConnecting.value, isFalse);
    });

    test(
        'повторный старт во время проверки игнорируется: проверка и туннель '
        'один раз', () async {
      pendingGate = Completer<IosHwidGateResult>();

      final first = globalState.handleStart([]);
      await Future<void>.delayed(Duration.zero);
      final second = await globalState.handleStart([]);
      pendingGate!.complete(gateResult);
      final firstResult = await first;

      expect(second, isNull);
      expect(firstResult, isTrue);
      expect(gateCalls, 1);
      expect(tunnelStarts, 1);
    });

    test('после отказа гейта следующий старт работает (флаги сброшены)',
        () async {
      gateResult = const IosHwidGateResult(IosHwidGateOutcome.limited);
      await globalState.handleStart([]);

      gateResult = const IosHwidGateResult(IosHwidGateOutcome.proceed);
      final started = await globalState.handleStart([]);

      expect(started, isTrue);
      expect(tunnelStarts, 1);
    });

    test(
        'сбой самого туннеля после проверки остаётся обычной ошибкой '
        'запуска (false)', () async {
      tunnelStartResult = false;

      final started = await globalState.handleStart([]);

      expect(started, isFalse);
      expect(globalState.startTime, isNull);
    });
  });
}
