// Адаптеры «приложение → вход главной M3E». Единственная точка, где экран знает про
// провайдеры приложения; golden-тесты подменяют `m3eHomeInputProvider` целиком и
// не трогают `globalState`.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropweb/common/base64_text.dart';
import 'package:dropweb/common/print.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'm3e_home_model.dart';

/// Мост `ValueNotifier` (старое состояние `globalState`) → Riverpod: провайдер
/// пересобирается при каждом изменении источника, подписка снимается с провайдером.
Provider<T> _bridge<T>(ValueListenable<T> Function() source) =>
    Provider<T>((ref) {
      final listenable = source();
      void onChange() => ref.invalidateSelf();
      listenable.addListener(onChange);
      ref.onDispose(() => listenable.removeListener(onChange));
      return listenable.value;
    });

/// Идёт подключение. Публичный: тесты подменяют его, не трогая `globalState`.
final m3eConnectingProvider = _bridge<bool>(() => globalState.isConnecting);

final _detectionProvider =
    _bridge<NetworkDetectionState>(() => detectionState.state);

// «Переключение…» не показываем: решение владельца 2026-10-29. Сцена остаётся в модели
// и golden, но в приложении этот вход всегда `false`.
const bool _kSwitching = false;

/// Источник связи телефона. Обёртка над `connectivity_plus` 7.x (там список результатов),
/// чтобы тесты подменяли его без платформенных каналов.
class M3eConnectivitySource {
  const M3eConnectivitySource({required this.check, required this.changes});

  /// Платформенная реализация.
  factory M3eConnectivitySource.platform() {
    final c = Connectivity();
    return M3eConnectivitySource(
      check: c.checkConnectivity,
      changes: c.onConnectivityChanged,
    );
  }

  final Future<List<ConnectivityResult>> Function() check;
  final Stream<List<ConnectivityResult>> changes;
}

final m3eConnectivitySourceProvider = Provider<M3eConnectivitySource>(
  (ref) => M3eConnectivitySource.platform(),
);

/// Сеть есть, если хотя бы один результат не `none` (wifi, mobile, vpn и прочее).
/// «Нет сети» только когда нет ни одной сети; пустой список тоже значит «нет».
bool m3eIsOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// Есть ли сеть: проверка при старте и далее изменения.
final m3eOnlineProvider = StreamProvider<bool>((ref) async* {
  final source = ref.watch(m3eConnectivitySourceProvider);
  try {
    yield m3eIsOnline(await source.check());
  } on Object {
    // Канал связи недоступен: лучше не показывать «Нет сети» зря, чем спрятать главную.
    yield true;
  }
  yield* source.changes.map(m3eIsOnline);
});

/// Пауза перед проверкой «подключение не удалось». `isConnecting` гаснет в `finally`
/// после `startUpdateTasks`, который сам ставит `runTime`, но на устройстве между ними
/// возможен тик задач (2 с): ждём чуть дольше одного тика, чтобы удачный старт
/// не показался неудачным.
final m3eStartSettleProvider =
    Provider<Duration>((ref) => const Duration(milliseconds: 2500));

/// Помнит неудачный запуск VPN с M3E-главной: `true` — «Сервер не отвечает».
///
/// Правило. Попытка начинается, когда пользователь нажал кнопку и запуск реально запрошен
/// (окно раскрытия не отменено): [requested]. Попытка кончается неудачей, если
/// `isConnecting` прошёл true→false, а после паузы [m3eStartSettleProvider] `runTime`
/// всё ещё `null`. Любая новая попытка сбрасывает ошибку; включение VPN (`runTime` не
/// `null`) закрывает попытку и сбрасывает ошибку. Запуск без `isConnecting` (режим
/// «только прокси», отказ до старта) сюда не попадает: без признака «шёл запуск» ошибку
/// не придумываем.
class M3eStartFailure extends Notifier<bool> {
  bool _pending = false;
  bool _sawConnecting = false;
  Timer? _timer;

  @override
  bool build() {
    ref
      ..listen<bool>(m3eConnectingProvider, (prev, next) {
        if (!_pending) return;
        if (next) {
          _sawConnecting = true;
          _timer?.cancel();
        } else if (_sawConnecting) {
          _timer?.cancel();
          _timer = Timer(ref.read(m3eStartSettleProvider), _settle);
        }
      })
      ..listen<int?>(runTimeProvider, (prev, next) {
        if (next == null) return;
        _finish();
        state = false;
      })
      ..onDispose(() => _timer?.cancel());
    return false;
  }

  /// Запуск запрошен: прошлая ошибка снимается, начинается новая попытка.
  void requested() {
    _timer?.cancel();
    _pending = true;
    _sawConnecting = ref.read(m3eConnectingProvider);
    state = false;
  }

