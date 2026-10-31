import 'dart:async';
import 'dart:io' show Platform;

import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:dropweb/ui/ios27/glass/ios27_glass_away.dart';
import 'package:dropweb/ui/ios27/layers/ios27_spring_curve.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart' show Ios27Motion;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Класс стекла доски `canon/dropweb/glass.css`.
///
/// Карта «класс доски -> UIKit -> заглушка» — `.omo/ios/glass-map.md`.
enum Ios27GlassVariant {
  /// `glass`: круглые кнопки, капсулы, тост.
  small,

  /// `glass--md`: листы.
  md,

  /// `glass--lg`: алерт, лист цвета.
  lg,

  /// `glass--widget`: карточка главной.
  widget,

  /// `glass--inactive`: погасшая кнопка, плоская подложка без размытия.
  inactive,

  /// Матовый материал контента (`.hig-card-matte` доски карточек, HIG materials.md:
  /// `systemThickMaterial`), а не Liquid Glass. Решение владельца 30.10: стекло только у
  /// функционального слоя (шестерёнка, нижний ряд), а карточка с текстом — матовая, иначе
  /// серый вторичный текст на прозрачной подложке плохо читается.
  ///
  /// Одинаков на всех iOS (13–27): `UIBlurEffect(.systemThickMaterial)`, без `UIGlassEffect`.
  /// Ползунок «Стекло» ([Ios27GlassParams.level]), [Ios27Glass.tint] и подтемнение `widget` на
  /// него не действуют: материал контента не зависит от настроек стекла.
  content,
}

/// Материал стекла на iOS 13–25 (HIG: ultra-thin, thin, regular, thick).
///
/// По умолчанию материал выбирается по [Ios27GlassVariant]; явный нужен, когда
/// смысл элемента толще или тоньше класса (например, тост с двумя строками текста).
/// На iOS 26+ параметр игнорируется: там всегда `UIGlassEffect.regular`.
enum Ios27GlassMaterial { ultraThin, thin, regular, thick, chrome }

/// Форма стекла: капсула (круг на квадрате) или скруглённый прямоугольник.
@immutable
class Ios27GlassShape {
  /// Капсула: радиус равен половине меньшей стороны.
  const Ios27GlassShape.capsule() : radius = null;

  /// Прямоугольник с круговым скруглением [radius] dp.
  const Ios27GlassShape.rounded(double this.radius)
      : assert(radius >= 0, 'Радиус скругления не может быть отрицательным');

  /// Радиус в dp; `null` у капсулы.
  final double? radius;

  bool get isCapsule => radius == null;

  /// Граница заглушки: та же геометрия, что у CSS `border-radius` доски. Это
  /// круговая дуга, а не суперэллипс: так golden сверяется с доской попиксельно.
  ShapeBorder toBorder() => isCapsule
      ? const StadiumBorder()
      : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius!));

  @override
  bool operator ==(Object other) =>
      other is Ios27GlassShape && other.radius == radius;

  @override
  int get hashCode => radius.hashCode;

  @override
  String toString() => isCapsule
      ? 'Ios27GlassShape.capsule()'
      : 'Ios27GlassShape.rounded($radius)';
}

/// Параметры нативного стекла: то, что уходит в `UiKitView` и в `updateParams`.
///
/// Протокол ключей описан в `.omo/ios/glass-map.md`, раздел 6; читает его
/// `DropwebGlassParams` в `ios/Runner/Glass/DropwebGlassView.swift`.
@immutable
class Ios27GlassParams {
  const Ios27GlassParams({
    required this.shape,
    required this.dark,
    this.variant = Ios27GlassVariant.small,
    this.tint,
    this.interactive = false,
    this.nested = false,
    this.enabled = true,
    this.material,
    this.level,
    this.away = false,
    this.reduceMotion = false,
  });

  /// Плотность подложки тона на iOS 13–25, где `UIBlurEffect` цвета не принимает:
  /// как на доске (`glass.css`, контраст белого значка на акценте не ниже 3:1).
  static const double tintAlphaLight = 0.96;
  static const double tintAlphaDark = 0.50;

  final Ios27GlassShape shape;

  /// Тёмная ли тема: нативный вид переключает материал и вариант стекла явно,
  /// потому что тема приложения может расходиться с системной.
  final bool dark;
  final Ios27GlassVariant variant;

