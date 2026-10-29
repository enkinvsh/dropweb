import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../enum/enum.dart';
import '../color/color.dart';
import '../symbols.g.dart';
import '../theme/m3e_text.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import 'm3e_symbol.dart';

/// Слои состояния M3 (наведение, фокус, нажатие): цвет содержимого с прозрачностью из токенов.
WidgetStateProperty<Color?> m3eStateLayer(Color content) =>
    WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return content.withValues(alpha: M3eState.pressed);
      }
      if (states.contains(WidgetState.focused)) {
        return content.withValues(alpha: M3eState.focus);
      }
      if (states.contains(WidgetState.hovered)) {
        return content.withValues(alpha: M3eState.hover);
      }
      return null;
    });

/// Поверхность, на которой лежит список: пункты берут на ступень тона выше неё, иначе в
/// тёмной теме неона они сливаются с фоном (`--dr-item-bg` на доске).
enum M3eListSurface {
  /// Обычный `surfaceContainer`.
  container,

  /// Страница (`.dr-page`): `surfaceContainerHigh`. Ставит `M3ePage` сама.
  page,

  /// Нижний лист (`.dr-sheet`): `surfaceContainerHighest`.
  sheet,
}

/// Задаёт [M3eListSurface] всем спискам ниже. Страница ставит `page`, лист ставит `sheet`.
class M3eListSurfaceScope extends InheritedWidget {
  const M3eListSurfaceScope({
    super.key,
    required this.surface,
    required super.child,
  });

  final M3eListSurface surface;

  static M3eListSurface of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<M3eListSurfaceScope>()
          ?.surface ??
      M3eListSurface.container;

  @override
  bool updateShouldNotify(M3eListSurfaceScope old) => surface != old.surface;
}

/// Положение пункта в группе: от него зависят скругления (внешние 16, внутренние 4).
class _GroupSlot extends InheritedWidget {
  const _GroupSlot({
    required this.first,
    required this.last,
    required super.child,
  });

  final bool first;
  final bool last;

  @override
  bool updateShouldNotify(_GroupSlot old) =>
      first != old.first || last != old.last;
}

/// Сегментированный список M3E (`list()` и `.dr-list` доски): пункты через 2 dp, у группы
/// внешние углы 16, между пунктами 4.
///
/// В [children] кладут [M3eListItem]; первый и последний узнают своё место сами.
/// Соседние группы разделяют `SizedBox(height: 16)` (`.dr-list + .dr-list`), заголовок
/// группы — [M3eListHeader].
class M3eList extends StatelessWidget {
  const M3eList({super.key, required this.children, this.semanticLabel});

  final List<Widget> children;

  /// Подпись группы для диктора (`aria-label` у `radiogroup` на доске).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final last = children.length - 1;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i <= last; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          _GroupSlot(first: i == 0, last: i == last, child: children[i]),
        ],
      ],
    );
    if (semanticLabel == null) return column;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: column,
    );
  }
}

/// Заголовок группы (`.dr-list-head`): titleSmall цветом primary, поля 20/16/8.
class M3eListHeader extends StatelessWidget {
  const M3eListHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: m3eTextStyle(
              M3eType.titleSmall,
              color: M3eColors.of(context).scheme.primary,
            ),
          ),
        ),
      );
}

/// Тон пункта: `.dr-item--accent` (цвет primary) и `.dr-item--danger` (error).
enum M3eListItemTone { normal, accent, danger }

/// Цвета, которые пункт раздаёт своим ведущему и хвостовому слотам.
///
/// У выбранного пункта без радиокнопки значки и подпись наследуют цвет текста
/// (`color: inherit` у `.dr-item__lead`), иначе остаются onSurfaceVariant.
class M3eListPalette {
  const M3eListPalette._({
    required this.secondary,
    required this.onSurface,
    required this.scheme,
    required this.warn,
  });

  /// Цвет значков и подписи.
  final Color secondary;

  /// Цвет основного текста пункта.
  final Color onSurface;
  final M3eScheme scheme;

  /// Цвет медленного отклика (`--dr-warn`).
  final Color warn;
}

typedef _SlotBuilder = Widget Function(
  BuildContext context,
  M3eListPalette palette,
);

/// Ведущий слот пункта (`.dr-item__lead`): значок, аватар или радиокнопка.
class M3eListLead {
  const M3eListLead._(this._build, {this.isRadio = false});

  /// Значок 24 (`ic(name)`).
  factory M3eListLead.icon(M3eSymbol symbol, {bool fill = false}) =>
      M3eListLead._(
        (context, p) => M3eSymbolIcon(symbol, fill: fill, color: p.secondary),
      );

