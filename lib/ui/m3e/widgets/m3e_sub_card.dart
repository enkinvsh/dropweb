import 'dart:math' as math;

import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import '../../../enum/enum.dart';
import '../../../l10n/l10n.dart';
import '../m3e_format.dart';
import '../theme/m3e_flex.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import 'm3e_meter.dart';
import 'm3e_shape.dart';

/// Ключи частей карточки для тестов раскладки.
abstract final class M3eCardKeys {
  static const card = ValueKey<String>('m3e.card');
  static const head = ValueKey<String>('m3e.card.head');
  static const name = ValueKey<String>('m3e.card.name');
  static const timer = ValueKey<String>('m3e.card.timer');
  static const plan = ValueKey<String>('m3e.card.plan');
  static const meter = ValueKey<String>('m3e.card.meter');
  static const separator = ValueKey<String>('m3e.card.separator');

  /// Нижняя строка: страна слева, статус или «Обновить» справа.
  static const bar = ValueKey<String>('m3e.card.bar');

  /// Левая часть нижней строки: флаг и страна, индикатор определения или «—».
  static const country = ValueKey<String>('m3e.card.country');
  static const flag = ValueKey<String>('m3e.card.flag');

  /// Слово статуса справа: точка и слово.
  static const state = ValueKey<String>('m3e.card.state');
  static const dot = ValueKey<String>('m3e.card.dot');
  static const refresh = ValueKey<String>('m3e.card.refresh');

  /// Подвал с объявлением под карточкой.
  static const footer = ValueKey<String>('m3e.card.footer');
  static const footerText = ValueKey<String>('m3e.card.footer.text');
}

/// Точка состояния: нет подключения, идёт подключение, подключено, ошибка. Всегда стоит
/// на месте: бесконечное движение на главной жгло батарею (замер iOS-ветки), поэтому
/// «дыхание» подключения живёт только в кнопке питания и фоне.
enum M3eDotState { off, busy, on, bad }

/// Данные карточки подписки. Только готовые строки: форматирует вызывающий
/// (`m3e_format.dart`), карточка ничего не считает и не читает провайдеры.
@immutable
class M3eCardData {
  const M3eCardData({
    required this.providerName,
    required this.dot,
    required this.statusText,
    required this.statusVisible,
    this.timer,
    required this.planText,
    this.planTone = M3ePlanTone.normal,
    this.meterPercent,
    this.meterTone = M3eMeterTone.normal,
    this.ipFlag,
    required this.ipAddress,
    required this.countryText,
    this.ipLoading = false,
    required this.announce,
    this.showRefresh = false,
  });

  final String providerName;
  final M3eDotState dot;

  /// Слово состояния («Подключено», «Сервер не отвечает»). Стоит справа в нижней строке,
  /// пока страна не определяется и нет «Обновить»; диктор получает его в фразе карточки.
  final String statusText;

  /// `true`, когда тон «ошибка»: слово статуса и точка красные.
  final bool statusVisible;

  /// Время сеанса `m:ss` или `null` без подключения. Вне живой области.
  final String? timer;

  final String planText;
  final M3ePlanTone planTone;

  /// Расход в процентах (может быть 100 и выше) или `null` для безлимита.
  final double? meterPercent;
  final M3eMeterTone meterTone;

  /// Флаг-эмодзи рядом со страной; `null`, когда адреса или кода страны нет.
  final String? ipFlag;

  /// Внешний адрес как его знает модель (или «—»). Карточка его НЕ рисует и не отдаёт
  /// диктору: на экране только [countryText]. Поле нужно другим экранам, читающим ту же модель.
  final String ipAddress;

  /// Что карточка показывает вместо адреса: короткое название страны, маска адреса
  /// («94.183.•••.•••», когда кода страны нет) или «—».
  final String countryText;

  /// Страна определяется: на месте значения индикатор загрузки и «Подключение…», а не «—».
  /// «—» без анимации остаётся, когда проверять нечего (нет сети, VPN выключен без проверки).
  final bool ipLoading;

  /// Объявление провайдера или адрес сайта; `https://…` становятся ссылками. Рисуется не в
  /// карточке, а в подвале под ней ([M3eCardFooter]).
  final String announce;
  final bool showRefresh;

