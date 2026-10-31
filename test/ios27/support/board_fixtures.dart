// Данные колонки iOS доски canon/dropweb (app.js, коммит df156ea1): наборы NORMAL (143-173) и WORST (174-193),
// трафик LOW/OUT (206-207), языки LANGS (197), тосты TOASTS (198-205), объявление ANNOUNCE (467-470),
// строки главной (statusB 480-486, карточка 508-531). Значения перенесены как есть, включая русские тексты.
//
// Провайдеры (PROVIDERS, строки 66-73) тут не дублируются: они лежат в `../fixtures/board_providers.dart`
// (`kBoardProviders`). Форма данных та же, что у `test/m3e/support/board_fixtures.dart`, с приставкой
// `Ios27Board`, чтобы два набора можно было подключить в один тест.

/// Страна в списке маршрутов; `ms == null` значит «узел недоступен».
class Ios27BoardCountry {
  const Ios27BoardCountry(this.id, this.flag, this.name, this.ms);

  final String id;
  final String flag;
  final String name;
  final int? ms;
}

/// Узел группы: имя, протокол, пинг (`null` без ответа).
class Ios27BoardNode {
  const Ios27BoardNode(this.name, this.protocol, this.ms);

  final String name;
  final String protocol;
  final int? ms;
}

class Ios27BoardGroup {
  const Ios27BoardGroup(this.name, this.nodes);

  final String name;
  final List<Ios27BoardNode> nodes;
}

/// Трафик строками, как его показывает доска; [gb] нужен значению «Трафик» в карточке главной.
class Ios27BoardTraffic {
  const Ios27BoardTraffic({
    required this.used,
    required this.total,
    required this.left,
    required this.pct,
    required this.gb,
  });

  final String used;
  final String total;
  final String left;
  final double pct;

  /// Израсходовано в гигабайтах числом (поле `gb` в LOW/OUT).
  final double gb;
}

/// Набор данных доски (`NORMAL` или `WORST`) вместе с тем, что главная строит из флага worst.
class Ios27BoardData {
  const Ios27BoardData({
    required this.profiles,
    required this.pages,
    required this.logos,
    required this.traffic,
    required this.until,
    required this.usedGB,
    required this.best,
    required this.countries,
    required this.groups,
    required this.announce,
    required this.ipOn,
  });

  final List<String> profiles;

  /// Адрес страницы подписки у каждого провайдера.
  final List<String> pages;

  /// Путь логотипа относительно canon/dropweb или `null` (тогда инициал).
  final List<String?> logos;

  /// `null` в NORMAL: безлимит.
  final Ios27BoardTraffic? traffic;

  /// `null` в NORMAL: без срока.
  final String? until;
  final double usedGB;

  /// Идентификатор лучшей страны.
  final String best;
  final List<Ios27BoardCountry> countries;
  final List<Ios27BoardGroup> groups;

  /// Объявление провайдера (ANNOUNCE, app.js:467-470): в WORST ровно 200 символов.
  final String announce;

  /// Адрес под VPN (app.js:516): в WORST IPv6.
  final String ipOn;
}

/// Адрес без VPN: доска показывает настоящий (app.js:516), с флагом [kIos27BoardFlagOff].
const String kIos27BoardIpOff = '95.24.118.7';

/// Флаг настоящего адреса без VPN (`cf` в app.js:517).
const String kIos27BoardFlagOff = '🇷🇺';

