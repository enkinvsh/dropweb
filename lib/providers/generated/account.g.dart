// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../account.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$accountFeatureEnabledHash() =>
    r'56b3266d60235f6b70b0110a8c52f8766443ee4b';

/// Аккаунт есть только в сборках вне магазинов. В Google Play (а с iOS — и
/// в App Store) приложение остаётся чистым клиентом, как RabbitHole: вход по
/// почте создаёт аккаунт, а это тянет удаление в приложении, демо-доступ для
/// ревью и другую декларацию данных. Провайдером — чтобы тесты подменяли тип
/// сборки.
///
/// Copied from [accountFeatureEnabled].
@ProviderFor(accountFeatureEnabled)
final accountFeatureEnabledProvider = AutoDisposeProvider<bool>.internal(
  accountFeatureEnabled,
  name: r'accountFeatureEnabledProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$accountFeatureEnabledHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AccountFeatureEnabledRef = AutoDisposeProviderRef<bool>;
String _$accountDefaultApiBasesHash() =>
    r'a43ecd99fcc8045834c117baa63de386ec019b85';

/// Бэкенд аккаунта по умолчанию из `--dart-define=DROPWEB_ACCOUNT_API`.
/// Провайдером, а не константой — чтобы тесты подменяли дефолт сборки.
///
/// Copied from [accountDefaultApiBases].
@ProviderFor(accountDefaultApiBases)
final accountDefaultApiBasesProvider =
    AutoDisposeProvider<List<String>>.internal(
  accountDefaultApiBases,
  name: r'accountDefaultApiBasesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$accountDefaultApiBasesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AccountDefaultApiBasesRef = AutoDisposeProviderRef<List<String>>;
String _$accountLoginBasesHash() => r'3617e57b894463f37a1bd73d3da3ad78d59b994e';

/// See also [accountLoginBases].
@ProviderFor(accountLoginBases)
final accountLoginBasesProvider = AutoDisposeProvider<List<String>>.internal(
  accountLoginBases,
  name: r'accountLoginBasesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$accountLoginBasesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AccountLoginBasesRef = AutoDisposeProviderRef<List<String>>;
String _$accountLoginAvailableHash() =>
    r'5d0ea251ec25d6e6cb77d0afb9f83cfec01c5499';

/// See also [accountLoginAvailable].
@ProviderFor(accountLoginAvailable)
final accountLoginAvailableProvider = AutoDisposeProvider<bool>.internal(
  accountLoginAvailable,
  name: r'accountLoginAvailableProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$accountLoginAvailableHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AccountLoginAvailableRef = AutoDisposeProviderRef<bool>;
String _$accountProfileHash() => r'5337407d937f4b92312f5bc09f171a40129f3632';

/// Профиль с подпиской аккаунта — только его кабинет открывается с
/// автовходом. null — нет сессии или профиль не найден.
///
/// Copied from [accountProfile].
@ProviderFor(accountProfile)
final accountProfileProvider = AutoDisposeProvider<Profile?>.internal(
  accountProfile,
  name: r'accountProfileProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$accountProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AccountProfileRef = AutoDisposeProviderRef<Profile?>;
String _$accountHash() => r'aebb76ca1cd78a0e29b94d8017b8e8ee071b9cd9';

/// Аккаунт кабинета внутри приложения: вход по коду с почты, сессия,
/// биометрический замок, импорт подписки, удаление аккаунта.
///
/// Все методы бросают AccountApiException; UI сам решает, что показать.
/// keepAlive: сессия и общий refresh в полёте должны жить весь процесс.
///
/// Copied from [Account].
@ProviderFor(Account)
final accountProvider = NotifierProvider<Account, AccountState>.internal(
  Account.new,
  name: r'accountProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$accountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Account = Notifier<AccountState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
