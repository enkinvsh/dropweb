import 'dart:async';
import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/providers/state.dart';
import 'package:dropweb/services/account/account_api.dart';
import 'package:dropweb/services/account/account_biometrics.dart';
import 'package:dropweb/services/account/account_controller.dart';
import 'package:dropweb/services/account/account_models.dart';
import 'package:dropweb/services/account/account_profiles.dart';
import 'package:dropweb/services/account/account_state.dart';
import 'package:dropweb/services/account/account_store.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:dropweb/services/account/account_api_exception.dart';
export 'package:dropweb/services/account/account_models.dart';
export 'package:dropweb/services/account/account_state.dart';

part 'generated/account.g.dart';

/// Аккаунт есть только в сборках вне магазинов. В Google Play и на iOS
/// ([System.isStoreBuild]) приложение остаётся чистым клиентом, как
/// RabbitHole: вход по почте создаёт аккаунт, а это тянет удаление в
/// приложении, демо-доступ для ревью и другую декларацию данных. Провайдером —
/// чтобы тесты подменяли тип сборки.
@riverpod
bool accountFeatureEnabled(Ref ref) => !system.isStoreBuild;

/// Бэкенд аккаунта по умолчанию из `--dart-define=DROPWEB_ACCOUNT_API`.
/// Провайдером, а не константой — чтобы тесты подменяли дефолт сборки.
@riverpod
List<String> accountDefaultApiBases(Ref ref) =>
    parseAccountApiBases(kAccountApiDefault);

/// Где можно войти по почте. Есть хоть один профиль — только бэкенд,
/// объявленный текущим профилем (`dropweb-account`); без заголовка вход
/// недоступен, даже если у сборки есть дефолт: иначе почта пользователя
/// чужого провайдера ушла бы на бэкенд издателя. Профилей нет — дефолт
/// сборки (пусто в общих сборках).
List<String> resolveAccountLoginBases({
  required List<Profile> profiles,
  required Profile? current,
  required List<String> defaults,
}) {
  if (profiles.isNotEmpty) return profileAccountApiBases(current);
  return defaults;
}

@riverpod
List<String> accountLoginBases(Ref ref) => resolveAccountLoginBases(
      profiles: ref.watch(profilesProvider),
      current: ref.watch(currentProfileProvider),
      defaults: ref.watch(accountDefaultApiBasesProvider),
    );

@riverpod
bool accountLoginAvailable(Ref ref) =>
    ref.watch(accountFeatureEnabledProvider) &&
    ref.watch(accountLoginBasesProvider).isNotEmpty;

/// Профиль с подпиской аккаунта — только его кабинет открывается с
/// автовходом. null — нет сессии или профиль не найден.
@riverpod
Profile? accountProfile(Ref ref) {
  final id = ref.watch(accountProvider.select((state) => state.profileId));
  if (id == null) return null;
  return ref.watch(profilesProvider.select((state) => state.getProfile(id)));
}

/// Аккаунт кабинета внутри приложения: вход по коду с почты, сессия,
/// биометрический замок, импорт подписки, удаление аккаунта.
///
/// Все методы бросают AccountApiException; UI сам решает, что показать.
/// keepAlive: сессия и общий refresh в полёте должны жить весь процесс.
@Riverpod(keepAlive: true)
class Account extends _$Account {
  AccountController? _controller;

  AccountController get _account => _controller ??= AccountController(
        api: (bases) => AccountApi(
          baseUrls: bases,
          userAgent: () => globalState.ua,
        ),
        store: AccountStore.instance,
        biometrics: LocalAccountBiometrics(),
        profiles: _RiverpodAccountProfiles(ref),
        language: _language,
        loginBases: () => ref.read(accountLoginBasesProvider),
        defaultBases: () => ref.read(accountDefaultApiBasesProvider),
        // Источники новых зеркал сессии: заголовок каждого профиля, а не
        // только текущего, — подписка аккаунта может быть не выбрана.
        knownBases: () => [
          for (final profile in ref.read(profilesProvider))
            profileAccountApiBases(profile),
          ref.read(accountDefaultApiBasesProvider),
        ],
        onState: (next) => state = next,
      );