const List<Ios27BoardGroup> _normalGroups = [
  Ios27BoardGroup('🌍 VPN', [
    Ios27BoardNode('⚡ Авто', 'Группа', 41),
    Ios27BoardNode('⚡ Fastest', 'Группа', 41),
    Ios27BoardNode('📶 First Available', 'Группа', 88),
  ]),
  Ios27BoardGroup('⚡ Fastest', [
    Ios27BoardNode('Нидерланды, Амстердам', 'VLESS', 41),
    Ios27BoardNode('Финляндия, Хельсинки', 'VLESS', 64),
    Ios27BoardNode('Германия, Франкфурт', 'VLESS', 88),
    Ios27BoardNode('США, Нью-Йорк', 'VLESS', 156),
  ]),
  Ios27BoardGroup('📶 First Available', [
    Ios27BoardNode('Германия, Франкфурт', 'VLESS', 88),
    Ios27BoardNode('Нидерланды, Амстердам', 'VLESS', 41),
  ]),
  Ios27BoardGroup('🇺🇸 США ✨', [
    Ios27BoardNode('США, Нью-Йорк', 'VLESS', 156),
    Ios27BoardNode('США, Даллас', 'VLESS', 171),
  ]),
  Ios27BoardGroup('🇩🇪 Германия ✨', [
    Ios27BoardNode('Германия, Франкфурт', 'VLESS', 88),
    Ios27BoardNode('Германия, Берлин', 'Trojan', 112),
  ]),
  Ios27BoardGroup('🇳🇱 Нидерланды ✨', [
    Ios27BoardNode('Нидерланды, Амстердам', 'VLESS', 41),
  ]),
];

/// `NORMAL` (app.js:143-173): подписка как в заголовках настоящей DROPWEB (безлимит, без срока, 0,23 ГБ).
const Ios27BoardData kIos27BoardNormal = Ios27BoardData(
  profiles: ['DROPWEB', 'Дом'],
  pages: ['cfgpull.com', 'panel.home-vpn.ru'],
  logos: ['mock/logo.svg', null],
  traffic: null,
  until: null,
  usedGB: 0.23,
  best: 'nl',
  countries: [
    Ios27BoardCountry('nl', '🇳🇱', 'Нидерланды', 41),
    Ios27BoardCountry('fi', '🇫🇮', 'Финляндия', 64),
    Ios27BoardCountry('de', '🇩🇪', 'Германия', 88),
    Ios27BoardCountry('us', '🇺🇸', 'США', 156),
  ],
  groups: _normalGroups,
  announce: 'dropweb.org',
  ipOn: '185.107.56.12',
);

/// `WORST` (app.js:174-193): длинные имена, крайние числа, страна без пинга, объявление в 200 символов.
const Ios27BoardData kIos27BoardWorst = Ios27BoardData(
  profiles: [
    'Северо-Западный Интернет-Провайдер Плюс',
    'Работа (резерв, не трогать)',
    'Дом',
    'Мамин телефон',
    'Тестовая подписка от 12.09',
    'DROPWEB',
  ],
  pages: [
    'lk.severo-zapadnyi-internet-provaider-plus.ru',
    'reserve.work-vpn.ru',
    'panel.home-vpn.ru',
    'mama.home-vpn.ru',
    'test.cfgpull.com',
    'cfgpull.com',
  ],
  logos: [null, null, null, null, null, 'mock/logo.png'],
  traffic: Ios27BoardTraffic(
    used: '49,2',
    total: '50',
    left: '0,8',
    pct: 98.4,
    gb: 49.2,
  ),
  until: '13 января 2027',
  usedGB: 49.2,
  best: 'de',
  countries: [
    Ios27BoardCountry('de', '🇩🇪', 'Германия', 212),
    Ios27BoardCountry('nl', '🇳🇱', 'Нидерланды', 640),
    Ios27BoardCountry('us', '🇺🇸', 'Соединённые Штаты Америки', 1840),
    Ios27BoardCountry('ae', '🇦🇪', 'Объединённые Арабские Эмираты', null),
    Ios27BoardCountry('kz', '🇰🇿', 'Казахстан', 97),
  ],
  groups: [
    Ios27BoardGroup(
      '🛰 Резервный канал для обхода блокировок мобильного оператора',
      [
        Ios27BoardNode(
          'Объединённые Арабские Эмираты, Дубай, резервный узел №3',
          'Hysteria2',
          null,
        ),
        Ios27BoardNode('Германия, Франкфурт', 'VLESS', 212),
      ],
    ),
    ..._normalGroups,
  ],
  announce:
      'Добавили серверы в Казахстане и Турции. Старые адреса в Нидерландах '
      'отключим 1 ноября, до этого дня обновите подписку в приложении. Новости, '
      'ответы на частые вопросы в канале https://t.me/dropweb_news',
  ipOn: '2a0e:97c0:3e3:4f1::1c',
);

