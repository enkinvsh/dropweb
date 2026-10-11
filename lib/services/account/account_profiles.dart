export 'package:dropweb/common/subscription_resilience.dart'
    show normalizeProfileUrl;

/// Узкий доступ контроллера аккаунта к VPN-профилям: только то, что нужно для
/// импорта подписки и удаления её профиля. Продакшен-реализация живёт рядом с
/// провайдером и ходит в существующие потоки AppController.
abstract interface class AccountProfiles {
  /// id профиля с тем же (нормализованным) URL подписки, если он есть.
  Future<String?> findProfileIdByUrl(String url);

  /// Кабинет из заголовка `dropweb-cabinet` профиля [id]; null — профиля нет
  /// или кабинет не объявлен.
  Uri? cabinetUriOf(String id);

  Future<void> selectProfile(String id);

  /// Импорт тем же путём, что ручное добавление по URL. Может не бросать при
  /// ошибке (ошибку показывает сам поток импорта) — контроллер проверяет
  /// результат повторным [findProfileIdByUrl].
  Future<void> importProfile(String url);

  Future<void> deleteProfile(String id);

  /// Перевести существующий профиль [profileId] на новый адрес подписки
  /// [url] и обновить его — тот же профиль, без дубля. Бросает, если профиля
  /// нет, адрес негоден или обновление по новому адресу не удалось (адрес в
  /// последнем случае уже сменён).
  Future<void> repointProfile(String profileId, String url);
}
