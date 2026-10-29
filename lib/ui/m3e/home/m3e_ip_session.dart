// Одна последовательность проверки внешнего адреса на главной.
//
// Подключение даёт несколько независимых поводов перепроверить адрес: сам туннель
// (runTime null→set), переприменение профиля через ~0,6 с (сигнал контроллера в его
// конце, ~1,3 с) и смена узла, которую это переприменение подставляет. Раньше каждый
// повод сбрасывал адрес и запрашивал его заново, поэтому один и тот же IP появлялся
// дважды. Здесь все поводы сводятся в одну сессию: адрес сбрасывается один раз, индикатор
// держится до конца сессии, промежуточные ответы не показываются.

import 'dart:async';

import 'm3e_home_providers.dart';

/// Адрес для журнала: хвост скрыт, полный адрес пользователя в файл журнала не пишем.
String m3eMaskIp(String? ip) {
  if (ip == null || ip.isEmpty) return '—';
  if (ip.contains(':')) return '${ip.split(':').take(2).join(':')}:x';
  final octets = ip.split('.');
  if (octets.length == 4) return '${octets[0]}.${octets[1]}.x.x';
  return 'x';
}

enum _Phase { idle, waiting, checking }

class M3eIpSession {
  M3eIpSession({
    required this.io,
    required this.settle,
    required this.connectWait,
    required this.afterBump,
    required this.retryPause,
    required this.grace,
    required this.onSettling,
    required this.log,
    this.retries = kM3eIpRetries,
  });

  final M3eIpRefresh io;

  /// Пауза до проверки после выключения VPN или смены узла пользователем.
  final Duration settle;

  /// Потолок ожидания сигнала контроллера после включения VPN.
  final Duration connectWait;

  /// Пауза между сигналом контроллера и проверкой (схлопывает серию сигналов).
  final Duration afterBump;

  final Duration retryPause;

  /// Окно после включения VPN, в котором смена узла — часть подключения.
  final Duration grace;
  final int retries;

  /// Сессия идёт: на месте адреса нужен индикатор. Вызывается только при смене значения.
  final void Function({required bool settling}) onSettling;
  final void Function(String message) log;

  _Phase _phase = _Phase.idle;
  Timer? _timer;
  Timer? _graceTimer;
  int _epoch = 0;
  bool _disposed = false;
  bool _settling = false;

  /// Адрес, который висел до сессии: повтор нужен, если проверка вернула его же
  /// (туннель мог ещё не маршрутизировать).
  String? _before;

  /// Пока шла проверка, пришёл сигнал контроллера: после неё нужна одна тихая сверка.
  bool _stale = false;

  /// Экран появился: адреса нет — спрашиваем один раз, без сброса и сессии.
  void start() {
    if (io.read() != null) return;
    log('trigger start');
    unawaited(_quiet());
  }

  /// Туннель включили или выключили: старый адрес больше не верен.
  void tunnelChanged({required bool on}) {
    log('trigger tunnel ${on ? 'on' : 'off'}');
    _graceTimer?.cancel();
    _graceTimer = null;
    if (on) _graceTimer = Timer(grace, () => _graceTimer = null);
    _begin(on ? connectWait : settle);
  }

  /// Узел или страна сменились.
  void routeChanged() {
    if (_graceTimer?.isActive ?? false) {
      log('route ignored (подключение)');
      return;
    }
    if (_phase != _Phase.idle) {
      log('route ignored (сессия идёт)');
      if (_phase == _Phase.checking) _stale = true;
      return;
    }
    log('trigger route');
    _begin(settle);
  }

  /// Контроллер сообщил, что маршрут применён и адрес пора проверить.
  void bump() {
    switch (_phase) {
      case _Phase.waiting:
        log('bump coalesced');
        _schedule(afterBump);
      case _Phase.checking:
        log('bump during check');
        _stale = true;
      case _Phase.idle:
        log('bump quiet');
        unawaited(_quiet());
    }
  }

  void dispose() {
    _disposed = true;
    _epoch++;
    _timer?.cancel();
    _graceTimer?.cancel();
  }

  void _begin(Duration wait) {
    if (_phase == _Phase.idle) _before = io.read();
    _epoch++;
    _phase = _Phase.waiting;
    _stale = false;
    _setSettling(true);
    io.reset();
    _schedule(wait);
  }

  void _schedule(Duration wait) {
    _timer?.cancel();
    final epoch = _epoch;
    _timer = Timer(wait, () => unawaited(_run(epoch)));
  }

  void _setSettling(bool value) {
    if (_settling == value) return;
    _settling = value;
    onSettling(settling: value);
  }

  Future<void> _run(int epoch) async {
    if (_disposed || epoch != _epoch) return;
    _phase = _Phase.checking;
    for (var attempt = 0; attempt <= retries; attempt++) {
      log('check #${attempt + 1} start');
      await io.checkQuiet();
      if (_disposed || epoch != _epoch) return;
      final address = io.read();
      log('check #${attempt + 1} result ${m3eMaskIp(address)}');
      if (address != null && address != _before) break;
      if (attempt == retries) break;
      log('retry (адрес не изменился)');
      final wait = Completer<void>();
      _timer = Timer(retryPause, wait.complete);
      await wait.future;
      if (_disposed || epoch != _epoch) return;
    }
    final stale = _stale;
    _stale = false;
    _before = null;
    _phase = _Phase.idle;
    _timer = null;
    log('shown ${m3eMaskIp(io.read())}');
    _setSettling(false);
    if (stale) {
      log('recheck after bump');
      unawaited(_quiet());
    }
  }

  /// Проверка без сброса и без индикатора: значение меняется на месте, только если адрес
  /// действительно другой (тот же IP не перерисовывается).
  Future<void> _quiet() async {
    final epoch = _epoch;
    final before = io.read();
    log('quiet start');
    await io.checkQuiet();
    // Началась сессия: решает она, а не эта сверка.
    if (_disposed || epoch != _epoch) return;
    final after = io.read();
    log(after == before
        ? 'quiet unchanged ${m3eMaskIp(after)}'
        : 'quiet changed ${m3eMaskIp(before)} -> ${m3eMaskIp(after)}');
  }
}