  /// Непрозрачный акцент; `null` — стекло без тона.
  final Color? tint;
  final bool interactive;
  final bool nested;
  final bool enabled;
  final Ios27GlassMaterial? material;

  /// Ползунок «Стекло» 0..100 (`--lg` доски, app.js:424): 0 — максимально прозрачное, 100 —
  /// полностью тонированное. `null` — «как в системе»: на iOS 26+ системное жидкое стекло как
  /// есть, на iOS 13–25 стандарт доски (`GLASS_STD = 25`, app.js:213).
  final int? level;

  /// Стекло ушло под лист (`.home:has(~ .sheet) .joy .glass { --g-o: 0 }`, app.css:330). Нативный
  /// вид сам убирает материал (`effect = nil`, на iOS 26 это дематериализация) и кромку: Flutter
  /// не может сделать прозрачным предка `UIVisualEffectView`, не сломав его отрисовку.
  final bool away;

  /// «Уменьшить движение»: нативные переходы тона и ухода идут 100 мс линейно (тон — мгновенно).
  /// Решение принимает Dart, чтобы значки Flutter и материал гасли с одним таймингом.
  final bool reduceMotion;

  /// Значение «как в системе» в карте для нативной стороны: ключ всегда присутствует и целый,
  /// так `DropwebGlassParams` разбирает его без ветвления на отсутствие.
  static const int levelSystem = -1;

  double get tintAlpha => dark ? tintAlphaDark : tintAlphaLight;

  /// Карта для `creationParams` и `updateParams` (полный набор каждый раз).
  Map<String, Object?> toMap() => <String, Object?>{
        'shape': shape.isCapsule ? 'capsule' : 'rect',
        'radius': shape.radius ?? 0.0,
        'variant': variant.name,
        'glass': 'regular',
        'tint': tint?.toARGB32(),
        'tintAlpha': tintAlpha,
        'interactive': interactive,
        'nested': nested,
        'enabled': enabled,
        'material': material?.name,
        'dark': dark,
        'level': level ?? levelSystem,
        'away': away,
        'reduceMotion': reduceMotion,
      };

  /// Совпадает ли всё, кроме формы. Радиус слоя зума меняется каждый кадр, а вид, ушедший под
  /// лист, формы не показывает: такие сообщения нативной стороне не нужны (см. `_NativeGlassState._push`).
  bool sameExceptShape(Ios27GlassParams other) =>
      other.dark == dark &&
      other.variant == variant &&
      other.tint == tint &&
      other.interactive == interactive &&
      other.nested == nested &&
      other.enabled == enabled &&
      other.material == material &&
      other.level == level &&
      other.away == away &&
      other.reduceMotion == reduceMotion;

  @override
  bool operator ==(Object other) =>
      other is Ios27GlassParams &&
      other.shape == shape &&
      sameExceptShape(other);

  @override
  int get hashCode => Object.hash(
        shape,
        dark,
        variant,
        tint,
        interactive,
        nested,
        enabled,
        material,
        level,
        away,
        reduceMotion,
      );
}

/// Непрозрачные цвета заглушки при Reduce Transparency (`glass.css`,
/// `@media (prefers-reduced-transparency: reduce)`).
///
/// Значения по умолчанию — доска. Токены из `lib/ui/ios27/theme/tokens.g.dart`
/// подключаются позже подменой палитры через [Ios27GlassColors].
@immutable
class Ios27GlassPalette {
  const Ios27GlassPalette({
    required this.fill,
    required this.disabledTintFill,
    required this.contrastRing,
  });

  /// Заливка всех классов без тона (`glass.css:296`, `#F2F2F2`).
  static const Ios27GlassPalette light = Ios27GlassPalette(
    fill: Color(0xFFF2F2F2),
    disabledTintFill: Color(0x33F8F8F8),
    contrastRing: Color(0x80000000),
  );

  /// Заливка всех классов без тона (`glass.css:296`, `#2A2A2A`).
  static const Ios27GlassPalette dark = Ios27GlassPalette(
    fill: Color(0xFF2A2A2A),
    disabledTintFill: Color(0x2B999999),
    contrastRing: Color(0x80FFFFFF),
  );

  /// Заливка заглушки без тона.
  final Color fill;

  /// Заливка у `glass--tint:disabled`: перебивает правило Reduce Transparency
  /// (`glass.css:261`), поэтому остаётся полупрозрачной, как на доске.
  final Color disabledTintFill;

