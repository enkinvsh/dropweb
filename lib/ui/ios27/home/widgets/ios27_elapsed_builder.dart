// Строка таймера сеанса `m:ss`: один одноразовый таймер на границу секунды.
//
// Цифры не перекатываются (в отличие от `roll()` доски, motion.js:317-351): в карточке №4 (решение
// владельца 30.10) таймер простой текст, потому что перекат просил бы 47 кадров/с на нативных стёклах.

import 'dart:async';

import 'package:dropweb/ui/ios27/widgets/ios27_activity_indicator.dart'
    show Ios27Foreground;
import 'package:dropweb/ui/m3e/m3e_format.dart' show elapsedText;
import 'package:flutter/widgets.dart';

/// Строка `m:ss` с момента [since], обновляемая раз в секунду по границе секунды.
///
/// Вместо `Ticker`: при «Уменьшить движение» (и в покое) экран не должен просить ни одного
/// кадра, а Ticker просит каждый. Одноразовый [Timer] будится ровно на границу секунды
/// (+5 мс от дрожания часов, иначе тик придёт до границы и цифра отстанет на кадр), перестраивает
/// только [builder] и ставит следующий.
///
/// Таймер стоит, пока приложение в фоне (`paused`/`hidden`/`detached`) или поддерево под
/// `TickerMode(false)`; при возврате строка пересчитывается сразу, а не по старой секунде.
/// [now] подменяется тестами (`tester.binding.clock.now`): `DateTime.now()` fake-async не видит.
class Ios27ElapsedBuilder extends StatefulWidget {
  const Ios27ElapsedBuilder({
    super.key,
    required this.since,
    required this.builder,
    this.now = DateTime.now,
  });

  final DateTime since;
  final DateTime Function() now;
  final Widget Function(BuildContext context, String text) builder;

  @override
  State<Ios27ElapsedBuilder> createState() => _Ios27ElapsedBuilderState();
}

class _Ios27ElapsedBuilderState extends State<Ios27ElapsedBuilder> {
  late final Ios27Foreground _foreground = Ios27Foreground(() {
    if (mounted) {
      setState(_apply);
    }
  });
  Timer? _timer;
  late String _text = _compute();
  bool _tickerEnabled = true;

  String _compute() => elapsedText(widget.now().difference(widget.since));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _apply();
  }

  @override
  void didUpdateWidget(Ios27ElapsedBuilder old) {
    super.didUpdateWidget(old);
    if (old.since != widget.since) {
      _apply();
    }
  }

  /// Согласует таймер с условиями: можно тикать — пересчитываем строку и ставим таймер,
  /// нельзя — снимаем. Строка пересчитывается и здесь: после фона или чужого маршрута показанная
  /// секунда устарела, а следующий тик ждал бы до границы.
  void _apply() {
    _timer?.cancel();
    _timer = null;
    if (!_foreground.active || !_tickerEnabled) {
      return;
    }
    _text = _compute();
    _schedule();
  }

  void _schedule() {
    final elapsedMs = widget.now().difference(widget.since).inMilliseconds;
    final intoSecond = elapsedMs % 1000;
    final wait = Duration(
      milliseconds:
          1000 - (intoSecond < 0 ? intoSecond + 1000 : intoSecond) + 5,
    );
    _timer = Timer(wait, () {
      _timer = null;
      if (!mounted) {
        return;
      }
      setState(() => _text = _compute());
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _foreground.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _text);
}