/// `LOW` (app.js:206): трафик на исходе, 98,4 %.
const Ios27BoardTraffic kIos27BoardTrafficLow = Ios27BoardTraffic(
  used: '49,2',
  total: '50',
  left: '0,8',
  pct: 98.4,
  gb: 49.2,
);

/// `OUT` (app.js:207): трафик исчерпан.
const Ios27BoardTraffic kIos27BoardTrafficOut = Ios27BoardTraffic(
  used: '50',
  total: '50',
  left: '0',
  pct: 100,
  gb: 50,
);

/// Язык интерфейса: код, название, подпись справа (только у «Как в системе»). `LANGS`, app.js:197.
class Ios27BoardLang {
  const Ios27BoardLang(this.code, this.name, [this.detail]);

  final String code;
  final String name;
  final String? detail;
}

const List<Ios27BoardLang> kIos27BoardLangs = [
  Ios27BoardLang('system', 'Как в системе', 'Русский'),
  Ios27BoardLang('ru', 'Русский'),
  Ios27BoardLang('en', 'English'),
  Ios27BoardLang('ja', '日本語'),
  Ios27BoardLang('zh', '简体中文'),
];

/// Тост: имя значка из карты доски и текст. `TOASTS`, app.js:198-205.
///
/// Тост `installer` («Открываем установщик Android») в iOS-приложение не попадает: обновления в
/// магазинной сборке нет (R10 плана), поэтому в списке его нет.
class Ios27BoardToast {
  const Ios27BoardToast(this.icon, this.text);

  final String icon;
  final String text;
}

const Map<String, Ios27BoardToast> kIos27BoardToasts = {
  'support': Ios27BoardToast('out', 'Открываем справочную'),
  'refreshed': Ios27BoardToast('check', 'Подписка обновлена'),
  'qr': Ios27BoardToast('camera', 'Здесь откроется камера для QR-кода'),
  'link': Ios27BoardToast('out', 'Откроется в браузере'),
  'refreshFail': Ios27BoardToast('alert', 'Нет связи с сервером'),
};

/// Слово состояния на главной (`statusB`, app.js:480-486).
const String kIos27BoardStatusConnecting = 'Подключение…';
const String kIos27BoardStatusSwitching = 'Переключение…';
const String kIos27BoardStatusNoNetwork = 'Нет сети';
const String kIos27BoardStatusOn = 'Подключено';
const String kIos27BoardStatusError = 'Сервер не отвечает';
const String kIos27BoardStatusOff = 'Не подключено';

/// Значение «Трафик» в карточке: запятая вместо точки, два знака до 10 ГБ, один после,
/// неразрывный пробел перед «ГБ» (`gbText` и `dec`, app.js:475-478).
String ios27BoardGbText(double gb) =>
    '${gb.toStringAsFixed(gb < 10 ? 2 : 1).replaceFirst('.', ',')}\u00a0ГБ';

/// Строка плана в карточке главной (app.js:521-531): нормальный случай и три сигнала.
///
/// [sub] — состояние подписки доски: `null`/`ok`, `expired`, `traffic-out`, `expiring`.
String ios27BoardPlanLine(Ios27BoardData data,
    {Ios27BoardTraffic? traffic, String? sub}) {
  if (sub == 'expired') {
    return 'Подписка закончилась';
  }
  if (sub == 'traffic-out') {
    return 'Трафик закончился';
  }
  if (sub == 'expiring') {
    return 'Осталось 2 дня';
  }
  final t = traffic ?? data.traffic;
  if (t != null && t.pct > 90) {
    return 'Осталось ${t.left} ГБ';
  }
  final used = t != null ? '${t.used} из ${t.total} ГБ' : 'Безлимит';
  final until = data.until != null ? 'до ${data.until}' : 'бессрочно';
  return '$used · $until';
}
