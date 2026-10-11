import 'dart:math' as math;

import 'package:dropweb/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassCard,
        GlassDefaults,
        GlassFillTransition,
        GlassMenu,
        GlassMenuAlignment,
        GlassMenuItem,
        GlassModalSheet,
        GlassModalSheetController,
        GlassModalSheetScaffold,
        GlassQuality,
        GlassSheetDetent,
        GlassSheetState,
        LiquidRoundedSuperellipse;

// Общие блоки «Liquid Lumina» из шита «Подписка»: стеклянный шит, карточки,
// строки, разделители и круглый «⋯». Аккаунт и вход собраны из них же, чтобы
// все шиты приложения говорили одним языком.

/// Отступ разделителя в сгруппированной карточке: паддинг строки 16 +
/// иконка 24 + зазор 12 — линия начинается под заголовком, как в iOS.
const double kLiquidDividerIndent = 52;

/// Контент шита начинается под ручкой (пилюля стоит на y 8–12).
const double kLiquidSheetTopInset = 24;

/// Нижний отступ контента шита над safe area.
const double kLiquidSheetBottomInset = 16;

/// Зазор под шитом; равен `bottomMargin`, который [showLiquidSheet] отдаёт
/// шиту, — суммы высот на него опираются.
const double kLiquidSheetBottomMargin = 8;

/// Высота одной строки [style] с учётом масштаба шрифта. GlassModalSheet не
/// мерит контент сам, поэтому высоту шита складывают из таких строк.
double liquidLineHeight(BuildContext context, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(text: 'Ag', style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

/// Стеклянный шит как у «Подписки»: одна средняя высота [halfSize]
/// (в логических пикселях), стекло меню Lumina, свечение акцентом.
///
/// С [morphFromRect] это ровно `GlassModalSheet.show`: морф держится на
/// приватном презентере пакета. Без морфа маршрут собран из тех же частей с
/// теми же параметрами, но через хост: пакет прибивает шит к низу экрана и не
/// знает про клавиатуру, а высоту берёт числом. Хост поднимает шит над IME и
/// подгоняет высоту под [LiquidSheetBody], когда её содержимое меняется.
Future<T?> showLiquidSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  required double halfSize,
  Rect? morphFromRect,
}) {
  final glowColor = context.colorScheme.primary;
  if (morphFromRect != null) {
    return GlassModalSheet.show<T>(
      context: context,
      builder: builder,
      morphFromRect: morphFromRect,
      halfSize: halfSize,
      initialState: GlassSheetState.half,
      detents: const {GlassSheetDetent.medium},
      bottomMargin: kLiquidSheetBottomMargin,
      settings: Lumina.liquidMenu,
      quality: GlassQuality.standard,
      glowColor: glowColor,
    );
  }
  // Маршрут и анимация — копия немонфного пути `GlassModalSheet.show`.
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: GlassDefaults.barrierColor,
    transitionDuration: const Duration(milliseconds: 500),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        SlideTransition(
      position:
          Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutQuart),
      ),
      child: child,
    ),
    pageBuilder: (context, animation, secondaryAnimation) => _LiquidSheetHost(
      halfSize: halfSize,
      glowColor: glowColor,
      sheet: builder(context),
    ),
  );
}

class _LiquidSheetHost extends StatefulWidget {
  const _LiquidSheetHost({
    required this.halfSize,
    required this.glowColor,
    required this.sheet,
  });

  final double halfSize;
  final Color glowColor;
  final Widget sheet;

  @override
  State<_LiquidSheetHost> createState() => _LiquidSheetHostState();
}

class _LiquidSheetHostState extends State<_LiquidSheetHost> {
  final _controller = GlassModalSheetController();
  double? _contentHeight;
  bool _closing = false;

  void _setContentHeight(double height) {
    if (!mounted || _contentHeight == height) return;
    setState(() => _contentHeight = height);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final contentHeight = _contentHeight;
    final requested = contentHeight == null
        ? widget.halfSize
        : contentHeight + kLiquidSheetBottomMargin;
    // Шит стоит на клавиатуре, поэтому потолок считается от того, что над ней.
    final halfSize = math.min(requested, (media.size.height - keyboard) * 0.85);
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      // Шиту и контенту отдаём раскладку без клавиатуры: подъём уже сделан
      // паддингом. Нижний safe-area отступ над открытой клавиатурой не нужен
      // (жестовую панель закрывает она), иначе под карточкой висят лишние
      // 24 dp. Снимаем его одним шагом, а не вслед за кадрами анимации IME:
      // каждая смена высоты перезапускает пружину шита с нулевой скоростью.
      child: MediaQuery(
        data: media.copyWith(
          viewInsets: media.viewInsets.copyWith(bottom: 0),
          padding: media.padding.copyWith(
            bottom: keyboard > 0 ? 0 : media.padding.bottom,
          ),
        ),
        child: _LiquidSheetScope(
          onContentHeight: _setContentHeight,
          child: GlassModalSheetScaffold(
            controller: _controller,
            halfSize: halfSize,
            initialState: GlassSheetState.half,
            fillThreshold: 0.60,
            settings: Lumina.liquidMenu,
            quality: GlassQuality.standard,
            fillTransition: GlassFillTransition.instant,
            topBorderRadius: 56,
            fullTopBorderRadius: 46,
            bottomMargin: kLiquidSheetBottomMargin,
            glowColor: widget.glowColor,
            detents: const {GlassSheetDetent.medium},
            onStateChanged: (state) {
              if (state == GlassSheetState.hidden && !_closing) {
                _closing = true;
                Navigator.of(context).pop();
              }
            },
            body: const SizedBox.shrink(),
            sheet: widget.sheet,
          ),
        ),
      ),
    );
  }
}

