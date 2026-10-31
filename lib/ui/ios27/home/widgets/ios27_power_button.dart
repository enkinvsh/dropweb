// Большая круглая кнопка питания главной (`.power`) со всеми её состояниями.
//
// Доска: app.js:432 (`powerGlass`), app.js:543-561 (`joy()`), app.js:965-979 (смена вида),
// app.css:46-52 и :94-111 (`.power`, `.spin`), glass.css:264-306 (нажатие, Reduce Motion).

import 'dart:ui' show ImageFilter;

import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_circle_button.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart' show Ios27Motion;
import 'package:dropweb/ui/ios27/widgets/ios27_activity_indicator.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Диаметр кнопки питания, `.power` (app.css:46).
const double kIos27PowerButtonSize = 80;

/// Сторона спиннера внутри кнопки: `.power .spin { --s: 30px }` (app.css:94).
const double kIos27PowerSpinnerSize = 30;

/// Идентификатор кнопки питания для автотестов и интеграции со старым UI (`dw_connect`).
const String kIos27PowerSemanticsId = 'dw_connect';

/// Состояние кнопки питания.
///
/// Вид на доске только четырёх сортов (`data-look`: dead, busy, off, on), а состояний
/// приложения больше: [error] и [offline] выглядят как [off] — отличается лишь подпись,
/// которую задаёт вызывающий (`Повторить подключение`, app.js:543-548).
enum Ios27PowerState {
  /// Отключено: стекло, значок питания, нажимается.
  off,

  /// Подключается: вместо значка спиннер `.spin`, подпись `--glass-label-2`, нажатие отменяет.
  connecting,

  /// Подключено: стекло в цвет провайдера, значок на акценте.
  on,

  /// Ошибка подключения: вид как у [off].
  error,

  /// Нет сети: вид как у [off].
  offline,

  /// Подписка истекла или трафик кончился (`blocked()`): не нажимается, значок `--label-3`.
  disabled,
}

/// Вид кнопки, `data-look` доски: смена вида запускает анимацию значка.
enum _Look { dead, busy, off, on }

_Look _lookOf(Ios27PowerState state) {
  switch (state) {
    case Ios27PowerState.disabled:
      return _Look.dead;
    case Ios27PowerState.connecting:
      return _Look.busy;
    case Ios27PowerState.on:
      return _Look.on;
    case Ios27PowerState.off:
    case Ios27PowerState.error:
    case Ios27PowerState.offline:
      return _Look.off;
  }
}

/// Кнопка питания: стеклянный круг 80 со значком питания или спиннером.
///
/// Поведение по доске:
///  * [Ios27PowerState.on] — стекло с тоном провайдера. Тон «просачивается» пружиной smooth
///    (735 мс, `is-tint-in`/`is-tint-out`), цвет значка плавно идёт от `--glass-label` к белому
///    (при Reduce Transparency — к `--on-accent`). Стеклу передаётся ЦЕЛЕВОЕ состояние (есть
///    тон или нет), а плавно его проявляет и гасит само стекло: нативный вид — анимацией
///    `effect`, заглушка — тем же временем. Тон нельзя вести долей пружины: без среза хвоста
///    она садится на ~8.5e-5, а не на 0, и условие `t > 0` оставило бы тон включённым после
///    выключения кнопки. Поэтому пружина здесь ведёт только цвет значка.
///  * Смена вида (dead/busy/off/on; [Ios27PowerState.error] и [Ios27PowerState.offline] —
///    те же off) заменяет значок через `appear()`: масштаб 0.5→1, прозрачность 0→1, размытие
///    4→0, пружина bouncy (motion.js:355-361). «Уменьшить движение»: только прозрачность за
///    180 мс, тон меняется мгновенно.
///  * Нажатие: общая механика [Ios27CircleButton] (подъём 6 %, свечение).
///
/// Подпись [semanticLabel] целиком от вызывающего: на доске она зависит от состояния
/// (`Подключить VPN` / `Отключить VPN` / `Отменить подключение` / `Повторить подключение`).
/// Позиционирование — дело родителя: виджет занимает ровно 80×80.
class Ios27PowerButton extends StatefulWidget {
  const Ios27PowerButton({
    super.key,
    required this.state,
    required this.semanticLabel,
    this.onPressed,
    this.away = false,
  });

  final Ios27PowerState state;

  /// Подпись для VoiceOver; в семантике кнопка носит идентификатор `dw_connect`.
  final String semanticLabel;

  /// Нажатие. В [Ios27PowerState.disabled] игнорируется, как `disabled` у `.power` на доске.
  final VoidCallback? onPressed;

  /// Кнопка ушла под лист (`.joy .glass { --g-o: 0 }`, app.css:330).
  final bool away;

  @override
  State<Ios27PowerButton> createState() => _Ios27PowerButtonState();
}