  @override
  bool operator ==(Object other) =>
      other is M3eCardData &&
      providerName == other.providerName &&
      dot == other.dot &&
      statusText == other.statusText &&
      statusVisible == other.statusVisible &&
      timer == other.timer &&
      planText == other.planText &&
      planTone == other.planTone &&
      meterPercent == other.meterPercent &&
      meterTone == other.meterTone &&
      ipFlag == other.ipFlag &&
      ipAddress == other.ipAddress &&
      countryText == other.countryText &&
      ipLoading == other.ipLoading &&
      announce == other.announce &&
      showRefresh == other.showRefresh;

  @override
  int get hashCode => Object.hash(
        providerName,
        dot,
        statusText,
        statusVisible,
        timer,
        planText,
        planTone,
        meterPercent,
        meterTone,
        ipFlag,
        ipAddress,
        countryText,
        ipLoading,
        announce,
        showRefresh,
      );
}

/// Цель нажатия «Обновить» (M3: не меньше 48 dp).
const double _kHitTarget = 48;

/// Фраза карточки для диктора одной строкой: имя, тариф, страна, статус.
///
/// Решение владельца 2026-10-30 (карточка №4): страна вместо адреса, адрес целиком в
/// дерево доступности не попадает. Пока страна определяется, вместо неё «Подключение…»,
/// а слово статуса не повторяем.
String m3eCardLabel(AppLocalizations l, M3eCardData data) {
  final parts = <String>[
    data.providerName,
    data.planText,
    if (data.ipLoading)
      l.m3eStatusConnecting
    else if (data.countryText != l.m3eStatNone)
      '${l.m3eStatCountry}: ${data.countryText}',
    if (!data.ipLoading) data.statusText,
  ];
  return parts
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map((e) => e.endsWith('.') || e.endsWith('…') ? e : '$e.')
      .join(' ');
}

/// Карточка подписки главной: компактная плашка (вариант №4 доски карточек iOS-ветки).
///
/// Заливка secondary-container (`home.card`), угол 28. Строки: имя и секундный таймер,
/// тариф со шкалой квоты, тонкая черта, внизу страна выхода слева и слово статуса или
/// «Обновить» справа. Объявление провайдера лежит под карточкой — [M3eCardFooter].
///
/// Никакого бесконечного движения: точка стоит, таймер — простой текст раз в секунду
/// (канал [liveTimer]). Единственное движение — конечная смена страны.
class M3eSubCard extends StatelessWidget {
  const M3eSubCard({
    super.key,
    required this.data,
    this.onRefresh,
    this.liveTimer,
  });

  final M3eCardData data;

  /// Живая строка таймера (раз в секунду), пока она не `null`; иначе показывается
  /// [M3eCardData.timer]. Отдельный канал, чтобы секунда не пересобирала всю карточку.
  final ValueListenable<String?>? liveTimer;

  /// Нажатие «Обновить»; кнопка видна при [M3eCardData.showRefresh].
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = M3eColors.of(context);
    final home = colors.home;
    final scheme = colors.scheme;
    final l = AppLocalizations.of(context);
    final ts = MediaQuery.textScalerOf(context).scale(1);

    final planColor = switch (data.planTone) {
      M3ePlanTone.normal => home.ink2,
      M3ePlanTone.warn => home.warn,
      M3ePlanTone.bad => scheme.role('error'),
    };
    final meterColor = switch (data.meterTone) {
      M3eMeterTone.normal => scheme.role('primary'),
      M3eMeterTone.low => home.warn,
      M3eMeterTone.out => scheme.role('error'),
    };

    // Цель нажатия «Обновить» добираем до 48 dp полями вокруг текста. Строка нижней
    // панели от этого выше номинальных 22 dp на `half` с каждой стороны; эту прибавку
    // забираем из отступа под чертой (11) и нижнего поля карточки (14), чтобы карточка
    // росла только на то, что в них не влезло.
    final need = data.showRefresh ? math.max(0.0, _kHitTarget - 20 * ts) : 0.0;
    final slopTop = need / 2;
    final slopBottom = need / 2;
    final half = math.max(0.0, (20 * ts + need - 22 * ts) / 2);

    final head = _Head(data: data, liveTimer: liveTimer);

