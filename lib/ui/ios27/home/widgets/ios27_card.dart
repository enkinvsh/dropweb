// Карточка главной: вариант №4 «Компактная плашка (Control Center)».
//
// Источник: canon/.omo/hig-cards/index.html, CSS `.v4*` (строки 469-536) и render() варианта v4
// (1029-1061). Владелец выбрал её 30.10 вместо карточки `hc` основной доски: на нативном
// стекле серый вторичный текст не читался (iOS 27, тёмная тема), а плотный матовый материал
// решает это. HIG: Liquid Glass только у функционального слоя (кнопки), а контент (текст) лежит
// на материале, не на стекле.
//
// Виджет чистый: ничего не читает из провайдеров и l10n, все строки приходят в [Ios27CardData].
// Объявление провайдера вынесено из карточки в подвал под ней — [Ios27CardFooter].

import 'dart:math' as math;

import 'package:dropweb/enum/enum.dart' show FontFamily;
import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card_data.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_elapsed_builder.dart';
import 'package:dropweb/ui/ios27/layers/ios27_spring_curve.dart';
import 'package:dropweb/ui/ios27/theme/ios27_card_colors.dart';
import 'package:dropweb/ui/ios27/theme/ios27_footer_colors.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_activity_indicator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Ключи элементов карточки для сверки рамок с доской карточек (`ios27Parity`, G4-lite).
abstract final class Ios27CardKeys {
  static const card = ValueKey<String>('card');
  static const head = ValueKey<String>('card.head');
  static const name = ValueKey<String>('card.name');
  static const timer = ValueKey<String>('card.timer');
  static const plan = ValueKey<String>('card.plan');
  static const meter = ValueKey<String>('card.meter');
  static const separator = ValueKey<String>('card.separator');
  static const bar = ValueKey<String>('card.bar');

  /// Левая часть нижней строки: флаг и название страны (или индикатор и «Подключение…»).
  static const country = ValueKey<String>('card.country');
  static const flag = ValueKey<String>('card.flag');
  static const spinner = ValueKey<String>('card.spinner');

  /// Статус справа в нижней строке: точка и слово.
  static const state = ValueKey<String>('card.state');
  static const dot = ValueKey<String>('card.dot');

  /// «Обновить» справа в нижней строке.
  static const refresh = ValueKey<String>('card.refresh');

  /// Подвал с объявлением под карточкой (вся ширина карточки, с полями).
  static const footer = ValueKey<String>('card.footer');
  static const footerText = ValueKey<String>('card.footer.text');
}

/// Высота цели нажатия (HIG: не меньше 44 pt).
const double _kHitTarget = 44;

/// Карточка №4: имя и таймер, тариф со шкалой квоты, разделитель, страна и статус или «Обновить».
///
/// - Поверхность — стекло Widget Glass ([Ios27GlassVariant.widget], как `.hc glass--widget` доски),
///   радиус 26. Стекло — выбор владельца 30.10 («мне нравится стекло»). Читаемость вторичного текста держит затемнение подложки в Swift
///   (`widgetDim`), поэтому основной текст карточки красится ярлыком стекла `glassLabel`
///   (`--glass-label`, app.css:516-556), а вторичный — живым вторичным уровнем
///   [Ios27CardColors.secondary] (HIG materials.md:44; серый `--glass-label-2` на стекле не виден).
/// - Размеры доски умножены на масштаб шрифта системы (D8): множитель из
///   `MediaQuery.textScalerOf`, строки фиксированной высоты по роли, карточка растёт вниз и не
///   прокручивается.
/// - Никакого бесконечного движения: точка статуса статична, таймер обычный текст раз в секунду.
///   Вечная анимация держала бы 62,5 кадра/с поверх нативных стёкол и грела iPhone 8 (замер
///   `test/ios27/battery_probe_test.dart`).
class Ios27Card extends StatelessWidget {
  const Ios27Card({
    super.key,
    required this.data,
    this.onRefresh,
    this.now = DateTime.now,
  });

  final Ios27CardData data;

  /// Нажатие «Обновить» (`data.refreshLabel != null`).
  final VoidCallback? onRefresh;

