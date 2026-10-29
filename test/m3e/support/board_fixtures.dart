// Данные доски canon/dropweb/app.js: провайдеры (PROVIDERS, строки 66-73) и наборы
// NORMAL (143-173) и WORST (174-193). Значения перенесены как есть, включая русские тексты.

/// Провайдер доски: имя и строка заголовка `dropweb-theme`.
class BoardProvider {
  const BoardProvider(this.name, this.theme);

  final String name;
  final String theme;
}

/// `PROVIDERS` в app.js: первый настоящий DROPWEB, остальные придуманы доской.
const List<BoardProvider> kBoardProviders = [
  BoardProvider('DROPWEB', 'fidelity,#29FF76,#000000,#2BFF7A,4'),
  BoardProvider('Голубой', 'fidelity,#38BDF8,#6366F1,#22D3EE,3'),
  BoardProvider('Сиреневый', 'fidelity,#A78BFA,#EC4899,#6366F1,4'),
  BoardProvider('Красный', 'fidelity,#EF4444,#F59E0B,#BE185D,3'),
  BoardProvider('Янтарный', 'fidelity,#F59E0B,#EF4444,#FACC15,4'),
  BoardProvider('Серый', 'fidelity,#64748B,#0EA5E9,#94A3B8,2'),
];

/// Страна в списке маршрутов; `ms == null` значит «узел недоступен».
class BoardCountry {
  const BoardCountry(this.id, this.flag, this.name, this.ms);

  final String id;
  final String flag;
  final String name;
  final int? ms;
}

/// Узел группы: имя, протокол, пинг (`null` без ответа).
class BoardNode {
  const BoardNode(this.name, this.protocol, this.ms);

  final String name;
  final String protocol;
  final int? ms;
}

class BoardGroup {
  const BoardGroup(this.name, this.nodes);

  final String name;
  final List<BoardNode> nodes;
}

/// Трафик строками, как их показывает доска (запятая и неразрывные пробелы не добавляются).
class BoardTraffic {
  const BoardTraffic({
    required this.used,
    required this.total,
    required this.left,
    required this.pct,
  });

  final String used;
  final String total;
  final String left;
  final double pct;
}

/// Набор данных доски (`NORMAL` или `WORST`).
class BoardData {
  const BoardData({
    required this.profiles,
    required this.pages,
    required this.logos,
    required this.traffic,
    required this.until,
    required this.usedGB,
    required this.best,
    required this.countries,
    required this.groups,
  });

  final List<String> profiles;

  /// Адрес страницы подписки у каждого провайдера.
  final List<String> pages;

  /// Путь логотипа относительно canon/dropweb или `null` (тогда инициалы).
  final List<String?> logos;

  /// `null` в NORMAL: безлимит.
  final BoardTraffic? traffic;

  /// `null` в NORMAL: без срока.
  final String? until;
  final double usedGB;
  final String best;
  final List<BoardCountry> countries;
  final List<BoardGroup> groups;
}

const List<BoardGroup> _normalGroups = [
  BoardGroup('🌍 VPN', [
    BoardNode('⚡ Авто', 'Группа', 41),
    BoardNode('⚡ Fastest', 'Группа', 41),
    BoardNode('📶 First Available', 'Группа', 88),
  ]),
  BoardGroup('⚡ Fastest', [
    BoardNode('Нидерланды, Амстердам', 'VLESS', 41),
    BoardNode('Финляндия, Хельсинки', 'VLESS', 64),
    BoardNode('Германия, Франкфурт', 'VLESS', 88),
    BoardNode('США, Нью-Йорк', 'VLESS', 156),
  ]),
  BoardGroup('📶 First Available', [
    BoardNode('Германия, Франкфурт', 'VLESS', 88),
    BoardNode('Нидерланды, Амстердам', 'VLESS', 41),
  ]),
  BoardGroup('🇺🇸 США ✨', [
    BoardNode('США, Нью-Йорк', 'VLESS', 156),
    BoardNode('США, Даллас', 'VLESS', 171),
  ]),
  BoardGroup('🇩🇪 Германия ✨', [
    BoardNode('Германия, Франкфурт', 'VLESS', 88),
    BoardNode('Германия, Берлин', 'Trojan', 112),
  ]),
  BoardGroup('🇳🇱 Нидерланды ✨', [
    BoardNode('Нидерланды, Амстердам', 'VLESS', 41),
  ]),
];

/// `NORMAL`: подписка как в заголовках настоящей DROPWEB (безлимит, без срока, 0,23 ГБ).
const BoardData kBoardNormal = BoardData(
  profiles: ['DROPWEB', 'Дом'],
  pages: ['cfgpull.com', 'panel.home-vpn.ru'],
  logos: ['mock/logo.svg', null],
  traffic: null,
  until: null,
  usedGB: 0.23,
  best: 'nl',
  countries: [
    BoardCountry('nl', '🇳🇱', 'Нидерланды', 41),
    BoardCountry('fi', '🇫🇮', 'Финляндия', 64),
    BoardCountry('de', '🇩🇪', 'Германия', 88),
    BoardCountry('us', '🇺🇸', 'США', 156),
  ],
  groups: _normalGroups,
);

/// `WORST`: длинные имена, крайние числа, страна без пинга.
const BoardData kBoardWorst = BoardData(
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
  traffic: BoardTraffic(used: '49,2', total: '50', left: '0,8', pct: 98.4),
  until: '13 января 2027',
  usedGB: 49.2,
  best: 'de',
  countries: [
    BoardCountry('de', '🇩🇪', 'Германия', 212),
    BoardCountry('nl', '🇳🇱', 'Нидерланды', 640),
    BoardCountry('us', '🇺🇸', 'Соединённые Штаты Америки', 1840),
    BoardCountry('ae', '🇦🇪', 'Объединённые Арабские Эмираты', null),
    BoardCountry('kz', '🇰🇿', 'Казахстан', 97),
  ],
  groups: [
    BoardGroup(
        '🛰 Резервный канал для обхода блокировок мобильного оператора', [
      BoardNode(
        'Объединённые Арабские Эмираты, Дубай, резервный узел №3',
        'Hysteria2',
        null,
      ),
      BoardNode('Германия, Франкфурт', 'VLESS', 212),
    ]),
    ..._normalGroups,
  ],
);

/// `LOW` (app.js:206): трафик на исходе, 98,4%.
const BoardTraffic kBoardTrafficLow =
    BoardTraffic(used: '49,2', total: '50', left: '0,8', pct: 98.4);

/// `OUT` (app.js:207): трафик исчерпан.
const BoardTraffic kBoardTrafficOut =
    BoardTraffic(used: '50', total: '50', left: '0', pct: 100);
