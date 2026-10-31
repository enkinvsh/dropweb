// Списки iOS 27: группа-карточка со строками, заголовок и примечание группы, разделитель между строками
// (доска `.group`, `.list`, `.row`, `.group-head`, `.group-foot`, `.gap`, app.css:171-250).

import 'dart:math' as math;

import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart'
    show Ios27Motion, Ios27Text, Ios27Tokens;
import 'package:dropweb/ui/ios27/widgets/ios27_avatar.dart';
import 'package:flutter/material.dart';

/// Левый отступ разделителя строки без ведущего значка (`.row + .row::before{left:16px}`).
const double kIos27RowSeparatorInset = 16;

/// Левый отступ разделителя под текстом после значка, флага или логотипа (`--sep: 62px`).
const double kIos27RowSeparatorInsetLeading = 62;

/// Левый отступ разделителя у строки с цветным кружком (`.row:has(> .row__swatch){--sep:58px}`).
const double kIos27RowSeparatorInsetSwatch = 58;

/// Минимальная высота строки (`.row{min-height:52px}`).
const double kIos27RowMinHeight = 52;

/// Что стоит в конце строки.
enum Ios27RowAccessory {
  /// Ничего.
  none,

  /// Шеврон `right` 18 px цвета `--label-3` (`.row > .ico`, app.css:240).
  chevron,

  /// Галочка выбора 20 px, штрих 2,5, цвет `--accent` (`.ico.check`).
  check,

  /// Значок `out` 18 px (ссылка наружу, страница «О программе»).
  external,
}

/// Окраска строки.
enum Ios27RowTone {
  /// Обычная: подпись `--label`.
  normal,

  /// `.row--link` (app.css:569): подпись слева цветом `--accent` («Добавить подписку»).
  link,

  /// `.row--center`: подпись по центру цветом `--accent`.
  center,

  /// `.row--danger`: подпись по центру цветом `--red-text` («Удалить подписку»).
  danger,
}

/// Цвет значения справа (`.row__detail`).
enum Ios27RowDetailTone {
  /// `--label-2`.
  normal,

  /// `.is-slow`: `--orange-text` (медленный сервер).
  slow,

  /// `.is-dead`: `--label-3` (сервер не отвечает).
  dead,
}

/// Состояние для потомков списка: карточки внутри листа светлее (`.is-elevated .list`) и
/// ключи частей носят имена `sheet.*`, на странице `page.*` (`layout.json`).
class _ListScope extends InheritedWidget {
  const _ListScope({required this.elevated, required super.child});

  final bool elevated;

  static bool elevatedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ListScope>()?.elevated ??
      false;

  @override
  bool updateShouldNotify(_ListScope old) => elevated != old.elevated;
}

String _scene(BuildContext context) =>
    _ListScope.elevatedOf(context) ? 'sheet' : 'page';

/// Группа строк: карточка с полями 16 по бокам, радиусом `--r-card` (26), фоном `--card`
/// (внутри листа `--sheet-card`) и разделителями между строками (`.group > .list`).
///
/// * [children] — обычно [Ios27ListRow]; разделитель между соседями берёт отступ у нижней
///   строки (`separatorInset`), как `.row + .row::before` доски. Любой другой виджет
///   считается строкой с отступом 16.
/// * [elevated] `null` — решает по окружению: внутри листа (`Ios27SheetScope`) карточка
///   `--sheet-card`, на странице `--card`.
/// * Ключи частей для сверки с `layout.json`: `page.group` / `sheet.group`.
class Ios27List extends StatelessWidget {
  const Ios27List({super.key, required this.children, this.elevated});

  final List<Widget> children;
  final bool? elevated;

  @override
  Widget build(BuildContext context) {
    final isElevated = elevated ?? Ios27SheetScope.maybeOf(context) != null;
    final palette = Ios27Colors.of(context).palette;
    final scene = isElevated ? 'sheet' : 'page';

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      if (i == 0) {
        rows.add(child);
        continue;
      }
      final inset = child is Ios27ListRow
          ? child.effectiveSeparatorInset
          : kIos27RowSeparatorInset;
      rows.add(
        Stack(
          children: [
            child,
            // Волосок под строкой выше: 0,5 логического px = 1 физический пиксель на доске
            // (`height:1px; scale:1 .5`), цвет `--separator`.
            PositionedDirectional(
              top: 0,
              start: inset,
              end: kIos27RowSeparatorInset,
              height: 0.5,
              child: IgnorePointer(
                child: ColoredBox(color: palette.separator),
              ),
            ),
          ],
        ),
      );
    }

