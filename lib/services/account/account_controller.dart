import 'dart:async';

import 'package:dropweb/services/account/account_api.dart';
import 'package:dropweb/services/account/account_api_exception.dart';
import 'package:dropweb/services/account/account_biometrics.dart';
import 'package:dropweb/services/account/account_models.dart';
import 'package:dropweb/services/account/account_profiles.dart';
import 'package:dropweb/services/account/account_state.dart';
import 'package:dropweb/services/account/account_store.dart';
import 'package:flutter/foundation.dart';

/// Логика аккаунта без Riverpod: провайдер `Account` только оборачивает её,
/// поэтому всё поведение проверяется юнит-тестами на фейках.
class AccountController {
  /// [api] собирает клиента под заданный набор баз: вход и сессия ходят
  /// через разных клиентов, у каждого свой перебор зеркал.
  /// [loginBases] — бэкенд входа по текущему профилю (заголовок
  /// `dropweb-account` или дефолт сборки в пустом состоянии); пусто — вход
  /// недоступен. [defaultBases] — дефолт сборки: им доучиваются сессии,
  /// созданные до привязки к бэкенду. [knownBases] — все наборы адресов,
  /// известные сейчас (заголовки профилей и дефолт сборки): из них сессия
  /// при запуске подхватывает новые зеркала своего бэкенда.
  AccountController({
    required AccountApi Function(List<String> Function() bases) api,
    required AccountStorage store,
    required AccountBiometrics biometrics,
    required AccountProfiles profiles,
    required String Function() language,
    required List<String> Function() loginBases,
    required List<String> Function() defaultBases,
    List<List<String>> Function()? knownBases,
    required void Function(AccountState state) onState,
  })  : _api = api,
        _store = store,
        _biometrics = biometrics,
        _profiles = profiles,
        _language = language,
        _loginBases = loginBases,
        _defaultBases = defaultBases,
        _knownBases = knownBases ?? (() => const []),
        _onState = onState {
    _loginApi = api(_loginBases);
    _sessionApi = api(() => _sessionBases);
  }

  final AccountApi Function(List<String> Function() bases) _api;
  final AccountStorage _store;
  final AccountBiometrics _biometrics;
  final AccountProfiles _profiles;
  final String Function() _language;
  final List<String> Function() _loginBases;
  final List<String> Function() _defaultBases;
  final List<List<String>> Function() _knownBases;
  final void Function(AccountState state) _onState;

  /// Только запрос и проверка кода — на бэкенд текущего профиля.
  late final AccountApi _loginApi;

  /// Всё с токенами — строго на бэкенд, где создана сессия, какой бы
  /// профиль ни был текущим: иначе refresh-токен уйдёт чужому провайдеру.
  late final AccountApi _sessionApi;

  /// Базы бэкенда текущей сессии; пусто — сессии нет или ещё не загружена.
  List<String> _sessionBases = const [];

  AccountState _state = const AccountState();
  AccountState get state => _state;

  /// Access-токен только в памяти: после перезапуска получаем новый по refresh.
  String? _accessToken;

  /// Копия refresh-токена в памяти. Если KeyStore не сохранил повёрнутый
  /// токен, процесс всё равно продолжит с новым, а не переиспользует старый.
  String? _refreshToken;

  /// Общий на всех вызывающих refresh в полёте. Refresh-токены одноразовые:
  /// повторное использование старого позже 10 с бэкенд считает кражей и
  /// отзывает всю цепочку сессий (401 'Refresh token reuse detected').
  Future<String>? _refreshing;

  void _emit(AccountState next) {
    _state = next;
    _onState(next);
  }

  Future<void> restore() async {
    final refresh = await _store.readRefreshToken();
    final available = await _biometrics.isAvailable();
    if (refresh == null || refresh.isEmpty) {
      _emit(AccountState(
        status: AccountStatus.loggedOut,
        biometricAvailable: available,
      ));
      return;
    }
    var bases = await _store.readApiBases();
    final bound = bases.isNotEmpty;
    if (!bound) {
      // Сессия создана до привязки к бэкенду. Тогда вход шёл только на
      // бэкенд издателя сборки — им и доучиваем. Без дефолта бэкенд
      // неизвестен: гадать нельзя, токен мог бы уйти чужому серверу.
      bases = _defaultBases();
      if (bases.isEmpty) {
        await _store.clear();
        _emit(AccountState(
          status: AccountStatus.loggedOut,
          biometricAvailable: available,
        ));
        return;
      }
    }
    final merged = _withMirrors(bases);
    if (!bound || merged.length != bases.length) {
      if (!await _store.writeApiBases(merged) && kDebugMode) {
        debugPrint('[Account] api bases were not persisted');
      }
    }
    _sessionBases = List.unmodifiable(merged);
    _refreshToken = refresh;
    final biometricEnabled = await _store.readBiometricEnabled();
    _emit(AccountState(
      status: biometricEnabled ? AccountStatus.locked : AccountStatus.ready,
      email: await _store.readEmail(),
      biometricEnabled: biometricEnabled,
      biometricAvailable: available,
    ));
    await refreshProfileId();
    try {
      // Продлеваем 30-дневное скользящее окно сессии при каждом запуске.
      await _refreshAccess();
    } on AccountApiException catch (e) {
      // 401 уже обработан в _refreshAccess (стёрто → loggedOut); сеть — штатно
      // для старта без интернета: сессию не трогаем, обновим при первом вызове.
      if (e.kind != AccountApiErrorKind.unauthorized &&
          e.kind != AccountApiErrorKind.network) {
        rethrow;
      }
      if (kDebugMode) debugPrint('[Account] restore refresh: $e');
    }
  }