    return Semantics(
      container: true,
      // Одна читаемая фраза; видимые тексты из семантики убраны, иначе диктор прочёл бы
      // всё дважды. «Обновить» остаётся своей кнопкой.
      explicitChildNodes: true,
      label: m3eCardLabel(l, data),
      child: Container(
        key: M3eCardKeys.card,
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          math.max(0.0, 14 - half),
        ),
        decoration: BoxDecoration(
          color: home.card,
          borderRadius: BorderRadius.circular(M3eShape.extraLarge),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: home.ink),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExcludeSemantics(child: head),
                  ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            key: M3eCardKeys.plan,
                            width: double.infinity,
                            child: Text(
                              data.planText,
                              style: M3eFlex.cardLine(color: planColor),
                            ),
                          ),
                          if (data.meterPercent != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SizedBox(
                                key: M3eCardKeys.meter,
                                height: M3eMeter.height,
                                child: M3eMeter(
                                  percent: data.meterPercent!,
                                  activeColor: meterColor,
                                  // Трек по токену слился бы с заливкой карточки: тон черты.
                                  trackColor: home.line,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      top: 11,
                      bottom: math.max(0.0, 11 - half),
                    ),
                    child: ColoredBox(
                      key: M3eCardKeys.separator,
                      color: home.line,
                      child: const SizedBox(height: 1, width: double.infinity),
                    ),
                  ),
                  _Bar(
                    key: M3eCardKeys.bar,
                    data: data,
                    slopTop: slopTop,
                    slopBottom: slopBottom,
                    onRefresh: onRefresh,
                  ),
                ],
              ),
              // Живая область для диктора: смена состояния («Подключено») озвучивается
              // сама, без перечитывания всей карточки. Узел 1x1 ничего не рисует и лежит
              // поверх, а не в колонке, чтобы не добавлять карточке высоты.
              Positioned(
                left: 0,
                top: 0,
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: data.statusText,
                  child: const SizedBox(width: 1, height: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Шапка: имя и таймер

class _Head extends StatelessWidget {
  const _Head({required this.data, this.liveTimer});

  final M3eCardData data;
  final ValueListenable<String?>? liveTimer;

  @override
  Widget build(BuildContext context) {
    final home = M3eColors.of(context).home;
    final name = Text(
      data.providerName,
      key: M3eCardKeys.name,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: M3eFlex.cardName(color: home.ink),
    );

    Widget clock(String text) => Text(
          text,
          key: M3eCardKeys.timer,
          maxLines: 1,
          softWrap: false,
          style: M3eFlex.cardClock(color: home.ink2),
        );

    Widget row(String? timer) => Row(
          // Базовая линия, а не центр: имя 17 и таймер 15 стоят на одной строке письма.
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: name),
            if (timer != null) ...[const SizedBox(width: 12), clock(timer)],
          ],
        );

    final live = liveTimer;
    // Высота шапки 22 dp держится минимумом: строка растёт вместе с текстом приложения.
    return ConstrainedBox(
      key: M3eCardKeys.head,
      constraints: const BoxConstraints(minHeight: 22),
      child: data.timer == null
          ? row(null)
          : live == null
              ? row(data.timer)
              // Таймер идёт, только пока есть сеанс; без VPN канал отдаёт `null`.
              : ValueListenableBuilder<String?>(
                  valueListenable: live,
                  builder: (context, text, _) => row(text ?? data.timer),
                ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Нижняя строка

/// Диаметр флага рядом со страной: 18 dp при масштабе 1,0, дальше растёт с текстом,
/// иначе при 1,4–2,0 флаг превращался в точку рядом с крупными буквами.
double _flagSize(TextScaler scaler) => scaler.scale(18);

class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.data,
    required this.slopTop,
    required this.slopBottom,
    required this.onRefresh,
  });

  final M3eCardData data;

  /// Поля над и под строкой, добирающие цель нажатия «Обновить» до 48 dp.
  final double slopTop;
  final double slopBottom;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context).scale(1);
    final Widget? right;
    if (data.showRefresh) {
      right = _RefreshAction(
        key: M3eCardKeys.refresh,
        slopTop: slopTop,
        slopBottom: slopBottom,
        onTap: onRefresh,
      );
    } else if (data.ipLoading) {
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
        // шрифте для обоих не хватает ширины, и статус переходит строкой ниже, а не
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

/// Контраст не ниже 4,5:1 (WCAG AA для мелкого текста).
bool _legible(Color fg, Color bg) {
  double f(double v) =>
      v <= .03928 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
  double lum(Color c) => .2126 * f(c.r) + .7152 * f(c.g) + .0722 * f(c.b);
  final a = lum(fg), b = lum(bg);
  return (math.max(a, b) + .05) / (math.min(a, b) + .05) >= 4.5;
}

/// Слово статуса с точкой: серое, зелёное при подключении, красное при ошибке.
class _StateWord extends StatelessWidget {
  const _StateWord({required this.data});

  final M3eCardData data;

  @override
  Widget build(BuildContext context) {
    final colors = M3eColors.of(context);
    final home = colors.home;
    final ts = MediaQuery.textScalerOf(context).scale(1);
    final (dot, raw) = switch (data.dot) {
      M3eDotState.off || M3eDotState.busy => (home.dotOff, home.ink2),
      M3eDotState.on => (home.ok, home.ok),
      M3eDotState.bad => (
          colors.scheme.role('error'),
          colors.scheme.role('error'),
        ),
    };
    // Слово 13 sp мелкое: если цвет состояния не набирает 4,5:1 на заливке карточки
    // (зелёный на светлой, красный на тёмной), слово остаётся основным цветом, а
    // состояние несёт точка.
    final text = _legible(raw, home.card) ? raw : home.ink;
    return Row(
      key: M3eCardKeys.state,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: M3eCardKeys.dot,
          width: 8 * ts,
          height: 8 * ts,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        SizedBox(width: 6 * ts),
        Text(
          data.statusText,
          maxLines: 1,
          softWrap: false,
          style: M3eFlex.cardState(color: text),
        ),
      ],
    );
  }
}

/// «Обновить»: акцентный текст без подложки, цель нажатия до 48 dp за счёт полей.
class _RefreshAction extends StatefulWidget {
  const _RefreshAction({
    super.key,
    required this.slopTop,
    required this.slopBottom,
    required this.onTap,
  });

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
    final label = AppLocalizations.of(context).m3eRefresh;
    final primary = M3eColors.of(context).scheme.role('primary');
    return Semantics(
      button: true,
      label: label,
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
          child: Opacity(
            opacity: _pressed ? .5 : 1,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: M3eFlex.cardAction(color: primary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Страна: флаг и название, индикатор и «Подключение…» или приглушённое «—» без сети.
class _Country extends StatelessWidget {
  const _Country({required this.data});

  final M3eCardData data;

  @override
  Widget build(BuildContext context) {
    final home = M3eColors.of(context).home;
    final l = AppLocalizations.of(context);
    final ts = MediaQuery.textScalerOf(context).scale(1);
    final Widget content;
    if (data.ipLoading) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _CountryLoading(),
          SizedBox(width: 7 * ts),
          Flexible(
            child: Text(
              l.m3eStatusConnecting,
              style: M3eFlex.cardLine(color: home.ink2),
            ),
          ),
        ],
      );
    } else if (data.countryText == l.m3eStatNone) {
      content = Text(
        data.countryText,
        maxLines: 1,
        softWrap: false,
        style: M3eFlex.cardLine(color: home.ink2),
      );
    } else {
      final text = Flexible(
        child: Text(
          data.countryText,
          style: M3eFlex.cardCountry(color: home.ink),
        ),
      );
      final flag = data.ipFlag;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (flag != null && flag.isNotEmpty) ...[
            _MiniFlag(
              key: M3eCardKeys.flag,
              flag: flag,
              size: _flagSize(MediaQuery.textScalerOf(context)),
            ),
            SizedBox(width: 7 * ts),
          ],
          text,
        ],
      );
    }
    return KeyedSubtree(
      key: M3eCardKeys.country,
      child: _CountrySwap(
        loading: data.ipLoading,
        valueKey: '${data.ipFlag}${data.countryText}',
        child: content,
      ),
    );
  }
}