  /// «Сейчас» для таймера: тесты подставляют часы fake-async.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context).scale(1);
    final p = Ios27Colors.of(context).palette;
    final hasAction = data.refreshLabel != null;
    // Цель нажатия «Обновить» растёт вверх и вниз за счёт полей вокруг строки, а не высоты
    // карточки: ровно сколько не хватает до 44 pt, ровно столько снимаем с разделителя и низа.
    // Строка текста «Обновить» — 20·ts (subhead), до 44 pt не хватает `need`. Добираем его полями
    // вокруг текста, а не высотой карточки: сверху съедаем отступ разделителя, снизу — нижнее
    // поле карточки (оно не уходит в минус). Текст при этом смещается от оси доски не больше
    // чем на 1–2 dp.
    final need = hasAction ? math.max(0.0, _kHitTarget - 20 * ts) : 0.0;
    final slopTop = need / 2;
    final slopBottom = math.min(need / 2, 14.0);

    final head = data.since == null
        ? _Head(data: data, timerText: null)
        : Ios27ElapsedBuilder(
            since: data.since!,
            now: now,
            builder: (context, text) => _Head(data: data, timerText: text),
          );

    return Semantics(
      container: true,
      // Группа с одной читаемой фразой: имя, тариф, страна, статус. Видимые тексты из
      // семантики убраны, иначе VoiceOver прочёл бы всё дважды; «Обновить» остаётся своей кнопкой.
      explicitChildNodes: true,
      label: data.semanticsLabel,
      child: Ios27Glass(
        key: Ios27CardKeys.card,
        shape: const Ios27GlassShape.rounded(Ios27Tokens.rCard),
        variant: Ios27GlassVariant.widget,
        child: Padding(
          // Нижнее поле возвращает то, что верхний запас занял сверх отступа разделителя (11):
          // иначе низ карточки поднялся бы на эту величину относительно доски.
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            14 - slopBottom + math.max(0.0, slopTop - 11),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(child: head),
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _Plan(data: data),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                    top: 11, bottom: math.max(0.0, 11 - slopTop)),
                // Линия 0.5 px в боксе 1 px: так её раскладывает Chrome (`scaleY(.5)`).
                child: SizedBox(
                  key: Ios27CardKeys.separator,
                  height: 1,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: .5,
                      width: double.infinity,
                      child: ColoredBox(color: p.separator),
                    ),
                  ),
                ),
              ),
              _Bar(
                key: Ios27CardKeys.bar,
                data: data,
                slopTop: slopTop,
                slopBottom: slopBottom,
                onRefresh: onRefresh,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Общие помощники

/// На сколько px поднять базовую линию строки роли, чтобы совпасть с Chrome доски.
///
/// Chrome округляет подъём и спуск шрифта до целых px и сажает базовую линию 17-пиксельных
/// строк на 16 px от верха строки 22, Flutter по тем же метрикам Onest — на 17. 13 и 15 px
/// совпадают с доской (замер golden против эталона, `.omo/ios/t4/a2/`).
double _raise(Ios27TextRole role) => role.size == 17 ? 1 : 0;

/// Однострочная строка фиксированной высоты роли: запасной шрифт эмодзи не растягивает строку.
///
/// Базовая линия строки при `forceStrutHeight` определяется метриками самой распорки, поэтому
/// кегль распорки подбирается так, чтобы линия поднялась на [_raise] px (подъём шрифта Onest
/// 0.970, спуск 0.305: сдвиг линии = 0.3325 кегля).
StrutStyle _strut(Ios27TextRole role) {
  final size = role.size - _raise(role) / 0.3325;
  return StrutStyle(
    fontFamily: Ios27Text.style(role).fontFamily,
    fontSize: size,
    height: role.lineHeight / size,
    forceStrutHeight: true,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

/// Вторичный текст карточки: живой уровень поверх стекла вместо плоского серого
/// (см. [Ios27CardColors]).
Color _secondary(BuildContext context) =>
    Ios27CardColors.secondary(dark: Ios27Colors.of(context).dark);

/// Моноширинные цифры (`.num` доски): таймер и счётчики не прыгают по ширине.
const _tabular = [FontFeature.tabularFigures()];

// ---------------------------------------------------------------------------------------------
// Шапка: имя и таймер

class _Head extends StatelessWidget {
  const _Head({required this.data, required this.timerText});

  final Ios27CardData data;
  final String? timerText;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context).scale(1);
    final p = Ios27Colors.of(context).palette;
    final name = Text(
      data.title,
      key: Ios27CardKeys.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: ios27Text(context, Ios27Text.headline, color: p.glassLabel),
      strutStyle: _strut(Ios27Text.headline),
    );
    return ConstrainedBox(
      key: Ios27CardKeys.head,
      constraints: BoxConstraints(minHeight: 22 * ts),
      child: timerText == null
          ? SizedBox(width: double.infinity, child: name)
          : Row(
              // Базовая линия, а не центр: имя 17 и таймер 15 стоят на одной строке письма.
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: name),
                const SizedBox(width: 12),
                Text(
                  timerText!,
                  key: Ios27CardKeys.timer,
                  maxLines: 1,
                  softWrap: false,
                  style: ios27Text(context, Ios27Text.subhead,
                          color: _secondary(context))
                      .copyWith(fontFeatures: _tabular),
                  strutStyle: _strut(Ios27Text.subhead),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Тариф

class _Plan extends StatelessWidget {
  const _Plan({required this.data});

  final Ios27CardData data;

  @override
  Widget build(BuildContext context) {
    final p = Ios27Colors.of(context).palette;
    final color = switch (data.planTone) {
      Ios27CardTone.normal => _secondary(context),
      Ios27CardTone.warn => p.orangeText,
      Ios27CardTone.bad => p.redText,
    };
    final pct = data.meterPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: Ios27CardKeys.plan,
          width: double.infinity,
          child: Text(
            data.planText,
            style: ios27Text(context, Ios27Text.subhead, color: color)
                .copyWith(fontFeatures: _tabular),
            strutStyle: _strut(Ios27Text.subhead),
          ),
        ),
        if (pct != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _Meter(key: Ios27CardKeys.meter, percent: pct),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Шкала квоты

/// Шкала квоты: дорожка `fill-3`, полоса зелёная, после 90 % оранжевая, на 100 % красная.
class _Meter extends StatelessWidget {
  const _Meter({super.key, required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final p = Ios27Colors.of(context).palette;
    final fill = percent >= 100
        ? p.red
        : percent > 90
            ? p.orange
            : p.green;
    return SizedBox(
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: ColoredBox(
          color: p.fill3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (percent / 100).clamp(0.0, 1.0),
              heightFactor: 1,
              child: ColoredBox(color: fill),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Нижняя строка: страна слева, статус или «Обновить» справа

class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.data,
    required this.slopTop,
    required this.slopBottom,
    required this.onRefresh,
  });

  final Ios27CardData data;

  /// Поля над и под строкой, добирающие цель нажатия «Обновить» до 44 pt.
  final double slopTop;
  final double slopBottom;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context).scale(1);
    final Widget? right;
    if (data.refreshLabel != null) {
      right = _RefreshAction(
        key: Ios27CardKeys.refresh,
        label: data.refreshLabel!,
        slopTop: slopTop,
        slopBottom: slopBottom,
        onTap: onRefresh,
      );
    } else if (data.countryPending) {
      // Пока страна определяется, справа пусто: слово статуса дублировало бы «Подключение…».
      right = null;
    } else {
      right = ExcludeSemantics(child: _StateWord(data: data));
    }

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 22 * ts),
      child: Align(
        alignment: Alignment.centerLeft,
        // Wrap вместо Row: на обычном размере страна слева, статус прижат вправо; на крупном
        // шрифте (D8) для обоих не хватает ширины, и статус переходит на строку ниже, а не
        // сжимает название страны до букв в столбик.
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              ExcludeSemantics(child: _Country(data: data)),
              if (right != null) right,
            ],
          ),
        ),
      ),
    );
  }
}

/// Страна: флаг и название, индикатор и «Подключение…» или приглушённое «—» без сети.
class _Country extends StatelessWidget {
  const _Country({required this.data});

  final Ios27CardData data;

  String get _swapKey => data.countryPending
      ? 'busy'
      : data.countryText == null
          ? 'none'
          : '${data.countryFlag} ${data.countryText}';

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context).scale(1);
    final p = Ios27Colors.of(context).palette;
    final base = ios27Text(context, Ios27Text.subhead);
    final Widget content;
    if (data.countryPending) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            key: Ios27CardKeys.spinner,
            dimension: 18 * ts,
            child: Ios27ActivityIndicator(
                size: 18 * ts, color: _secondary(context)),
          ),
          SizedBox(width: 7 * ts),
          Flexible(
            child: Text(
              data.countryLoadingLabel,
              style: base.copyWith(color: _secondary(context)),
              strutStyle: _strut(Ios27Text.subhead),
            ),
          ),
        ],
      );
    } else if (data.countryText == null) {
      content = Text(
        data.countryPlaceholder,
        maxLines: 1,
        softWrap: false,
        style: base.copyWith(color: _secondary(context)),
        strutStyle: _strut(Ios27Text.subhead),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data.countryFlag.isNotEmpty) ...[
            _Flag(emoji: data.countryFlag),
            SizedBox(width: 7 * ts),
          ],
          Flexible(
            child: Text(
              data.countryText!,
              style: base.copyWith(
                color: p.glassLabel,
                fontWeight: FontWeight.w500,
              ),
              strutStyle: _strut(Ios27Text.subhead),
            ),
          ),
        ],
      );
    }
    return _ValueSwap(
      swapKey: _swapKey,
      lineHeight: 20 * ts,
      child: KeyedSubtree(key: Ios27CardKeys.country, child: content),
    );
  }
}

