// Ползунок «Стекло» страницы «Оформление»: шкала от прозрачного до тонированного и подписи под ней
// (доска: `.slider-row`, `.slider`, `.slider-caps`, app.css:631-651; значение и подпись `glassName`,
// app.js:425-427, 1272-1278).
//
// Нативный `<input type=range>` доски во Flutter не нужен: рисуем сами, чтобы повторить ручку 37×24,
// длину заливки `18.5 + (W − 37) · v / 100` и линзу под пальцем.

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/screens/appearance/ios27_glass_level.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart'
    show Ios27Motion, Ios27SpringSpec, Ios27Text;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Высота ползунка (`.slider{height:28px}`).
const double kIos27SliderHeight = 28;

/// Толщина дорожки и радиус её скругления (`::-webkit-slider-runnable-track`, 6 и 3).
const double kIos27SliderTrack = 6;

/// Ручка в покое: 37×24, радиус 12.
const double kIos27SliderThumbWidth = 37;
const double kIos27SliderThumbHeight = 24;

/// Поля строки ползунка: `padding: 14px 16px 12px`.
const EdgeInsets kIos27SliderRowPadding = EdgeInsets.fromLTRB(16, 14, 16, 12);

/// Зазор между ползунком и подписями (`.slider-caps{margin-top:6px}`).
const double kIos27SliderCapsGap = 6;

/// Увеличение ручки под пальцем: `scale: 1.54 1.58`.
const double kIos27SliderPressScaleX = 1.54;
const double kIos27SliderPressScaleY = 1.58;

// Серые кромки линзы под пальцем: `0 0 0 1px light-dark(#D9D9D9, #8C8C8C)` (app.css:645).
// В палитре токенов такого цвета нет, поэтому берётся через `Ios27Rgb`, как белый и чёрный.
const Ios27Rgb _rimLight = Ios27Rgb(0xD9, 0xD9, 0xD9);
const Ios27Rgb _rimDark = Ios27Rgb(0x8C, 0x8C, 0x8C);

/// Ползунок с целым значением 0..100.
///
/// * Заливка дорожки идёт до центра ручки (`--v`, app.js:427), остальное `--fill-1`.
/// * Нажатие (тап) на дорожку переносит ручку под палец, а касание, ушедшее в вертикальную
///   прокрутку страницы, значения не меняет; нажатие на саму ручку её не дёргает (ручка
///   остаётся там, где её схватили, как в Chrome).
/// * Под пальцем ручка растёт и становится линзой (`#FFFFFF33` светлая / `#FFFFFF1A` тёмная);
///   размытие линзы доски не повторяется (сырой `BackdropFilter` запрещён). При Reduce
///   Transparency ручка остаётся белой (app.css:661), при «Уменьшить движение» не растёт.
/// * Для VoiceOver это регулируемый элемент: значение читается словами ([valueText]), смахивание
///   вверх/вниз двигает на [kIos27GlassAccessibilityStep] единиц. Шаг на доске равен 1; мелкий шаг
///   для смахиваний слишком долог, поэтому 5 (в обычном касании значение по-прежнему целое).
class Ios27GlassSlider extends StatefulWidget {
  const Ios27GlassSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.valueText,
    this.semanticIdentifier,
  });

  /// Текущее значение 0..100.
  final int value;

  /// Вызывается только при реальной смене значения.
  final ValueChanged<int> onChanged;

  /// Подпись для VoiceOver («Стекло»).
  final String label;

  /// Значение словами для VoiceOver («Стандартное»).
  final String Function(int value) valueText;

  final String? semanticIdentifier;

  @override
  State<Ios27GlassSlider> createState() => _Ios27GlassSliderState();
}