/// Размер ребёнка меняется пружиной `defaultSpatial` (канон 06-motion-and-feedback.md
/// 71 и 79-80: размер — spatial) или сразу, если [moving] ложь.
///
/// Без движения [AnimatedSize] не ставим совсем: при нулевой длительности он помечает
/// себя на перекладку внутри собственной раскладки (ошибка рендера), а под закрытым
/// маршрутом его контроллер заглушён и размер завис бы на старом значении.
class _SpringSize extends StatelessWidget {
  const _SpringSize({
    required this.moving,
    required this.alignment,
    required this.child,
  });

  final bool moving;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!moving) return child;
    return AnimatedSize(
      alignment: alignment,
      clipBehavior: Clip.none,
      duration: M3eDuration.medium3,
      curve: const M3eSpringCurve(M3eSpring.defaultSpatial, 0.35),
      child: child,
    );
  }
}

/// Смена значения страны: загрузка → значение и значение → значение.
///
/// Решение владельца 2026-10-29: прочерк на месте адреса заменён индикатором загрузки
/// M3E, а смена значения идёт по канону `canon/material-3-expressive/learn/
/// 06-motion-and-feedback.md`:
/// - уходящее гаснет первым и быстро (`fastEffects`, 100 мс; стр. 281 «сначала убрать
///   старое, потом показать новое», стр. 24-25 effects всегда без перелёта);
/// - входящее проявляется с небольшой задержкой на `defaultEffects` и въезжает снизу на
///   треть высоты строки (`defaultSpatial`, стр. 71 и 79-80: перемещение — spatial,
///   прозрачность — effects), 350 мс;
/// - ширина и высота значения меняются тем же `defaultSpatial` через [AnimatedSize], чтобы
///   флаг и страна другой длины не щёлкали.
/// Под «меньше движения» остаётся перекрёстное проявление 100 мс без сдвига и без
/// анимации размера; под закрытым маршрутом (нет тикеров) значение меняется сразу.
class _CountrySwap extends StatelessWidget {
  const _CountrySwap({
    required this.loading,
    required this.valueKey,
    required this.child,
  });

