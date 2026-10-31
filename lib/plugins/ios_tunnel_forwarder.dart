import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dropweb/plugins/ios_tunnel.dart';
import 'package:flutter/services.dart';

/// NEVPNStatus.connected.
const _statusConnected = 3;

/// Итог пересылки действия ядра в расширение.
enum IosForwardOutcome {
  /// Расширение приняло действие и ответило кодом успеха.
  sent,

  /// Туннель не поднят (или расширение не ответило): слать некому, а выбор
  /// подхватит следующий `start` — он пишет свежие `setup.json`/`state.json`.
  notConnected,

  /// Канал упал, время вышло или ядро расширения вернуло ошибку.
  failed,

  /// Не iOS: канала нет, ничего не отправлялось.
  disabled,
}

/// Пересылает в работающий PacketTunnel те действия ядра, которые меняют
/// маршрут налету.
///
/// Зачем. На iOS ядро в приложении (`ClashLibIos`) офлайновое, а трафик ведёт
/// отдельное ядро в расширении, которое читает `setup.json` один раз при старте.
/// Без пересылки выбор узла в селекторе менял галочку в UI и не менял выход
/// туннеля. Пересылка идёт В ДОПОЛНЕНИЕ к локальному вызову: UI читает группы и
/// задержки из локального ядра, поэтому оно обязано остаться в синхроне.
///
/// Пересылаются только дешёвые операции без разбора конфига (в расширении лимит
/// ~15 МБ на iOS 13–14): выбор члена селектора и закрытие соединений.
/// Всё, что требует разбора конфига, идёт перезапуском туннеля
/// (`GlobalState.syncIosTunnelConfig`).
class IosTunnelForwarder {
  IosTunnelForwarder({
    required this.log,
    IosTunnel? tunnel,
    bool? enabled,
    this.timeout = const Duration(seconds: 5),
  })  : _tunnel = tunnel ?? IosTunnel.instance,
        _enabled = enabled ?? Platform.isIOS;

  /// Методы ядра, которые имеет смысл слать в расширение.
  static const forwardedMethods = {
    'changeProxy',
    'closeConnections',
    'resetConnections',
  };

  /// Действие `changeProxy`/`close*` весит сотни байт. Всё, что больше, —
  /// `setupConfig` и подобные: их не пересылаем и не разбираем, чтобы не
  /// декодировать мегабайты JSON в UI-изоляте на каждый вызов.
  static const _maxActionLength = 4096;

  final void Function(String message) log;
  final Duration timeout;
  final IosTunnel _tunnel;
  final bool _enabled;

  /// Хвост очереди: в полёте не больше одного сообщения, порядок сохраняется
  /// (`changeProxy` обязан дойти раньше следующего за ним `closeConnections`).
  Future<void> _tail = Future<void>.value();

  /// Метод ядра из JSON действия, если его надо переслать; иначе `null`.
  static String? forwardedMethodOf(String actionJson) {
    if (actionJson.length > _maxActionLength) return null;
    try {
      final decoded = json.decode(actionJson);
      if (decoded is! Map) return null;
      final method = decoded['method'];
      return method is String && forwardedMethods.contains(method)
          ? method
          : null;
    } on FormatException {
      return null;
    }
  }

  /// Ставит [actionJson] в очередь и отправляет в расширение, когда туннель
  /// поднят. Никогда не бросает: сбой уходит в журнал, UI о нём не узнаёт.
  Future<IosForwardOutcome> forward(String actionJson) {
    if (!_enabled) return Future.value(IosForwardOutcome.disabled);
    final result = _tail.then((_) => _forwardOne(actionJson));
    _tail = result.then<void>((_) {});
    return result;
  }

  Future<IosForwardOutcome> _forwardOne(String actionJson) async {
    final method = forwardedMethodOf(actionJson) ?? 'action';
    try {
      // Статус проверяем здесь, а не только в Swift: так при выключенном VPN
      // в канал уходит один дешёвый запрос статуса, а не само действие.
      final status = await _tunnel.status().timeout(timeout);
      if (status != _statusConnected) {
        log('[ios-tunnel] $method not forwarded: tunnel status $status');
        return IosForwardOutcome.notConnected;
      }
      final reply = await _tunnel.send(actionJson).timeout(timeout);
      if (reply == null) {
        log('[ios-tunnel] $method: extension did not reply '
            '(tunnel went down)');
        return IosForwardOutcome.notConnected;
      }
      final error = _errorOf(reply);
      if (error != null) {
        log('[ios-tunnel] $method rejected by extension: $error');
        return IosForwardOutcome.failed;
      }
      log('[ios-tunnel] $method forwarded');
      return IosForwardOutcome.sent;
    } on TimeoutException {
      log('[ios-tunnel] $method forward timed out after '
          '${timeout.inSeconds}s');
    } on PlatformException catch (e) {
      log('[ios-tunnel] $method forward failed: ${e.code} ${e.message}');
    } on MissingPluginException {
      log('[ios-tunnel] $method forward failed: channel is not registered');
    } catch (e) {
      log('[ios-tunnel] $method forward failed: $e');
    }
    return IosForwardOutcome.failed;
  }

