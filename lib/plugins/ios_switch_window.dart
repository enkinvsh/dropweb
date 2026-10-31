import 'package:flutter/foundation.dart';

/// Окно запланированного переключения маршрута на iOS.
///
/// На iOS ядро внутри приложения ходит в сеть (health-check групп сразу после
/// перезагрузки конфига, замеры задержки) через системный VPN, то есть через
/// расширение PacketTunnel. Когда мы сами перезапускаем туннель (смена
/// страны/«Авто»/«Весь трафик») или пересылаем в расширение
/// `changeProxy`/`closeConnections` (смена узла), эти соединения рвутся, и
/// ядро пишет ERROR вида `EOF` / `unexpected EOF` / `connection reset by peer`.
/// `ClashManager.onLog` превращал их в тост «Соединение с сервером потеряно»
/// на каждое переключение сервера (жалоба владельца на сборке 2050000029).
///
/// То же происходит при запуске и остановке туннеля: маршрут приложения
/// переключается между «напрямую» и «через расширение», и идущие в этот момент
/// замеры задержки и загрузки провайдеров получают обрыв.
///
/// Окно открывается только из iOS-кода (`ClashLibIos`, `syncIosTunnelConfig`,
/// запуск и остановка туннеля в `handleStart`/`handleStop`), поэтому на Android
/// и десктопе оно всегда закрыто.
class IosPlannedSwitchWindow {
  IosPlannedSwitchWindow._();

  /// Запас после конца переключения: health-check ядра и проверки IP,
  /// начатые до разрыва, досыпают свои ошибки ещё несколько секунд
  /// (таймауты проверок в шаблонах панели — 5 с).
  static const grace = Duration(seconds: 8);

  static int _active = 0;
  static DateTime? _until;

  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// Начало переключения; каждому [begin] должен соответствовать [end].
  static void begin() {
    _active++;
  }

  /// Конец переключения: окно держится ещё [grace].
  static void end() {
    if (_active > 0) _active--;
    _extend(grace);
  }

  /// Выполняет [body] внутри окна; [end] вызывается и при исключении.
  static Future<T> around<T>(Future<T> Function() body) async {
    begin();
    try {
      return await body();
    } finally {
      end();
    }
  }

  /// Короткое переключение без явного конца (пересылка действия).
  static void mark([Duration duration = grace]) => _extend(duration);

  static void _extend(Duration duration) {
    final until = now().add(duration);
    if (_until == null || until.isAfter(_until!)) _until = until;
  }

  static bool get isActive {
    if (_active > 0) return true;
    final until = _until;
    return until != null && now().isBefore(until);
  }

  @visibleForTesting
  static void reset() {
    _active = 0;
    _until = null;
    now = DateTime.now;
  }
}

/// Ошибки обрыва уже открытого соединения — ровно то, что даёт наш собственный
/// разрыв туннеля. Ошибки настройки (порт занят, авторизация, DNS, таймаут
/// подключения к серверу) сюда не входят и показываются даже в окне.
final _plannedDropError = RegExp(
  r'\bunexpected EOF\b|\bEOF\b|connection reset by peer|broken pipe|'
  r'use of closed network connection|connection aborted|'
  r'software caused connection abort',
  caseSensitive: false,
);

bool isPlannedSwitchDropError(String payload) =>
    _plannedDropError.hasMatch(payload);

/// Пуш ядра `{type: log, data: {LogLevel: error, Payload: …}}` с обрывом
/// соединения в окне переключения → та же запись с уровнем `warning`.
/// `ClashManager.onLog` тостит только `error`, так что тоста не будет, а
/// запись остаётся в журнале приложения. Всё остальное — `null` (без правки).
Map<String, Object?>? downgradePlannedSwitchLog(
  Object? message, {
  required bool inWindow,
}) {
  if (!inWindow || message is! Map || message['type'] != 'log') return null;
  final data = message['data'];
  if (data is! Map || data['LogLevel'] != 'error') return null;
  final payload = data['Payload'];
  if (payload is! String || !isPlannedSwitchDropError(payload)) return null;
  return <String, Object?>{
    ...message.cast<String, Object?>(),
    'data': <String, Object?>{
      ...data.cast<String, Object?>(),
      'LogLevel': 'warning',
    },
  };
}
