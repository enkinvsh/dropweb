// Превью стекла на странице «Оформление»: цветной фон с диагональными полосами и три стеклянные
// кнопки главной (доска: `.glass-preview`, app.js:~617, app.css:623-629).
//
// Кнопки живые: это настоящие виджеты главной со стеклом, поэтому при движении ползунка
// (`Ios27GlassColors.level`) они меняются прямо на глазах, как на доске меняется `--lg`.
// Фон превью даёт стеклу, что преломлять: на плоском фоне прозрачность не видна.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dropweb/ui/ios27/home/widgets/ios27_dock_button.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_power_button.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:flutter/widgets.dart';

/// Высота превью (`.glass-preview{height:136px}`).
const double kIos27GlassPreviewHeight = 136;

/// Поля превью: по бокам 20, снизу 22 (`padding:0 20px 22px`).
const double kIos27GlassPreviewSide = 20;
const double kIos27GlassPreviewBottom = 22;

/// Добавочный отступ ряда кнопок (`.joy__row{padding:0 4px}`, app.css:560).
const double kIos27GlassPreviewRowInset = 4;

/// Угол градиентов фона (`linear-gradient(150deg, …)`).
const double kIos27GlassPreviewAngle = 150;

// Доли смешения цвета с фоном страницы: `color-mix(in srgb, X p%, var(--bg))`.
const double _mixOrb2 = 0.55;
const double _mixOrb1Top = 0.45;
const double _mixAccent = 0.35;
const double _mixOrb1Bottom = 0.30;

/// Превью стекла: 136 dp, фон из трёх цветов провайдера и ряд «подписки · питание · маршрут».
///
/// Не принимает касаний и не читается VoiceOver: на доске превью `pointer-events:none` и
/// `aria-hidden`, управляет им только ползунок ниже.
class Ios27GlassPreview extends StatelessWidget {
  const Ios27GlassPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Ios27Colors.of(context);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          key: const ValueKey<String>('page.glassPreview'),
          height: kIos27GlassPreviewHeight,
          child: CustomPaint(
            painter: _PreviewPainter(
              bg: colors.palette.bg,
              accent: colors.accentColor,
              orb1: colors.orb1,
              orb2: colors.orb2,
            ),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(
                kIos27GlassPreviewSide + kIos27GlassPreviewRowInset,
                0,
                kIos27GlassPreviewSide + kIos27GlassPreviewRowInset,
                kIos27GlassPreviewBottom,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _Slot(
                      size: kIos27DockButtonSize,
                      child: Ios27DockButton.subscriptions(semanticLabel: ''),
                    ),
                    _Slot(
                      size: kIos27PowerButtonSize,
                      child: Ios27PowerButton(
                        state: Ios27PowerState.off,
                        semanticLabel: '',
                      ),
                    ),
                    _Slot(
                      size: kIos27DockButtonSize,
                      child: Ios27DockButton.route(semanticLabel: ''),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Кнопка превью. Ключ `page.glassBtn` ставится на потомка: три одинаковых ключа у соседей по
/// `Row` дают «Duplicate keys», а тесту нужны все три рамки.
class _Slot extends StatelessWidget {
  const _Slot({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: KeyedSubtree(
          key: const ValueKey<String>('page.glassBtn'),
          child: child,
        ),
      );
}

/// Два наложенных градиента 150° с жёсткими границами полос (CSS `linear-gradient`).
///
/// Градиент строится на оси CSS (`ui.Gradient.linear` по двум точкам), а не на долях рамки: ось
/// под углом 150° длиннее диагонали блока и в `Alignment` не укладывается.
///
/// Нижний слой непрозрачный (три полосы 0–30 / 30–71 / 71–100 %), верхний прозрачный, с одной
/// полосой 44–57 % цвета `orb2`. Цвета смешаны с фоном страницы `--bg`, как `color-mix` доски.
class _PreviewPainter extends CustomPainter {
  const _PreviewPainter({
    required this.bg,
    required this.accent,
    required this.orb1,
    required this.orb2,
  });

  final Color bg;
  final Color accent;
  final Color orb1;
  final Color orb2;

  Color _mix(Color color, double share) => Color.lerp(bg, color, share)!;

  @override
  void paint(Canvas canvas, Size size) {
    // Ось градиента CSS: направление (sin a, -cos a) в экранных координатах, длина
    // |W·sin a| + |H·cos a|, середина в центре блока.
    const a = kIos27GlassPreviewAngle * math.pi / 180;
    final dir = Offset(math.sin(a), -math.cos(a));
    final length =
        (size.width * math.sin(a)).abs() + (size.height * math.cos(a)).abs();
    final center = size.center(Offset.zero);
    final from = center - dir * (length / 2);
    final to = center + dir * (length / 2);
    final rect = Offset.zero & size;

    final base = _mix(orb1, _mixOrb1Top);
    final mid = _mix(accent, _mixAccent);
    final end = _mix(orb1, _mixOrb1Bottom);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          from,
          to,
          [base, base, mid, mid, end, end],
          const [0, 0.30, 0.30, 0.71, 0.71, 1],
        ),
    );

    final stripe = _mix(orb2, _mixOrb2);
    final clear = stripe.withAlpha(0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          from,
          to,
          [clear, clear, stripe, stripe, clear, clear],
          const [0, 0.44, 0.44, 0.57, 0.57, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.bg != bg ||
      old.accent != accent ||
      old.orb1 != orb1 ||
      old.orb2 != orb2;
}
