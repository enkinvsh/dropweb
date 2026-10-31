// Кривая по пружине доски для маршрутов слоёв (тост, алерт, лист).

import 'package:dropweb/ui/ios27/theme/tokens.g.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Кривая `0..1` по пружине [spec]: положение пружины от покоя в 0 к цели 1 за время затухания.
///
/// Маршрутам нужна именно кривая, а не `SpringSimulation`: `PopupRoute` ведёт обычный
/// `AnimationController`, и его длительность задаёт [Ios27SpringSpec.settle]. На `t = 1` отдаётся
/// ровно 1: пружина к этому времени затухла до 0.1 %, а хвост нужно срезать, иначе
/// анимация закончится на 0.999.
///
/// У пружин с отскоком (`bounce > 0`) значение может выходить за 1; у `springSmooth`, которой
/// пользуются слои, отскока нет.
class Ios27SpringCurve extends Curve {
  Ios27SpringCurve(this.spec)
      : _simulation = SpringSimulation(spec.description, 0, 1, 0);

  /// Пружина доски (`Ios27Motion.springSmooth` и остальные).
  final Ios27SpringSpec spec;

  final SpringSimulation _simulation;

  @override
  double transformInternal(double t) {
    if (t >= 1) {
      return 1;
    }
    return _simulation.x(t * spec.settle.inMicroseconds / 1e6);
  }
}