  /// Адреса сессии плюс зеркала, которые её бэкенд объявил позже. Без этого
  /// сессия навсегда помнит адреса на момент входа и при падении единственного
  /// шлюза не переключится на новый. Набор считается тем же бэкендом, только
  /// если в нём есть хоть один адрес сессии: иначе это другой провайдер, и
  /// refresh-токен к нему уходить не должен.
  List<String> _withMirrors(List<String> bases) {
    final merged = [...bases];
    for (final known in _knownBases()) {
      if (!known.any(merged.contains)) continue;
      for (final base in known) {
        if (!merged.contains(base)) merged.add(base);
      }
    }
    return merged;
  }

  /// Пересчитать профиль аккаунта: профили добавляют, удаляют и меняют им
  /// URL мимо аккаунта. Сбой поиска не ломает сессию — профиль просто
  /// считается ненайденным до следующего пересчёта.
  Future<void> refreshProfileId() async {
    if (!_hasSession) return;
    String? id;
    try {
      id = await _accountProfileId();
    } on AccountApiException catch (e) {
      if (kDebugMode) debugPrint('[Account] profile lookup failed: $e');
    }
    // За время поиска могли выйти из аккаунта.
    if (_hasSession && id != _state.profileId) {
      _emit(_state.withProfileId(id));
    }
  }

  bool get _hasSession =>
      _state.status == AccountStatus.ready ||
      _state.status == AccountStatus.locked;

  Future<String?> _accountProfileId() async {
    final url = await _store.readImportedUrl();
    if (url == null || url.isEmpty) return null;
    return _guardProfile(() => _profiles.findProfileIdByUrl(url));
  }

  /// Снимок баз входа: без бэкенда вход недоступен, и в сеть не идём.
  List<String> _requireLoginBases() {
    final bases = _loginBases();
    if (bases.isEmpty) {
      throw const AccountApiException(
        AccountApiErrorKind.notAvailable,
        code: 'login_unavailable',
        message: 'no account backend for the current profile',
      );
    }
    return List.unmodifiable(bases);
  }

  /// async — чтобы отказ «вход недоступен» приходил через Future, как
  /// любая сетевая ошибка, а не синхронным исключением у вызывающего.
  Future<CodeRequestResult> requestCode(String email) async {
    _requireLoginBases();
    return _loginApi.requestCode(email: email.trim(), language: _language());
  }

  /// Вход по коду. Если упадёт последующая синхронизация подписки, сессия
  /// уже сохранена и состояние ready — исключение относится только к импорту.
  Future<SubscriptionSyncResult> verifyCode(String email, String code) async {
    final bases = _requireLoginBases();
    final tokens = await _loginApi.verifyCode(
      email: email.trim(),
      code: code.trim(),
      language: _language(),
    );
    // Базы — до refresh-токена: токен без своего бэкенда restore() сотрёт.
    if (!await _store.writeApiBases(bases) ||
        !await _store.writeRefreshToken(tokens.refreshToken)) {
      throw const AccountApiException(
        AccountApiErrorKind.storage,
        message: 'session was not persisted',
      );
    }
    _sessionBases = bases;
    final accountEmail = tokens.email ?? email.trim();
    await _store.writeEmail(accountEmail);
    _refreshToken = tokens.refreshToken;
    _accessToken = tokens.accessToken;
    _emit(AccountState(
      status: AccountStatus.ready,
      email: accountEmail,
      biometricEnabled: await _store.readBiometricEnabled(),
      biometricAvailable: await _biometrics.isAvailable(),
    ));
    return syncSubscription();
  }