    return _ListScope(
      elevated: isElevated,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Ios27Tokens.margin),
        child: KeyedSubtree(
          key: ValueKey<String>('$scene.group'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Ios27Tokens.rCard),
            child: ColoredBox(
              color: isElevated ? palette.sheetCard : palette.card,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Заголовок группы: 13/18, `--label-2`, поля `22 16 0`, внутренний отступ `0 16 8` (`.group-head`).
///
/// Ключ `sheet.groupHead` / `page.groupHead` стоит на всей полосе (поля 16 по бокам, 26 высотой, как
/// элемент в `layout.json`), а не на тексте. Заголовок живёт вне `Ios27List`, поэтому «лист или
/// страница» определяется по `Ios27SheetScope`, а не по списку.
class Ios27GroupHead extends StatelessWidget {
  const Ios27GroupHead(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = Ios27Colors.of(context).palette;
    final scene = Ios27SheetScope.maybeOf(context) != null ||
            _ListScope.elevatedOf(context)
        ? 'sheet'
        : 'page';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: KeyedSubtree(
        key: ValueKey<String>('$scene.groupHead'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: ios27Text(
                context,
                Ios27Text.footnote,
                color: palette.label2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Примечание под группой: 13/18, `--label-2`, поля `0 16`, внутренний отступ `8 16 0` (`.group-foot`).
class Ios27GroupFoot extends StatelessWidget {
  const Ios27GroupFoot(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = Ios27Colors.of(context).palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
      child: Text(
        text,
        style: ios27Text(context, Ios27Text.footnote, color: palette.label2),
      ),
    );
  }
}

/// Промежуток между группами: 24 px (`.gap`).
class Ios27Gap extends StatelessWidget {
  const Ios27Gap({super.key, this.height = 24});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

/// Строка списка: все варианты доски (`.row`, app.css:197-249).
///
/// Раскладка: `[leading] 14 [title / subtitle] [detail] [accessory]`, поля `11 16`, минимальная
/// высота 52, строка растёт вместе с текстом (при крупном шрифте заголовок переносится, значение
/// остаётся в одну строку и занимает не больше 55 % ширины).
///
/// * [leading] — [Ios27Avatar] или свой виджет (кружок цвета, флаг); [separatorInset] задаёт
///   отступ разделителя (по умолчанию 62 при наличии [leading], иначе 16).
/// * [title], [subtitle] (13/18 `--label-2`), [detail] (значение справа, `--label-2`, цифры
///   моноширинные), [detailTone] (медленный/недоступный сервер), [detailShrinks] — значение
///   (адрес) сжимается с многоточием вместо заголовка (`.row:has(.host)`).
/// * [accessory] — шеврон, галочка, значок «наружу»; [trailing] — свой виджет вместо него
///   (например `Ios27Toggle`).
/// * [tone] — `link` (акцентом слева), `center` (акцентом по центру), `danger` (красным по
///   центру, `.row--danger`, app.css:243).
/// * [onTap] `null` — строка не нажимается (`div`/`label` доски, без подсветки). Нажатая
///   строка заливается `--fill-4` мгновенно и гаснет за 250 мс (app.css:208-209); отключена
///   ([enabled] `false`) — подпись `--label-3`, без отклика.
/// * [semanticLabel] заменяет склейку заголовка, значения и подписи; [semanticIdentifier] —
///   идентификатор автотестов; галочка выставляет `selected`.
/// * Ключи частей по `layout.json`: `page.row`/`sheet.row` (содержимое строки),
///   `…rowTitle`, `…rowDetail`, `…rowCheck`; значок строки носит ключ `…rowIcon` /
///   `…rowFlag` / `…rowLogo`, если его оборачивают снаружи.
class Ios27ListRow extends StatefulWidget {
  const Ios27ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.detail,
    this.detailTone = Ios27RowDetailTone.normal,
    this.detailShrinks = false,
    this.leading,
    this.separatorInset,
    this.accessory = Ios27RowAccessory.none,
    this.trailing,
    this.tone = Ios27RowTone.normal,
    this.onTap,
    this.enabled = true,
    this.semanticLabel,
    this.semanticIdentifier,
  });

  final String title;
  final String? subtitle;
  final String? detail;
  final Ios27RowDetailTone detailTone;
  final bool detailShrinks;
  final Widget? leading;
  final double? separatorInset;
  final Ios27RowAccessory accessory;
  final Widget? trailing;
  final Ios27RowTone tone;
  final VoidCallback? onTap;
  final bool enabled;
  final String? semanticLabel;
  final String? semanticIdentifier;

  /// Отступ разделителя над этой строкой.
  double get effectiveSeparatorInset =>
      separatorInset ??
      (leading != null
          ? kIos27RowSeparatorInsetLeading
          : kIos27RowSeparatorInset);

  @override
  State<Ios27ListRow> createState() => _Ios27ListRowState();
}

class _Ios27ListRowState extends State<Ios27ListRow> {
  bool _pressed = false;

  bool get _active => widget.onTap != null && widget.enabled;

  void _set(bool pressed) {
    if (_pressed != pressed && mounted) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  void didUpdateWidget(Ios27ListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Строку отключили посреди нажатия: подсветка не должна застрять.
    if (!_active && _pressed) {
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Ios27Colors.of(context);
    final palette = colors.palette;
    final scene = _scene(context);
    final centered = widget.tone == Ios27RowTone.center ||
        widget.tone == Ios27RowTone.danger;

    final titleColor = !widget.enabled
        ? palette.label3
        : switch (widget.tone) {
            Ios27RowTone.normal => palette.label,
            Ios27RowTone.link || Ios27RowTone.center => colors.accentColor,
            Ios27RowTone.danger => palette.redText,
          };
    final titleStyle = ios27Text(context, Ios27Text.body, color: titleColor);

    // У строк `link`/`center`/`danger` на доске нет `.row__title`: подпись лежит прямо в кнопке.
    final title = Text(
      widget.title,
      key: widget.tone == Ios27RowTone.normal
          ? ValueKey<String>('$scene.rowTitle')
          : null,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: titleStyle,
    );

    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        title,
        if (widget.subtitle != null)
          Text(
            widget.subtitle!,
            style:
                ios27Text(context, Ios27Text.footnote, color: palette.label2),
          ),
      ],
    );

    Widget? accessory;
    final trailing = widget.trailing;
    if (trailing != null) {
      accessory = trailing;
    } else {
      switch (widget.accessory) {
        case Ios27RowAccessory.none:
          break;
        case Ios27RowAccessory.chevron:
          accessory = Ios27Icon.spec(
            Ios27IconName.right,
            Ios27IconSpecs.row,
            color: Ios27RowIconColors.trailing(palette),
          );
        case Ios27RowAccessory.check:
          accessory = KeyedSubtree(
            key: ValueKey<String>('$scene.rowCheck'),
            child: Ios27Icon.spec(
              Ios27IconName.check,
              Ios27IconSpecs.check,
              color: colors.accentColor,
            ),
          );
        case Ios27RowAccessory.external:
          accessory = Ios27Icon.spec(
            Ios27IconName.out,
            Ios27IconSpecs.row,
            color: Ios27RowIconColors.trailing(palette),
          );
      }
    }

    final detailColor = switch (widget.detailTone) {
      Ios27RowDetailTone.normal => palette.label2,
      Ios27RowDetailTone.slow => palette.orangeText,
      Ios27RowDetailTone.dead => palette.label3,
    };
    final detailStyle = ios27Text(context, Ios27Text.body, color: detailColor)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final detail = widget.detail == null
        ? null
        : Text(
            widget.detail!,
            key: ValueKey<String>('$scene.rowDetail'),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: detailStyle,
          );

    final lead = widget.leading;
    final leadingWithKey = lead is Ios27Avatar
        ? KeyedSubtree(
            key: ValueKey<String>('$scene.${lead.layoutName}'),
            child: lead,
          )
        : lead;

    Widget content;
    if (centered) {
      content = Center(child: text);
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) {
          final detailMax = math.max(0.0, constraints.maxWidth * 0.55);
          return Row(
            children: [
              if (widget.leading != null) ...[
                // Имя части по `layout.json`: у `Ios27Avatar` свой вид даёт своё имя.
                leadingWithKey!,
                const SizedBox(width: 14),
              ],
              if (widget.detailShrinks && detail != null) ...[
                // Заголовок не растягивается, сжимается адрес (`.row:has(.host)`, app.css:236);
                // потолок 70 % ширины страхует от переполнения при крупном шрифте.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.7,
                  ),
                  child: text,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: detail,
                  ),
                ),
              ] else ...[
                Expanded(child: text),
                if (detail != null) ...[
                  const SizedBox(width: 14),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: detailMax),
                    child: detail,
                  ),
                ],
              ],
              if (accessory != null) ...[
                const SizedBox(width: 14),
                accessory,
              ],
            ],
          );
        },
      );
    }

