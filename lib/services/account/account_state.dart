import 'package:dropweb/services/account/account_models.dart';

enum AccountStatus {
  /// restore() ещё не отработал — UI не должен показывать ни вход, ни аккаунт.
  unknown,
  loggedOut,

  /// Сессия есть, но включена биометрия и её ещё не подтвердили.
  locked,
  ready,
}

class AccountState {
  const AccountState({
    this.status = AccountStatus.unknown,
    this.email,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
    this.subscription,
    this.profileId,
  });

  final AccountStatus status;
  final String? email;
  final bool biometricEnabled;
  final bool biometricAvailable;

  /// Последняя полученная сводка подписки; null — ещё не запрашивали.
  final AccountSubscription? subscription;

  /// id VPN-профиля с подпиской этого аккаунта (его URL совпадает с
  /// импортированным). Только его кабинет получает handoff-токен; null —
  /// профиль не найден или подписки нет.
  final String? profileId;

  /// copyWith не умеет обнулять поле, а профиль аккаунта может исчезнуть.
  AccountState withProfileId(String? id) => AccountState(
        status: status,
        email: email,
        biometricEnabled: biometricEnabled,
        biometricAvailable: biometricAvailable,
        subscription: subscription,
        profileId: id,
      );

  AccountState copyWith({
    AccountStatus? status,
    String? email,
    bool? biometricEnabled,
    bool? biometricAvailable,
    AccountSubscription? subscription,
  }) =>
      AccountState(
        status: status ?? this.status,
        email: email ?? this.email,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        biometricAvailable: biometricAvailable ?? this.biometricAvailable,
        subscription: subscription ?? this.subscription,
        profileId: profileId,
      );

  @override
  bool operator ==(Object other) =>
      other is AccountState &&
      other.status == status &&
      other.email == email &&
      other.biometricEnabled == biometricEnabled &&
      other.biometricAvailable == biometricAvailable &&
      other.subscription == subscription &&
      other.profileId == profileId;

  @override
  int get hashCode => Object.hash(status, email, biometricEnabled,
      biometricAvailable, subscription, profileId);

  @override
  String toString() =>
      'AccountState(${status.name}, biometric: $biometricEnabled/$biometricAvailable, '
      'subscription: ${subscription != null})';
}
