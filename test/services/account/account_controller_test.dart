import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dropweb/services/account/account_api.dart';
import 'package:dropweb/services/account/account_api_exception.dart';
import 'package:dropweb/services/account/account_controller.dart';
import 'package:dropweb/services/account/account_models.dart';
import 'package:dropweb/services/account/account_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_fakes.dart';

const _base = 'https://gw.example/api';
const _subUrl = 'https://sub.example/s/abc';

class _Harness {
  /// [bound] — в хранилище уже есть сессия, привязанная к [_base]: так
  /// выглядит любой вход, сделанный после привязки сессии к бэкенду.
  _Harness(
    FakeHandler handler, {
    List<String> login = const [_base],
    List<String> defaults = const [],
    List<List<String>> known = const [],
    bool bound = true,
  })  : adapter = FakeAdapter(handler),
        loginBases = login,
        defaultBases = defaults,
        knownBases = known {
    if (bound) store.apiBases = const [_base];
    controller = AccountController(
      api: (bases) => AccountApi(
        baseUrls: bases,
        userAgent: () => 'dropweb/test',
        dio: fakeDio(adapter),
      ),
      store: store,
      biometrics: biometrics,
      profiles: profiles,
      language: () => 'ru',
      loginBases: () => loginBases,
      defaultBases: () => defaultBases,
      knownBases: () => knownBases,
      onState: states.add,
      clock: () => now,
    );
  }

  /// Часы контроллера: тест двигает их, проверяя паузу между починками.
  DateTime now = DateTime(2026, 10, 11, 12);

  final FakeAdapter adapter;
  final store = MemoryAccountStore();
  final biometrics = FakeBiometrics();
  final profiles = FakeProfiles();
  final states = <AccountState>[];
  late final AccountController controller;

  /// Базы входа по текущему профилю; тест меняет их, «переключая» профиль.
  List<String> loginBases;
  List<String> defaultBases;

  /// Все наборы адресов, которые приложение сейчас знает (заголовки профилей
  /// и дефолт сборки).
  List<List<String>> knownBases;

  int count(String path) =>
      adapter.requests.where((r) => r.path.endsWith(path)).length;

  /// Хосты, на которые ушёл запрос с данным суффиксом пути.
  List<String> hostsOf(String path) => adapter.requests
      .where((r) => r.path.endsWith(path))
      .map((r) => r.uri.host)
      .toList();
}

ResponseBody _tokens(String access, String refresh) => jsonResponse(200, {
      'access_token': access,
      'refresh_token': refresh,
      'token_type': 'bearer',
      'expires_in': 900,
    });

ResponseBody _subscription({String? url = _subUrl}) => jsonResponse(200, {
      'has_subscription': url != null,
      'subscription': url == null
          ? null
          : {'subscription_url': url, 'is_active': true, 'days_left': 30},
    });

String? _bearer(RequestOptions o) =>
    (o.headers['Authorization'] as String?)?.replaceFirst('Bearer ', '');

ResponseBody get h401 =>
    jsonResponse(401, {'detail': 'Invalid or expired token'});

Future<AccountApiException> _error(Future<Object?> call) async {
  try {
    await call;
  } on AccountApiException catch (e) {
    return e;
  }
  fail('ожидалось AccountApiException');
}