  void _settle() {
    if (!_pending) return;
    final failed = ref.read(runTimeProvider) == null;
    _finish();
    if (failed) state = true;
  }

  void _finish() {
    _timer?.cancel();
    _pending = false;
    _sawConnecting = false;
  }
}

final m3eStartFailureProvider =
    NotifierProvider<M3eStartFailure, bool>(M3eStartFailure.new);

/// Узел, через который сейчас идёт трафик; `null` — VPN выключен или групп нет. Нужен
/// главной только как сигнал «маршрут сменился»: новый узел даёт новый выходной адрес, и
/// адрес на карточке надо перепроверить. Публичный, чтобы тест подменял выбор.
///
/// Сначала группа из заголовка `dropweb-serverinfo` (выбор провайдера). Без заголовка
/// или если такой группы нет, берём первую группу из `currentGroupsState`: в режиме
/// правил это порядок `proxy-groups` шаблона, где главный маршрут стоит первым (так же
/// `detectPrimaryRouter` откатывается на первую подходящую группу), а в глобальном
/// режиме первой идёт `GLOBAL`, через неё и идёт трафик. Страна и «Умный» привязываются
/// к этому же маршрутизатору.
final m3eRouteNodeProvider = Provider<String?>((ref) {
  // `select` по null-флагу, чтобы не пересобираться на каждый тик `runTime` (раз в 2 с).
  final on = ref.watch(runTimeProvider.select((t) => t != null));
  if (!on) return null;
  final profile = ref.watch(currentProfileProvider);
  final groups = ref.watch(currentGroupsStateProvider.select((s) => s.value));

  Group? group;
  final raw = profile?.providerHeaders['dropweb-serverinfo'];
  if (raw != null && raw.isNotEmpty) {
    final name = decodeMaybeBase64(raw);
    if (name.isNotEmpty) group = groups.getGroup(name);
  }
  group ??= groups.firstOrNull;
  if (group == null) return null;

  // Как строка группы в листе «Серверы и группы»: то, что ядро выбирает сейчас, а не
  // сохранённый пин (отказавший узел группа с проверкой уже бросила).
  final pin = ref.watch(getProxyNameProvider(group.name)) ?? '';
  final selected = group.resolveSelectedName(pin);
  // Пустое имя у неприкреплённой «Умной» группы: узлом считается сама группа.
  return selected.isNotEmpty ? selected : group.name;
});

/// Хост из адреса, если разобрать не удалось — сама строка.
String _hostOf(String url) =>
    Uri.tryParse(url)?.host.isNotEmpty == true ? Uri.parse(url).host : url;

M3eHomeSubscription? _subscriptionOf(SubscriptionInfo? info) {
  if (info == null) return null;
  final expire = info.expire;
  return M3eHomeSubscription(
    usedBytes: info.upload + info.download,
    totalBytes: info.total,
    // 0 — бессрочно; иначе секунды Unix.
    expire:
        expire > 0 ? DateTime.fromMillisecondsSinceEpoch(expire * 1000) : null,
  );
}

/// Вход главной, собранный из приложения. Тесты подменяют его через
/// `m3eHomeInputProvider.overrideWithValue(...)`.
final m3eHomeInputProvider = Provider<M3eHomeInput>((ref) {
  final runTimeMs = ref.watch(runTimeProvider);
  final connecting = ref.watch(m3eConnectingProvider);
  final detection = ref.watch(_detectionProvider);
  final profile = ref.watch(currentProfileProvider);
  // Пока связь не проверена, считаем сеть есть: «Нет сети» не должна мигать при старте.
  final online = ref.watch(m3eOnlineProvider).valueOrNull ?? true;
  final startFailed = ref.watch(m3eStartFailureProvider);

  final headers = profile?.providerHeaders ?? const <String, String>{};
  final linksTappable = announceLinksTappable();
  final rawAnnounce = headers['announce'];
  var announce = (rawAnnounce == null || rawAnnounce.isEmpty)
      ? ''
      : decodeMaybeBase64(rawAnnounce).trim();
  if (announce.isEmpty) {
    // Без объявления под чертой показываем сайт провайдера: в магазинной сборке
    // только хост, без нажимаемой ссылки.
    final site = headers['profile-web-page-url'] ?? headers['support-url'];
    if (site != null && site.isNotEmpty) {
      announce = linksTappable ? site : _hostOf(site);
    }
  }

  return M3eHomeInput(
    vpnOn: runTimeMs != null,
    connecting: connecting,
    runTime: runTimeMs == null ? null : Duration(milliseconds: runTimeMs),
    switching: _kSwitching,
    error: startFailed,
    online: online,
    ipAddress: detection.ipInfo?.ip,
    ipCountryCode: detection.ipInfo?.countryCode,
    subscription: _subscriptionOf(profile?.subscriptionInfo),
    providerName: profile?.serviceName ?? '',
    announce: announce,
    linksTappable: linksTappable,
  );
});