  final bool loading;

  /// Ключ значения: смена текста запускает переход, перерисовка с тем же — нет.
  final String valueKey;
  final Widget child;

  static const Curve _spatial = M3eSpringCurve(M3eSpring.defaultSpatial, 0.35);
  static const Curve _effectIn = M3eSpringCurve(M3eSpring.defaultEffects, 0.2);
  static const Curve _effectOut = M3eSpringCurve(M3eSpring.fastEffects, 0.1);

  /// Доля высоты строки, на которую значение въезжает.
  static const double _shift = 0.3;

  @override
  Widget build(BuildContext context) {
    final tickers = TickerMode.valuesOf(context).enabled;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final moving = tickers && !reduce;
    final currentKey = loading
        ? const ValueKey<String>('loading')
        : ValueKey<String>('v:$valueKey');

    Widget transition(Widget child, Animation<double> animation) {
      final incoming = child.key == currentKey;
      if (!moving) return FadeTransition(opacity: animation, child: child);
      if (!incoming) {
        return FadeTransition(
          opacity: animation.drive(CurveTween(curve: _effectOut)),
          child: child,
        );
      }
      return FadeTransition(
        opacity: animation.drive(
          CurveTween(curve: const Interval(0.15, 0.75, curve: _effectIn)),
        ),
        child: SlideTransition(
          position: animation.drive(CurveTween(curve: _spatial)).drive(
                Tween<Offset>(begin: const Offset(0, _shift), end: Offset.zero),
              ),
          child: child,
        ),
      );
    }

    // По размеру содержимого, а не на всю строку: иначе страна занимала бы строку целиком
    // и слово статуса уходило под неё.
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: _SpringSize(
        moving: moving,
        alignment: Alignment.centerLeft,
        child: AnimatedSwitcher(
          duration: !tickers
              ? Duration.zero
              : (reduce ? M3eDuration.short2 : M3eDuration.medium3),
          reverseDuration: !tickers ? Duration.zero : M3eDuration.short2,
          switchInCurve: Curves.linear,
          switchOutCurve: Curves.linear,
          transitionBuilder: transition,
          // Размер Stack задаёт только текущее значение: уходящее не держит ширину,
          // иначе AnimatedSize ждал бы его исчезновения.
          layoutBuilder: (current, previous) => Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              for (final old in previous)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Align(alignment: Alignment.centerLeft, child: old),
                ),
              if (current != null) current,
            ],
          ),
          child: KeyedSubtree(key: currentKey, child: child),
        ),
      ),
    );
  }
}

/// Диаметр индикатора загрузки в строке значения при масштабе текста 1,0.
const double _loadingSize = 20;

/// Размер активной формы `ExpressiveLoadingIndicator` в пакете, независимо от рамки.
const double _loadingActiveSize = 38;