/// Слово статуса с точкой: серое, зелёное при подключении, красное при ошибке.
class _StateWord extends StatelessWidget {
  const _StateWord({required this.data});

  final Ios27CardData data;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context).scale(1);
    final p = Ios27Colors.of(context).palette;
    final (dot, text) = switch (data.dot) {
      Ios27DotKind.off || Ios27DotKind.busy => (p.gray, _secondary(context)),
      Ios27DotKind.on => (p.greenText, p.greenText),
      Ios27DotKind.bad => (p.redText, p.redText),
    };
    return Row(
      key: Ios27CardKeys.state,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Точка статична: пульс и кольцо держали бы кадры поверх нативных стёкол (батарея).
        Container(
          key: Ios27CardKeys.dot,
          width: 8 * ts,
          height: 8 * ts,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        SizedBox(width: 6 * ts),
        Text(
          data.statusText,
          maxLines: 1,
          softWrap: false,
          style: ios27Text(context, Ios27Text.footnote, color: text)
              .copyWith(fontWeight: FontWeight.w500),
          strutStyle: _strut(Ios27Text.footnote),
        ),
      ],
    );
  }
}

/// «Обновить»: акцентный текст без подложки, цель нажатия до 44 pt за счёт полей [slopTop] и [slopBottom].
class _RefreshAction extends StatefulWidget {
  const _RefreshAction({
    super.key,
    required this.label,
    required this.slopTop,
    required this.slopBottom,
    required this.onTap,
  });