  /// Единственное кольцо 1px при Increase Contrast (`glass.css:283-288`).
  final Color contrastRing;

  @override
  bool operator ==(Object other) =>
      other is Ios27GlassPalette &&
      other.fill == fill &&
      other.disabledTintFill == disabledTintFill &&
      other.contrastRing == contrastRing;

  @override
  int get hashCode => Object.hash(fill, disabledTintFill, contrastRing);
}

/// Цвета матового материала контента ([Ios27GlassVariant.content]) у Dart-заглушки.
///
/// Источник — `.hig-card-matte` в `canon/.omo/hig-cards/index.html`. На устройстве материал
/// рисует система (`systemThickMaterial`), заглушка стоит в тестах, на не-iOS и при Reduce
/// Transparency, поэтому заливка здесь непрозрачная: на доске она `rgba(255,255,255,.86)` /
/// `rgba(28,28,30,.86)` поверх размытия, а без размытия под ней остаётся только сам цвет
/// (`#FFFFFF` / `#1C1C1E`, `secondarySystemGroupedBackground`). Это не палитра темы: цвета
/// фиксированы системой и от акцента не зависят.
@immutable
class Ios27GlassContentColors {
  const Ios27GlassContentColors({
    required this.fill,
    required this.rim,
    required this.shadow,
  });

  static const Ios27GlassContentColors light = Ios27GlassContentColors(
    fill: Color(0xFFFFFFFF),
    // inset 0 0 0 .5px rgba(255,255,255,.65)
    rim: Color(0xA6FFFFFF),
    // 0 1px 3px rgba(0,0,0,.06)
    shadow: Color(0x0F000000),
  );

  static const Ios27GlassContentColors dark = Ios27GlassContentColors(
    fill: Color(0xFF1C1C1E),
    // inset 0 0 0 .5px rgba(255,255,255,.09)
    rim: Color(0x17FFFFFF),
    // 0 1px 3px rgba(0,0,0,.38)
    shadow: Color(0x61000000),
  );

  /// Ширина внутренней кромки (`0.5px` доски).
  static const double rimWidth = 0.5;

  /// Заливка заглушки.
  final Color fill;

  /// Внутренняя кромка 0.5 dp.
  final Color rim;

  /// Внешняя тень `0 1 3`.
  final Color shadow;

  @override
  bool operator ==(Object other) =>
      other is Ios27GlassContentColors &&
      other.fill == fill &&
      other.rim == rim &&
      other.shadow == shadow;

  @override
  int get hashCode => Object.hash(fill, rim, shadow);
}

/// Палитра и яркость для [Ios27Glass] в поддереве.
///
/// Нужен, чтобы экраны задали цвета один раз, а не передавали их каждому стеклу.
/// Без него действуют [Ios27GlassPalette.light] и [Ios27GlassPalette.dark], а
/// яркость берётся из `MediaQuery.platformBrightness` (iOS-интерфейс следует
/// системной теме).
class Ios27GlassColors extends InheritedWidget {
  const Ios27GlassColors({
    required super.child,
    super.key,
    this.light = Ios27GlassPalette.light,
    this.dark = Ios27GlassPalette.dark,
    this.brightness,
    this.level,
  });

  final Ios27GlassPalette light;
  final Ios27GlassPalette dark;

  /// Если задана, перекрывает системную яркость для всего поддерева.
  final Brightness? brightness;

  /// Ползунок «Стекло» приложения (0..100); `null` — как в системе. Один на всё поддерево, как
  /// `--lg` на корне доски (app.js:424). Заглушка (Reduce Transparency, тесты) его не читает:
  /// она непрозрачна при любом положении ползунка.
  final int? level;

  static Ios27GlassColors? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Ios27GlassColors>();

  @override
  bool updateShouldNotify(Ios27GlassColors oldWidget) =>
      oldWidget.light != light ||
      oldWidget.dark != dark ||
      oldWidget.brightness != brightness ||
      oldWidget.level != level;
}