  Future<SubscriptionSyncResult> syncSubscription() async {
    _requireReady();
    final info = await _authed(_sessionApi.subscription);
    _emit(_state.copyWith(subscription: info));
    final rawUrl = info.url;
    if (rawUrl == null) return SubscriptionSyncResult.noSubscription;

    final url = normalizeProfileUrl(rawUrl);
    final existing =
        await _guardProfile(() => _profiles.findProfileIdByUrl(url));
    if (existing != null) {
      await _guardProfile(() => _profiles.selectProfile(existing));
      await _store.writeImportedUrl(url);
      _emit(_state.withProfileId(existing));
      return SubscriptionSyncResult.alreadyPresent;
    }
    await _guardProfile(() => _profiles.importProfile(url));
    // Поток импорта сам показывает ошибку и не бросает — проверяем результат.
    final imported =
        await _guardProfile(() => _profiles.findProfileIdByUrl(url));
    if (imported == null) {
      throw const AccountApiException(
        AccountApiErrorKind.profile,
        code: 'import_failed',
        message: 'subscription profile was not imported',
      );
    }
    await _store.writeImportedUrl(url);
    _emit(_state.withProfileId(imported));
    return SubscriptionSyncResult.imported;
  }

  Future<bool> unlock(String reason) async {
    if (_state.status != AccountStatus.locked) {
      return _state.status == AccountStatus.ready;
    }
    if (!await _biometrics.authenticate(reason)) return false;
    _emit(_state.copyWith(status: AccountStatus.ready));
    return true;
  }

  Future<bool> enableBiometric(String reason) async {
    _requireReady();
    if (!await _biometrics.isAvailable()) {
      _emit(_state.copyWith(biometricAvailable: false));
      throw const AccountApiException(
        AccountApiErrorKind.biometric,
        code: 'not_available',
      );
    }
    // Сначала подтверждение: нельзя включить замок, который владелец не откроет.
    if (!await _biometrics.authenticate(reason)) return false;
    if (!await _store.writeBiometricEnabled(enabled: true)) {
      throw const AccountApiException(AccountApiErrorKind.storage);
    }
    _emit(_state.copyWith(biometricEnabled: true, biometricAvailable: true));
    return true;
  }

  Future<void> disableBiometric() async {
    if (!await _store.writeBiometricEnabled(enabled: false)) {
      throw const AccountApiException(AccountApiErrorKind.storage);
    }
    _emit(_state.copyWith(biometricEnabled: false));
  }

  /// Кабинет своего профиля аккаунта сразу авторизованным. Токен выпускается
  /// только для кабинета профиля с подпиской этого аккаунта: кабинет другого
  /// провайдера не должен получить токен нашего бэкенда.
  Future<Uri> cabinetHandoffUri() async {
    _requireReady();
    final id = await _accountProfileId();
    final cabinet = id == null ? null : _profiles.cabinetUriOf(id);
    if (cabinet == null) {
      throw const AccountApiException(
        AccountApiErrorKind.notAvailable,
        code: 'no_cabinet',
        message: 'account profile has no cabinet',
      );
    }
    return _handoff(cabinet);
  }

  /// Кабинет профиля [profileId] для меню. Автовход — только если это
  /// профиль аккаунта и сессия открыта; иначе обычная ссылка, как без
  /// аккаунта. null — у профиля нет кабинета.
  Future<Uri?> cabinetUriFor(String? profileId) async {
    if (profileId == null) return null;
    final cabinet = _profiles.cabinetUriOf(profileId);
    if (cabinet == null) return null;
    if (_state.status != AccountStatus.ready) return cabinet;
    final String? own;
    try {
      own = await _accountProfileId();
    } on AccountApiException catch (e) {
      if (kDebugMode) debugPrint('[Account] profile lookup failed: $e');
      return cabinet;
    }
    if (own != profileId) return cabinet;
    return _handoff(cabinet);
  }

  /// Одноразовая ссылка `/auto-login` на origin кабинета. Если handoff на
  /// бэкенде нет или сеть упала — корень кабинета без токена.
  Future<Uri> _handoff(Uri cabinet) async {
    final origin = cabinet.origin;
    try {
      final handoff = await _authed(_sessionApi.appHandoff);
      return Uri.parse(
        '$origin/auto-login?token=${Uri.encodeQueryComponent(handoff.token)}',
      );
    } on AccountApiException catch (e) {
      if (e.kind == AccountApiErrorKind.notAvailable ||
          e.kind == AccountApiErrorKind.network) {
        if (kDebugMode) debugPrint('[Account] handoff fallback: ${e.kind}');
        return Uri.parse('$origin/');
      }
      rethrow;
    }
  }

