// Тост iOS-редизайна: стеклянная подсказка в строке кнопок панели (доска `.toast`, app.css:410-426).

import 'dart:async';
import 'dart:math' as math;

import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/layers/ios27_spring_curve.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart'
    show Ios27Motion, Ios27TextRole;
import 'package:dropweb/ui/m3e/widgets/m3e_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;

export 'package:dropweb/ui/m3e/widgets/m3e_toast.dart'
    show M3eToastKind, M3eToastMessage, kM3eToastHold;

/// Высота тоста (`.toast{height:48px}`). Не растёт с размером текста: тост стоит в строке
/// кнопок панели, и вылезти из неё ему нельзя (решение владельца 29.10, D4).
const double kIos27ToastHeight = 48;

/// Высота кнопок панели (`circle-btn`, 44): центр тоста лежит на линии их центров.
const double kIos27ToastNavButtonSize = 44;

/// Наибольшая ширина тоста (`min(360px, …)`).
const double kIos27ToastMaxWidth = 360;

/// Боковые поля слота: поле экрана 16 + кнопка 44 + зазор 8. Тост с таким полем не задевает
/// ни шестерёнку справа, ни «Назад» слева (`max-width: min(360px, 100% - 136px)`).
const double kIos27ToastSideInset = 16 + kIos27ToastNavButtonSize + 8;

/// Верх тоста относительно верхнего края safe area.
///
/// Кнопки панели главной стоят на верхней границе safe area (на доске `top:48` при отступе 48),
/// тост выше них на 2 dp: у него 48, у кнопки 44, центры совпадают. На доске это `top: 46px`
/// (app.css:411).
const double kIos27ToastTopGap =
    (kIos27ToastNavButtonSize - kIos27ToastHeight) / 2;

/// Наибольшая ширина тоста на экране шириной [screenWidth].
double ios27ToastMaxWidthFor(double screenWidth) =>
    (screenWidth - 2 * kIos27ToastSideInset)
        .clamp(0.0, kIos27ToastMaxWidth)
        .toDouble();

/// Роль текста тоста: `font: 500 15px/18px` (app.css:413). Среди `.t-*` такой нет, поэтому
/// своя роль; кегль в px без `--ts`, как на доске.
const Ios27TextRole kIos27ToastTextRole =
    Ios27TextRole(size: 15, lineHeight: 18, weight: 500, tracking: 0);

Ios27IconName _iconFor(M3eToastKind kind) => switch (kind) {
      M3eToastKind.check => Ios27IconName.check,
      M3eToastKind.alert => Ios27IconName.alert,
      M3eToastKind.out => Ios27IconName.out,
      M3eToastKind.camera => Ios27IconName.camera,
    };

/// Сама плашка: стеклянная капсула высотой 48 с значком и текстом в одну или две строки.
///
/// Значок: `check` зелёный, `alert` красный, остальные цветом подписи стекла (`.toast--ok`,
/// `.toast--bad`, app.css:418-420). Значок несёт смысл тоста, это не цвет провайдера: тост не
/// нажимается. Без [kind] значка нет, и текст держит те же поля.
///
/// Текст не зависит от системного размера шрифта: высота слота фиксирована, полный текст остаётся
/// в семантике. Положение и движение задаёт [Ios27ToastPresenter].
class Ios27Toast extends StatelessWidget {
  const Ios27Toast({
    super.key,
    required this.text,
    this.kind,
    this.maxWidth = kIos27ToastMaxWidth,
  });

  final M3eToastKind? kind;
  final String text;

  /// Предел ширины; презентер берёт его из слота экрана.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final palette = ios27ColorsFor(context).palette;
    final kind = this.kind;
    final iconColor = switch (kind) {
      M3eToastKind.check => palette.greenText,
      M3eToastKind.alert => palette.redText,
      _ => palette.glassLabel,
    };
    final style = ios27RoleStyle(
      kIos27ToastTextRole,
      color: palette.glassLabel,
      bold: MediaQuery.boldTextOf(context),
    );