  /// Радиокнопка 20/10 в слоте 24 (`radioVis`): кольцо и точка primary у выбранной.
  // ignore: avoid_positional_boolean_parameters
  factory M3eListLead.radio(bool checked) => M3eListLead._(
        (context, p) => ExcludeSemantics(
          child: _RadioVisual(checked: checked, scheme: p.scheme),
        ),
        isRadio: true,
      );

  /// Круглый аватар 40 (32 при [small]) `.dr-avatar`. Ровно один из вариантов:
  /// - [text]: инициалы на secondary-container;
  /// - [icon]: значок 24 (`iconAv`); [accent] делает заливку прозрачной, а значок primary
  ///   (`.dr-avatar--add`: неоновый круг перетягивал взгляд с выбранной подписки);
  /// - [logo] / [logoSvg]: логотип провайдера на родном чёрном фоне;
  /// - [flag]: флаг на всё поле круга (Twemoji), фон surface-container-highest;
  /// - [emoji]: эмодзи из начала имени группы, фон secondary-container.
  factory M3eListLead.avatar({
    String? text,
    M3eSymbol? icon,
    ImageProvider? logo,
    String? logoSvg,
    String? flag,
    String? emoji,
    bool small = false,
    bool accent = false,
  }) {
    final given =
        [text, icon, logo, logoSvg, flag, emoji].where((v) => v != null).length;
    assert(given == 1, 'аватару нужен ровно один вариант содержимого');
    return M3eListLead._(
      (context, p) => ExcludeSemantics(
        child: _Avatar(
          scheme: p.scheme,
          text: text,
          icon: icon,
          logo: logo,
          logoSvg: logoSvg,
          flag: flag,
          emoji: emoji,
          small: small,
          accent: accent,
        ),
      ),
    );
  }

  final _SlotBuilder _build;

  /// Пункт с радиокнопкой не заливается при выборе: выбор виден по самой кнопке.
  final bool isRadio;
}

/// Тон текстового хвоста (`.dr-ms`): медленный отклик жёлтым, нет ответа красным.
enum M3eTrailTone { normal, slow, dead }

/// Хвостовой слот пункта (`.dr-item__trail`).
class M3eListTrail {
  const M3eListTrail._(this._build);

  /// Значок 24 (`open_in_new`, `check`).
  factory M3eListTrail.icon(M3eSymbol symbol, {bool fill = false}) =>
      M3eListTrail._(
        (context, p) => M3eSymbolIcon(symbol, fill: fill, color: p.secondary),
      );

  /// Задержка или счётчик (`.dr-ms`, `.dr-count`): labelMedium, цифры моноширинные.
  factory M3eListTrail.text(
    String text, {
    M3eTrailTone tone = M3eTrailTone.normal,
  }) =>
      M3eListTrail._((context, p) {
        final color = switch (tone) {
          M3eTrailTone.normal => p.secondary,
          M3eTrailTone.slow => p.warn,
          M3eTrailTone.dead => p.scheme.error,
        };
        return Text(
          text,
          maxLines: 1,
          style: m3eTextStyle(M3eType.labelMedium, color: color).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      });

  /// Малый бейдж M3: точка 6 dp цвета error («есть обновление»).
  factory M3eListTrail.badge() => M3eListTrail._(
        (context, p) => ExcludeSemantics(
          child: DecoratedBox(
            decoration:
                BoxDecoration(color: p.scheme.error, shape: BoxShape.circle),
            child: const SizedBox.square(dimension: 6),
          ),
        ),
      );

  /// Точка 24 одного цвета (`.dr-swatch--dot`): цвет приложения у пункта «Оформление».
  factory M3eListTrail.colorDot(Color color) => M3eListTrail._(
        (context, p) => ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox.square(dimension: 24),
          ),
        ),
      );

  /// Образец-точка 24 как в «Обоях и стиле» Pixel (`swatchVars`): верхняя половина —
  /// [primary] (primary-container), нижняя поделена на [tertiary] справа и [secondary] слева.
  factory M3eListTrail.swatch({
    required Color primary,
    required Color secondary,
    required Color tertiary,
  }) =>
      M3eListTrail._(
        (context, p) => ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // CSS `conic-gradient(from -90deg, a 0 50%, c 0 75%, b 0)`: старт слева,
              // по часовой. Во Flutter угол 0 смотрит вправо, поэтому поворот на pi.
              gradient: SweepGradient(
                transform: const GradientRotation(3.141592653589793),
                colors: [
                  primary,
                  primary,
                  tertiary,
                  tertiary,
                  secondary,
                  secondary
                ],
                stops: const [0, 0.5, 0.5, 0.75, 0.75, 1],
              ),
            ),
            child: const SizedBox.square(dimension: 24),
          ),
        ),
      );

  /// Переключатель 52×32 (`switchVis`): только картинка, нажимается весь пункт
  /// (передайте `toggled` пункту для диктора).
  // ignore: avoid_positional_boolean_parameters
  factory M3eListTrail.toggle(bool on) => M3eListTrail._(
        (context, p) =>
            ExcludeSemantics(child: _SwitchVisual(on: on, scheme: p.scheme)),
      );

  /// Несколько хвостов в ряд с зазором 8 (`ms()` кладёт «галочку» после задержки).
  factory M3eListTrail.row(List<M3eListTrail> parts) => M3eListTrail._(
        (context, p) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              parts[i]._build(context, p),
            ],
          ],
        ),
      );

  final _SlotBuilder _build;
}