class _LiquidSheetScope extends InheritedWidget {
  const _LiquidSheetScope({
    required this.onContentHeight,
    required super.child,
  });

  final ValueChanged<double> onContentHeight;

  static ValueChanged<double>? of(BuildContext context) => context
      .getInheritedWidgetOfExactType<_LiquidSheetScope>()
      ?.onContentHeight;

  @override
  bool updateShouldNotify(_LiquidSheetScope oldWidget) => false;
}

/// Содержимое шита [showLiquidSheet]: поля как у «Подписки» и колонка, под
/// высоту которой хост подгоняет шит (шаги, ошибки, новые строки).
class LiquidSheetBody extends StatelessWidget {
  const LiquidSheetBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final onContentHeight = _LiquidSheetScope.of(context);
    Widget content = Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        kLiquidSheetTopInset,
        16,
        kLiquidSheetBottomInset + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    if (onContentHeight != null) {
      content = _HeightReporter(onHeight: onContentHeight, child: content);
    }
    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(child: content),
    );
  }
}

class _HeightReporter extends SingleChildRenderObjectWidget {
  const _HeightReporter({required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeightReporter(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeightReporter renderObject,
  ) =>
      renderObject.onHeight = onHeight;
}

class _RenderHeightReporter extends RenderProxyBox {
  _RenderHeightReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (size.height == _reported) return;
    _reported = size.height;
    // Высоту шита меняем после кадра: посреди layout перестраивать хост нельзя.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached && hasSize) onHeight(size.height);
    });
  }
}

/// Подложка карточки — то же стекло, что у карточки подписки на дашборде.
/// Material обрезает ripple строк по форме карточки.
class LiquidCard extends StatelessWidget {
  const LiquidCard({super.key, required this.child, this.flat = false});

  final Widget child;

