// Живой таймер сеанса на главной: тикает раз в секунду по границе секунды.
//
// Источник `runTimeProvider` обновляет цепочка `globalState.startUpdateTasks` раз в 2 с
// (её период общий для трафика и других экранов, менять его нельзя), поэтому цифры
// секунд шли через одну. Здесь запоминаем момент старта и считаем секунды сами.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../m3e_format.dart';

/// «Сейчас» для таймера. Тесты подставляют часы fake-async (`tester.binding.clock.now`):
/// `DateTime.now()` виртуальное время не видит.
final m3eTickClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

/// Строка `m:ss` текущего сеанса или `null`, когда VPN выключен.
///
/// Таймер платформы запущен только пока [setTick] получил `true`: экран виден (не закрыт
/// другим маршрутом) и приложение на переднем плане. Иначе ни таймеров, ни кадров:
/// при выключенном VPN и под закрытым маршрутом экран ничего не будит.
class M3eElapsedClock extends ValueNotifier<String?> {
  M3eElapsedClock(this._now) : super(null);

  final DateTime Function() _now;

  /// Момент старта сеанса. Берётся из первого значения `runTime` и дальше не
  /// пересчитывается от каждого обновления: задержка доставки (миллисекунды) сдвигала бы
  /// его туда-сюда, и секунда на экране на миг откатывалась бы назад.
  DateTime? _anchor;
  Timer? _timer;
  bool _tick = false;

  /// Расхождение, после которого это уже другой сеанс (переподключение, лечение
  /// `startTime`), а не дрожание доставки.
  static const Duration _reanchorGap = Duration(milliseconds: 1500);

  /// Ниже этого ожидания таймер не ставим: часы стены и таймер Dart могут разойтись на
  /// миллисекунду, и тик пришёл бы чуть раньше границы.
  static const Duration _minWait = Duration(milliseconds: 5);

  /// Идёт ли локальный таймер (для тестов).
  bool get ticking => _timer != null;

  /// Свежее значение источника: [runTime] — длительность сеанса на момент его записи
  /// (`null` — VPN выключен).
  ///
  /// Звать только на новое значение источника: по возвращении из фона в провайдере лежит
  /// устаревшее число, и пересчёт якоря от него откатил бы таймер назад.
  void update(Duration? runTime) {
    if (runTime == null) {
      _stop();
      _anchor = null;
      value = null;
      return;
    }
    final candidate = _now().subtract(runTime);
    final anchor = _anchor;
    if (anchor == null || candidate.difference(anchor).abs() > _reanchorGap) {
      _anchor = candidate;
    }
    _publish();
    _apply();
  }

  /// Нужен ли бег по секундам (экран виден и приложение на переднем плане).
  void setTick({required bool tick}) {
    _tick = tick;
    if (_anchor != null) _publish();
    _apply();
  }

  void _apply() {
    if (_anchor == null || !_tick) {
      _stop();
    } else if (_timer == null) {
      _schedule();
    }
  }

  void _publish() => value = elapsedText(_now().difference(_anchor!));

  void _schedule() {
    final past = _now().difference(_anchor!).inMicroseconds % 1000000;
    var wait = Duration(microseconds: 1000000 - past);
    if (wait < _minWait) wait = _minWait;
    _timer = Timer(wait, () {
      _timer = null;
      _publish();
      _schedule();
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}