  final String label;
  final double slopTop;
  final double slopBottom;
  final VoidCallback? onTap;

  @override
  State<_RefreshAction> createState() => _RefreshActionState();
}

class _RefreshActionState extends State<_RefreshAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = Ios27Colors.of(context).accentColor;
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Padding(
          padding:
              EdgeInsets.only(top: widget.slopTop, bottom: widget.slopBottom),
          // Нажатая кнопка текста темнеет, как стандартная кнопка-надпись iOS.
          child: Opacity(
            opacity: _pressed ? .5 : 1,
            child: Text(
              widget.label,
              maxLines: 1,
              softWrap: false,
              style: ios27Text(context, Ios27Text.subhead, color: accent)
                  .copyWith(fontWeight: FontWeight.w600),
              strutStyle: _strut(Ios27Text.subhead),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Флаг и смена значения

/// Плитка флага: квадрат `18·ts`, скругление `.22`, эмодзи Twemoji `1.2×`, кромка 0.5 px изнутри.
class _Flag extends StatelessWidget {
  const _Flag({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context).scale(1);
    final dark = Ios27Colors.of(context).dark;
    final side = 18 * ts;
    final radius = BorderRadius.circular(side * .22);
    return SizedBox.square(
      key: Ios27CardKeys.flag,
      dimension: side,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Глиф выходит за плитку, поэтому центрируется сдвигом и режется скруглением.
            OverflowBox(
              minWidth: 0,
              minHeight: 0,
              maxWidth: side * 2,
              maxHeight: side * 2,
              child: Text(
                emoji,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: FontFamily.twEmoji.value,
                  fontSize: 18 * 1.2,
                  height: 1,
                  // `light-dark(#0000001F, #FFFFFF24)` доски — кромка, а не цвет текста.
                  color: const Color(0xFF000000),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    width: .5,
                    // Светлая кромка `#0000001F` совпадает с `--separator`. Тёмная `#FFFFFF24`
                    // (альфа 0x24) отличается от `--separator` тёмной (0x1F), токена для неё
                    // нет: остаётся литералом до переноса в тему.
                    color: dark
                        ? const Color(0x24FFFFFF)
                        : Ios27Colors.of(context).palette.separator,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Плавная смена страны (`ipSwap` основной доски, app.js:876-890): прежнее гаснет за 100 мс поверх,
/// новое проявляется за ним и поднимается на треть строки пружиной `smooth`. При «Уменьшить
/// движение» только угасание/проявление за 100 мс. Первая отрисовка и скрытое поддерево без
/// движения. Движение конечное (≤ 0,9 с), бесконечного в карточке нет.
class _ValueSwap extends StatefulWidget {
  const _ValueSwap({
    required this.swapKey,
    required this.lineHeight,
    required this.child,
  });

  final String swapKey;
  final double lineHeight;
  final Widget child;

  @override
  State<_ValueSwap> createState() => _ValueSwapState();
}

class _ValueSwapState extends State<_ValueSwap>
    with SingleTickerProviderStateMixin {
  static const _fadeMs = 100;
  static final _settleMs = Ios27Motion.springSmooth.settle.inMilliseconds;
  static final _curve = Ios27SpringCurve(Ios27Motion.springSmooth);

  late final AnimationController _controller;

  Widget? _old;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    // Создаём сразу, а не лениво: ленивый контроллер впервые создался бы уже в dispose(),
    // когда поиск TickerMode по дереву запрещён.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _fadeMs),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _old = null);
        }
      });
  }

  @override
  void didUpdateWidget(_ValueSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.swapKey == widget.swapKey) {
      return;
    }
    if (!TickerMode.valuesOf(context).enabled) {
      _controller.stop();
      _old = null;
      return;
    }
    _reduce = MediaQuery.disableAnimationsOf(context);
    _old = oldWidget.child;
    _controller.duration =
        Duration(milliseconds: _reduce ? _fadeMs : _fadeMs + _settleMs);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final old = _old;
    if (old == null) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final total = _controller.duration!.inMilliseconds;
        final ms = _controller.value * total;
        final fadeOut = (ms / _fadeMs).clamp(0.0, 1.0);
        final double opacity;
        var dy = 0.0;
        if (_reduce) {
          opacity = fadeOut;
        } else {
          final p =
              _curve.transform(((ms - _fadeMs) / _settleMs).clamp(0.0, 1.0));
          opacity = p;
          dy = widget.lineHeight / 3 * (1 - p);
        }
        return Stack(
          fit: StackFit.passthrough,
          clipBehavior: Clip.none,
          children: [
            Transform.translate(
              offset: Offset(0, dy),
              child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0), child: widget.child),
            ),
            // Без `right`: уходящее значение держит свою естественную ширину. Иначе его
            // стеснила бы ширина нового (например, «—» вместо «Россия»), и строка переполнилась.
            Positioned(
              left: 0,
              top: 0,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Opacity(opacity: 1 - fadeOut, child: old),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Подвал с объявлением под карточкой

/// Сгруппированный подвал (`.hig-foot`): объявление провайдера прямо под карточкой.
///
/// Лежит на обоях без подложки, поэтому цвета — отдельные токены [Ios27FooterColors], а не
/// палитра ярлыков. Ссылки `https?://…` подчёркнуты и нажимаются. Пустое объявление — подвала нет.
class Ios27CardFooter extends StatefulWidget {
  const Ios27CardFooter({super.key, required this.text, this.onLink});

  final String text;

  /// Нажатие на ссылку; получает адрес `https?://…`. `null` — ссылки видны, но не нажимаются.
  final ValueChanged<String>? onLink;

  @override
  State<Ios27CardFooter> createState() => _Ios27CardFooterState();
}

class _Ios27CardFooterState extends State<Ios27CardFooter> {
  static final _url = RegExp(r'https?://\S+');
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) {
      return const SizedBox.shrink();
    }
    final dark = Ios27Colors.of(context).dark;
    final base = ios27Text(
      context,
      Ios27Text.footnote,
      color: Ios27FooterColors.text(dark: dark),
    );
    _disposeRecognizers();
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in _url.allMatches(widget.text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, m.start)));
      }
      final url = m.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = widget.onLink == null ? null : () => widget.onLink!(url);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: Ios27FooterColors.link(dark: dark),
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
            decorationColor: Ios27FooterColors.link(dark: dark),
          ),
          recognizer: recognizer,
        ),
      );
      cursor = m.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return Padding(
      key: Ios27CardKeys.footer,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: Text.rich(
          TextSpan(children: spans),
          key: Ios27CardKeys.footerText,
          style: base,
          strutStyle: _strut(Ios27Text.footnote),
        ),
      ),
    );
  }
}