/// Материал «жидкое стекло» под своим [child].
///
/// На iOS это платформенный вид `dropweb/glass` (`UIGlassEffect` на iOS 26+,
/// `UIBlurEffect` ниже), поверх которого Flutter рисует [child]: нативный вид
/// только материал, текст и значки рисует Flutter. Касания проходят сквозь
/// нативный вид (`hitTestBehavior: transparent`).
///
/// Везде, где нативного вида нет, — не iOS, `flutter test`, включённый Reduce
/// Transparency (`Ios27A11y.reduceTransparency`) или [debugForceStub] — рисуется
/// непрозрачная Dart-заглушка: заливка и кромка доски в режиме Reduce
/// Transparency, поэтому golden детерминированы и совпадают с доской.
///
/// Размер: с [child] размер задаёт он; без [child] виджет занимает все доступные
/// ограничения (оберните в `SizedBox` и подобное). [child] обрезается по форме
/// ([clipBehavior]); тени заглушки выходят за форму намеренно.
class Ios27Glass extends StatefulWidget {
  const Ios27Glass({
    super.key,
    this.shape = const Ios27GlassShape.capsule(),
    this.variant = Ios27GlassVariant.small,
    this.tint,
    this.interactive = false,
    this.nested = false,
    this.enabled = true,
    this.material,
    this.brightness,
    this.clipBehavior = Clip.antiAlias,
    this.away = false,
    this.child,
  });

  /// Заглушка вместо `UiKitView` во что бы то ни стало. Для тестов и golden на
  /// хосте, где платформа переопределена в iOS (`debugDefaultTargetPlatformOverride`).
  @visibleForTesting
  static bool debugForceStub = false;

  /// Разрешает нативный вид внутри `flutter test`. Без него тест с платформой
  /// iOS всё равно получает заглушку: `UiKitView` в тесте падает без мока канала
  /// `flutter/platform_views`. Включать только вместе с таким моком.
  @visibleForTesting
  static bool debugAllowNativeInTests = false;

  final Ios27GlassShape shape;
  final Ios27GlassVariant variant;

  /// Непрозрачный акцент (`glass--tint`); `null` — стекло без тона. У [Ios27GlassVariant.content]
  /// игнорируется: матовую карточку не окрашивают. Смена тона плавная:
  /// на iOS её ведёт нативный вид (пружина smooth 0.5 с, `is-tint-in`/`is-tint-out` доски,
  /// glass.css:221-226), у заглушки — она сама тем же временем. Передавайте целевое состояние
  /// (есть тон или нет), а не промежуточную долю: иначе анимация пойдёт дважды.
  final Color? tint;

  /// `UIGlassEffect.isInteractive`. Касания до нативного вида не доходят, поэтому
  /// родную реакцию система не покажет: нажатие рисует Flutter (см. glass-map, раздел 7).
  final bool interactive;

  /// Стекло внутри другого стекла: на iOS без эффекта, плоская полупрозрачная
  /// заливка (HIG и WWDC25: стекло на стекло не кладут). На [Ios27GlassVariant.content] не
  /// действует: матовый материал контента стеклом не является.
  final bool nested;

  /// `false` вместе с [tint] — `glass--tint:disabled`: тон пропадает.
  final bool enabled;

  /// Явный материал для iOS 13–25; по умолчанию выбирается по [variant].
  final Ios27GlassMaterial? material;

  /// Яркость стекла; по умолчанию — из [Ios27GlassColors] или системная.
  final Brightness? brightness;

  /// Обрезка [child] по форме; `Clip.none` отключает обрезку.
  final Clip clipBehavior;

  /// Стекло ушло под лист: материал и [child] гаснут. Нажатия блокирует родитель
  /// (`IgnorePointer`). Уход 250 мс `ease-out`, возврат 300 мс с задержкой 150 мс
  /// (app.css:326-333), при Reduce Motion 100 мс линейно ([Ios27GlassAwayTiming]).
  ///
  /// На iOS материал убирает сам нативный вид (ключ `away` протокола `dropweb/glass`):
  /// прозрачный предок `UiKitView` с `UIVisualEffectView` рисуется неправильно, поэтому над
  /// ним нет ни `Opacity`, ни `FadeTransition`. Flutter гасит только [child]. У заглушки
  /// (тесты, Reduce Transparency) гаснет и её заливка: нативного вида там нет.
  final bool away;

  final Widget? child;

