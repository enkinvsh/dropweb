import 'package:flutter/material.dart';

/// Тон полосы трафика: обычный, на исходе (> 90 %) и исчерпан (100 %).
enum M3eMeterTone { normal, low, out }

/// Линейный индикатор M3E: контейнер 6 dp, активная часть и трек по 4 dp прижаты к
/// верху, зазор 4 dp, точка-стоп 4 dp у правого края (`.dr-progress.dr-meter` в
/// android.css, 152-156 и 178-185).
///
/// На доске правила `.dr-meter > b` (6 dp) перебиты более поздним `.dr-progress > b` (4 dp),
/// поэтому толщина полосы 4, а не 6: так отрисован эталон (замер по пикселям).
///
/// При 100 % и выше трек и точка скрыты, активная часть занимает всю ширину
/// (`.is-full`).
class M3eMeter extends StatelessWidget {
  const M3eMeter({
    super.key,
    required this.percent,
    required this.activeColor,
    required this.trackColor,
  });

  /// Заполнение в процентах; значения вне 0..100 обрезаются.
  final double percent;
  final Color activeColor;
  final Color trackColor;

  /// Высота контейнера; сама полоса тоньше ([_bar]).
  static const double height = 6;
  static const double _bar = 4;
  static const double _gap = 4;
  static const double _stop = 4;

  @override
  Widget build(BuildContext context) {
    final full = percent >= 100;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final active = full ? width : width * percent.clamp(0, 100) / 100;
          final track = full ? 0.0 : (width - active - _gap).clamp(0.0, width);
          return Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bar(width: active, color: activeColor),
                  if (!full) ...[
                    const SizedBox(width: _gap),
                    _Bar(width: track, color: trackColor),
                  ],
                ],
              ),
              if (!full)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: _stop,
                    height: _stop,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: M3eMeter._bar,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(M3eMeter._bar / 2),
        ),
      );
}