/// Сигнал «пора перепроверить внешний адрес»: номер проверки, который двигает контроллер
/// (смена профиля, остановка VPN, смена сети), и флаг «VPN включён». Чистый адаптер без
/// побочных эффектов; тесты подменяют значение.
final m3eIpCheckSignalProvider = Provider<(int, bool)>((ref) {
  final num = ref.watch(checkIpNumProvider);
  final on = ref.watch(runTimeProvider.select((t) => t != null));
  return (num, on);
});

/// Операции над внешним адресом для смены туннеля: прочитать показанный, сбросить в «—»,
/// проверить без промежуточных сбросов. Отдельный объект, чтобы тест подменял
/// `detectionState`.
class M3eIpRefresh {
  const M3eIpRefresh({
    required this.read,
    required this.reset,
    required this.checkQuiet,
  });

  /// Настоящая реализация поверх `detectionState`.
  factory M3eIpRefresh.app() => M3eIpRefresh(
        read: () => detectionState.state.value.ipInfo?.ip,
        reset: () {
          // Летящий ответ прежней проверки не должен вернуть старый адрес после сброса.
          detectionState.cancelToken?.cancel();
          detectionState.cancelToken = null;
          detectionState.state.value = detectionState.state.value
              .copyWith(isLoading: true, ipInfo: null);
        },
        checkQuiet: detectionState.checkQuiet,
      );

  final String? Function() read;
  final void Function() reset;
  final Future<void> Function() checkQuiet;
}

final m3eIpRefreshProvider =
    Provider<M3eIpRefresh>((ref) => M3eIpRefresh.app());

/// Пауза до первой проверки после смены туннеля. После включения VPN или смены узла
/// контроллер заново применяет профиль через `applyProfileDebounce` (600 мс), и ядро в это
/// время не маршрутизирует; 700 мс = дебаунс + небольшой запас. Дальше добирают повторы.
final m3eIpSettleProvider =
    Provider<Duration>((ref) => const Duration(milliseconds: 700));

/// Пауза между повторами, если адрес не изменился. Сама проверка идёт 1–3 с, туннель
/// переустанавливается до ~3 с; два повтора с паузой 2 с дают окно около 5–7 с и не
/// долбят сервис определения адреса.
final m3eIpRetryPauseProvider =
    Provider<Duration>((ref) => const Duration(seconds: 2));

/// Сколько показывать индикатор вместо адреса, пока адреса нет: первая проверка (дебаунс
/// 1,2 с и запрос 1–3 с) и проверки по сигналу контроллера. Запас с потолком, а не флаг
/// «идёт»: `detectionState.isLoading` при ошибке запроса остаётся `true` навсегда и
/// крутил бы индикатор бесконечно. Дальше — прочерк.
final m3eIpWaitProvider =
    Provider<Duration>((ref) => const Duration(seconds: 8));

/// Число повторов после первой проверки (всего до трёх запросов).
const int kM3eIpRetries = 2;

/// Потолок ожидания сигнала контроллера после включения VPN. Профиль переприменяется
/// через ~0,6 с после поднятия туннеля, а сигнал проверки адреса приходит в конце
/// переприменения (~1,3 с). Ждём его, чтобы проверять уже по готовому маршруту, а не
/// посреди переприменения; если сигнала нет — проверяем по потолку.
final m3eIpConnectWaitProvider =
    Provider<Duration>((ref) => const Duration(seconds: 3));

/// Пауза между сигналом контроллера и проверкой: серия сигналов (смена узла + остановка
/// переприменения) схлопывается в одну проверку.
final m3eIpBumpDelayProvider =
    Provider<Duration>((ref) => const Duration(milliseconds: 300));

/// Окно после включения VPN, в котором смена узла считается частью подключения, а не
/// действием пользователя: переприменение профиля подставляет узел (null→X или X→Y), и
/// это не новый маршрут.
final m3eIpGraceProvider =
    Provider<Duration>((ref) => const Duration(seconds: 5));

/// Журнал последовательности проверок адреса (`[m3e-ip]`). Провайдер, чтобы тесты не
/// писали в файловый журнал приложения.
final m3eIpLogProvider = Provider<void Function(String)>(
  (ref) => (message) => commonPrint.log('[m3e-ip] $message'),
);
