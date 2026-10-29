// Сцены главной на данных доски: `SCENES` из app.js, `NORMAL`/`WORST` и `LOW`/`OUT`.
// Общая заготовка для home_model_test.dart и home_test.dart: вход модели собирается тем же
// способом, каким его кормит адаптер приложения.

import 'package:dropweb/ui/m3e/home/m3e_home_model.dart';

import 'support/board_fixtures.dart';

/// Имена сцен как в именах эталонов `test/m3e/ref/<сцена>-<тема>-p<N>.png`.
const List<String> kHomeSceneIds = [
  'home-off',
  'connecting',
  'switching',
  'home-on',
  'error',
  'offline',
  'expiring',
  'traffic-low',
  'traffic-out',
  'expired',
];

/// Сцена модели для имени сцены доски.
const Map<String, M3eHomeScene> kHomeSceneByName = {
  'home-off': M3eHomeScene.homeOff,
  'connecting': M3eHomeScene.connecting,
  'switching': M3eHomeScene.switching,
  'home-on': M3eHomeScene.homeOn,
  'error': M3eHomeScene.error,
  'offline': M3eHomeScene.offline,
  'expiring': M3eHomeScene.expiring,
  'traffic-low': M3eHomeScene.trafficLow,
  'traffic-out': M3eHomeScene.trafficOut,
  'expired': M3eHomeScene.expired,
};

/// Момент «сейчас» для расчёта срока подписки в тестах.
final DateTime kHomeNow = DateTime(2026, 10, 29, 12);

/// Объявление провайдера: копия `ANNOUNCE` из android.js (27-35).
const String kHomeAnnounceNormal = 'dropweb.org';
const String kHomeAnnounceWorst =
    'Добавили серверы в Казахстане и Турции. Старые адреса в Нидерландах отключим 1 ноября, '
    'до этого дня обновите подписку в приложении. Новости, ответы на частые вопросы в канале '
    'https://t.me/dropweb_news';

/// Таймер эталона home-on: часы доски на паузе.
const Duration kHomeRunTime = Duration(minutes: 12, seconds: 49);

int _bytes(double gb) => (gb * kM3eGigabyte).round();

/// Вход модели для сцены доски [scene] на данных NORMAL или WORST (`worst`).
M3eHomeInput homeInputFor(String scene, {bool worst = false}) {
  final d = worst ? kBoardWorst : kBoardNormal;
  final best = d.countries.firstWhere((c) => c.id == d.best);
  final on = scene == 'home-on';
  final switching = scene == 'switching';
  final connecting = scene == 'connecting';

  // Подписка сцены: у LOW и OUT доска подменяет трафик целиком (traffic()).
  M3eHomeSubscription? sub;
  switch (scene) {
    case 'traffic-low':
      sub = M3eHomeSubscription(
        usedBytes: _bytes(49.2),
        totalBytes: _bytes(50),
      );
    case 'traffic-out':
      sub = M3eHomeSubscription(
        usedBytes: _bytes(50),
        totalBytes: _bytes(50),
      );
    case 'expiring':
      sub = M3eHomeSubscription(
        usedBytes: _bytes(d.usedGB),
        totalBytes: d.traffic == null ? 0 : _bytes(50),
        expire: kHomeNow.add(const Duration(days: 2)),
      );
    case 'expired':
      sub = M3eHomeSubscription(
        usedBytes: _bytes(d.usedGB),
        totalBytes: d.traffic == null ? 0 : _bytes(50),
        expire: kHomeNow.subtract(const Duration(days: 1)),
      );
    default:
      sub = M3eHomeSubscription(
        usedBytes: _bytes(d.usedGB),
        totalBytes: d.traffic == null ? 0 : _bytes(50),
        expire: d.until == null ? null : DateTime(2027, 1, 13),
      );
  }

  final String ip;
  if (on) {
    ip = worst ? '2a0e:97c0:3e3:4f1::1c' : '185.107.56.12';
  } else {
    ip = '95.24.118.7';
  }
  final flag = on
      ? switch (best.id) {
          'nl' => 'NL',
          'de' => 'DE',
          _ => 'RU',
        }
      : 'RU';

  return M3eHomeInput(
    vpnOn: on || switching,
    connecting: connecting,
    switching: switching,
    runTime: on ? kHomeRunTime : null,
    error: scene == 'error',
    online: scene != 'offline',
    ipAddress: ip,
    ipCountryCode: flag,
    subscription: sub,
    providerName: d.profiles[0],
    announce: worst ? kHomeAnnounceWorst : kHomeAnnounceNormal,
  );
}
