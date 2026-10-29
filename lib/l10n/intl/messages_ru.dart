// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ru locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'ru';

  static String m0(wait) => "Слишком часто, подождите ${wait}";

  static String m1(n) => "${n} ч";

  static String m2(n) => "${n} мин";

  static String m3(n) => "${n} с";

  static String m4(host) => "Добавить ${host}";

  static String m5(label) => "Вы уверены, что хотите удалить текущий ${label}?";

  static String m6(path) => "Диагностика: ${path}";

  static String m7(label) => "${label} не может быть пустым";

  static String m8(label) => "Текущий ${label} уже существует";

  static String m9(version) => "Доступна версия ${version}";

  static String m10(version, core) => "Версия ${version}, ядро ${core}";

  static String m11(n) => "Цвет ${n}";

  static String m12(n) => "Оттенок ${n}";

  static String m13(name) => "Удалить «${name}»?";

  static String m14(count) =>
      "${Intl.plural(count, one: 'Остался ${count} день', few: 'Осталось ${count} дня', many: 'Осталось ${count} дней', other: 'Осталось ${count} дня')}";

  static String m15(traffic, term) => "${traffic} · ${term}";

  static String m16(left) => "Осталось ${left} ГБ";

  static String m17(used, total) => "${used} из ${total} ГБ";

  static String m18(date) => "до ${date}";

  static String m19(count) =>
      "${Intl.plural(count, one: '${count} группа', few: '${count} группы', many: '${count} групп', other: '${count} группы')}";

  static String m20(version) => "Версия ${version}";

  static String m21(percent) => "Загрузка… ${percent}%";

  static String m22(version) => "dropweb ${version}";

  static String m23(count) =>
      "${Intl.plural(count, one: 'Обновлено ${count} день назад', few: 'Обновлено ${count} дня назад', many: 'Обновлено ${count} дней назад', other: 'Обновлено ${count} дня назад')}";

  static String m24(count) =>
      "${Intl.plural(count, one: 'Обновлено ${count} час назад', few: 'Обновлено ${count} часа назад', many: 'Обновлено ${count} часов назад', other: 'Обновлено ${count} часа назад')}";

  static String m25(count) =>
      "${Intl.plural(count, one: 'Обновлено ${count} минуту назад', few: 'Обновлено ${count} минуты назад', many: 'Обновлено ${count} минут назад', other: 'Обновлено ${count} минуты назад')}";

  static String m26(value) => "${value} ГБ";

  static String m27(value) => "${value} мс";

  static String m28(label) => "${label} должно быть числом";

  static String m29(label) => "${label} должен быть числом от 1024 до 49151";

  static String m30(count) => "Выбрано ${count} элементов";

  static String m31(days) => "Ваша подписка истекает через ${days} дн.";

  static String m32(label) => "${label} должен быть URL";

  static String m33(date) => "до ${date}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("О программе"),
    "accessControl": MessageLookupByLibrary.simpleMessage("Контроль доступа"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Только выбранные приложения будут использовать VPN",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Выбранные приложения не будут использовать VPN",
    ),
    "account": MessageLookupByLibrary.simpleMessage("Аккаунт"),
    "accountBiometricEnable": MessageLookupByLibrary.simpleMessage("Включить"),
    "accountBiometricEnableReason": MessageLookupByLibrary.simpleMessage(
      "Подтвердите, чтобы входить по отпечатку",
    ),
    "accountBiometricOfferText": MessageLookupByLibrary.simpleMessage(
      "Аккаунт будет открываться по отпечатку.",
    ),
    "accountBiometricOfferTitle": MessageLookupByLibrary.simpleMessage(
      "Входить по отпечатку?",
    ),
    "accountBiometricSwitch": MessageLookupByLibrary.simpleMessage(
      "Вход по отпечатку",
    ),
    "accountBiometricUnlockReason": MessageLookupByLibrary.simpleMessage(
      "Подтвердите вход в аккаунт",
    ),
    "accountChangeEmail": MessageLookupByLibrary.simpleMessage(
      "Изменить почту",
    ),
    "accountCodeLabel": MessageLookupByLibrary.simpleMessage("Код"),
    "accountEmailInvalid": MessageLookupByLibrary.simpleMessage(
      "Проверьте адрес почты",
    ),
    "accountEmailLabel": MessageLookupByLibrary.simpleMessage("Почта"),
    "accountErrorCodeExpired": MessageLookupByLibrary.simpleMessage(
      "Код истёк — запросите новый",
    ),
    "accountErrorDisabled": MessageLookupByLibrary.simpleMessage(
      "Вход временно недоступен",
    ),
    "accountErrorEmailRejected": MessageLookupByLibrary.simpleMessage(
      "Почта не подходит",
    ),
    "accountErrorGeneric": MessageLookupByLibrary.simpleMessage(
      "Не получилось",
    ),
    "accountErrorInvalidCode": MessageLookupByLibrary.simpleMessage(
      "Неверный код",
    ),
    "accountErrorNetwork": MessageLookupByLibrary.simpleMessage(
      "Нет связи с сервером",
    ),
    "accountErrorRateLimited": m0,
    "accountErrorRateLimitedLater": MessageLookupByLibrary.simpleMessage(
      "Слишком часто, попробуйте позже",
    ),
    "accountGetCode": MessageLookupByLibrary.simpleMessage("Получить код"),
    "accountLoggedOut": MessageLookupByLibrary.simpleMessage("Вы вышли"),
    "accountLoginByEmail": MessageLookupByLibrary.simpleMessage(
      "Войти по почте",
    ),
    "accountLogout": MessageLookupByLibrary.simpleMessage("Выйти"),
    "accountNoSubscription": MessageLookupByLibrary.simpleMessage(
      "Вы вошли, подписки пока нет",
    ),
    "accountRemoveFromDevice": MessageLookupByLibrary.simpleMessage(
      "Удалить с устройства",
    ),
    "accountRemoveFromDeviceText": MessageLookupByLibrary.simpleMessage(
      "Аккаунт и его подписка исчезнут с устройства. Войти снова можно по почте.",
    ),
    "accountRemoveFromDeviceTitle": MessageLookupByLibrary.simpleMessage(
      "Удалить с устройства?",
    ),
    "accountRemovedFromDevice": MessageLookupByLibrary.simpleMessage(
      "Удалено с устройства",
    ),
    "accountResend": MessageLookupByLibrary.simpleMessage("Отправить ещё раз"),
    "accountSignInWithCode": MessageLookupByLibrary.simpleMessage(
      "Войти по коду",
    ),
    "accountSubscriptionAlreadyPresent": MessageLookupByLibrary.simpleMessage(
      "Подписка уже в приложении",
    ),
    "accountSubscriptionImported": MessageLookupByLibrary.simpleMessage(
      "Подписка подключена",
    ),
    "accountSyncFailed": MessageLookupByLibrary.simpleMessage(
      "Вы вошли, подписка не подключилась",
    ),
    "accountSyncSubscription": MessageLookupByLibrary.simpleMessage(
      "Обновить подписку",
    ),
    "accountUnlock": MessageLookupByLibrary.simpleMessage("Разблокировать"),
    "accountWaitHours": m1,
    "accountWaitMinutes": m2,
    "accountWaitSeconds": m3,
    "action": MessageLookupByLibrary.simpleMessage("Действие"),
    "add": MessageLookupByLibrary.simpleMessage("Добавить"),
    "addFromPhoneSubtitle": MessageLookupByLibrary.simpleMessage(
      "Сканировать QR-код телефоном",
    ),
    "addFromPhoneTitle": MessageLookupByLibrary.simpleMessage(
      "Добавить с телефона",
    ),
    "addNamedSubscription": m4,
    "addProfile": MessageLookupByLibrary.simpleMessage("Добавить профиль"),
    "addRule": MessageLookupByLibrary.simpleMessage("Добавить правило"),
    "addSubscription": MessageLookupByLibrary.simpleMessage(
      "Добавить подписку",
    ),
    "address": MessageLookupByLibrary.simpleMessage("Адрес"),
    "ago": MessageLookupByLibrary.simpleMessage(" назад"),
    "agree": MessageLookupByLibrary.simpleMessage("Согласен"),
    "allowBypass": MessageLookupByLibrary.simpleMessage("Разрешить обход VPN"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "Некоторые приложения смогут обходить VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("Разрешить LAN"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить доступ к прокси из локальной сети",
    ),
    "alwaysOnVpn": MessageLookupByLibrary.simpleMessage("Всегда включен"),
    "alwaysOnVpnOpenFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось открыть настройки VPN",
    ),
    "app": MessageLookupByLibrary.simpleMessage("Приложение"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "Контроль доступа приложений",
    ),
    "application": MessageLookupByLibrary.simpleMessage("Настройки приложения"),
    "auto": MessageLookupByLibrary.simpleMessage("Авто"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Автопроверка обновлений",
    ),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "Проверять обновления при запуске",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Автозакрытие соединений",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматически закрывать соединения при смене сервера",
    ),
    "autoFollowAccent": MessageLookupByLibrary.simpleMessage(
      "Авто (по акценту)",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Автозапуск приложения"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Запускать вместе с системой",
    ),
    "autoRun": MessageLookupByLibrary.simpleMessage("Автозапуск прокси"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматически запускать прокси при открытии приложения",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Автоматическая настройка системного DNS",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("Автообновление"),
    "backgroundOrbs": MessageLookupByLibrary.simpleMessage("Орбы фона"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("Конфигурация ядра"),
    "bind": MessageLookupByLibrary.simpleMessage("Привязать"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage(
      "Режим черного списка",
    ),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Обход домена"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Действует только при включенном системном прокси",
    ),
    "cabinet": MessageLookupByLibrary.simpleMessage("Кабинет"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "Кэш повреждён. Очистить его?",
    ),
    "cameraPermissionDenied": MessageLookupByLibrary.simpleMessage(
      "Доступ к камере запрещён",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Отмена"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage(
      "Отменить выбор всего",
    ),
    "changeServer": MessageLookupByLibrary.simpleMessage("Изменить сервер"),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("Проверить обновления"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "Текущее приложение уже является последней версией",
    ),
    "checkUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось проверить обновления. Проверьте интернет и попробуйте ещё раз",
    ),
    "checking": MessageLookupByLibrary.simpleMessage("Проверка..."),
    "clearData": MessageLookupByLibrary.simpleMessage("Очистить данные"),
    "clearDataTip": MessageLookupByLibrary.simpleMessage(
      "Это удалит все данные приложения и перезапустит его. Вы уверены?",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage(
      "Экспорт в буфер обмена",
    ),
    "clipboardImport": MessageLookupByLibrary.simpleMessage(
      "Импорт из буфера обмена",
    ),
    "close": MessageLookupByLibrary.simpleMessage("Закрыть"),
    "color": MessageLookupByLibrary.simpleMessage("Цвет"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("Цветовые схемы"),
    "columns": MessageLookupByLibrary.simpleMessage("Столбцы"),
    "compatible": MessageLookupByLibrary.simpleMessage("Режим совместимости"),
    "confirm": MessageLookupByLibrary.simpleMessage("Подтвердить"),
    "connections": MessageLookupByLibrary.simpleMessage("Соединения"),
    "connectivity": MessageLookupByLibrary.simpleMessage("Связь："),
    "content": MessageLookupByLibrary.simpleMessage("Содержание"),
    "copy": MessageLookupByLibrary.simpleMessage("Копировать"),
    "copyLogs": MessageLookupByLibrary.simpleMessage("Скопировать логи"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Копирование успешно"),
    "core": MessageLookupByLibrary.simpleMessage("Ядро"),
    "country": MessageLookupByLibrary.simpleMessage("Страна"),
    "crashTest": MessageLookupByLibrary.simpleMessage("Тест на сбои"),
    "create": MessageLookupByLibrary.simpleMessage("Создать"),
    "cut": MessageLookupByLibrary.simpleMessage("Вырезать"),
    "dark": MessageLookupByLibrary.simpleMessage("Темный"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Главная"),
    "dashboardEmptyHint": MessageLookupByLibrary.simpleMessage(
      "Вставьте ссылку или отсканируйте QR-код",
    ),
    "dashboardEmptyTitle": MessageLookupByLibrary.simpleMessage(
      "Добавьте подписку",
    ),
    "day": MessageLookupByLibrary.simpleMessage("день"),
    "days": MessageLookupByLibrary.simpleMessage("дней"),
    "daysGenitive": MessageLookupByLibrary.simpleMessage("дня"),
    "defaultNameserver": MessageLookupByLibrary.simpleMessage(
      "Сервер имен по умолчанию",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Для разрешения DNS-сервера",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("По умолчанию"),
    "delay": MessageLookupByLibrary.simpleMessage("Задержка"),
    "delete": MessageLookupByLibrary.simpleMessage("Удалить"),
    "deleteTip": m5,
    "desc": MessageLookupByLibrary.simpleMessage(
      "dropweb — простой и быстрый VPN-клиент с открытым исходным кодом, без рекламы.",
    ),
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Использует сторонний API. Только для справки",
    ),
    "devAdbRemote": MessageLookupByLibrary.simpleMessage("adb-пульт"),
    "devAdbRemoteReplies": MessageLookupByLibrary.simpleMessage(
      "Ответы: adb logcat -s dropweb-dbg",
    ),
    "devCopyAll": MessageLookupByLibrary.simpleMessage("Копировать всё"),
    "devDiagnostics": MessageLookupByLibrary.simpleMessage("Диагностика"),
    "devDiagnosticsWritten": m6,
    "devEffectiveConfig": MessageLookupByLibrary.simpleMessage(
      "Итоговый конфиг",
    ),
    "devEffectiveConfigEmpty": MessageLookupByLibrary.simpleMessage(
      "Ядро ещё не запускалось — конфига пока нет",
    ),
    "devSubscriptionHeaders": MessageLookupByLibrary.simpleMessage(
      "Заголовки подписки",
    ),
    "devTakeDiagnostics": MessageLookupByLibrary.simpleMessage(
      "Снять диагностику",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Режим разработчика"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Режим разработчика активирован.",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("Прямой"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage("Новая версия"),
    "discovery": MessageLookupByLibrary.simpleMessage(
      "Обнаружена новая версия",
    ),
    "dnsDesc": MessageLookupByLibrary.simpleMessage(
      "Обновление настроек, связанных с DNS",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("Режим DNS"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage(
      "Добавляем профиль по адресу",
    ),
    "domain": MessageLookupByLibrary.simpleMessage("Домен"),
    "download": MessageLookupByLibrary.simpleMessage("Загрузка"),
    "edit": MessageLookupByLibrary.simpleMessage("Редактировать"),
    "emptyTip": m7,
    "en": MessageLookupByLibrary.simpleMessage("Английский"),
    "entries": MessageLookupByLibrary.simpleMessage(" записей"),
    "errorTitle": MessageLookupByLibrary.simpleMessage("Ошибка"),
    "exclude": MessageLookupByLibrary.simpleMessage("Скрыть из списка задач"),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "Скрывать приложение из списка последних задач в фоновом режиме",
    ),
    "existsTip": m8,
    "exit": MessageLookupByLibrary.simpleMessage("Выход"),
    "expand": MessageLookupByLibrary.simpleMessage("Стандартный"),
    "expiresOn": MessageLookupByLibrary.simpleMessage("Истекает"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Экспорт логов"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "Внешний контроллер",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Включить управление службой VPN через API на порту 9090",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("Внешняя ссылка"),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Фильтр Fakeip"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Диапазон Fakeip"),
    "fallback": MessageLookupByLibrary.simpleMessage("Резервный"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Обычно используется оффшорный DNS",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage(
      "Фильтр резервного DNS",
    ),
    "file": MessageLookupByLibrary.simpleMessage("Файл"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage(
      "Режим поиска процесса",
    ),
    "fontFamily": MessageLookupByLibrary.simpleMessage("Семейство шрифтов"),
    "fullTunnelTitle": MessageLookupByLibrary.simpleMessage(
      "Весь трафик через VPN",
    ),
    "general": MessageLookupByLibrary.simpleMessage("Общие"),
    "generalDesc": MessageLookupByLibrary.simpleMessage(
      "Изменение общих настроек",
    ),
    "genericErrorMessage": MessageLookupByLibrary.simpleMessage(
      "Что-то пошло не так. Попробуйте ещё раз.",
    ),
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Экономия памяти для геоданных",
    ),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать режим загрузки геоданных с низким потреблением памяти",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("Код Geoip"),
    "global": MessageLookupByLibrary.simpleMessage("Глобальный"),
    "go": MessageLookupByLibrary.simpleMessage("Перейти"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Перейти к загрузке"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("Добавить Hosts"),
    "hour": MessageLookupByLibrary.simpleMessage("час"),
    "hours": MessageLookupByLibrary.simpleMessage("Часов"),
    "hoursGenitive": MessageLookupByLibrary.simpleMessage("часов"),
    "hoursPlural": MessageLookupByLibrary.simpleMessage("часа"),
    "hwidFreeSlot": MessageLookupByLibrary.simpleMessage("Освободить лимит"),
    "hwidRecovered": MessageLookupByLibrary.simpleMessage(
      "Устройство зарегистрировано\nПодписка обновлена",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("Иконка"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Стиль иконки"),
    "import": MessageLookupByLibrary.simpleMessage("Импорт"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("Импорт из URL"),
    "importFromUrlHint": MessageLookupByLibrary.simpleMessage(
      "https://… — ссылка подписки вашего провайдера",
    ),
    "importUrl": MessageLookupByLibrary.simpleMessage("Импорт по URL"),
    "init": MessageLookupByLibrary.simpleMessage("Инициализация"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "Интеллектуальный выбор",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Интернет"),
    "interval": MessageLookupByLibrary.simpleMessage("Интервал"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("Внутренний IP"),
    "invalidProfileUrl": MessageLookupByLibrary.simpleMessage(
      "Некорректная ссылка на подписку. Используйте http:// или https://",
    ),
    "ipcidr": MessageLookupByLibrary.simpleMessage("IPCIDR"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "При включении будет возможно получать IPv6 трафик",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить входящий IPv6",
    ),
    "ja": MessageLookupByLibrary.simpleMessage("Японский"),
    "just": MessageLookupByLibrary.simpleMessage("Только что"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "Интервал поддержания TCP-соединения",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Ключ"),
    "language": MessageLookupByLibrary.simpleMessage("Язык"),
    "layout": MessageLookupByLibrary.simpleMessage("Макет"),
    "light": MessageLookupByLibrary.simpleMessage("Светлый"),
    "list": MessageLookupByLibrary.simpleMessage("Список"),
    "listen": MessageLookupByLibrary.simpleMessage("Слушать"),
    "loadingEllipsis": MessageLookupByLibrary.simpleMessage("Загрузка…"),
    "local": MessageLookupByLibrary.simpleMessage("Локальный"),
    "logLevel": MessageLookupByLibrary.simpleMessage("Уровень логов"),
    "logcat": MessageLookupByLibrary.simpleMessage("Журналирование"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "Вести журнал событий приложения",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Логи"),
    "logsCopied": MessageLookupByLibrary.simpleMessage("Логи скопированы"),
    "loopback": MessageLookupByLibrary.simpleMessage("Разблокировка Loopback"),
    "loose": MessageLookupByLibrary.simpleMessage("Свободный"),
    "m3eA11yBack": MessageLookupByLibrary.simpleMessage("Назад"),
    "m3eA11yCancel": MessageLookupByLibrary.simpleMessage(
      "Отменить подключение",
    ),
    "m3eA11yCard": MessageLookupByLibrary.simpleMessage(
      "Подключение и подписка",
    ),
    "m3eA11yConnect": MessageLookupByLibrary.simpleMessage("Подключить VPN"),
    "m3eA11yDisconnect": MessageLookupByLibrary.simpleMessage("Отключить VPN"),
    "m3eA11yJoy": MessageLookupByLibrary.simpleMessage("Подключение и маршрут"),
    "m3eA11yRetry": MessageLookupByLibrary.simpleMessage(
      "Повторить подключение",
    ),
    "m3eA11yRoute": MessageLookupByLibrary.simpleMessage("Выбрать маршрут"),
    "m3eA11ySettings": MessageLookupByLibrary.simpleMessage(
      "Открыть настройки",
    ),
    "m3eA11ySubs": MessageLookupByLibrary.simpleMessage("Открыть подписки"),
    "m3eAboutPrivacy": MessageLookupByLibrary.simpleMessage(
      "Политика конфиденциальности",
    ),
    "m3eAboutSite": MessageLookupByLibrary.simpleMessage("Сайт проекта"),
    "m3eAboutTitle": MessageLookupByLibrary.simpleMessage("О программе"),
    "m3eAboutUpdate": MessageLookupByLibrary.simpleMessage("Обновление"),
    "m3eAboutUpdateAvailable": m9,
    "m3eAboutVersion": m10,
    "m3eAddFieldError": MessageLookupByLibrary.simpleMessage(
      "Ссылка должна начинаться с https://",
    ),
    "m3eAddFieldLabel": MessageLookupByLibrary.simpleMessage(
      "Ссылка на подписку",
    ),
    "m3eAppearanceBasicColors": MessageLookupByLibrary.simpleMessage(
      "Основные цвета",
    ),
    "m3eAppearanceGroupLabel": MessageLookupByLibrary.simpleMessage(
      "Цвет приложения",
    ),
    "m3eAppearanceOwn": MessageLookupByLibrary.simpleMessage("Свой цвет"),
    "m3eAppearanceOwnSub": MessageLookupByLibrary.simpleMessage(
      "Выбрать из палитры",
    ),
    "m3eAppearanceProvider": MessageLookupByLibrary.simpleMessage(
      "Цвет провайдера",
    ),
    "m3eAppearanceProviderSub": MessageLookupByLibrary.simpleMessage(
      "Как в подписке",
    ),
    "m3eAppearanceTitle": MessageLookupByLibrary.simpleMessage("Оформление"),
    "m3eColorN": m11,
    "m3eColorShade": m12,
    "m3eColorTitle": MessageLookupByLibrary.simpleMessage("Другой цвет"),
    "m3eDeleteBody": MessageLookupByLibrary.simpleMessage(
      "Оплаченная подписка у провайдера останется.",
    ),
    "m3eDeleteTitle": m13,
    "m3eDisclosureBody": MessageLookupByLibrary.simpleMessage(
      "dropweb создаёт VPN-туннель через системное разрешение Android. Трафик идёт через серверы вашей подписки. dropweb не видит и не записывает, что вы делаете в сети. Провайдер подписки получает ваш IP-адрес и, если это не отключено в настройках, идентификатор устройства.",
    ),
    "m3eDisclosureTitle": MessageLookupByLibrary.simpleMessage(
      "Перед подключением",
    ),
    "m3eEmptyPaste": MessageLookupByLibrary.simpleMessage("Вставить ссылку"),
    "m3eEmptyScanQr": MessageLookupByLibrary.simpleMessage(
      "Сканировать QR-код",
    ),
    "m3eEmptyTitle": MessageLookupByLibrary.simpleMessage("Добавьте подписку"),
    "m3eLangSystem": MessageLookupByLibrary.simpleMessage("Как в системе"),
    "m3eMsNoAnswer": MessageLookupByLibrary.simpleMessage("нет ответа"),
    "m3ePlanDaysLeft": m14,
    "m3ePlanExpired": MessageLookupByLibrary.simpleMessage(
      "Подписка закончилась",
    ),
    "m3ePlanForever": MessageLookupByLibrary.simpleMessage("бессрочно"),
    "m3ePlanLine": m15,
    "m3ePlanTrafficLeft": m16,
    "m3ePlanTrafficOf": m17,
    "m3ePlanTrafficOut": MessageLookupByLibrary.simpleMessage(
      "Трафик закончился",
    ),
    "m3ePlanUnlimited": MessageLookupByLibrary.simpleMessage("Безлимит"),
    "m3ePlanUntil": m18,
    "m3eRefresh": MessageLookupByLibrary.simpleMessage("Обновить"),
    "m3eRouteAllTraffic": MessageLookupByLibrary.simpleMessage(
      "Весь трафик через VPN",
    ),
    "m3eRouteAuto": MessageLookupByLibrary.simpleMessage("Авто"),
    "m3eRouteCountries": MessageLookupByLibrary.simpleMessage("Страна"),
    "m3eRouteGroupsCount": m19,
    "m3eRouteTitle": MessageLookupByLibrary.simpleMessage("Маршрут"),
    "m3eScanGallery": MessageLookupByLibrary.simpleMessage(
      "Выбрать из галереи",
    ),
    "m3eScanTorch": MessageLookupByLibrary.simpleMessage("Фонарик"),
    "m3eServersTitle": MessageLookupByLibrary.simpleMessage("Серверы и группы"),
    "m3eSettingsAboutVersion": m20,
    "m3eStatIp": MessageLookupByLibrary.simpleMessage("IP-адрес"),
    "m3eStatNone": MessageLookupByLibrary.simpleMessage("—"),
    "m3eStatPing": MessageLookupByLibrary.simpleMessage("Пинг"),
    "m3eStatTraffic": MessageLookupByLibrary.simpleMessage("Трафик"),
    "m3eStatusConnected": MessageLookupByLibrary.simpleMessage("Подключено"),
    "m3eStatusConnecting": MessageLookupByLibrary.simpleMessage("Подключение…"),
    "m3eStatusDisconnected": MessageLookupByLibrary.simpleMessage(
      "Не подключено",
    ),
    "m3eStatusError": MessageLookupByLibrary.simpleMessage(
      "Сервер не отвечает",
    ),
    "m3eStatusOffline": MessageLookupByLibrary.simpleMessage("Нет сети"),
    "m3eStatusSwitching": MessageLookupByLibrary.simpleMessage("Переключение…"),
    "m3eSubAll": MessageLookupByLibrary.simpleMessage("Все подписки"),
    "m3eSubDelete": MessageLookupByLibrary.simpleMessage("Удалить подписку"),
    "m3eSubListLabel": MessageLookupByLibrary.simpleMessage("Подписки"),
    "m3eSubSupport": MessageLookupByLibrary.simpleMessage("Справочная"),
    "m3eSubTitle": MessageLookupByLibrary.simpleMessage("Подписка"),
    "m3eToastInstaller": MessageLookupByLibrary.simpleMessage(
      "Открываем установщик Android",
    ),
    "m3eToastRefreshFail": MessageLookupByLibrary.simpleMessage(
      "Нет связи с сервером",
    ),
    "m3eToastRefreshed": MessageLookupByLibrary.simpleMessage(
      "Подписка обновлена",
    ),
    "m3eToastSupport": MessageLookupByLibrary.simpleMessage(
      "Открываем справочную",
    ),
    "m3eUpdateDownloading": m21,
    "m3eUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось обновить",
    ),
    "m3eUpdateNotes": MessageLookupByLibrary.simpleMessage("Что нового"),
    "m3eUpdateProgressLabel": MessageLookupByLibrary.simpleMessage(
      "Загрузка обновления",
    ),
    "m3eUpdateReady": MessageLookupByLibrary.simpleMessage(
      "Загружено, можно установить",
    ),
    "m3eUpdateTitle": m22,
    "m3eUpdateVerifying": MessageLookupByLibrary.simpleMessage("Проверка…"),
    "m3eUpdatedDaysAgo": m23,
    "m3eUpdatedHoursAgo": m24,
    "m3eUpdatedJustNow": MessageLookupByLibrary.simpleMessage(
      "Обновлено только что",
    ),
    "m3eUpdatedMinutesAgo": m25,
    "m3eValueGb": m26,
    "m3eValueMs": m27,
    "managedByProvider": MessageLookupByLibrary.simpleMessage(
      "Заблокированными настройками управляет ваш провайдер",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("Информация о памяти"),
    "menu": MessageLookupByLibrary.simpleMessage("MENU"),
    "min": MessageLookupByLibrary.simpleMessage("Мин"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage(
      "Сворачивать при выходе",
    ),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "Сворачивать приложение в трей вместо закрытия",
    ),
    "minutes": MessageLookupByLibrary.simpleMessage("Минут"),
    "mixedPort": MessageLookupByLibrary.simpleMessage("Смешанный порт"),
    "mode": MessageLookupByLibrary.simpleMessage("Режим"),
    "months": MessageLookupByLibrary.simpleMessage("Месяцев"),
    "more": MessageLookupByLibrary.simpleMessage("Еще"),
    "name": MessageLookupByLibrary.simpleMessage("Имя"),
    "nameserver": MessageLookupByLibrary.simpleMessage("Сервер имен"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Для разрешения домена",
    ),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Политика сервера имен",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Указать соответствующую политику сервера имен",
    ),
    "network": MessageLookupByLibrary.simpleMessage("Сеть"),
    "networkDesc": MessageLookupByLibrary.simpleMessage(
      "Изменение настроек, связанных с сетью",
    ),
    "networkDetection": MessageLookupByLibrary.simpleMessage("Ваш IP-адрес"),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Скорость сети"),
    "noData": MessageLookupByLibrary.simpleMessage("Нет данных"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("Нет сети"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("Приложение без сети"),
    "noResolve": MessageLookupByLibrary.simpleMessage("Не разрешать IP"),
    "none": MessageLookupByLibrary.simpleMessage("Нет"),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Профиль отсутствует. Пожалуйста, добавьте профиль",
    ),
    "numberTip": m28,
    "ok": MessageLookupByLibrary.simpleMessage("OK"),
    "onboardingClipboardImport": MessageLookupByLibrary.simpleMessage(
      "Вставить подписку из буфера",
    ),
    "onboardingImported": MessageLookupByLibrary.simpleMessage(
      "Подписка добавлена. Нажмите, чтобы подключиться",
    ),
    "oneline": MessageLookupByLibrary.simpleMessage("Линия"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Учитывать только прокси-трафик",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Учитывать в статистике только трафик через прокси",
    ),
    "openLogsFolder": MessageLookupByLibrary.simpleMessage(
      "Открыть папку логов",
    ),
    "options": MessageLookupByLibrary.simpleMessage("Опции"),
    "orbBlur": MessageLookupByLibrary.simpleMessage("Размытие"),
    "orbOne": MessageLookupByLibrary.simpleMessage("Орбы верх"),
    "orbTwo": MessageLookupByLibrary.simpleMessage("Орбы низ"),
    "other": MessageLookupByLibrary.simpleMessage("Другое"),
    "outboundMode": MessageLookupByLibrary.simpleMessage(
      "Режим исходящих подключений",
    ),
    "override": MessageLookupByLibrary.simpleMessage("Переопределение"),
    "overrideDns": MessageLookupByLibrary.simpleMessage("Переопределить DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Переопределить настройки DNS из профиля",
    ),
    "overrideNetworkSettings": MessageLookupByLibrary.simpleMessage(
      "Переопределение сетевых настроек",
    ),
    "overrideNetworkSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Игнорировать сетевые настройки из конфига провайдера",
    ),
    "overrideProviderSettings": MessageLookupByLibrary.simpleMessage(
      "Переопределение",
    ),
    "overrideProviderSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Игнорировать настройки от провайдера и управлять вручную",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("Палитра"),
    "password": MessageLookupByLibrary.simpleMessage("Пароль"),
    "paste": MessageLookupByLibrary.simpleMessage("Вставить"),
    "pasteFromClipboard": MessageLookupByLibrary.simpleMessage("Вставить"),
    "personalCabinet": MessageLookupByLibrary.simpleMessage("Личный кабинет"),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, введите пароль администратора",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, загрузите действительный QR-код",
    ),
    "port": MessageLookupByLibrary.simpleMessage("Порт"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Введите другой порт",
    ),
    "portTip": m29,
    "preferH3Desc": MessageLookupByLibrary.simpleMessage(
      "Использовать HTTP/3 для DOH (если доступно)",
    ),
    "presetAmber": MessageLookupByLibrary.simpleMessage("Янтарь"),
    "presetAmethyst": MessageLookupByLibrary.simpleMessage("Аметист"),
    "presetCrimson": MessageLookupByLibrary.simpleMessage("Багрянец"),
    "presetEmerald": MessageLookupByLibrary.simpleMessage("Падение"),
    "presetFrost": MessageLookupByLibrary.simpleMessage("Иней"),
    "presetMagma": MessageLookupByLibrary.simpleMessage("Магма"),
    "presetStealth": MessageLookupByLibrary.simpleMessage("Стелс"),
    "preview": MessageLookupByLibrary.simpleMessage("Предпросмотр"),
    "privacyPolicy": MessageLookupByLibrary.simpleMessage(
      "Политика конфиденциальности",
    ),
    "profile": MessageLookupByLibrary.simpleMessage("Профиль"),
    "profiles": MessageLookupByLibrary.simpleMessage("Профили"),
    "project": MessageLookupByLibrary.simpleMessage("Проект"),
    "providers": MessageLookupByLibrary.simpleMessage("Провайдеры"),
    "proxies": MessageLookupByLibrary.simpleMessage("Прокси"),
    "proxiesSetting": MessageLookupByLibrary.simpleMessage("Настройка прокси"),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage(
      "Прокси-сервер имен",
    ),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Домен для разрешения прокси-узлов",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("Провайдеры прокси"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Чисто черный режим"),
    "qrNotFound": MessageLookupByLibrary.simpleMessage("QR-код не найден"),
    "qrScanFromImageUnsupported": MessageLookupByLibrary.simpleMessage(
      "Сканирование QR-кода из изображения не поддерживается на этой платформе. Используйте ссылку на подписку.",
    ),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR-код"),
    "receiveSubscriptionTitle": MessageLookupByLibrary.simpleMessage(
      "Получение подписки",
    ),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir-порт"),
    "redo": MessageLookupByLibrary.simpleMessage("Повторить"),
    "regExp": MessageLookupByLibrary.simpleMessage("Регулярное выражение"),
    "remaining": MessageLookupByLibrary.simpleMessage("Осталось"),
    "remainingPlural": MessageLookupByLibrary.simpleMessage("Осталось"),
    "remainingSingular": MessageLookupByLibrary.simpleMessage("Остался"),
    "remote": MessageLookupByLibrary.simpleMessage("Удаленный"),
    "remove": MessageLookupByLibrary.simpleMessage("Удалить"),
    "rename": MessageLookupByLibrary.simpleMessage("Переименовать"),
    "renew": MessageLookupByLibrary.simpleMessage("Продлить"),
    "requests": MessageLookupByLibrary.simpleMessage("Запросы"),
    "reset": MessageLookupByLibrary.simpleMessage("Сброс"),
    "resetTip": MessageLookupByLibrary.simpleMessage(
      "Убедитесь, что хотите сбросить",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("Ресурсы"),
    "respectRules": MessageLookupByLibrary.simpleMessage("Соблюдать правила"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS-запросы следуют правилам маршрутизации (требуется настройка proxy-server-nameserver)",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("Перезапустить"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("Адрес маршрутизации"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage(
      "Настройка адреса прослушивания маршрутизации",
    ),
    "routeMode": MessageLookupByLibrary.simpleMessage("Режим маршрутизации"),
    "routeMode_bypassPrivate": MessageLookupByLibrary.simpleMessage(
      "Обход частных адресов маршрутизации",
    ),
    "routeMode_config": MessageLookupByLibrary.simpleMessage(
      "Использовать конфигурацию",
    ),
    "routeUndetected": MessageLookupByLibrary.simpleMessage(
      "Не удалось определить маршрут",
    ),
    "ru": MessageLookupByLibrary.simpleMessage("Русский"),
    "rule": MessageLookupByLibrary.simpleMessage("По правилам"),
    "ruleName": MessageLookupByLibrary.simpleMessage("Название правила"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("Провайдеры правил"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Цель правила"),
    "rules": MessageLookupByLibrary.simpleMessage("Правила"),
    "running": MessageLookupByLibrary.simpleMessage("Запущено"),
    "save": MessageLookupByLibrary.simpleMessage("Сохранить"),
    "scanQrCode": MessageLookupByLibrary.simpleMessage("Сканировать QR-код"),
    "schemeBright": MessageLookupByLibrary.simpleMessage("Яркие"),
    "schemeCalm": MessageLookupByLibrary.simpleMessage("Обычные"),
    "schemeExpressive": MessageLookupByLibrary.simpleMessage("Выразительные"),
    "schemeMono": MessageLookupByLibrary.simpleMessage("Моно"),
    "schemeNeutral": MessageLookupByLibrary.simpleMessage("Нейтральные"),
    "script": MessageLookupByLibrary.simpleMessage("Скрипт"),
    "search": MessageLookupByLibrary.simpleMessage("Поиск"),
    "seconds": MessageLookupByLibrary.simpleMessage("Секунд"),
    "selectAll": MessageLookupByLibrary.simpleMessage("Выбрать все"),
    "selectProfile": MessageLookupByLibrary.simpleMessage("Выбрать профиль"),
    "selected": MessageLookupByLibrary.simpleMessage("Выбрано"),
    "selectedCountTitle": m30,
    "serversAndGroups": MessageLookupByLibrary.simpleMessage(
      "Серверы и группы",
    ),
    "settings": MessageLookupByLibrary.simpleMessage("Настройки"),
    "settingsSendDeviceDataSubtitle": MessageLookupByLibrary.simpleMessage(
      "Отправлять идентификатор устройства, версию приложения и название устройства на сервер прокси-провайдера",
    ),
    "settingsSendDeviceDataTitle": MessageLookupByLibrary.simpleMessage(
      "Отправлять HWID",
    ),
    "show": MessageLookupByLibrary.simpleMessage("Показать"),
    "shrink": MessageLookupByLibrary.simpleMessage("Сжать"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("Скрытый запуск"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Запускать в свернутом виде",
    ),
    "size": MessageLookupByLibrary.simpleMessage("Размер"),
    "smart": MessageLookupByLibrary.simpleMessage("Умный"),
    "smartAuto": MessageLookupByLibrary.simpleMessage("Авто"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socks-порт"),
    "sort": MessageLookupByLibrary.simpleMessage("Сортировка"),
    "source": MessageLookupByLibrary.simpleMessage("Источник"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("Исходный IP"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Режим стека"),
    "standard": MessageLookupByLibrary.simpleMessage("Стандартный"),
    "start": MessageLookupByLibrary.simpleMessage("Старт"),
    "startVpn": MessageLookupByLibrary.simpleMessage("Запуск VPN..."),
    "startingVpnCore": MessageLookupByLibrary.simpleMessage(
      "Запускаем VPN-ядро…",
    ),
    "status": MessageLookupByLibrary.simpleMessage("Статус"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "При выключении будет использоваться системный DNS",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Стоп"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Остановка VPN..."),
    "stopped": MessageLookupByLibrary.simpleMessage("Остановлено"),
    "style": MessageLookupByLibrary.simpleMessage("Стиль"),
    "subRule": MessageLookupByLibrary.simpleMessage("Подправило"),
    "submit": MessageLookupByLibrary.simpleMessage("Отправить"),
    "subscription": MessageLookupByLibrary.simpleMessage("Подписка"),
    "subscriptionEternal": MessageLookupByLibrary.simpleMessage(
      "Бессрочная подписка",
    ),
    "subscriptionExpired": MessageLookupByLibrary.simpleMessage(
      "Ваша подписка истекла",
    ),
    "subscriptionExpiresInDays": m31,
    "subscriptionExpiresToday": MessageLookupByLibrary.simpleMessage(
      "Ваша подписка истекает сегодня",
    ),
    "subscriptionLogo": MessageLookupByLibrary.simpleMessage(
      "Лого из подписки",
    ),
    "subscriptionTheme": MessageLookupByLibrary.simpleMessage(
      "Тема из подписки",
    ),
    "subscriptionUnlimited": MessageLookupByLibrary.simpleMessage(
      "Бессрочная подписка",
    ),
    "support": MessageLookupByLibrary.simpleMessage("Поддержка"),
    "supportProject": MessageLookupByLibrary.simpleMessage("Поддержать проект"),
    "sync": MessageLookupByLibrary.simpleMessage("Обновление"),
    "system": MessageLookupByLibrary.simpleMessage("Система"),
    "systemApp": MessageLookupByLibrary.simpleMessage("Системное приложение"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("Системный прокси"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать HTTP-прокси через VPN",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("Вкладка"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("Анимация вкладок"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "Работает только в мобильном режиме",
    ),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("Параллельный TCP"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "Использовать параллельные TCP-соединения",
    ),
    "testUrl": MessageLookupByLibrary.simpleMessage("Тест URL"),
    "textScale": MessageLookupByLibrary.simpleMessage("Масштабирование текста"),
    "theme": MessageLookupByLibrary.simpleMessage("Тема"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Цвет темы"),
    "themeMode": MessageLookupByLibrary.simpleMessage("Режим темы"),
    "themePresets": MessageLookupByLibrary.simpleMessage("Готовые темы"),
    "tight": MessageLookupByLibrary.simpleMessage("Плотный"),
    "time": MessageLookupByLibrary.simpleMessage("Время"),
    "tip": MessageLookupByLibrary.simpleMessage("Подсказка"),
    "toggle": MessageLookupByLibrary.simpleMessage("Переключить"),
    "tooFrequentOperation": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, подождите 15 секунд перед повторным обновлением",
    ),
    "tools": MessageLookupByLibrary.simpleMessage("Настройки"),
    "topUpTraffic": MessageLookupByLibrary.simpleMessage("Докупить трафик"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxy-порт"),
    "traffic": MessageLookupByLibrary.simpleMessage("Трафик"),
    "trafficUnlimited": MessageLookupByLibrary.simpleMessage(
      "Безлимитный трафик",
    ),
    "trafficUsage": MessageLookupByLibrary.simpleMessage(
      "Использование трафика",
    ),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "Доступно только в режиме администратора",
    ),
    "undo": MessageLookupByLibrary.simpleMessage("Отменить"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage(
      "Унифицированная задержка",
    ),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "Не учитывать дополнительные задержки (например, рукопожатие)",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("Неизвестно"),
    "unnamed": MessageLookupByLibrary.simpleMessage("Без имени"),
    "update": MessageLookupByLibrary.simpleMessage("Обновить"),
    "updateCancel": MessageLookupByLibrary.simpleMessage("Отмена"),
    "updateDownloading": MessageLookupByLibrary.simpleMessage("Загрузка…"),
    "updateFailed": MessageLookupByLibrary.simpleMessage("Не удалось обновить"),
    "updateInstall": MessageLookupByLibrary.simpleMessage("Установить"),
    "updateLater": MessageLookupByLibrary.simpleMessage("Позже"),
    "updateMandatoryNote": MessageLookupByLibrary.simpleMessage(
      "Рекомендуем обновиться",
    ),
    "updateRetry": MessageLookupByLibrary.simpleMessage("Повторить"),
    "updateSubscription": MessageLookupByLibrary.simpleMessage("Обновить"),
    "updateVerifying": MessageLookupByLibrary.simpleMessage("Проверка…"),
    "updated": MessageLookupByLibrary.simpleMessage("Обновлено"),
    "upload": MessageLookupByLibrary.simpleMessage("Отправка"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlTip": m32,
    "useHosts": MessageLookupByLibrary.simpleMessage("Использовать hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage(
      "Использовать системные hosts",
    ),
    "validUntil": m33,
    "value": MessageLookupByLibrary.simpleMessage("Значение"),
    "view": MessageLookupByLibrary.simpleMessage("Просмотр"),
    "vpnDisclosureBody": MessageLookupByLibrary.simpleMessage(
      "dropweb использует системное VPN-разрешение Android, чтобы создать VPN-туннель на вашем устройстве. Ваш сетевой трафик идёт через серверы из подписки или конфигурации, которую вы добавили сами, и их операторы обрабатывают его по своим правилам. dropweb не просматривает, не записывает и не отправляет содержимое вашего трафика и посещаемые сайты, в нём нет рекламы и аналитики. Когда вы добавляете или обновляете подписку, её провайдер получает ваш IP-адрес и, если вы не отключили это в настройках, идентификатор устройства (HWID) и модель устройства. Вы можете в любой момент отключиться с этого экрана или из системных настроек VPN.",
    ),
    "vpnDisclosureBodyIos": MessageLookupByLibrary.simpleMessage(
      "dropweb добавляет на iPhone конфигурацию VPN, чтобы создать VPN-туннель на вашем устройстве. Ваш сетевой трафик идёт через серверы из подписки или конфигурации, которую вы добавили сами, и их операторы обрабатывают его по своим правилам. dropweb не просматривает, не записывает и не отправляет содержимое вашего трафика и посещаемые сайты, в нём нет рекламы и аналитики. Когда вы добавляете или обновляете подписку, её провайдер получает ваш IP-адрес и, если вы не отключили это в настройках, идентификатор устройства (HWID) и модель устройства. Вы можете в любой момент отключиться с этого экрана или из системных настроек VPN.",
    ),
    "vpnDisclosureContinue": MessageLookupByLibrary.simpleMessage("Продолжить"),
    "vpnDisclosureTitle": MessageLookupByLibrary.simpleMessage(
      "Перед подключением",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматически направляет весь системный трафик через VpnService",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage(
      "Изменения вступят в силу после перезапуска VPN",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage(
      "Режим белого списка",
    ),
    "workModeCountry": MessageLookupByLibrary.simpleMessage("Страна"),
    "workModeResetNotice": MessageLookupByLibrary.simpleMessage(
      "Режим сброшен на Стандарт: настройки недоступны после обновления подписки.",
    ),
    "years": MessageLookupByLibrary.simpleMessage("Лет"),
    "zh_CN": MessageLookupByLibrary.simpleMessage("Упрощенный китайский"),
  };
}