  static bool get _nativeAvailable {
    if (debugForceStub ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    return debugAllowNativeInTests ||
        !Platform.environment.containsKey('FLUTTER_TEST');
  }

  @override
  State<Ios27Glass> createState() => _Ios27GlassState();
}

class _Ios27GlassState extends State<Ios27Glass>
    with SingleTickerProviderStateMixin {
  // Кривая смены тона у заглушки: пружина smooth доски, на конце ровно 1. Пружина без среза
  // хвоста застревала на 0.9999, и заливка не доходила до целевого цвета.
  static final Curve _tintCurve = Ios27SpringCurve(Ios27Motion.springSmooth);

  // Прозрачность Flutter-части при уходе под лист. Контроллер заводится только при первой
  // смене `away`: у подавляющего большинства стёкол ухода нет, и им он ни к чему.
  AnimationController? _away;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(Ios27Glass oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.away == widget.away) {
      return;
    }
    final controller = _away ??= AnimationController(
      vsync: this,
      value: oldWidget.away ? 0 : 1,
    );
    Ios27GlassAwayTiming.drive(
      controller,
      away: widget.away,
      reduceMotion: _reduceMotion,
    );
  }

  @override
  void dispose() {
    _away?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Ios27GlassColors.maybeOf(context);
    final resolved = widget.brightness ??
        colors?.brightness ??
        MediaQuery.platformBrightnessOf(context);
    final isDark = resolved == Brightness.dark;
    final palette = isDark
        ? colors?.dark ?? Ios27GlassPalette.dark
        : colors?.light ?? Ios27GlassPalette.light;
    final highContrast = MediaQuery.highContrastOf(context);
    final content = widget.child;
    // Без контроллера прозрачность постоянная: значение известно по `away`.
    final fade = _away ??
        (widget.away ? kAlwaysDismissedAnimation : kAlwaysCompleteAnimation);
    // Источник зума прячет Flutter-часть кнопки отсюда, а не слоем над кнопкой: над нативным
    // видом полупрозрачных предков быть не может (см. [Ios27GlassAwayFade]).
    final external = Ios27GlassFadeScope.maybeOf(context);

    return ValueListenableBuilder<bool>(
      valueListenable: Ios27A11y.reduceTransparencyListenable,
      builder: (context, reduceTransparency, _) {
        final Widget background;
        if (Ios27Glass._nativeAvailable && !reduceTransparency) {
          // Нативный вид без прозрачных предков: уход делает он сам.
          // Матовый материал контента не читает тон, уровень «Стекло», интерактивность, явный
          // материал и вложенность: в протокол они не попадают, чтобы ползунок или смена
          // акцента не слали нативному виду сообщения, которые он всё равно проигнорирует.
          final matte = widget.variant == Ios27GlassVariant.content;
          background = _NativeGlass(
            params: Ios27GlassParams(
              shape: widget.shape,
              dark: isDark,
              variant: widget.variant,
              tint: matte ? null : widget.tint,
              interactive: !matte && widget.interactive,
              nested: !matte && widget.nested,
              enabled: matte || widget.enabled,
              material: matte ? null : widget.material,
              level: matte ? null : colors?.level,
              away: widget.away,
              reduceMotion: _reduceMotion,
            ),
          );
        } else {
          background = Ios27GlassAwayFade(
            opacity: fade,
            external: external,
            child: _buildStub(
              palette: palette,
              dark: isDark,
              highContrast: highContrast,
            ),
          );
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: background),
            if (content != null)
              Ios27GlassAwayFade(
                opacity: fade,
                external: external,
                child: _clipped(content),
              ),
          ],
        );
      },
    );
  }

  Widget _clipped(Widget content) => widget.clipBehavior == Clip.none
      ? content
      : ClipPath(
          clipper: ShapeBorderClipper(shape: widget.shape.toBorder()),
          clipBehavior: widget.clipBehavior,
          child: content,
        );

  Widget _buildStub({
    required Ios27GlassPalette palette,
    required bool dark,
    required bool highContrast,
  }) {
    if (widget.variant == Ios27GlassVariant.content) {
      return _buildContentStub(
        palette: palette,
        dark: dark,
        highContrast: highContrast,
      );
    }
    final tint = widget.tint;
    final tinted = tint != null;
    final Color fill;
    if (tinted) {
      fill = widget.enabled ? tint : palette.disabledTintFill;
    } else {
      fill = palette.fill;
    }
    final shadows = _edgeShadows(
      variant: widget.nested ? Ios27GlassVariant.small : widget.variant,
      dark: dark,
      highContrast: highContrast && !tinted,
      contrastRing: palette.contrastRing,
    );
    // Заливка плавно идёт к целевому цвету той же пружиной, что тон нативного стекла. Первая
    // сборка не анимируется (начало = конец), «Уменьшить движение» красит сразу (glass.css:305).
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: fill),
      duration: _reduceMotion ? Duration.zero : Ios27Motion.springSmooth.settle,
      curve: _tintCurve,
      builder: (context, animated, _) => _stubSurface(
        fill: animated ?? fill,
        shadows: shadows,
      ),
    );
  }

  // Матовая карточка: заливка и кромка системного материала без тона. [Ios27Glass.tint],
  // [Ios27Glass.enabled] и ползунок «Стекло» её не меняют: материал контента не окрашивают
  // (иначе серый вторичный текст снова сядет на цветную подложку). Заливка непрозрачна и
  // цвет не анимируется: переходить нечему.
  Widget _buildContentStub({
    required Ios27GlassPalette palette,
    required bool dark,
    required bool highContrast,
  }) {
    final colors =
        dark ? Ios27GlassContentColors.dark : Ios27GlassContentColors.light;
    // Increase Contrast заменяет мягкую тень и кромку одним кольцом, как у остальных классов.
    final shadows = highContrast
        ? <BoxShadow>[BoxShadow(color: palette.contrastRing, spreadRadius: 1)]
        : <BoxShadow>[
            BoxShadow(
              color: colors.shadow,
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ];
    // Кромка лежит внутри формы (`strokeAlignInside` по умолчанию): это `inset` доски.
    final shape = highContrast
        ? widget.shape.toBorder()
        : (widget.shape.toBorder() as OutlinedBorder).copyWith(
            side: BorderSide(
              color: colors.rim,
              width: Ios27GlassContentColors.rimWidth,
            ),
          );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.fill,
        shape: shape,
        shadows: shadows,
      ),
    );
  }

  Widget _stubSurface({
    required Color fill,
    required List<BoxShadow> shadows,
  }) {
    // Полупрозрачная заливка (недоступная кнопка из цветного стекла, glass.css:261): CSS
    // `box-shadow` не рисуется под рамкой элемента, а Flutter кладёт тень под заливку, и сквозь
    // неё кольцо серит кнопку до #b5b5b5 вместо почти прозрачной. Непрозрачные заливки остаются
    // на обычной декорации: там тень скрыта заливкой, и кадры не меняются.
    if (fill.a < 1) {
      return CustomPaint(
        painter: _OutsideShadowPainter(
          border: widget.shape.toBorder(),
          fill: fill,
          shadows: shadows,
        ),
      );
    }
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: widget.shape.toBorder(),
        shadows: shadows,
      ),
    );
  }
}

