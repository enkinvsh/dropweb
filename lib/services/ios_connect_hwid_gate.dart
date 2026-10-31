import 'package:dropweb/models/profile.dart';
import 'package:dropweb/services/hwid_recovery.dart';

/// Чем закончилась проверка перед подключением.
enum IosHwidGateOutcome {
  /// Подключаться можно: проверка не нужна или подписку заново скачали без лимита.
  proceed,

  /// Панель отказала по лимиту устройств. Пользователя уже предупредил
  /// контроллер (диалог/тост), подключаться нельзя.
  limited,

  /// Подписку скачивали с другим HWID, а проверить заново не вышло: это
  /// заведомо другое устройство (копия приложения с чужого телефона).
  unverified,
}

class IosHwidGateResult {
  const IosHwidGateResult(this.outcome, {this.error});

  final IosHwidGateOutcome outcome;

  /// Причина сбоя обновления для [IosHwidGateOutcome.unverified].
  final Object? error;
}

/// Проверка HWID перед подключением на iOS.
///
/// Зачем. Профили лежат в App Group и в конфиге приложения, а те уезжают на
/// другой телефон вместе с резервной копией. Новый телефон получает рабочую
/// подписку, ни разу не спросив панель про свой HWID, и подключается мимо
/// лимита устройств. Профиль помнит HWID, с которым его скачали
/// ([Profile.fetchedHwid]); если он не совпал с текущим, перед запуском туннеля
/// подписку скачивают заново, и панель решает по настоящему HWID.
///
/// Всё, что не относится к подписке по ссылке или к отправке HWID, пропускается:
/// гейт никогда не мешает подключению без причины. Значения HWID и ссылки в
/// журнал не пишутся.
class IosConnectHwidGate {
  const IosConnectHwidGate({
    required this.sendDeviceHeaders,
    required this.currentProfile,
    required this.resolveUrl,
    required this.currentHwid,
    required this.refresh,
    required this.log,
  });

  /// Настройка «отправлять заголовки устройства». Выключена — панель HWID не
  /// получает, сверять нечего.
  final Future<bool> Function() sendDeviceHeaders;
  final Profile? Function() currentProfile;

  /// Ссылка подписки профиля (в защищённом хранилище); пусто — не подписка.
  final Future<String?> Function(Profile profile) resolveUrl;
  final Future<String?> Function() currentHwid;

  /// Скачивание подписки по запросу пользователя
  /// (`AppController.updateProfileByUser`).
  final Future<HwidVerdict> Function(Profile profile) refresh;
  final void Function(String message) log;

  Future<IosHwidGateResult> run() async {
    const proceed = IosHwidGateResult(IosHwidGateOutcome.proceed);

    final Profile profile;
    final String hwid;
    try {
      if (!await sendDeviceHeaders()) return proceed;
      final current = currentProfile();
      if (current == null) return proceed;
      final url = await resolveUrl(current);
      if (url == null || url.isEmpty) return proceed;
      final currentId = await currentHwid();
      if (currentId == null || currentId.isEmpty) return proceed;
      profile = current;
      hwid = currentId;
    } catch (e) {
      // Локальный сбой (хранилище, Keychain) не повод отказывать в
      // подключении: панель всё равно решит по HWID при следующей загрузке.
      log('[hwid] connect gate skipped: ${e.runtimeType}');
      return proceed;
    }

    final fetched = profile.fetchedHwid;
    if (fetched != null && fetched == hwid) return proceed;

    log('[hwid] connect gate: refreshing subscription '
        '(${fetched == null ? 'never verified' : 'other device'})');
    try {
      final verdict = await refresh(profile);
      return verdict == HwidVerdict.limited
          ? const IosHwidGateResult(IosHwidGateOutcome.limited)
          : proceed;
    } catch (e) {
      if (fetched == null) {
        // Профиль старой версии, HWID с которым его скачивали, неизвестен: нет
        // сети — не наказываем честного пользователя, подключаем как раньше.
        log('[hwid] connect gate: refresh failed (${e.runtimeType}), '
            'legacy profile, connecting');
        return proceed;
      }
      log('[hwid] connect gate: refresh failed (${e.runtimeType}), '
          'profile belongs to another device, not connecting');
      return IosHwidGateResult(IosHwidGateOutcome.unverified, error: e);
    }
  }
}
