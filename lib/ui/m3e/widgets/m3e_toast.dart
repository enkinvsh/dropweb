import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;

import '../theme/m3e_text.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import 'm3e_round_button.dart' show kM3eNavButtonSize, kM3eNavButtonTop;
import 'm3e_symbol.dart';
import 'm3e_toast_kind.dart';

export 'm3e_toast_kind.dart';

/// Сколько уведомление держится на экране до ухода: решение 10, 2200 мс.
const Duration kM3eToastHold = Duration(milliseconds: 2200);

/// Сообщение для [M3eToastPresenter]. Новый экземпляр — новое сообщение, даже с тем же
/// текстом: презентер сравнивает экземпляры по identity.
class M3eToastMessage {
  const M3eToastMessage({this.kind, required this.text});

  /// `null` — плашка без значка, только текст.
  final M3eToastKind? kind;
  final String text;
}

/// Высота слота уведомления: полоса между строкой состояния и верхом карточки (64 dp)
/// минус верхний отступ 8 и запас снизу. Плашка занимает ровно столько, сколько
/// `min-height` доски: при системном textScaler она не растёт и не заходит на карточку.
const double kM3eToastHeight = 48;

/// Отступ плашки от строки состояния. Решение владельца 2026-10-29: центр плашки лежит
/// на линии центра кнопки настроек (на доске плашка стоит на 6 dp ниже). Кнопка 44 на
/// 4 dp ниже строки состояния, плашка 48 выше неё на 2 dp с каждой стороны.
const double kM3eToastTopGap =
    kM3eNavButtonTop + (kM3eNavButtonSize - kM3eToastHeight) / 2;

/// Ширина слота по доске: `max-width: 360px` у `.dr-toast`.
const double kM3eToastMaxWidth = 360;

/// Боковое поле слота: поле экрана 16 + кнопка (настройки 44 справа, «Назад» 40 слева,
/// берём больший) + зазор 8. Плашка с этим полем не накрывает ни одну из кнопок.
const double kM3eToastSideInset = 16 + kM3eNavButtonSize + 8;

/// Максимальная ширина плашки на экране шириной [screenWidth].
double m3eToastMaxWidthFor(double screenWidth) {
  final slot = screenWidth - 2 * kM3eToastSideInset;
  return slot.clamp(0.0, kM3eToastMaxWidth);
}

/// Сама плашка: капсула системного Toast Android (`.dr-toast` в android.css).
///
/// Ширина по содержимому до [maxWidth], высота всегда [kM3eToastHeight]: одна строка
/// title-small 14/20 или две строки с межстрочным 18 (те же 48 с вертикальным отступом 6),
/// дальше многоточие. Значок 20 и текст не зависят от системного textScaler: слот
/// фиксированной высоты, а полный текст остаётся в Semantics. Положение и движение
/// задаёт [M3eToastPresenter]; плашку можно ставить и отдельно.
class M3eToast extends StatelessWidget {
  const M3eToast({
    super.key,
    this.kind,
    required this.text,
    this.maxWidth = kM3eToastMaxWidth,
  });

  /// `null` — без значка: у сообщений без типа значок не выбран (решение владельца
  /// пока не принято), показываем только текст.
  final M3eToastKind? kind;
  final String text;

  /// Предел ширины; презентер берёт его из слота экрана, чтобы плашка не накрывала кнопки.
  final double maxWidth;

  /// Z-тень Flutter при level3 заметно темнее CSS-тени доски (0,09 и 0,12 при блюре
  /// около 4 px); множитель подобран по листу сравнения с эталоном.
  static const double _shadowAlpha = 0.45;

  /// Межстрочный в двух строках: при 20 две строки (40) не влезли бы в 48 с отступами.
  static const double _twoLineHeight = 18;