    final body = AnimatedContainer(
      key: ValueKey<String>('$scene.row'),
      // Под пальцем подсветка сразу, при отпускании гаснет 250 мс ease-out (app.css:208-209).
      duration: _pressed ? Duration.zero : const Duration(milliseconds: 250),
      curve: Ios27Motion.easeOut,
      constraints: const BoxConstraints(minHeight: kIos27RowMinHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      color: _pressed ? palette.fill4 : const Color(0x00000000),
      child: content,
    );

    final tappable = _active
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _set(true),
            onTapUp: (_) => _set(false),
            onTapCancel: () => _set(false),
            onTap: widget.onTap,
            child: body,
          )
        : body;

    final hasLabel = widget.semanticLabel != null;
    final node = Semantics(
      container: hasLabel,
      identifier: widget.semanticIdentifier,
      button: widget.onTap != null,
      enabled: widget.enabled,
      selected: widget.accessory == Ios27RowAccessory.check ? true : null,
      label: widget.semanticLabel,
      onTap: _active ? widget.onTap : null,
      child: hasLabel ? ExcludeSemantics(child: tappable) : tappable,
    );
    // Без своей подписи заголовок, значение и подпись склеиваются в один узел для VoiceOver.
    return hasLabel ? node : MergeSemantics(child: node);
  }
}