    // Тост живёт над Navigator и может оказаться вне Material/Scaffold: без своего
    // `DefaultTextStyle` текст наследует стиль по умолчанию WidgetsApp (жёлтое двойное подчёркивание).
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: style.copyWith(decoration: TextDecoration.none),
        child: MediaQuery.withNoTextScaling(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            // Читается как status: диктор произносит текст сам, когда тост появляется.
            child: Semantics(
              container: true,
              liveRegion: true,
              label: text,
              child: ExcludeSemantics(
                child: SizedBox(
                  height: kIos27ToastHeight,
                  child: Ios27Glass(
                    key: const ValueKey<String>('ios27.toast'),
                    // Два строки текста на стекле: материал толще, чем у кнопки (glass-map).
                    material: Ios27GlassMaterial.thin,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14, right: 18),
                      // Центр по высоте плашки: стекло кладёт ребёнка к верхней кромке.
                      child: Center(
                        widthFactor: 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (kind != null) ...[
                              Ios27Icon.spec(
                                _iconFor(kind),
                                Ios27IconSpecs.button,
                                color: iconColor,
                              ),
                              const SizedBox(width: 10),
                            ],
                            Flexible(
                              child: Text(
                                text,
                                key: const ValueKey<String>('ios27.toast.text'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: style,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Показывает и прячет [Ios27Toast] в строке кнопок панели, по центру.
///
/// Вход: пружина `smooth`, тост опускается на 24 dp сверху и растёт с .9 от верхней кромки
/// (`glass-toast-in`). Выход: 400 мс по той же кривой, тост уезжает обратно вверх и сжимается
/// (`glass-toast-out`). Reduce Motion: только прозрачность за 100 мс.
///
/// Очередь сообщений остаётся у вызывающего (`MessageManager`): презентер показывает одно
/// сообщение за раз; новый экземпляр [message] заменяет текущее с новым входом, `null` запускает
/// выход. Ставится в `Stack` на весь экран выше навигатора; касания не перехватывает.
class Ios27ToastPresenter extends StatefulWidget {
  const Ios27ToastPresenter({
    super.key,
    required this.message,
    this.hold = kM3eToastHold,
    this.onDismissed,
  });

  final M3eToastMessage? message;

  /// Через сколько уйти самому: 2200 мс, как `setTimeout` в `showToast` доски.
  /// `null` держит тост, пока [message] не станет `null`.
  final Duration? hold;

  /// Вызывается, когда истёк [hold] и тост начал уходить: вызывающий снимает сообщение.
  final ValueChanged<M3eToastMessage>? onDismissed;

  @override
  State<Ios27ToastPresenter> createState() => _Ios27ToastPresenterState();
}

class _Ios27ToastPresenterState extends State<Ios27ToastPresenter>
    with SingleTickerProviderStateMixin {
  static const double _shift = 24;
  static const double _startScale = 0.9;
  static const Duration _exit = Duration(milliseconds: 400);
  static const Duration _fade = Duration(milliseconds: 100);

  static final Ios27SpringCurve _smooth =
      Ios27SpringCurve(Ios27Motion.springSmooth);

  /// Прогресс показа: 0 скрыт, 1 на месте. Создаётся в `initState`, а не лениво: ленивое
  /// создание в `dispose` (тост ни разу не показывали) падало бы на тикере размонтируемого состояния.
  late final AnimationController _progress;

  /// Что сейчас на экране; при выходе остаётся, пока не доиграет.
  M3eToastMessage? _shown;
  bool _leaving = false;
  Timer? _holdTimer;

  /// Вход первого сообщения откладывается до `didChangeDependencies`: там уже есть `MediaQuery`.
  bool _enterPending = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController.unbounded(vsync: this, value: 0)
      ..addStatusListener(_onStatus);
    _shown = widget.message;
    _enterPending = _shown != null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_enterPending) {
      _enterPending = false;
      _enter(_shown!);
    }
  }

  @override
  void didUpdateWidget(Ios27ToastPresenter old) {
    super.didUpdateWidget(old);
    final next = widget.message;
    if (identical(next, old.message)) {
      return;
    }
    if (next != null) {
      setState(() {
        _shown = next;
        _leaving = false;
      });
      _enter(next);
    } else {
      _hide();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  void _enter(M3eToastMessage message) {
    _holdTimer?.cancel();
    _progress.value = 0;
    if (MediaQuery.disableAnimationsOf(context)) {
      unawaited(_progress.animateTo(1, duration: _fade, curve: Curves.linear));
    } else {
      unawaited(
        _progress.animateWith(
          SpringSimulation(Ios27Motion.springSmooth.description, 0, 1, 0),
        ),
      );
    }
    final hold = widget.hold;
    if (hold != null) {
      _holdTimer = Timer(hold, () {
        widget.onDismissed?.call(message);
        _hide();
      });
    }
  }

  void _hide() {
    _holdTimer?.cancel();
    if (_shown == null || _leaving) {
      return;
    }
    _leaving = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      unawaited(_progress.animateTo(0, duration: _fade, curve: Curves.linear));
    } else {
      // Значение идёт 1 -> 0 по кривой пружины: тост «отлетает» быстро и тормозит у края,
      // как `forwards`-анимация доски со `spring-smooth` на 400 мс.
      unawaited(_progress.animateTo(0, duration: _exit, curve: _smooth));
    }
  }

  void _onStatus(AnimationStatus status) {
    // animateTo всегда идёт как forward, даже к нулю: конец выхода это completed.
    if (_leaving && status == AnimationStatus.completed && mounted) {
      setState(() {
        _shown = null;
        _leaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) {
      return const SizedBox.shrink();
    }
    final reduced = MediaQuery.disableAnimationsOf(context);
    final safe = MediaQuery.paddingOf(context);
    final top = math.max(0.0, safe.top + kIos27ToastTopGap);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Слот тоста лежит между боковыми safe area: на iPhone Duo торцевая колонка Dynamic
        // Island закрыла бы край плашки, а кнопки панели сдвинуты внутрь на тот же отступ.
        final maxWidth = ios27ToastMaxWidthFor(
          constraints.maxWidth - safe.left - safe.right,
        );
        return Padding(
          padding:
              EdgeInsets.only(top: top, left: safe.left, right: safe.right),
          child: Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, child) {
                  final p = _progress.value;
                  return Opacity(
                    key: const ValueKey<String>('ios27.toast.fade'),
                    opacity: p.clamp(0.0, 1.0),
                    child: reduced
                        ? child
                        : Transform(
                            key: const ValueKey<String>('ios27.toast.motion'),
                            alignment: Alignment.topCenter,
                            transform: Matrix4.identity()
                              ..translateByDouble(0, -_shift * (1 - p), 0, 1)
                              ..scaleByDouble(
                                _startScale + (1 - _startScale) * p,
                                _startScale + (1 - _startScale) * p,
                                1,
                                1,
                              ),
                            child: child,
                          ),
                  );
                },
                child: Ios27Toast(
                  kind: shown.kind,
                  text: shown.text,
                  maxWidth: maxWidth,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
