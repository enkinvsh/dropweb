// Индикатор активности iOS и наблюдатель «приложение на переднем плане» для бесконечных анимаций.
//
// Доска: app.js:435 (`spinner()`), app.css:94-110 (`.spin`), app.css:610 (Reduce Motion).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Следит за жизненным циклом приложения и сообщает, на переднем ли оно плане.
///
/// Бесконечные анимации и секундные таймеры в фоне не нужны: `TickerMode` гасит только поддерево,
/// скрытое маршрутом, а свёрнутое приложение (`paused`/`hidden`/`detached`) видит лишь binding.
/// Один наблюдатель на виджет, [dispose] обязателен.
class Ios27Foreground with WidgetsBindingObserver {
  Ios27Foreground(this.onChange) {
    _active = _isActive(WidgetsBinding.instance.lifecycleState);
    WidgetsBinding.instance.addObserver(this);
  }

  /// Зовётся только при смене значения [active].
  final VoidCallback onChange;

  bool _active = true;

  /// `true`, пока приложение на переднем плане (до первого события жизненного цикла — тоже).
  bool get active => _active;

  static bool _isActive(AppLifecycleState? state) =>
      state != AppLifecycleState.paused &&
      state != AppLifecycleState.hidden &&
      state != AppLifecycleState.detached;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final next = _isActive(state);
    if (next == _active) {
      return;
    }
    _active = next;
    onChange();
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);
}

/// Ступенчатые часы вместо `Ticker`: `AnimationController.repeat` просит кадр на каждом vsync
/// (62,5 кадра/с), даже если картинка меняется 8 раз в секунду. Периодический [Timer] просит кадр
/// только на смене ступени. Прецедент в репозитории: `lib/widgets/mesh_background.dart`.
///
/// `Timer` не знает про `TickerMode` и жизненный цикл, поэтому владелец обязан сам вызывать
/// [start]/[stop] по `TickerMode.getNotifier` и [Ios27Foreground]. Время считается числом тиков, а
/// не часами: детерминированно в тестах и без дрейфа, пока таймер идёт.
class Ios27SteppedClock {
  Ios27SteppedClock({required Duration period, required this.onStep})
      : _period = period;

  final VoidCallback onStep;
  Duration _period;
  Timer? _timer;
  int _ticks = 0;

  Duration get period => _period;
  bool get running => _timer != null;

  /// Число прошедших тиков с последнего [reset].
  int get ticks => _ticks;

  /// Время на часах: `ticks × period`.
  Duration get elapsed => _period * _ticks;

  /// Запускает часы; другой [period] у идущих часов перезапускает их с нуля.
  void start([Duration? period]) {
    final next = period ?? _period;
    if (_timer != null && next == _period) {
      return;
    }
    _timer?.cancel();
    if (next != _period) {
      _ticks = 0;
    }
    _period = next;
    _timer = Timer.periodic(_period, (_) {
      _ticks++;
      onStep();
    });
  }

  /// Останавливает часы, не сбрасывая время: после паузы движение продолжается с того же места.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void reset() => _ticks = 0;

  void dispose() => stop();
}

/// Индикатор активности iOS: 8 спиц, крутится шагами по одной (`steps(8)`).
///
/// Геометрия и прозрачности спиц — `.spin` доски: спица `0.143·size × 0.371·size` от верха
/// центра, первая плотная, остальные `.15….87` против часовой по возрастанию. Цвет — [color]
/// (на доске `currentColor`).
///
/// Период 1 с; при «Уменьшить движение» 2 с и всё равно крутится (app.css:610): без него
/// индикатор был бы мёртвой картинкой, а он единственный знак, что IP ещё определяется.
/// Шагает [Ios27SteppedClock] (8 кадров/с вместо 62,5 у Ticker). В фоне и под `TickerMode(false)`
/// не крутится и не будит кадры.
class Ios27ActivityIndicator extends StatefulWidget {
  const Ios27ActivityIndicator({super.key, this.size = 20, this.color});

  /// Сторона квадрата, логические пиксели (уже умноженная на масштаб шрифта).
  final double size;

  /// Цвет спиц; `null` — `DefaultTextStyle` (как `currentColor`).
  final Color? color;

  @override
  State<Ios27ActivityIndicator> createState() => _Ios27ActivityIndicatorState();
}

class _Ios27ActivityIndicatorState extends State<Ios27ActivityIndicator> {
  // Ступень меняется 8 раз за оборот: перерисовка только на смене, а не каждый кадр.
  final ValueNotifier<int> _step = ValueNotifier<int>(0);
  late final Ios27SteppedClock _clock = Ios27SteppedClock(
    // 125 мс = 1 с / 8 ступеней (`steps(8)` доски).
    period: const Duration(milliseconds: 125),
    onStep: () => _step.value = _clock.ticks % 8,
  );
  late final Ios27Foreground _foreground = Ios27Foreground(_sync);
  ValueListenable<TickerModeData>? _tickerMode;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    // `Timer` не гасится `TickerMode` сам, поэтому слушаем его вручную.
    final notifier = TickerMode.getValuesNotifier(context);
    if (!identical(notifier, _tickerMode)) {
      _tickerMode?.removeListener(_sync);
      _tickerMode = notifier..addListener(_sync);
    }
    _sync();
  }

  void _sync() {
    if (_foreground.active && (_tickerMode?.value.enabled ?? true)) {
      // При «Уменьшить движение» оборот 2 с (app.css:610): ступень 250 мс.
      _clock.start(Duration(milliseconds: _reduceMotion ? 250 : 125));
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _tickerMode?.removeListener(_sync);
    _foreground.dispose();
    _clock.dispose();
    _step.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? DefaultTextStyle.of(context).style.color;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _SpokesPainter(_step, color ?? const Color(0xFF000000)),
        ),
      ),
    );
  }
}

class _SpokesPainter extends CustomPainter {
  _SpokesPainter(this.step, this.color) : super(repaint: step);

  final ValueNotifier<int> step;
  final Color color;

  // `.spin i:nth-child(n)`: первая спица плотная, остальные нарастают на 0.12.
  static const _opacity = [1.0, .15, .27, .39, .51, .63, .75, .87];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final w = s * .143;
    final h = s * .371;
    final paint = Paint();
    // Вращается весь индикатор: оборот шагами по 45° против набора спиц, как `rotate` у `.spin`.
    final base = step.value * math.pi / 4;
    for (var k = 0; k < 8; k++) {
      canvas
        ..save()
        ..translate(s / 2, s / 2)
        ..rotate(base + k * math.pi / 4);
      paint.color = color.withValues(alpha: color.a * _opacity[k]);
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-w / 2, -s / 2, w, h),
            Radius.circular(w / 2),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_SpokesPainter old) =>
      old.color != color || old.step != step;
}