/// Кромка и внешняя тень заглушки: перенос `--g-shadow-out` и кольца доски.
///
/// CSS `box-shadow` и Flutter `BoxShadow` дают одно и то же при `sigma = blur / 2`.
/// Внутренние тени (`inset`) во Flutter недоступны и не воспроизводятся: это
/// известное расхождение у самой кромки (glass-map, раздел 4).
List<BoxShadow> _edgeShadows({
  required Ios27GlassVariant variant,
  required bool dark,
  required bool highContrast,
  required Color contrastRing,
}) {
  // Increase Contrast заменяет все внешние тени одним кольцом 1px.
  if (highContrast) {
    return [BoxShadow(color: contrastRing, spreadRadius: 1)];
  }

  // Боковые щели `±1.25px 0 0 -.75px`: имитируют светлый/тёмный торец стекла.
  List<BoxShadow> ringWithSlits(Color ring, {required double spread}) => [
        BoxShadow(color: ring, spreadRadius: spread),
        BoxShadow(
          color: ring,
          offset: const Offset(1.25, 0),
          spreadRadius: -0.75,
        ),
        BoxShadow(
          color: ring,
          offset: const Offset(-1.25, 0),
          spreadRadius: -0.75,
        ),
      ];

  switch (variant) {
    case Ios27GlassVariant.small:
      final ring = Color(dark ? 0x40000000 : 0x24000000);
      return [
        ...ringWithSlits(ring, spread: 0.5),
        BoxShadow(
          color: Color(dark ? 0x0A000000 : 0x05000000),
          offset: const Offset(0, 8),
          blurRadius: 15,
        ),
      ];
    case Ios27GlassVariant.md:
    case Ios27GlassVariant.lg:
      final ring = Color(dark ? 0x80000000 : 0x24000000);
      return [
        BoxShadow(color: ring, blurRadius: 0.3, spreadRadius: 0.3),
        BoxShadow(
          color: Color(dark ? 0x73000000 : 0x40000000),
          offset: const Offset(0, 18),
          blurRadius: variant == Ios27GlassVariant.lg ? 48 : 46,
        ),
      ];
    case Ios27GlassVariant.widget:
      return [
        BoxShadow(
          color: Color(dark ? 0x80000000 : 0x24000000),
          blurRadius: 0.3,
          spreadRadius: 0.3,
        ),
      ];
    case Ios27GlassVariant.inactive:
      return [
        BoxShadow(
          color: Color(dark ? 0x1A000000 : 0x14000000),
          spreadRadius: 0.5,
        ),
      ];
    case Ios27GlassVariant.content:
      // Сюда не доходит: матовая карточка рисуется в `_buildContentStub` со своей тенью и
      // кромкой, `nested` на неё не действует.
      return const [];
  }
}