class _Ios27GlassSliderState extends State<Ios27GlassSlider>
    with SingleTickerProviderStateMixin {
  // Раздутие ручки под пальцем `0..1` (пружина с отскоком выходит за границы).
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  bool _reduceMotion = false;
  bool _pressed = false;

  // Смещение точки захвата от центра ручки: ручка не прыгает под палец, если её схватили.
  double _grab = 0;

  // Касание началось на самой ручке: подъём без перетаскивания значение не меняет.
  bool _downOnThumb = false;
  double _width = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _drive(Ios27SpringSpec spec, double to) {
    _press.animateWith(
      SpringSimulation(spec.description, _press.value, to, _press.velocity),
    );
  }

  double get _span => _width - kIos27SliderThumbWidth;

  double _thumbLeft(int value) => _span * value / 100;

  int _valueAt(double dx) {
    if (_span <= 0) {
      return widget.value;
    }
    final centre = dx - _grab - kIos27SliderThumbWidth / 2;
    return (centre / _span * 100).round().clamp(0, 100);
  }

  void _set(int value) {
    final next = value.clamp(0, 100);
    if (next != widget.value) {
      widget.onChanged(next);
    }
  }

  // Касание только запоминает захват и раздувает ручку. Значение здесь не пишется: пока арена
  // не решила, горизонтальное это перетаскивание или вертикальная прокрутка страницы, палец
  // ничего не выбрал. Иначе прокрутка «Оформления», начатая на дорожке, включала бы своё
  // значение и выключала «Как в системе» (решение владельца 30.10: своё значение только после
  // движения ползунка).
  void _down(DragDownDetails details) {
    final dx = details.localPosition.dx;
    final left = _thumbLeft(widget.value);
    final onThumb = dx >= left && dx <= left + kIos27SliderThumbWidth;
    _grab = onThumb ? dx - (left + kIos27SliderThumbWidth / 2) : 0;
    _downOnThumb = onThumb;
    if (!_reduceMotion) {
      _pressed = true;
      _drive(Ios27Motion.springInteractive, 1);
    }
  }

  // Горизонтальное перетаскивание выиграло арену: с этого момента палец двигает значение.
  void _start(DragStartDetails details) =>
      _set(_valueAt(details.localPosition.dx));

  void _update(DragUpdateDetails details) =>
      _set(_valueAt(details.localPosition.dx));

  // Простое нажатие на дорожку переносит ручку под палец (как нативный range в Chrome). Если
  // касание началось на самой ручке, она уже под пальцем: живой палец при подъёме смещается на
  // 2-5 pt, и запись этой точки меняла бы значение без намерения тянуть и молча выключала бы
  // «Как в системе». Настоящее движение ручки приходит через горизонтальное перетаскивание.
  void _tap(TapUpDetails details) {
    if (_downOnThumb) {
      return;
    }
    _set(_valueAt(details.localPosition.dx));
  }

  // Палец ушёл (подъём, отмена жеста, конец перетаскивания): ручка возвращается пружиной.
  void _release() {
    if (_pressed) {
      _pressed = false;
      _drive(Ios27Motion.springBouncy, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Ios27Colors.of(context);
    final palette = colors.palette;
    final dark = colors.dark;
    const step = kIos27GlassAccessibilityStep;
    final value = widget.value;
    return Ios27A11yBuilder(
      builder: (context, a11y) => Semantics(
        container: true,
        slider: true,
        identifier: widget.semanticIdentifier,
        label: widget.label,
        value: widget.valueText(value),
        increasedValue: widget.valueText((value + step).clamp(0, 100)),
        decreasedValue: widget.valueText((value - step).clamp(0, 100)),
        onIncrease: value < 100 ? () => _set(value + step) : null,
        onDecrease: value > 0 ? () => _set(value - step) : null,
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, box) {
              _width = box.maxWidth;
              final fill = _thumbLeft(value) + kIos27SliderThumbWidth / 2;
              final share = _width <= 0 ? 0.0 : (fill / _width).clamp(0.0, 1.0);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragDown: _down,
                onHorizontalDragStart: _start,
                onHorizontalDragUpdate: _update,
                onHorizontalDragEnd: (_) => _release(),
                onHorizontalDragCancel: _release,
                onTapUp: _tap,
                child: SizedBox(
                  key: const ValueKey<String>('page.slider'),
                  height: kIos27SliderHeight,
                  child: AnimatedBuilder(
                    animation: _press,
                    builder: (context, _) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: (kIos27SliderHeight - kIos27SliderTrack) / 2,
                          height: kIos27SliderTrack,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                kIos27SliderTrack / 2,
                              ),
                              // Жёсткая граница на `--v`: `linear-gradient(90deg, accent v, fill-1 v)`.
                              gradient: LinearGradient(
                                colors: [
                                  colors.accentColor,
                                  colors.accentColor,
                                  palette.fill1,
                                  palette.fill1,
                                ],
                                stops: [0, share, share, 1],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: _thumbLeft(value),
                          top: (kIos27SliderHeight - kIos27SliderThumbHeight) /
                              2,
                          child: _Thumb(
                            press: _press.value,
                            dark: dark,
                            opaque: a11y.reduceTransparency,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Ручка: белая в покое, линза с кромкой под пальцем.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.press,
    required this.dark,
    required this.opaque,
  });

  final double press;
  final bool dark;
  final bool opaque;

  @override
  Widget build(BuildContext context) {
    final lens = press.clamp(0.0, 1.0);
    // Под пальцем заливка почти прозрачная, при Reduce Transparency остаётся белой.
    final lensFill = Colors.white.withAlpha(dark ? 0x1A : 0x33);
    final fill =
        opaque ? Colors.white : Color.lerp(Colors.white, lensFill, lens)!;
    final shadow = Colors.black.withAlpha(0x1F);
    final rim = (dark ? _rimDark : _rimLight).color;
    return Transform.scale(
      scaleX: 1 + (kIos27SliderPressScaleX - 1) * press,
      scaleY: 1 + (kIos27SliderPressScaleY - 1) * press,
      child: DecoratedBox(
        key: const ValueKey<String>('slider.thumb'),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(kIos27SliderThumbHeight / 2),
          boxShadow: [
            // В покое: `0 6px 13px #0000001F, 0 .5px 4px #0000001F`; под пальцем их заменяют
            // кромка `0 0 0 1px` и тень `0 4px 12px`.
            BoxShadow(
              color: shadow.withValues(alpha: shadow.a * (1 - lens)),
              blurRadius: 13,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: shadow.withValues(alpha: shadow.a * (1 - lens)),
              blurRadius: 4,
              offset: const Offset(0, 0.5),
            ),
            if (lens > 0)
              BoxShadow(color: rim.withValues(alpha: lens), spreadRadius: 1),
            if (lens > 0)
              BoxShadow(
                color: shadow.withValues(alpha: shadow.a * lens),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: const SizedBox(
          width: kIos27SliderThumbWidth,
          height: kIos27SliderThumbHeight,
        ),
      ),
    );
  }
}

/// Строка ползунка целиком: сам ползунок и подписи краёв шкалы.
///
/// Читает и пишет уровень стекла через провайдер: пока включено «Как в системе», ручка стоит на
/// стандартных 25, а первое же движение переключает на своё значение.
class Ios27GlassSliderRow extends ConsumerWidget {
  const Ios27GlassSliderRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(ios27GlassSliderValueProvider);
    final actions = ref.read(ios27GlassLevelActionsProvider);
    final palette = Ios27Colors.of(context).palette;
    final caption =
        ios27Text(context, Ios27Text.footnote, color: palette.label2);
    return Padding(
      key: const ValueKey<String>('page.sliderRow'),
      padding: kIos27SliderRowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Ios27GlassSlider(
            value: value,
            onChanged: actions.setLevel,
            label: l10n.ios27GlassTitle,
            valueText: (v) => ios27GlassName(l10n, v),
            semanticIdentifier: 'dw_appearance_glass_slider',
          ),
          const SizedBox(height: kIos27SliderCapsGap),
          Row(
            key: const ValueKey<String>('page.sliderCaps'),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Подписи гибкие: при крупном шрифте они переносятся, а не вылезают за край.
              Flexible(child: Text(l10n.ios27GlassCapClear, style: caption)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.ios27GlassTinted,
                  style: caption,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