  /// Текст ошибки из `ActionResult` расширения; `null` — успех.
  ///
  /// Ядро кладёт ошибку в `data` с `code = -1`. Для `changeProxy` успех — это
  /// пустая строка в `data`, а непустая строка при `code = 0` тоже ошибка
  /// (так же читает ответ Android: `fn(err.Error())` в `handleChangeProxy`).
  static String? _errorOf(String reply) {
    try {
      final decoded = json.decode(reply);
      if (decoded is! Map) return 'unexpected reply';
      final data = decoded['data'];
      if (decoded['code'] == -1) return '$data';
      if (data is String && data.isNotEmpty) return data;
      return null;
    } on FormatException {
      return 'unparsable reply';
    }
  }
}

/// Итог перезапуска туннеля.
enum IosRestartOutcome { restarted, notConnected, failed }

/// Перезапуск работающего туннеля: стоп, ожидание остановки, новый старт со
/// свежими `init`/`setup`/`state`. Сам старт передаётся колбэком —
/// `GlobalState._startIosTunnel` — чтобы запись JSON и ожидание `connected`
/// остались в одном месте.
class IosTunnelRestarter {
  IosTunnelRestarter({
    required this.log,
    IosTunnel? tunnel,
    this.stopTimeout = const Duration(seconds: 5),
    this.pollInterval = const Duration(milliseconds: 200),
    this.statusTimeout = const Duration(seconds: 2),
  }) : _tunnel = tunnel ?? IosTunnel.instance;

  final void Function(String message) log;
  final Duration stopTimeout;
  final Duration pollInterval;
  final Duration statusTimeout;
  final IosTunnel _tunnel;

  Future<IosRestartOutcome> restart({
    required Future<bool> Function() start,
  }) async {
    try {
      final status = await _tunnel.status().timeout(statusTimeout);
      if (status != _statusConnected) {
        log('[ios-tunnel] restart skipped: tunnel status $status');
        return IosRestartOutcome.notConnected;
      }
      // Второй stop: если расширение не остановилось, старт поверх живого
      // туннеля вернёт true на старом конфиге (тихое расхождение), а поверх
      // `disconnecting` молча не сработает. Поэтому без остановки — failed.
      var stopped = false;
      for (var attempt = 1; attempt <= 2 && !stopped; attempt++) {
        await _tunnel.stop().timeout(stopTimeout);
        stopped = await _waitStopped();
        if (!stopped) {
          log('[ios-tunnel] restart: tunnel not disconnected after stop '
              '#$attempt');
        }
      }
      if (!stopped) return IosRestartOutcome.failed;
    } on TimeoutException {
      log('[ios-tunnel] restart: stop timed out');
      return IosRestartOutcome.failed;
    } on PlatformException catch (e) {
      log('[ios-tunnel] restart: stop failed: ${e.code} ${e.message}');
      return IosRestartOutcome.failed;
    }
    final started = await start();
    log('[ios-tunnel] restart ${started ? 'done' : 'failed'}');
    return started ? IosRestartOutcome.restarted : IosRestartOutcome.failed;
  }

  /// `stopVPNTunnel` возвращается до остановки расширения; новый старт поверх
  /// `disconnecting` Network Extension молча проглатывает. Зависший `status()`
  /// считается «неизвестно» — то есть не остановлен.
  Future<bool> _waitStopped() async {
    final startedAt = DateTime.now();
    while (DateTime.now().difference(startedAt) < stopTimeout) {
      int? status;
      var known = true;
      try {
        status = await _tunnel.status().timeout(statusTimeout);
      } on TimeoutException {
        known = false;
        log('[ios-tunnel] restart: status() timed out');
      }
      // 0 invalid, 1 disconnected, null — менеджера нет: туннеля нет.
      if (known && (status == null || status <= 1)) return true;
      await Future<void>.delayed(pollInterval);
    }
    return false;
  }
}