/// Рисует тени только снаружи формы, как CSS `box-shadow`, и затем заливку.
class _OutsideShadowPainter extends CustomPainter {
  const _OutsideShadowPainter({
    required this.border,
    required this.fill,
    required this.shadows,
  });

  final ShapeBorder border;
  final Color fill;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = border.getOuterPath(rect);
    // Вырез по форме: запас 200 px покрывает самую широкую тень (blur 48 + смещение 18).
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect.inflate(200)),
      outer,
    );
    canvas
      ..save()
      ..clipPath(outside);
    for (final s in shadows) {
      canvas.drawPath(
        border.getOuterPath(rect.shift(s.offset).inflate(s.spreadRadius)),
        s.toPaint(),
      );
    }
    canvas
      ..restore()
      ..drawPath(outer, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_OutsideShadowPainter old) =>
      old.border != border ||
      old.fill != fill ||
      !listEquals(old.shadows, shadows);
}

/// Нативный фон: `UiKitView` `dropweb/glass` с обновлением параметров без
/// пересоздания вида.
class _NativeGlass extends StatefulWidget {
  const _NativeGlass({required this.params});

  final Ios27GlassParams params;

  @override
  State<_NativeGlass> createState() => _NativeGlassState();
}

class _NativeGlassState extends State<_NativeGlass> {
  static const String _viewType = 'dropweb/glass';

  MethodChannel? _channel;

  // Параметры, о которых нативный вид уже знает: с ними он создан или
  // получил их через updateParams.
  late Ios27GlassParams _sent;

  @override
  void initState() {
    super.initState();
    _sent = widget.params;
  }

  @override
  void didUpdateWidget(_NativeGlass oldWidget) {
    super.didUpdateWidget(oldWidget);
    _push();
  }

  void _onCreated(int viewId) {
    _channel = MethodChannel('dropweb/glass_$viewId');
    // Параметры могли смениться, пока вид создавался: creationParams зафиксированы
    // при первом кадре.
    _push();
  }

  void _push() {
    final channel = _channel;
    final params = widget.params;
    if (channel == null || params == _sent) {
      return;
    }
    // Стекло слоя зума получает новый радиус каждый кадр. Пока оба состояния «ушло», форму никто
    // не видит, и слать сообщение каждый кадр незачем. Swift и сам не трогает переход при смене
    // одной формы (`surfaceDiffers`), так что этот запрет — вторая линия защиты. `_sent` не
    // обновляется, поэтому возврат (`away == false`) уйдёт с актуальной формой.
    if (params.away && _sent.away && params.sameExceptShape(_sent)) {
      return;
    }
    _sent = params;
    unawaited(_send(channel, params));
  }

  Future<void> _send(MethodChannel channel, Ios27GlassParams params) async {
    try {
      await channel.invokeMethod<void>('updateParams', params.toMap());
    } on MissingPluginException {
      // Вид уже уничтожен: обновлять нечего.
    } on PlatformException catch (e) {
      debugPrint('Ios27Glass: updateParams не принят: $e');
    }
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        // Материал не несёт смысла для VoiceOver: подписи и значки рисует Flutter.
        child: UiKitView(
          viewType: _viewType,
          creationParams: widget.params.toMap(),
          creationParamsCodec: const StandardMessageCodec(),
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
          onPlatformViewCreated: _onCreated,
        ),
      );
}