class _Ios27PowerButtonState extends State<Ios27PowerButton>
    with TickerProviderStateMixin {
  // Доля тона `--g-tint`: 1 у «включено», пружина smooth при смене (app.js:965-979).
  late final AnimationController _tint = AnimationController(
    vsync: this,
    value: _lookOf(widget.state) == _Look.on ? 1 : 0,
  );

  // Появление нового значка (`appear`): неограниченный контроллер, потому что пружина bouncy
  // выходит за 1.0. Стартует в покое (1): при первом показе значок не анимируется.
  late final AnimationController _appear =
      AnimationController.unbounded(vsync: this, value: 1);

  // Один и тот же значок живёт и в «голом» виде, и внутри оболочки появления (прозрачность,
  // масштаб, размытие): без глобального ключа смена родителя пересоздавала элемент, и спиннер
  // стартовал заново в начале и в конце `appear()` (спица прыгала на нулевой угол).
  final GlobalKey _glyphKey = GlobalKey(debugLabel: 'ios27PowerGlyph');

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(Ios27PowerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = _lookOf(oldWidget.state);
    final after = _lookOf(widget.state);
    if (before == after) {
      return;
    }
    final tintTarget = after == _Look.on ? 1.0 : 0.0;
    if (_reduceMotion) {
      // glass.css:305: без анимации тона; значок только проявляется за 180 мс.
      _tint.value = tintTarget;
      _appear
        ..value = 0
        ..animateTo(1, duration: Ios27Motion.fade, curve: Curves.linear);
      return;
    }
    if (_tint.value != tintTarget) {
      // `snapToEnd`: пружина по умолчанию «заканчивается» на 8.5e-5 от цели и записывает это
      // значение в контроллер. Доля нужна значку, и остаток красил бы его не в базовый цвет.
      _tint.animateWith(
        SpringSimulation(
          Ios27Motion.springSmooth.description,
          _tint.value,
          tintTarget,
          0,
          snapToEnd: true,
        ),
      );
    }
    _appear
      ..value = 0
      ..animateWith(_appearSpring);
  }

  SpringSimulation get _appearSpring =>
      SpringSimulation(Ios27Motion.springBouncy.description, 0, 1, 0);

  @override
  void dispose() {
    _tint.dispose();
    _appear.dispose();
    super.dispose();
  }

  Ios27GlassTone _baseTone(_Look look) {
    switch (look) {
      case _Look.dead:
        return Ios27GlassTone.muted;
      case _Look.busy:
        return Ios27GlassTone.secondary;
      case _Look.off:
      case _Look.on:
        return Ios27GlassTone.normal;
    }
  }

  Widget _glyph(BuildContext context, _Look look, Color color) => KeyedSubtree(
        key: _glyphKey,
        child: look == _Look.busy
            ? Ios27ActivityIndicator(size: kIos27PowerSpinnerSize, color: color)
            : Ios27Icon.spec(
                Ios27IconName.power,
                Ios27IconSpecs.power,
                color: color,
              ),
      );

  // `appear(icon)`: масштаб 0.5→1, прозрачность 0→1, размытие 4→0 (motion.js:355-361).
  // Под Reduce Motion — только прозрачность (motion.js:238-243).
  Widget _appearing(Widget glyph) => AnimatedBuilder(
        animation: _appear,
        child: glyph,
        builder: (context, child) {
          final v = _appear.value;
          if (!_appear.isAnimating) {
            return child!;
          }
          final opacity = v.clamp(0.0, 1.0);
          var out = child!;
          if (!_reduceMotion) {
            const from = Ios27Motion.replaceIconScale;
            out = Transform.scale(scale: from + (1 - from) * v, child: out);
            final blur = Ios27Motion.replaceIconBlur * (1 - v.clamp(0.0, 1.0));
            if (blur > 0.01) {
              out = ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: out,
              );
            }
          }
          return Opacity(opacity: opacity, child: out);
        },
      );

  @override
  Widget build(BuildContext context) {
    final look = _lookOf(widget.state);
    final disabled = widget.state == Ios27PowerState.disabled;
    final onPressed = disabled ? null : widget.onPressed;
    return Ios27A11yBuilder(
      builder: (context, _) => AnimatedBuilder(
        animation: _tint,
        builder: (context, _) {
          final t = _tint.value;
          // Тон по целевому состоянию. Плавность `is-tint-in`/`is-tint-out` (класс остаётся,
          // пока `--g-tint` гаснет 1→0) обеспечивает стекло, а не доля `t`.
          final tint =
              look == _Look.on ? Ios27Colors.of(context).accentColor : null;
          final base = ios27GlassLabelColor(context, _baseTone(look));
          final onTint = ios27GlassLabelColor(context, Ios27GlassTone.onTint);
          final color = t <= 0 ? base : Color.lerp(base, onTint, t)!;
          return Ios27CircleButton(
            diameter: kIos27PowerButtonSize,
            tint: tint,
            interactive: !disabled,
            onPressed: onPressed,
            semanticLabel: widget.semanticLabel,
            semanticIdentifier: kIos27PowerSemanticsId,
            toggled: widget.state == Ios27PowerState.on,
            away: widget.away,
            child: _appearing(_glyph(context, look, color)),
          );
        },
      ),
    );
  }
}