void main() {
  group('restore', () {
    test('нет refresh-токена → loggedOut без сети', () async {
      final h = _Harness((o) => fail('сеть не нужна'));
      await h.controller.restore();
      expect(h.controller.state.status, AccountStatus.loggedOut);
      expect(h.adapter.requests, isEmpty);
    });

    test('токен есть → ready сразу, refresh поворачивает и сохраняет токен',
        () async {
      final h = _Harness((o) => _tokens('a1', 'r2'));
      h.store
        ..refreshToken = 'r1'
        ..email = 'u@x.io';

      await h.controller.restore();

      expect(h.states.first.status, AccountStatus.ready);
      expect(h.controller.state.email, 'u@x.io');
      expect(h.store.refreshToken, 'r2');
      expect((h.adapter.requests.single.data as Map)['refresh_token'], 'r1');
    });

    test('биометрия включена → locked', () async {
      final h = _Harness((o) => _tokens('a1', 'r2'));
      h.store
        ..refreshToken = 'r1'
        ..biometricEnabled = true;
      await h.controller.restore();
      expect(h.controller.state.status, AccountStatus.locked);
      expect(h.controller.state.biometricEnabled, isTrue);
    });

    test('refresh 401 → хранилище стёрто, loggedOut', () async {
      final h = _Harness(
          (o) => jsonResponse(401, {'detail': 'Refresh token reuse detected'}));
      h.store
        ..refreshToken = 'r1'
        ..email = 'u@x.io'
        ..importedUrl = _subUrl;

      await h.controller.restore();

      expect(h.controller.state.status, AccountStatus.loggedOut);
      expect(h.store.refreshToken, isNull);
      expect(h.store.email, isNull);
    });

    test('сеть недоступна → токены и состояние сохраняются', () async {
      final h = _Harness((o) => throw DioException.connectionError(
          requestOptions: o, reason: 'offline'));
      h.store.refreshToken = 'r1';

      await h.controller.restore();

      expect(h.controller.state.status, AccountStatus.ready);
      expect(h.store.refreshToken, 'r1');
    });
  });

  test('single-flight: два параллельных 401 → ровно один refresh', () async {
    final refreshGate = Completer<void>();
    late _Harness h;
    h = _Harness((o) async {
      if (o.path.endsWith('/cabinet/auth/refresh')) {
        final sent = (o.data as Map)['refresh_token'];
        if (sent == 'r1') return _tokens('a1', 'r2');
        // Держим второй refresh, пока оба запроса не получат 401.
        await refreshGate.future;
        return _tokens('a2', 'r3');
      }
      if (_bearer(o) == 'a1') {
        if (h.count('/cabinet/auth/app-handoff') >= 2 &&
            !refreshGate.isCompleted) {
          scheduleMicrotask(refreshGate.complete);
        }
        return jsonResponse(401, {'detail': 'Invalid or expired token'});
      }
      return jsonResponse(200, {'token': 'tok', 'expires_in': 120});
    });
    h.store
      ..refreshToken = 'r1'
      ..importedUrl = _subUrl;
    h.profiles.profiles['sub'] = _subUrl;
    h.profiles.cabinets['sub'] = Uri.parse('https://gw.example');
    await h.controller.restore();

    final results = await Future.wait([
      h.controller.cabinetHandoffUri(),
      h.controller.cabinetHandoffUri(),
    ]);

    expect(h.count('/cabinet/auth/refresh'), 2); // restore + один общий
    final refreshBodies = h.adapter.requests
        .where((r) => r.path.endsWith('/cabinet/auth/refresh'))
        .map((r) => (r.data as Map)['refresh_token'])
        .toList();
    expect(refreshBodies, ['r1', 'r2']);
    expect(h.store.refreshToken, 'r3');
    expect(h.store.refreshWrites, ['r2', 'r3']);
    expect(results.map((u) => u.toString()),
        everyElement('https://gw.example/auto-login?token=tok'));
  });

  test('повторный 401 после refresh не уходит в цикл', () async {
    final h = _Harness((o) {
      if (o.path.endsWith('/cabinet/auth/refresh')) {
        return _tokens('a${o.hashCode}', 'r${o.hashCode}');
      }
      return jsonResponse(401, {'detail': 'Invalid or expired token'});
    });
    h.store.refreshToken = 'r1';
    await h.controller.restore();

    final e = await _error(h.controller.syncSubscription());
    expect(e.kind, AccountApiErrorKind.unauthorized);
    expect(h.count('/cabinet/subscription'), 2);
  });

  group('syncSubscription', () {
    Future<_Harness> ready(FakeHandler sub) async {
      final h = _Harness((o) {
        if (o.path.endsWith('/cabinet/auth/refresh')) {
          return _tokens('a1', 'r2');
        }
        return sub(o);
      });
      h.store.refreshToken = 'r1';
      await h.controller.restore();
      return h;
    }

    test('профиль с тем же url уже есть → делаем текущим, без импорта',
        () async {
      final h = await ready((o) => _subscription());
      h.profiles.profiles['manual'] = _subUrl;

      expect(await h.controller.syncSubscription(),
          SubscriptionSyncResult.alreadyPresent);
      expect(h.profiles.imports, isEmpty);
      expect(h.profiles.currentId, 'manual');
      expect(h.store.importedUrl, _subUrl);
      expect(h.controller.state.subscription?.daysLeft, 30);
    });

    test('профиля нет → импорт через поток профилей', () async {
      final h = await ready((o) => _subscription());
      expect(await h.controller.syncSubscription(),
          SubscriptionSyncResult.imported);
      expect(h.profiles.imports, [_subUrl]);
      expect(h.store.importedUrl, _subUrl);
    });

    test('подписки нет → noSubscription', () async {
      final h = await ready((o) => _subscription(url: null));
      expect(await h.controller.syncSubscription(),
          SubscriptionSyncResult.noSubscription);
      expect(h.profiles.imports, isEmpty);
    });

    test('импорт молча не удался → ошибка profile', () async {
      final h = await ready((o) => _subscription());
      h.profiles.importSucceeds = false;
      final e = await _error(h.controller.syncSubscription());
      expect(e.kind, AccountApiErrorKind.profile);
      expect(h.store.importedUrl, isNull);
    });

    test('в состоянии locked запрещено', () async {
      final h = _Harness((o) => _tokens('a1', 'r2'));
      h.store
        ..refreshToken = 'r1'
        ..biometricEnabled = true;
      await h.controller.restore();
      final e = await _error(h.controller.syncSubscription());
      expect(e.kind, AccountApiErrorKind.biometric);
      expect(h.count('/cabinet/subscription'), 0);
    });
  });

  test('verifyCode сохраняет сессию и импортирует подписку', () async {
    final h = _Harness((o) {
      if (o.path.endsWith('/email/code/verify')) {
        return jsonResponse(200, {
          'access_token': 'a1',
          'refresh_token': 'r1',
          'token_type': 'bearer',
          'expires_in': 900,
          'user': {'email': 'new@x.io'},
        });
      }
      expect(_bearer(o), 'a1');
      return _subscription();
    });

    final result = await h.controller.verifyCode('New@x.io', '123456');

    expect(result, SubscriptionSyncResult.imported);
    expect(h.store.refreshToken, 'r1');
    expect(h.store.email, 'new@x.io');
    expect(h.controller.state.status, AccountStatus.ready);
    final body = h.adapter.requests.first.data as Map;
    expect(body, {'email': 'New@x.io', 'code': '123456', 'language': 'ru'});
  });

  test('unlock: биометрия подтверждена → ready', () async {
    final h = _Harness((o) => _tokens('a1', 'r2'));
    h.store
      ..refreshToken = 'r1'
      ..biometricEnabled = true;
    await h.controller.restore();

    h.biometrics.result = false;
    expect(await h.controller.unlock('reason'), isFalse);
    expect(h.controller.state.status, AccountStatus.locked);

    h.biometrics.result = true;
    expect(await h.controller.unlock('reason'), isTrue);
    expect(h.controller.state.status, AccountStatus.ready);
  });

  test('enable/disableBiometric сохраняют флаг только после подтверждения',
      () async {
    final h = _Harness((o) => _tokens('a1', 'r2'));
    h.store.refreshToken = 'r1';
    await h.controller.restore();

    h.biometrics.result = false;
    expect(await h.controller.enableBiometric('r'), isFalse);
    expect(h.store.biometricEnabled, isFalse);

    h.biometrics.result = true;
    expect(await h.controller.enableBiometric('r'), isTrue);
    expect(h.store.biometricEnabled, isTrue);
    expect(h.controller.state.biometricEnabled, isTrue);

    await h.controller.disableBiometric();
    expect(h.store.biometricEnabled, isFalse);
  });

  group('cabinetHandoffUri', () {
    Future<_Harness> ready(FakeHandler handoff, {Uri? cabinet}) async {
      final h = _Harness((o) {
        if (o.path.endsWith('/cabinet/auth/refresh')) {
          return _tokens('a1', 'r2');
        }
        return handoff(o);
      });
      h.store
        ..refreshToken = 'r1'
        ..importedUrl = _subUrl;
      h.profiles.profiles['sub'] = _subUrl;
      if (cabinet != null) h.profiles.cabinets['sub'] = cabinet;
      await h.controller.restore();
      return h;
    }

    test('origin кабинета своего профиля + urlencoded токен', () async {
      final h = await ready(
        (o) => jsonResponse(200, {'token': 'a+b/c=', 'expires_in': 120}),
        cabinet: Uri.parse('https://cab.provider.io/some/path'),
      );
      expect((await h.controller.cabinetHandoffUri()).toString(),
          'https://cab.provider.io/auto-login?token=a%2Bb%2Fc%3D');
    });

    test('404 (эндпоинт не задеплоен) → корень кабинета без токена', () async {
      final h = await ready(
        (o) => jsonResponse(404, {'detail': 'Not Found'}),
        cabinet: Uri.parse('https://cab.provider.io/x'),
      );
      expect((await h.controller.cabinetHandoffUri()).toString(),
          'https://cab.provider.io/');
    });

    test('у своего профиля нет кабинета → notAvailable, токен не выпускаем',
        () async {
      final h = await ready((o) => fail('handoff не должен вызываться'));
      final e = await _error(h.controller.cabinetHandoffUri());
      expect(e.kind, AccountApiErrorKind.notAvailable);
      expect(h.count('/cabinet/auth/app-handoff'), 0);
    });
  });

  group('cabinetUriFor: токен только в кабинет своего профиля', () {
    Future<_Harness> ready() async {
      final h = _Harness((o) {
        if (o.path.endsWith('/cabinet/auth/refresh')) {
          return _tokens('a1', 'r2');
        }
        return jsonResponse(200, {'token': 'tok', 'expires_in': 120});
      });
      h.store
        ..refreshToken = 'r1'
        ..importedUrl = _subUrl;
      h.profiles.profiles
        ..['sub'] = _subUrl
        ..['foreign'] = 'https://other.example/s/zzz';
      h.profiles.cabinets
        ..['sub'] = Uri.parse('https://cab.own.io/path')
        ..['foreign'] = Uri.parse('https://cab.foreign.io/lk');
      await h.controller.restore();
      return h;
    }

    test('чужой профиль → обычная ссылка, handoff не вызывается', () async {
      final h = await ready();
      expect((await h.controller.cabinetUriFor('foreign')).toString(),
          'https://cab.foreign.io/lk');
      expect(h.count('/cabinet/auth/app-handoff'), 0);
    });

    test('свой профиль → handoff на origin его кабинета', () async {
      final h = await ready();
      expect((await h.controller.cabinetUriFor('sub')).toString(),
          'https://cab.own.io/auto-login?token=tok');
      expect(h.hostsOf('/cabinet/auth/app-handoff'), ['gw.example']);
    });

    test('профиль без кабинета → null', () async {
      final h = await ready();
      h.profiles.cabinets.remove('foreign');
      expect(await h.controller.cabinetUriFor('foreign'), isNull);
      expect(await h.controller.cabinetUriFor(null), isNull);
      expect(h.count('/cabinet/auth/app-handoff'), 0);
    });

    test('сессия заблокирована → обычная ссылка даже для своего профиля',
        () async {
      final h = _Harness((o) => _tokens('a1', 'r2'));
      h.store
        ..refreshToken = 'r1'
        ..biometricEnabled = true
        ..importedUrl = _subUrl;
      h.profiles.profiles['sub'] = _subUrl;
      h.profiles.cabinets['sub'] = Uri.parse('https://cab.own.io/');
      await h.controller.restore();
      expect((await h.controller.cabinetUriFor('sub')).toString(),
          'https://cab.own.io/');
      expect(h.count('/cabinet/auth/app-handoff'), 0);
    });

    test('profileId аккаунта попадает в состояние после restore', () async {
      final h = await ready();
      expect(h.controller.state.profileId, 'sub');
    });
  });

  group('привязка сессии к бэкенду', () {
    const x = 'https://x.example/api';
    const xMirror = 'https://x-mirror.example/api';
    const y = 'https://y.example/api';

    FakeHandler backend() => (o) {
          if (o.path.endsWith('/email/code/verify')) {
            return jsonResponse(200, {
              'access_token': 'a1',
              'refresh_token': 'r1',
              'token_type': 'bearer',
              'expires_in': 900,
            });
          }
          if (o.path.endsWith('/cabinet/auth/refresh')) {
            return _tokens('a${o.hashCode}', 'r${o.hashCode}');
          }
          if (o.path.endsWith('/cabinet/subscription') && _bearer(o) == 'a1') {
            // Первый access «протух» — заставляем пройти refresh.
            return h401;
          }
          return _subscription();
        };

    test('после входа на X смена профиля на Y не уводит сессию с X', () async {
      final h = _Harness(backend(), login: const [x, xMirror], bound: false);
      await h.controller.verifyCode('u@x.io', '123456');
      expect(h.store.apiBases, [x, xMirror]);

      // Пользователь переключился на профиль другого провайдера (или без
      // заголовка) — вход теперь шёл бы на Y, но сессия остаётся на X.
      for (final login in [
        const [y],
        const <String>[]
      ]) {
        h.loginBases = login;
        await h.controller.syncSubscription();
      }
      expect(h.hostsOf('/cabinet/subscription').toSet(), {'x.example'});
      expect(h.hostsOf('/cabinet/auth/refresh').toSet(), {'x.example'});

      await h.controller.logout();
      // Серверный logout уходит в фоне — даём ему дойти до адаптера.
      await pumpEventQueue();
      expect(h.hostsOf('/cabinet/auth/logout'), ['x.example']);
    });

    test('restore: привязанные базы → только они, не базы входа', () async {
      final h =
          _Harness((o) => _tokens('a1', 'r2'), login: const [y], bound: false);
      h.store
        ..refreshToken = 'r1'
        ..apiBases = const [x];
      await h.controller.restore();
      expect(h.hostsOf('/cabinet/auth/refresh'), ['x.example']);
    });

    test('restore: баз нет, дефолт сборки есть → дефолт и он запоминается',
        () async {
      final h = _Harness((o) => _tokens('a1', 'r2'),
          login: const [y], defaults: const [x], bound: false);
      h.store.refreshToken = 'r1';
      await h.controller.restore();
      expect(h.controller.state.status, AccountStatus.ready);
      expect(h.hostsOf('/cabinet/auth/refresh'), ['x.example']);
      expect(h.store.apiBases, [x]);
    });

    test('restore: новое зеркало того же бэкенда доучивается и выручает',
        () async {
      // Сессию создали, когда бэкенд объявлял один адрес. Потом провайдер
      // добавил зеркало в заголовок, а старый адрес лёг.
      final h = _Harness(
        (o) => o.uri.host == 'x.example'
            ? throw DioException.connectionError(
                requestOptions: o, reason: 'down')
            : _tokens('a1', 'r2'),
        login: const [y],
        known: const [
          [x, xMirror],
          [y],
        ],
        bound: false,
      );
      h.store
        ..refreshToken = 'r1'
        ..apiBases = const [x];
      await h.controller.restore();
      expect(h.store.apiBases, [x, xMirror]);
      expect(h.hostsOf('/cabinet/auth/refresh'),
          ['x.example', 'x-mirror.example']);
      expect(h.store.refreshToken, 'r2');
    });

    test('restore: адреса без общего с сессией не подмешиваются', () async {
      final h = _Harness((o) => _tokens('a1', 'r2'),
          login: const [y],
          known: const [
            [y, 'https://y-mirror.example/api'],
          ],
          bound: false);
      h.store
        ..refreshToken = 'r1'
        ..apiBases = const [x];
      await h.controller.restore();
      expect(h.store.apiBases, [x]);
      expect(h.hostsOf('/cabinet/auth/refresh'), ['x.example']);
    });

    test('restore: баз нет и дефолта нет → сессия стёрта, без сети', () async {
      final h = _Harness((o) => fail('сеть не нужна'),
          login: const [y], bound: false);
      h.store
        ..refreshToken = 'r1'
        ..email = 'u@x.io';
      await h.controller.restore();
      expect(h.controller.state.status, AccountStatus.loggedOut);
      expect(h.store.refreshToken, isNull);
      expect(h.store.email, isNull);
      expect(h.adapter.requests, isEmpty);
    });

    test('вход недоступен (нет баз) → notAvailable без сети', () async {
      final h =
          _Harness((o) => fail('сеть не нужна'), login: const [], bound: false);
      final request = await _error(h.controller.requestCode('u@x.io'));
      final verify = await _error(h.controller.verifyCode('u@x.io', '123456'));
      expect(request.kind, AccountApiErrorKind.notAvailable);
      expect(verify.kind, AccountApiErrorKind.notAvailable);
      expect(h.adapter.requests, isEmpty);
    });
  });

  group('удаление с устройства', () {
    _Harness withSession(FakeHandler other) {
      final h = _Harness((o) {
        if (o.path.endsWith('/cabinet/auth/refresh')) {
          return _tokens('a1', 'r2');
        }
        return other(o);
      });
      h.store
        ..refreshToken = 'r1'
        ..importedUrl = _subUrl;
      h.profiles.profiles
        ..['sub'] = _subUrl
        ..['other'] = 'https://other.example/x';
      return h;
    }

    test('серверный logout, сессия стёрта, удалён только профиль аккаунта',
        () async {
      final h = withSession((o) => jsonResponse(200, {'status': 'ok'}));
      await h.controller.restore();

      await h.controller.removeFromDevice();
      // Серверный logout уходит в фоне — даём ему дойти до адаптера.
      await pumpEventQueue();

      final logout = h.adapter.requests
          .singleWhere((r) => r.path.endsWith('/cabinet/auth/logout'));
      expect((logout.data as Map)['refresh_token'], 'r2');
      expect(h.store.refreshToken, isNull);
      expect(h.store.importedUrl, isNull);
      expect(h.controller.state.status, AccountStatus.loggedOut);
      expect(h.profiles.deleted, ['sub']);
      expect(h.profiles.profiles.keys, ['other']);
    });

    test('logout упал по сети → всё равно стёрто и профиль удалён', () async {
      final h = withSession((o) => throw DioException.connectionError(
          requestOptions: o, reason: 'offline'));
      await h.controller.restore();

      await h.controller.removeFromDevice();
      // Серверный logout уходит в фоне — даём ему дойти до адаптера.
      await pumpEventQueue();

      expect(h.count('/cabinet/auth/logout'), 1);
      expect(h.store.refreshToken, isNull);
      expect(h.controller.state.status, AccountStatus.loggedOut);
      expect(h.profiles.deleted, ['sub']);
      expect(h.profiles.profiles.keys, ['other']);
    });

    // На Pixel 2026-10-11 шлюз молчал, и кнопка крутилась 15+ с, пока
    // серверный logout ждал connectTimeout. Стирание на устройстве от ответа
    // сервера не зависит — ждать его нельзя.
    test('сервер молчит → удаление не ждёт ответа logout', () async {
      final hang = Completer<ResponseBody>();
      final h = withSession((o) => o.path.endsWith('/cabinet/auth/logout')
          ? hang.future
          : jsonResponse(200, {'status': 'ok'}));
      await h.controller.restore();

      await h.controller.removeFromDevice().timeout(const Duration(seconds: 1));

      expect(h.controller.state.status, AccountStatus.loggedOut);
      expect(h.store.refreshToken, isNull);
      expect(h.profiles.deleted, ['sub']);
      await pumpEventQueue();
      expect(h.count('/cabinet/auth/logout'), 1);
      hang.complete(jsonResponse(200, {'status': 'ok'}));
    });

    test('импортированной подписки нет → профили не трогаем', () async {
      final h = withSession((o) => jsonResponse(200, {'status': 'ok'}));
      h.store.importedUrl = null;
      await h.controller.restore();

      await h.controller.removeFromDevice();
      // Серверный logout уходит в фоне — даём ему дойти до адаптера.
      await pumpEventQueue();

      expect(h.controller.state.status, AccountStatus.loggedOut);
      expect(h.profiles.deleted, isEmpty);
      expect(h.profiles.profiles.keys, ['sub', 'other']);
    });
  });

  test('logout: сеть упала — локальный выход всё равно, профили остаются',
      () async {
    final h = _Harness((o) {
      if (o.path.endsWith('/cabinet/auth/refresh')) return _tokens('a1', 'r2');
      throw DioException.connectionError(requestOptions: o, reason: 'offline');
    });
    h.store
      ..refreshToken = 'r1'
      ..importedUrl = _subUrl;
    h.profiles.profiles['sub'] = _subUrl;
    await h.controller.restore();

    await h.controller.logout();
    // Серверный logout уходит в фоне — даём ему дойти до адаптера.
    await pumpEventQueue();

    expect(h.store.refreshToken, isNull);
    expect(h.controller.state.status, AccountStatus.loggedOut);
    expect(h.profiles.profiles, contains('sub'));
    expect(h.count('/cabinet/auth/logout'), 1);
  });

  group('починка адреса подписки', () {
    const newUrl = 'https://sub2.example/s/abc';

    /// Сессия ready, профиль аккаунта 'sub' на старом адресе [_subUrl].
    Future<_Harness> ready(FakeHandler sub, {bool locked = false}) async {
      final h = _Harness((o) {
        if (o.path.endsWith('/cabinet/auth/refresh')) {
          return _tokens('a1', 'r2');
        }
        return sub(o);
      });
      h.store
        ..refreshToken = 'r1'
        ..importedUrl = _subUrl
        ..biometricEnabled = locked;
      h.profiles.profiles['sub'] = _subUrl;
      await h.controller.restore();
      return h;
    }

    test('сервер выдал новый адрес → профиль переведён, imported обновлён',
        () async {
      final h = await ready((o) => _subscription(url: newUrl));

      expect(await h.controller.repairSubscription(), isTrue);

      expect(h.profiles.repoints, [('sub', newUrl)]);
      expect(h.profiles.imports, isEmpty);
      expect(h.store.importedUrl, newUrl);
      expect(h.controller.state.profileId, 'sub');
    });

    test('адрес тот же → false, профиль не трогаем', () async {
      final h = await ready((o) => _subscription());
      expect(await h.controller.repairSubscription(), isFalse);
      expect(h.profiles.repoints, isEmpty);
      expect(h.store.importedUrl, _subUrl);
    });

    test('locked → false без сети и без запроса биометрии', () async {
      final h = await ready((o) => _subscription(url: newUrl), locked: true);
      expect(h.controller.state.status, AccountStatus.locked);

      expect(await h.controller.repairSubscription(), isFalse);

      expect(h.count('/cabinet/subscription'), 0);
      expect(h.biometrics.calls, 0);
      expect(h.profiles.repoints, isEmpty);
    });

    test('пауза 30 минут между попытками', () async {
      final h = await ready((o) => _subscription(url: newUrl));
      expect(await h.controller.repairSubscription(), isTrue);

      h.now = h.now.add(const Duration(minutes: 29));
      expect(await h.controller.repairSubscription(), isFalse);
      expect(h.count('/cabinet/subscription'), 1);

      h.now = h.now.add(const Duration(minutes: 2));
      await h.controller.repairSubscription();
      expect(h.count('/cabinet/subscription'), 2);
    });

    test('профиль аккаунта удалён → false, нового не импортируем', () async {
      final h = await ready((o) => _subscription(url: newUrl));
      h.profiles.profiles.remove('sub');

      expect(await h.controller.repairSubscription(), isFalse);

      expect(h.profiles.imports, isEmpty);
      expect(h.profiles.profiles, isEmpty);
      expect(h.store.importedUrl, _subUrl);
    });

    test('подписки нет → false', () async {
      final h = await ready((o) => _subscription(url: null));
      expect(await h.controller.repairSubscription(), isFalse);
      expect(h.profiles.repoints, isEmpty);
    });

    test('ошибка API → false, наружу не бросает', () async {
      final h = await ready((o) => jsonResponse(500, {'detail': 'boom'}));
      expect(await h.controller.repairSubscription(), isFalse);
      expect(h.profiles.repoints, isEmpty);
    });

    test('сеть упала → false, наружу не бросает', () async {
      final h = await ready((o) => throw DioException.connectionError(
          requestOptions: o, reason: 'offline'));
      expect(await h.controller.repairSubscription(), isFalse);
      expect(h.profiles.repoints, isEmpty);
    });

    test('новый адрес тоже не отвечает → false, но аккаунт следит за профилем',
        () async {
      final h = await ready((o) => _subscription(url: newUrl));
      h.profiles.repointUpdateError = Exception('fetch failed');

      expect(await h.controller.repairSubscription(), isFalse);

      expect(h.profiles.profiles['sub'], newUrl);
      expect(h.store.importedUrl, newUrl);
      expect(h.controller.state.profileId, 'sub');
    });

    test('onProfileUpdateFailed: чужой профиль → без сети', () async {
      final h = await ready((o) => _subscription(url: newUrl));
      h.profiles.profiles['other'] = 'https://other.example/s/x';
      final before = h.adapter.requests.length;

      expect(await h.controller.onProfileUpdateFailed('other'), isFalse);

      expect(h.adapter.requests.length, before);
      expect(h.profiles.repoints, isEmpty);
    });

    test('onProfileUpdateFailed: профиль аккаунта → починка', () async {
      final h = await ready((o) => _subscription(url: newUrl));
      expect(await h.controller.onProfileUpdateFailed('sub'), isTrue);
      expect(h.profiles.repoints, [('sub', newUrl)]);
    });

    test('onProfileUpdateFailed: locked → без сети', () async {
      final h = await ready((o) => _subscription(url: newUrl), locked: true);
      final before = h.adapter.requests.length;
      expect(await h.controller.onProfileUpdateFailed('sub'), isFalse);
      expect(h.adapter.requests.length, before);
      expect(h.biometrics.calls, 0);
    });

    test('syncSubscription: адрес сменился → профиль переведён, без дубля',
        () async {
      final h = await ready((o) => _subscription(url: newUrl));

      expect(await h.controller.syncSubscription(),
          SubscriptionSyncResult.alreadyPresent);

      expect(h.profiles.imports, isEmpty);
      expect(h.profiles.repoints, [('sub', newUrl)]);
      expect(h.profiles.profiles, {'sub': newUrl});
      expect(h.store.importedUrl, newUrl);
      expect(h.controller.state.profileId, 'sub');
    });
  });
}