  /// Плоская заливка вместо стекла — для карточек внутри стеклянного шита:
  /// стекло в стекло не вкладываем.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    if (flat) {
      return Material(
        color: context.colorScheme.onSurface.opacity10,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(Lumina.radiusLg),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }
    return GlassCard(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      padding: EdgeInsets.zero,
      shape: const LiquidRoundedSuperellipse(borderRadius: Lumina.radiusLg),
      settings: Lumina.liquidCard,
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(Lumina.radiusLg),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// Строка сгруппированной карточки в стиле настроек: иконка, заголовок,
/// trailing.
class LiquidTile extends StatelessWidget {
  const LiquidTile({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final List<List<dynamic>> icon;
  final Widget title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: Center(
                  child: HugeIcon(
                    icon: icon,
                    size: 22,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: title),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Разделитель сгруппированного списка в стиле iOS.
class LiquidHairline extends StatelessWidget {
  const LiquidHairline({super.key, this.indent = 16});

  final double indent;

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 0.5,
        indent: indent,
        color: context.colorScheme.outlineVariant.opacity50,
      );
}

/// Шеврон строки, которая ведёт дальше.
class LiquidChevron extends StatelessWidget {
  const LiquidChevron({super.key});

  @override
  Widget build(BuildContext context) => HugeIcon(
        icon: HugeIcons.strokeRoundedArrowRight01,
        size: 18,
        color: context.colorScheme.onSurfaceVariant,
      );
}

/// Пункт стеклянного меню; [isDestructive] красит его в error.
GlassMenuItem liquidMenuItem(
  BuildContext context, {
  required String title,
  required VoidCallback onTap,
  List<List<dynamic>>? icon,
  String? subtitle,
  Widget? trailing,
  bool isSelected = false,
  bool isDestructive = false,
}) {
  final colorScheme = context.colorScheme;
  final textTheme = context.textTheme;
  final color = isDestructive ? colorScheme.error : colorScheme.onSurface;
  GlassMenuItem build(int maxLines) => GlassMenuItem(
        title: title,
        subtitle: subtitle,
        // Двухстрочному пункту мало штатных 44pt пакета — в них влезает только
        // заголовок.
        height: subtitle == null ? 44 : 56,
        icon:
            icon == null ? null : HugeIcon(icon: icon, size: 20, color: color),
        iconColor: color,
        titleStyle: textTheme.bodyLarge?.copyWith(color: color),
        maxLines: maxLines,
        subtitleStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        trailing: trailing,
        isSelected: isSelected,
        isDestructive: isDestructive,
        onTap: onTap,
      );
  final item = build(1);
  // Пакет резервирует высоту под maxLines строк у каждого пункта, даже если
  // текст влез в одну (на Pixel меню «⋯» получило пустую полосу снизу).
  // Вторую строку даём, только когда заголовок не влезает и в самое широкое
  // меню: на 320 dp ×1.4 «Удалить с устройства» не помещается и в 288.
  final limit = MediaQuery.sizeOf(context).width - 32;
  return _liquidMenuItemWidth(context, item) > limit ? build(2) : item;
}

/// Ширина пункта меню с заголовком в одну строку при текущем масштабе шрифта.
double _liquidMenuItemWidth(BuildContext context, GlassMenuItem item) {
  final painter = TextPainter(
    text: TextSpan(text: item.title, style: item.titleStyle),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  // Поля пакета: контент меню 12+12, пункт 16+16, иконка + зазор 12.
  final width =
      painter.width + 24 + 32 + (item.icon == null ? 0 : item.iconSize + 12);
  painter.dispose();
  return width.ceilToDouble();
}

/// Круг 32 px в квадрате 40 px — вид «⋯». Им же сделаны его заменители
/// (спиннер, кнопка отправки), чтобы соседи не прыгали при подмене.
class LiquidCircleButton extends StatelessWidget {
  const LiquidCircleButton({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget circle = SizedBox.square(
      dimension: 40,
      // Заливка держит глиф читаемым поверх водяного знака логотипа
      // провайдера (iOS «ellipsis.circle.fill»).
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Lumina.surface5.opacity60,
            border: Border.all(
              color: context.colorScheme.outlineVariant.opacity50,
              width: 0.5,
            ),
          ),
          child: SizedBox.square(
            dimension: 32,
            child: Center(child: child),
          ),
        ),
      ),
    );
    final onTap = this.onTap;
    if (onTap != null) {
      // Непрозрачный детектор: попадание — весь квадрат 40×40, а не только
      // нарисованные пиксели глифа.
      circle = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: circle,
      );
    }
    final semanticLabel = this.semanticLabel;
    if (semanticLabel == null) return circle;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: circle,
    );
  }
}

/// Заменитель «⋯» на время работы: тот же круг со спиннером, чтобы hero не
/// прыгал.
class LiquidUpdatingIndicator extends StatelessWidget {
  const LiquidUpdatingIndicator({super.key});

  @override
  Widget build(BuildContext context) => const LiquidCircleButton(
        child: SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
}

/// Базовая ширина меню «⋯»: короткие пункты («Подписка», «Аккаунт»)
/// живут в ней без изменений.
const kLiquidMenuWidth = 240.0;

/// Ширина меню «⋯»: 240, а если самый длинный заголовок при текущем
/// масштабе шрифта не влезает — по нему, но не шире экрана без 16 с боков.
/// На 320 dp ×1.4 «Удалить с устройства» в 240 резалось до «Удалить с…».
double liquidMenuWidth(BuildContext context, List<Widget> items) {
  var widest = 0.0;
  for (final item in items) {
    if (item is! GlassMenuItem) continue;
    widest = math.max(widest, _liquidMenuItemWidth(context, item));
  }
  final limit = MediaQuery.sizeOf(context).width - 32;
  return math.max(kLiquidMenuWidth, math.min(widest, limit));
}

/// «⋯» hero-карточки с меню действий, собранных через [liquidMenuItem].
class LiquidMoreMenu extends StatelessWidget {
  const LiquidMoreMenu({super.key, required this.items, this.semanticLabel});

  final List<Widget> items;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return GlassMenu(
      triggerBuilder: (_, toggle) => LiquidCircleButton(
        onTap: toggle,
        semanticLabel: semanticLabel,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedMoreHorizontal,
          size: 20,
          color: colorScheme.onSurface,
        ),
      ),
      items: items,
      menuAlignment: GlassMenuAlignment.topRight,
      autoAdjustToScreen: true,
      menuWidth: liquidMenuWidth(context, items),
      settings: Lumina.liquidMenu,
      quality: Lumina.liquidOverlayQuality,
      selectionColor: colorScheme.primary.opacity15,
      glowColor: colorScheme.primary,
    );
  }
}