/// Кружок цвета в начале строки: 28 px, кромка `inset 0 0 0 .5px #00000026` (`.row__swatch`).
///
/// Ставьте строке `separatorInset: kIos27RowSeparatorInsetSwatch` (58 = поле 16 + кружок 28 +
/// зазор 14: разделитель начинается под текстом).
class Ios27RowSwatch extends StatelessWidget {
  /// Три цвета провайдера секторами по 120° (`trio`, app.js:585).
  const Ios27RowSwatch.trio({
    super.key,
    required Color accent,
    required Color orb1,
    required Color orb2,
  })  : color = null,
        _trio = (accent, orb1, orb2);

  /// Один цвет.
  const Ios27RowSwatch.color(Color this.color, {super.key}) : _trio = null;

  final Color? color;
  final (Color, Color, Color)? _trio;

  @override
  Widget build(BuildContext context) {
    final trio = _trio;
    return SizedBox.square(
      dimension: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          gradient: trio == null
              ? null
              : SweepGradient(
                  // CSS `conic-gradient` идёт от верха по часовой, `SweepGradient` — от
                  // правого края: повернуть на -90°.
                  transform: const GradientRotation(-math.pi / 2),
                  colors: [
                    trio.$1,
                    trio.$1,
                    trio.$2,
                    trio.$2,
                    trio.$3,
                    trio.$3,
                  ],
                  stops: const [0, 1 / 3, 1 / 3, 2 / 3, 2 / 3, 1],
                ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x26000000), width: 0.5),
          ),
        ),
      ),
    );
  }
}

/// Колодец цвета (`.well`): радужное кольцо 28, зазор цвета строки 2, внутри цвет 22.
class Ios27RowWell extends StatelessWidget {
  const Ios27RowWell({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = Ios27Colors.of(context).palette;
    final card =
        _ListScope.elevatedOf(context) ? palette.sheetCard : palette.card;
    return SizedBox.square(
      dimension: 28,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            transform: GradientRotation(-math.pi / 2),
            colors: [
              Color(0xFFFF383C),
              Color(0xFFFF8D28),
              Color(0xFFFFCC00),
              Color(0xFF34C759),
              Color(0xFF00C3D0),
              Color(0xFF0088FF),
              Color(0xFF6155F5),
              Color(0xFFCB30E0),
              Color(0xFFFF383C),
            ],
          ),
        ),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: card, spreadRadius: 2),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x26000000), width: 0.5),
              ),
              child: const SizedBox.square(dimension: 22),
            ),
          ),
        ),
      ),
    );
  }
}