  @override
  AccountState build() {
    // Профиль аккаунта ищется по URL подписки: после добавления, удаления
    // или правки профилей его id мог смениться.
    ref.listen(profilesProvider, (_, __) {
      if (_controller != null) unawaited(_account.refreshProfileId());
    });
    return const AccountState();
  }

  String _language() {
    final locale = ref.read(appSettingProvider).locale ?? Platform.localeName;
    final code = locale.split(RegExp('[_-]')).first.toLowerCase();
    return RegExp(r'^[a-z]{2}$').hasMatch(code) ? code : 'ru';
  }

  /// Один раз при старте приложения; не блокирует запуск и VPN.
  Future<void> restore() async {
    // Магазинная сборка не трогает ни хранилище сессии, ни сеть; статус
    // остаётся unknown, и без входа пункты аккаунта не показываются.
    if (!ref.read(accountFeatureEnabledProvider)) return;
    await _account.restore();
  }

  Future<CodeRequestResult> requestCode(String email) =>
      _account.requestCode(email);

  Future<SubscriptionSyncResult> verifyCode(String email, String code) =>
      _account.verifyCode(email, code);

  Future<SubscriptionSyncResult> syncSubscription() =>
      _account.syncSubscription();

  /// Тихая починка адреса подписки профиля аккаунта; false — нечего чинить
  /// или нельзя (нет сессии, замок, пауза между попытками, сбой сети).
  Future<bool> repairSubscription() async {
    if (!ref.read(accountFeatureEnabledProvider)) return false;
    return _account.repairSubscription();
  }

  /// Зовёт AppController.updateProfile, когда загрузка профиля упала.
  /// Магазинная сборка и процесс без restore() — no-op: сессии там нет, и
  /// хранилище аккаунта трогать незачем.
  Future<void> onProfileUpdateFailed(String profileId) async {
    if (!ref.read(accountFeatureEnabledProvider)) return;
    final controller = _controller;
    if (controller == null) return;
    await controller.onProfileUpdateFailed(profileId);
  }

  /// [reason] — локализованный текст системного диалога, передаёт UI.
  Future<bool> unlock(String reason) => _account.unlock(reason);

  Future<bool> enableBiometric(String reason) =>
      _account.enableBiometric(reason);

  Future<void> disableBiometric() => _account.disableBiometric();

  Future<Uri> cabinetHandoffUri() => _account.cabinetHandoffUri();

  /// Кабинет профиля [profileId]: автовход только для профиля аккаунта.
  Future<Uri?> cabinetUriFor(String? profileId) =>
      _account.cabinetUriFor(profileId);

  Future<void> removeFromDevice() => _account.removeFromDevice();

  Future<void> logout() => _account.logout();
}

/// Профили через существующие потоки: импорт — тот же addProfileFormURL, что
/// при ручном добавлении (заголовки, HWID, транзакция), удаление — тот же
/// deleteProfile, что в списке профилей.
class _RiverpodAccountProfiles implements AccountProfiles {
  _RiverpodAccountProfiles(this._ref);

  final Ref _ref;

  @override
  Future<String?> findProfileIdByUrl(String url) async {
    final target = normalizeProfileUrl(url);
    for (final profile in _ref.read(profilesProvider)) {
      // У мигрированных профилей url в памяти пустой — реальный лежит в KeyStore.
      final stored = await preferences.getProfileUrl(profile);
      if (stored != null && normalizeProfileUrl(stored) == target) {
        return profile.id;
      }
    }
    return null;
  }

  @override
  Uri? cabinetUriOf(String id) =>
      profileCabinetUri(_ref.read(profilesProvider).getProfile(id));

  @override
  Future<void> selectProfile(String id) async {
    _ref.read(currentProfileIdProvider.notifier).value = id;
  }

  @override
  Future<void> importProfile(String url) =>
      globalState.appController.addProfileFormURL(url);

  @override
  Future<void> deleteProfile(String id) =>
      globalState.appController.deleteProfile(id);

  @override
  Future<void> repointProfile(String profileId, String url) =>
      globalState.appController.repointProfileUrl(profileId, url);
}