  /// Удалить аккаунт только с этого устройства. На проде аккаунты удаляет
  /// лишь поддержка по запросу, поэтому сервер не трогаем сверх обычного
  /// выхода: с устройства уходят сессия, отпечаток и подписка этого
  /// аккаунта, остальные профили остаются.
  Future<void> removeFromDevice() async {
    // URL читаем до выхода: _wipe() стирает его вместе с сессией.
    final importedUrl = await _store.readImportedUrl();
    await logout();
    if (importedUrl != null && importedUrl.isNotEmpty) {
      final id =
          await _guardProfile(() => _profiles.findProfileIdByUrl(importedUrl));
      if (id != null) await _guardProfile(() => _profiles.deleteProfile(id));
    }
  }

  /// Выход: локальная очистка сразу, серверный logout — в фоне. Бэкенд
  /// может молчать (на Pixel 2026-10-11 кнопка ждала connectTimeout 15+ с),
  /// а сессия на устройстве от его ответа не зависит.
  /// VPN-профили остаются — подписка продолжает работать без аккаунта.
  Future<void> logout() async {
    String? refresh;
    var bases = const <String>[];
    try {
      refresh = _refreshToken ?? await _store.readRefreshToken();
      await _loadSessionBases();
      bases = _sessionBases;
    } on AccountApiException catch (e) {
      if (kDebugMode) debugPrint('[Account] logout: session read failed: $e');
    } finally {
      await _wipe();
    }
    // Без своего бэкенда серверный выход пропускаем: чужому не отправляем.
    if (refresh != null && refresh.isNotEmpty && bases.isNotEmpty) {
      unawaited(_serverLogout(bases, refresh));
    }
  }

  /// Отдельный клиент на базах ушедшей сессии: _wipe() их уже обнулил,
  /// а _sessionApi читает базы в момент запроса.
  Future<void> _serverLogout(List<String> bases, String refresh) async {
    try {
      await _api(() => bases).logout(refresh);
    } on Object catch (e) {
      // Никто не ждёт этот запрос — ошибка не должна уйти в зону как
      // необработанная.
      if (kDebugMode) debugPrint('[Account] server logout failed: $e');
    }
  }

  void _requireReady() {
    switch (_state.status) {
      case AccountStatus.ready:
        return;
      case AccountStatus.locked:
        throw const AccountApiException(
          AccountApiErrorKind.biometric,
          code: 'locked',
        );
      case AccountStatus.unknown:
      case AccountStatus.loggedOut:
        throw const AccountApiException(AccountApiErrorKind.unauthorized);
    }
  }

  /// Выход и refresh могут прийти раньше restore(): базы — из хранилища.
  Future<void> _loadSessionBases() async {
    if (_sessionBases.isEmpty) {
      _sessionBases = List.unmodifiable(await _store.readApiBases());
    }
  }

  Future<void> _wipe() async {
    _accessToken = null;
    _refreshToken = null;
    _sessionBases = const [];
    await _store.clear();
    _emit(AccountState(
      status: AccountStatus.loggedOut,
      biometricAvailable: _state.biometricAvailable,
    ));
  }

  Future<String> _refreshAccess() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<String> _doRefresh() async {
    final current = _refreshToken ?? await _store.readRefreshToken();
    if (current == null || current.isEmpty) {
      await _wipe();
      throw const AccountApiException(AccountApiErrorKind.unauthorized);
    }
    await _loadSessionBases();
    final AccountTokens tokens;
    try {
      tokens = await _sessionApi.refresh(current);
    } on AccountApiException catch (e) {
      if (e.kind == AccountApiErrorKind.unauthorized) await _wipe();
      rethrow;
    }
    // Новый refresh фиксируем до того, как access попадёт к вызывающим.
    _refreshToken = tokens.refreshToken;
    if (!await _store.writeRefreshToken(tokens.refreshToken) && kDebugMode) {
      debugPrint('[Account] rotated refresh token was not persisted');
    }
    _accessToken = tokens.accessToken;
    return tokens.accessToken;
  }

  /// Вызов с Bearer: на 401 — один общий refresh и один повтор.
  Future<T> _authed<T>(Future<T> Function(String access) call) async {
    final access = _accessToken ?? await _refreshAccess();
    try {
      return await call(access);
    } on AccountApiException catch (e) {
      if (e.kind != AccountApiErrorKind.unauthorized) rethrow;
      // Если параллельный вызов уже обновил токен — второй refresh не нужен.
      final current = _accessToken;
      final fresh = current != null && current != access
          ? current
          : await _refreshAccess();
      return call(fresh);
    }
  }

  Future<T> _guardProfile<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AccountApiException {
      rethrow;
    } catch (e) {
      throw AccountApiException(
        AccountApiErrorKind.profile,
        message: e.toString(),
      );
    }
  }
}
