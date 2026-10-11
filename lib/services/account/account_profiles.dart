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
}

/// Та же нормализация, что делает `addProfileFormURL`, чтобы сравнение по URL
/// совпадало с тем, что реально сохранено в профиле.
String normalizeProfileUrl(String url) {
  final trimmed = url.trim();
  return Uri.tryParse(trimmed)?.toString() ?? trimmed;
}