/// Пункт списка (`item()` доски): от 56 dp, с подписью от 72; поля 16, между слотами 12.
///
/// - [onTap] `null` даёт статичный пункт без отклика (на доске это `div`, а не `button`).
/// - [radioChecked] не `null` делает пункт радиокнопкой для диктора (`checked`,
///   `inMutuallyExclusiveGroup`); выбранный пункт без радио в [lead] заливается
///   secondary-container.
/// - [toggled] не `null` объявляет переключатель; саму картинку даёт [M3eListTrail.toggle].
/// - [tone]: `accent` красит текст в primary, `danger` текст и значок в error.
class M3eListItem extends StatelessWidget {
  const M3eListItem({
    super.key,
    required this.label,
    this.sup,
    this.lead,
    this.trail,
    this.onTap,
    this.tone = M3eListItemTone.normal,
    this.radioChecked,
    this.toggled,
  });

  final String label;

  /// Подпись второй строкой (одна строка, с многоточием).
  final String? sup;
  final M3eListLead? lead;
  final M3eListTrail? trail;
  final VoidCallback? onTap;
  final M3eListItemTone tone;
  final bool? radioChecked;
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final colors = M3eColors.of(context);
    final scheme = colors.scheme;
    final slot = context.dependOnInheritedWidgetOfExactType<_GroupSlot>();
    final first = slot?.first ?? true;
    final last = slot?.last ?? true;

    const outer = Radius.circular(M3eShape.large);
    const inner = Radius.circular(M3eShape.extraSmall);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: first ? outer : inner,
        topRight: first ? outer : inner,
        bottomLeft: last ? outer : inner,
        bottomRight: last ? outer : inner,
      ),
    );

    final lead = this.lead;
    final selected = radioChecked == true && !(lead?.isRadio ?? false);
    final Color bg;
    if (selected) {
      bg = scheme.secondaryContainer;
    } else {
      bg = switch (M3eListSurfaceScope.of(context)) {
        M3eListSurface.container => scheme.surfaceContainer,
        M3eListSurface.page => scheme.surfaceContainerHigh,
        M3eListSurface.sheet => scheme.surfaceContainerHighest,
      };
    }

    final text = selected
        ? scheme.onSecondaryContainer
        : switch (tone) {
            M3eListItemTone.normal => scheme.onSurface,
            M3eListItemTone.accent => scheme.primary,
            M3eListItemTone.danger => scheme.error,
          };
    final palette = M3eListPalette._(
      secondary: selected
          ? text
          : tone == M3eListItemTone.danger
              ? scheme.error
              : scheme.onSurfaceVariant,
      onSurface: text,
      scheme: scheme,
      warn: colors.home['warn'],
    );
    // Хвост danger-пункта остаётся onSurfaceVariant (правило задаёт цвет только пункту
    // и ведущему слоту).
    final trailPalette = M3eListPalette._(
      secondary: selected ? text : scheme.onSurfaceVariant,
      onSurface: text,
      scheme: scheme,
      warn: palette.warn,
    );

    final sup = this.sup;
    final trail = this.trail;

    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: sup != null ? 72 : 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (lead != null) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 24),
                child: Center(
                    widthFactor: 1, child: lead._build(context, palette)),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: m3eTextStyle(M3eType.bodyLarge, color: text),
                  ),
                  if (sup != null)
                    Text(
                      sup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: m3eTextStyle(
                        M3eType.bodyMedium,
                        color: trailPalette.secondary,
                      ),
                    ),
                ],
              ),
            ),
            if (trail != null) ...[
              const SizedBox(width: 12),
              trail._build(context, trailPalette),
            ],
          ],
        ),
      ),
    );

    final Widget body = Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              customBorder: shape,
              onTap: onTap,
              splashFactory: InkRipple.splashFactory,
              splashColor: text.withValues(alpha: M3eState.pressed),
              highlightColor: Colors.transparent,
              overlayColor: m3eStateLayer(text),
              child: content,
            ),
    );

    if (radioChecked != null) {
      return MergeSemantics(
        child: Semantics(
          checked: radioChecked,
          inMutuallyExclusiveGroup: true,
          onTap: onTap,
          child: body,
        ),
      );
    }
    if (toggled != null) {
      return MergeSemantics(
        child: Semantics(toggled: toggled, onTap: onTap, child: body),
      );
    }
    return MergeSemantics(
      child: Semantics(button: onTap != null, child: body),
    );
  }
}

