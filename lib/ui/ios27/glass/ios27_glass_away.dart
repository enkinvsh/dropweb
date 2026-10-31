// Уход стекла под лист: тайминги и прозрачность Flutter-части без слоя над нативным видом.
//
// Доска: app.css:326-333 (`.home:has(~ .sheet) .joy .glass { --g-o: 0 }`), glass.css:93-94,115
// (`--g-o` гасит слои стекла и содержимое, но не хост: «прозрачный хост отрезал бы стеклу фон»).

import 'package:dropweb/ui/ios27/theme/tokens.g.dart' show Ios27Motion;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Тайминги ухода и возврата стекла.
///
/// Ровно те же числа читает нативная сторона (`DropwebGlassEffectView`, ключ `away`): значки,
/// которые рисует Flutter, должны гаснуть синхронно с дематериализацией материала.
abstract final class Ios27GlassAwayTiming {
  /// Уход: 250 мс, `glass-away` (app.css:331).
  static const Duration leave = Duration(milliseconds: 250);

  /// Задержка возврата: 150 мс, пока лист втягивается обратно (app.css:333).
  static const Duration returnDelay = Duration(milliseconds: 150);

  /// Ход возврата после задержки: 300 мс (app.css:333).
  static const Duration returnRun = Duration(milliseconds: 300);

  /// Reduce Motion: 100 мс линейно, без задержки (то же, что у остальных слоёв).
  static const Duration reduced = Duration(milliseconds: 100);

  /// Вся длина возврата: задержка и ход одним контроллером.
  static const Duration returnSpan = Duration(milliseconds: 450);

  /// Кривая ухода: `--ease-out` доски.
  static const Curve leaveCurve = Ios27Motion.easeOut;

  /// Кривая возврата: первые 150 из 450 мс стоит, затем `--ease-out`.
  static const Curve returnCurve = Interval(
    150 / 450,
    1,
    curve: Ios27Motion.easeOut,
  );

  /// Двигает [controller] к состоянию [away] (0 — ушло, 1 — на месте). Анимация стартует от
  /// текущего значения, поэтому быстрый повторный жест не прыгает.
  static void drive(
    AnimationController controller, {
    required bool away,
    required bool reduceMotion,
  }) {
    if (reduceMotion) {
      controller.animateTo(
        away ? 0 : 1,
        duration: reduced,
        curve: Curves.linear,
      );
    } else if (away) {
      controller.animateTo(0, duration: leave, curve: leaveCurve);
    } else {
      controller.animateTo(1, duration: returnSpan, curve: returnCurve);
    }
  }
}

/// Внешняя прозрачность для стёкол поддерева: её множат на свою и [Ios27GlassAwayFade].
///
/// Нужна кнопке-источнику зума: пока слой открыт, значок и подложка заглушки кнопки скрыты
/// (app.css:303-312 `.glass.is-src { --g-o: 0 }`), а вернуться должны в хвосте втягивания.
/// Скрывать кнопку целиком нельзя: предком нативного `UiKitView` не может быть ничто
/// полупрозрачное (см. [Ios27GlassAwayFade]), поэтому значение доходит до самого стекла и
/// гасит только то, что рисует Flutter. Нативный материал кнопки уходит своим `away`.
///
/// Берёт [ValueListenable], а не число: прозрачность меняется каждый кадр, и пересобирать
/// ради неё поддерево не нужно, достаточно перерисовать слой. Стекло внутри стекла множило бы
/// прозрачность дважды, поэтому вкладывать источники друг в друга нельзя.
class Ios27GlassFadeScope extends InheritedWidget {
  const Ios27GlassFadeScope({
    super.key,
    required this.opacity,
    required super.child,
  });

  /// 1 — стекло видно, 0 — спрятано.
  final ValueListenable<double> opacity;

  /// Прозрачность для стекла под [context]; `null` — над ним нет источника.
  static ValueListenable<double>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<Ios27GlassFadeScope>()
      ?.opacity;

  // Сам источник живёт столько же, сколько кнопка; сменился он только при перепосадке.
  @override
  bool updateShouldNotify(Ios27GlassFadeScope oldWidget) =>
      !identical(oldWidget.opacity, opacity);
}

/// Прозрачность Flutter-содержимого стекла, которое уходит под лист или спрятано источником.
///
/// Слой заводится только на время самой анимации (`0 < opacity < 1`): `Opacity` и
/// `FadeTransition` в этой версии Flutter делают из ребёнка граничный слой и сдвигают
/// сглаживание значков. Над `UiKitView` этот виджет ставить нельзя: полупрозрачный предок
/// нативного `UIVisualEffectView` рисуется неправильно (вспышка плоских кругов), поэтому
/// материал уходит силами самого нативного вида, а здесь гаснет только то, что рисует Flutter.
class Ios27GlassAwayFade extends SingleChildRenderObjectWidget {
  const Ios27GlassAwayFade({
    super.key,
    required this.opacity,
    this.external,
    super.child,
  });

  /// 1 — на месте, 0 — ушло.
  final Animation<double> opacity;

  /// Прозрачность от источника зума ([Ios27GlassFadeScope]); `null` — источника нет.
  final ValueListenable<double>? external;

  /// Итоговая прозрачность: уход под лист на прозрачность источника.
  double get value => opacity.value * (external?.value ?? 1);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      Ios27RenderGlassAwayFade(opacity, external);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant Ios27RenderGlassAwayFade renderObject,
  ) {
    renderObject.setSources(opacity, external);
  }
}

/// Render-объект [Ios27GlassAwayFade]; публичный только ради сигнатуры `updateRenderObject`.
class Ios27RenderGlassAwayFade extends RenderProxyBox {
  Ios27RenderGlassAwayFade(this._opacity, this._external);

  Animation<double> _opacity;
  ValueListenable<double>? _external;
  bool _hadLayer = false;

  // Слушатели живут, пока объект прикреплён к дереву: иначе контроллер, который переживёт
  // виджет, держал бы ссылку на мёртвый render-объект.
  void setSources(
      Animation<double> opacity, ValueListenable<double>? external) {
    if (identical(_opacity, opacity) && identical(_external, external)) {
      return;
    }
    if (attached) {
      _unlisten();
    }
    _opacity = opacity;
    _external = external;
    if (attached) {
      _listen();
    }
    _onTick();
  }

  void _listen() {
    _opacity.addListener(_onTick);
    _external?.addListener(_onTick);
  }

  void _unlisten() {
    _opacity.removeListener(_onTick);
    _external?.removeListener(_onTick);
  }

  double get _value => _opacity.value * (_external?.value ?? 1);

  bool get _needsLayer {
    final v = _value;
    return v > 0 && v < 1;
  }

  void _onTick() {
    final needs = _needsLayer;
    if (needs != _hadLayer) {
      _hadLayer = needs;
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listen();
    _hadLayer = _needsLayer;
  }

  @override
  void detach() {
    _unlisten();
    super.detach();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _needsLayer;

  @override
  void paint(PaintingContext context, Offset offset) {
    final v = _value;
    if (v <= 0) {
      layer = null;
      return;
    }
    if (v >= 1) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushOpacity(
      offset,
      (v * 255).round(),
      super.paint,
      oldLayer: layer as OpacityLayer?,
    );
  }
}