/// Индикатор загрузки M3E (`md.comp.loading-indicator`, без контейнера, цвет primary)
/// на месте значения. Канон: `canon/material-3-expressive/sources/guidelines/md/components/
/// loading-indicator--specs.md` 41 и 45 (цвет `md.sys.color.primary`, форма 38 в рамке 48);
/// гайдлайн «ожидание короче пяти секунд» совпадает с нашей проверкой адреса.
///
/// Размер растёт с масштабом текста приложения, как и строка значения. Под
/// «меньше движения» и под закрытым маршрутом — статичная форма SoftBurst: у пакета свой
/// `Timer.periodic(650 мс)`, который `TickerMode` не глушит (так же решено в
/// `m3e_hero_button.dart`, `_Indicator`).
class _CountryLoading extends StatelessWidget {
  const _CountryLoading();

  @override
  Widget build(BuildContext context) {
    final color = M3eColors.of(context).scheme.role('primary');
    final box = MediaQuery.textScalerOf(context).scale(_loadingSize);
    final still = (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        !TickerMode.valuesOf(context).enabled;
    final shape = still
        ? M3eShapeView(MaterialShapes.softBurst, color: color, size: box)
        : SizedBox.square(
            dimension: box,
            // Пакет рисует форму в 38 dp при любой рамке: рамку 38 вписываем масштабом.
            child: FittedBox(
              child: SizedBox.square(
                dimension: _loadingActiveSize,
                child: ExpressiveLoadingIndicator(
                  color: color,
                  constraints: BoxConstraints.tight(
                    const Size.square(_loadingActiveSize),
                  ),
                ),
              ),
            ),
          );
    return ExcludeSemantics(child: shape);
  }
}

/// Круглый флаг 18 dp (`.dr-mini-flag`): глиф Twemoji крупнее круга, лишнее срезано.
class _MiniFlag extends StatelessWidget {
  const _MiniFlag({super.key, required this.flag, required this.size});

  final String flag;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = M3eColors.of(context).scheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.role('surfaceContainerHighest'),
          shape: BoxShape.circle,
        ),
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Text(
            flag,
            maxLines: 1,
            softWrap: false,
            // Размер круга и глифа считаем сами, масштаб текста второй раз не нужен.
            textScaler: TextScaler.noScaling,
            // Глиф крупнее круга в 25/18 раза: центр совпадает, края срезает круг.
            style: TextStyle(
              fontFamily: FontFamily.twEmoji.value,
              fontSize: size * 25 / 18,
              height: 1,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Подвал с объявлением

/// Подвал под карточкой: объявление провайдера на фоне главной, без подложки.
///
/// Текст — `onSurfaceVariant`, ссылки `https?://…` — primary, подчёркнуты и нажимаются
/// (в магазинных сборках [onLink] равен `null`: ссылки видны, но не нажимаются).
/// Пустое объявление — подвала нет. Раскладка главной мерит карточку и подвал вместе.
class M3eCardFooter extends StatefulWidget {
  const M3eCardFooter({super.key, required this.text, this.onLink});

  final String text;

  /// Нажатие на ссылку в объявлении.
  final void Function(Uri uri)? onLink;

  @override
  State<M3eCardFooter> createState() => _M3eCardFooterState();
}

class _M3eCardFooterState extends State<M3eCardFooter> {
  static final RegExp _url = RegExp(r'https?://\S+');
  final List<TapGestureRecognizer> _taps = [];

  void _disposeTaps() {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
  }

  @override
  void dispose() {
    _disposeTaps();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();
    final scheme = M3eColors.of(context).scheme;
    final primary = scheme.role('primary');
    final base = M3eFlex.cardFooter(color: scheme.role('onSurfaceVariant'));
    _disposeTaps();
    final spans = <InlineSpan>[];
    var from = 0;
    for (final m in _url.allMatches(widget.text)) {
      if (m.start > from) {
        spans.add(TextSpan(text: widget.text.substring(from, m.start)));
      }
      final url = m.group(0)!;
      final tap = TapGestureRecognizer()
        ..onTap = widget.onLink == null
            ? null
            : () {
                final uri = Uri.tryParse(url);
                if (uri != null) widget.onLink?.call(uri);
              };
      _taps.add(tap);
      spans.add(
        TextSpan(
          text: url,
          recognizer: tap,
          style: base.copyWith(
            color: primary,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
            decorationColor: primary,
          ),
        ),
      );
      from = m.end;
    }
    if (from < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(from)));
    }
    return Padding(
      key: M3eCardKeys.footer,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        key: M3eCardKeys.footerText,
        width: double.infinity,
        child: Text.rich(TextSpan(children: spans), style: base),
      ),
    );
  }
}