/// Радиокнопка 24 (`in-radio`, ужатая с 48 до зоны пункта): кольцо 20/2 dp, точка 10.
class _RadioVisual extends StatelessWidget {
  const _RadioVisual({required this.checked, required this.scheme});

  final bool checked;
  final M3eScheme scheme;

  @override
  Widget build(BuildContext context) {
    final color = checked ? scheme.primary : scheme.onSurfaceVariant;
    final instant = MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
          AnimatedScale(
            scale: checked ? 1 : 0,
            duration:
                instant ? Duration.zero : const Duration(milliseconds: 200),
            curve: M3eEasing.emphasizedDecelerate,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const SizedBox.square(dimension: 10),
            ),
          ),
        ],
      ),
    );
  }
}

/// Переключатель M3 52×32 с галочкой на включённом ползунке. Галочка цвета primary, а не
/// on-primary-container: в CMF primary-container равен цвету провайдера и на неоне
/// пропадала (комментарий у `.in-switch` в android.css).
class _SwitchVisual extends StatelessWidget {
  const _SwitchVisual({required this.on, required this.scheme});

  final bool on;
  final M3eScheme scheme;

  @override
  Widget build(BuildContext context) {
    final instant = MediaQuery.disableAnimationsOf(context);
    final duration =
        instant ? Duration.zero : const Duration(milliseconds: 200);
    final size = on ? 24.0 : 16.0;
    return SizedBox(
      width: 52,
      height: 32,
      child: AnimatedContainer(
        duration: duration,
        curve: M3eEasing.standard,
        decoration: BoxDecoration(
          color: on ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: on ? Colors.transparent : scheme.outline,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: duration,
              curve: M3eEasing.standard,
              // Рамка трека 2 dp входит в бокс 52×32, ползунок считается от его края.
              left: (on ? 24.0 : 8.0) - 2,
              top: (32 - size) / 2 - 2,
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: on ? scheme.onPrimary : scheme.outline,
                  shape: BoxShape.circle,
                ),
                child: on
                    ? Center(
                        child: M3eSymbolIcon(
                          M3eSymbol.check,
                          size: 16,
                          color: scheme.primary,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.scheme,
    required this.small,
    required this.accent,
    this.text,
    this.icon,
    this.logo,
    this.logoSvg,
    this.flag,
    this.emoji,
  });

  final M3eScheme scheme;
  final bool small;
  final bool accent;
  final String? text;
  final M3eSymbol? icon;
  final ImageProvider? logo;
  final String? logoSvg;
  final String? flag;
  final String? emoji;

  /// Глиф Twemoji крупнее круга: лишнее срезает обрезка, а центр держит `OverflowBox`
  /// (grid прижимал глиф к левому краю и срезал справа 25 из 63 px).
  Widget _glyph(String glyph, double fontSize) => OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Text(
          glyph,
          softWrap: false,
          style: TextStyle(
            fontFamily: FontFamily.twEmoji.value,
            fontSize: fontSize,
            height: 1,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final d = small ? 32.0 : 40.0;
    var bg = scheme.secondaryContainer;
    var fg = scheme.onSecondaryContainer;
    Widget child;
    if (logo != null || logoSvg != null) {
      bg = Colors.black;
      child = logoSvg != null
          ? Padding(
              padding: small
                  ? const EdgeInsets.symmetric(horizontal: 4, vertical: 6)
                  : const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
              child: SvgPicture.string(logoSvg!, fit: BoxFit.contain),
            )
          : Image(image: logo!, fit: BoxFit.cover);
    } else if (flag != null) {
      bg = scheme.surfaceContainerHighest;
      child = _glyph(flag!, small ? 44 : 54);
    } else if (emoji != null) {
      child = _glyph(emoji!, small ? 18 : 22);
    } else if (icon != null) {
      if (accent) {
        bg = Colors.transparent;
        fg = scheme.primary;
      }
      child = M3eSymbolIcon(icon!, color: fg);
    } else {
      child = Center(
        child: Text(
          text!,
          maxLines: 1,
          style: m3eTextStyle(M3eType.titleMedium, color: fg).copyWith(
            fontSize: small ? 13 : 16,
            letterSpacing: 0.1,
          ),
        ),
      );
    }
    return SizedBox.square(
      dimension: d,
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: ClipOval(child: Center(child: child)),
      ),
    );
  }
}