  @override
  Widget build(BuildContext context) {
    final colors = M3eColors.of(context);
    final scheme = colors.scheme;
    final kind = this.kind;
    final iconColor = switch (kind) {
      M3eToastKind.check => colors.home.ok,
      M3eToastKind.alert => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
    // Слева 16 — это отступ до значка (`padding: 14px 20px 14px 16px`). Без значка
    // слева берём те же 20, что справа: в доске случая без значка нет, а
    // асимметрия 16/20 сдвинула бы текст в капсуле от центра.
    final left = kind == null ? 20.0 : 16.0;
    const right = 20.0;
    final iconSpace = kind == null ? 0.0 : 28.0;
    final base = m3eTextStyle(M3eType.titleSmall, color: scheme.onSurface);
    final direction = Directionality.of(context);

    return MediaQuery.withNoTextScaling(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final available = (constraints.maxWidth - left - right - iconSpace)
                .clamp(0.0, double.infinity);
            final painter = TextPainter(
              text: TextSpan(text: text, style: base),
              textDirection: direction,
              maxLines: 1,
            )..layout(maxWidth: available);
            final wraps = painter.didExceedMaxLines;
            painter.dispose();
            final style =
                wraps ? base.copyWith(height: _twoLineHeight / 14) : base;
            // Вживую читается как status: диктор произносит текст сам, когда плашка
            // появляется (polite на Android).
            return Semantics(
              container: true,
              liveRegion: true,
              child: Material(
                key: const ValueKey<String>('m3e.toast'),
                color: scheme.surfaceContainerHigh,
                shadowColor: scheme.shadow.withValues(alpha: _shadowAlpha),
                elevation: M3eElevation.level3,
                shape: const StadiumBorder(),
                child: SizedBox(
                  height: kM3eToastHeight,
                  child: Padding(
                    padding: EdgeInsets.only(left: left, right: right),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (kind != null) ...[
                          M3eSymbolIcon(
                            kind.symbol,
                            fill: true,
                            size: 20,
                            color: iconColor,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            text,
                            key: const ValueKey<String>('m3e.toast.text'),
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
            );
          },
        ),
      ),
    );
  }
}

/// Показывает и прячет [M3eToast] в шапке: top = строка состояния + 8, по центру.
///
/// Вход — пружина fast spatial со сдвигом сверху и масштабом .9 (`dr-toast-in`), выход
/// 200 мс по emphasized-accelerate (`dr-toast-out`). При отключённых анимациях только
/// прозрачность за 150 мс, без сдвига и масштаба.
///
/// Ставится в `Stack` или `Overlay` на весь экран выше навигатора. Очередь сообщений
/// остаётся у вызывающего: презентер показывает одно сообщение за раз; новый экземпляр
/// [message] заменяет текущее с новым входом, `null` запускает выход.
class M3eToastPresenter extends StatefulWidget {
  const M3eToastPresenter({
    super.key,
    required this.message,
    this.hold = kM3eToastHold,
    this.onDismissed,
  });

  final M3eToastMessage? message;

  /// Через сколько уйти самому; `null` держит плашку, пока [message] не станет `null`.
  final Duration? hold;

  /// Вызывается, когда истёк [hold] и плашка начала уходить: вызывающий снимает сообщение.
  final ValueChanged<M3eToastMessage>? onDismissed;

  @override
  State<M3eToastPresenter> createState() => _M3eToastPresenterState();
}

class _M3eToastPresenterState extends State<M3eToastPresenter>
    with SingleTickerProviderStateMixin {
  static const double _shift = 24;
  static const double _startScale = 0.9;
  static const Duration _exit = Duration(milliseconds: 200);
  static const Duration _fade = Duration(milliseconds: 150);

  /// Прогресс показа: 0 скрыто, 1 на месте. Пружина вылетает за 1, поэтому без границ.
  ///
  /// Создаётся в `initState`, а не лениво: `late final` с инициализатором впервые
  /// сработал бы в `dispose`, если плашку ни разу не показывали, и создание тикера
  /// в размонтируемом состоянии роняло `MessageManager`.
  late final AnimationController _progress;

  /// Что сейчас на экране; при выходе остаётся, пока не доиграет.
  M3eToastMessage? _shown;
  bool _leaving = false;
  Timer? _holdTimer;

  /// Вход первого сообщения откладывается до `didChangeDependencies`: там уже доступен
  /// `MediaQuery`, а в `initState` его читать нельзя.
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
  void didUpdateWidget(M3eToastPresenter old) {
    super.didUpdateWidget(old);
    final next = widget.message;
    if (identical(next, old.message)) return;
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
      _progress.animateTo(1, duration: _fade, curve: Curves.linear);
    } else {
      _progress.animateWith(
        SpringSimulation(M3eSpring.fastSpatial.description, 0, 1, 0),
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
    if (_shown == null || _leaving) return;
    _leaving = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _progress.animateTo(0, duration: _fade, curve: Curves.linear);
    } else {
      _progress.animateTo(0,
          duration: _exit, curve: M3eEasing.emphasizedAccelerate);
    }
  }

  void _onStatus(AnimationStatus status) {
    // animateTo всегда идёт как forward, даже к нулю: конец выхода — completed.
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
    if (shown == null) return const SizedBox.shrink();
    final reduced = MediaQuery.disableAnimationsOf(context);
    final top = MediaQuery.paddingOf(context).top + kM3eToastTopGap;
    // Слот один на всех экранах: полоса под строкой состояния шириной экрана без
    // боковых полей под кнопки. Расчёт от ширины самого презентера (он на весь экран).
    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = m3eToastMaxWidthFor(constraints.maxWidth);
      return Padding(
        padding: EdgeInsets.only(top: top),
        child: Align(
          alignment: Alignment.topCenter,
          // Плашка не перехватывает касания: на экранах она стоит рядом с кнопками.
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _progress,
              builder: (context, child) {
                final p = _progress.value;
                return Opacity(
                  key: const ValueKey<String>('m3e.toast.fade'),
                  opacity: p.clamp(0.0, 1.0),
                  child: reduced
                      ? child
                      : Transform(
                          key: const ValueKey<String>('m3e.toast.motion'),
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
              child: M3eToast(
                kind: shown.kind,
                text: shown.text,
                maxWidth: maxWidth,
              ),
            ),
          ),
        ),
      );
    });
  }
}
