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
import 'm3e_button.dart';
import 'm3e_meter.dart';
import 'm3e_shape.dart';

/// Ключи для сверки раскладки с `test/m3e/ref/layout.json` (имена как в эталоне).
abstract final class M3eCardKeys {
  static const card = ValueKey<String>('m3e.card');
  static const head = ValueKey<String>('m3e.card.head');
  static const plan = ValueKey<String>('m3e.card.plan');
  static const line = ValueKey<String>('m3e.card.line');
  static const meter = ValueKey<String>('m3e.card.meter');
  static const stats = ValueKey<String>('m3e.card.stats');
  static const sub = ValueKey<String>('m3e.card.sub');
  static const site = ValueKey<String>('m3e.card.site');
  static const refresh = ValueKey<String>('m3e.card.refresh');
  static const name = ValueKey<String>('m3e.card.name');
  static const state = ValueKey<String>('m3e.card.state');
  static const dot = ValueKey<String>('m3e.card.dot');
  static const timer = ValueKey<String>('m3e.card.timer');
  static const why = ValueKey<String>('m3e.card.why');

  /// Колонка показателя `i` (0 IP, 1 трафик).
  static ValueKey<String> stat(int i) => ValueKey<String>('m3e.card.stat.$i');

  /// Строка значения показателя `i`.
  static ValueKey<String> statValue(int i) =>
      ValueKey<String>('m3e.card.statValue.$i');
}

/// Точка состояния: нет подключения, идёт подключение (пульс), подключено, ошибка.
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
    this.ipLong = false,
    required this.trafficText,
    this.ipLoading = false,
    required this.announce,
    this.showRefresh = false,
  });

  final String providerName;
  final M3eDotState dot;

  /// Текст состояния («Подключено», «Сервер не отвечает»). Его читает диктор
  /// как живую область; на экране он виден только при [statusVisible].
  final String statusText;

  /// `true` только когда тон «ошибка»: красная причина на месте таймера.
  final bool statusVisible;

  /// Время сеанса `m:ss` или `null` без подключения. Вне живой области.
  final String? timer;

  final String planText;
  final M3ePlanTone planTone;

  /// Расход в процентах (может быть 100 и выше) или `null` для безлимита.
  final double? meterPercent;
  final M3eMeterTone meterTone;

  /// Флаг-эмодзи рядом с адресом; `null` и адрес «—», когда адреса нет.
  final String? ipFlag;
  final String ipAddress;

  /// Длинный адрес (IPv6): узкое начертание и кегль по ширине колонки.
  final bool ipLong;

  final String trafficText;

  /// Адрес сейчас определяется: на месте значения индикатор загрузки, а не «—».
  /// «—» без анимации остаётся, когда проверять нечего (нет сети, VPN выключен без проверки).
  final bool ipLoading;

  /// Объявление провайдера или адрес сайта; `https://…` становятся ссылками.
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
      ipLong == other.ipLong &&
      trafficText == other.trafficText &&
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
        ipLong,
        trafficText,
        ipLoading,
        announce,
        showRefresh,
      );
}

/// Карточка подписки главной: `.dr-card` в android.css (107-156), разметка `homeHtml()`.
///
/// Заливка secondary-container (`home.card`), угол 28. Шапка (точка, имя, таймер или
/// причина), тариф с полосой, три показателя, под чертой сайт и «Обновить».
class M3eSubCard extends StatelessWidget {
  const M3eSubCard({
    super.key,
    required this.data,
    this.onRefresh,
    this.onLink,
    this.liveTimer,
  });

  final M3eCardData data;

  /// Живая строка таймера (раз в секунду), пока она не `null`; иначе показывается
  /// [M3eCardData.timer]. Отдельный канал, чтобы секунда не пересобирала всю карточку.
  final ValueListenable<String?>? liveTimer;

  /// Нажатие «Обновить»; кнопка видна при [M3eCardData.showRefresh].
  final VoidCallback? onRefresh;

  /// Нажатие на ссылку в объявлении.
  final void Function(Uri uri)? onLink;

  @override
  Widget build(BuildContext context) {
    final colors = M3eColors.of(context);
    final home = colors.home;
    final scheme = colors.scheme;
    final l = AppLocalizations.of(context);

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

    return Container(
      key: M3eCardKeys.card,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: home.card,
        borderRadius: BorderRadius.circular(M3eShape.extraLarge),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: home.ink),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Head(data: data, liveTimer: liveTimer),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Padding(
                key: M3eCardKeys.plan,
                // Тариф на вертикали имени: точка 10 + зазор 16.
                padding: const EdgeInsets.only(left: 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      key: M3eCardKeys.line,
                      width: double.infinity,
                      child: Text(
                        data.planText,
                        style: M3eFlex.cardLine(color: planColor),
                      ),
                    ),
                    if (data.meterPercent != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Semantics(
                          label: l.m3eStatTraffic,
                          value: '${data.meterPercent!.round()}%',
                          child: ExcludeSemantics(
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
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _Stats(data: data, l: l),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _Sub(
                data: data,
                onRefresh: onRefresh,
                onLink: onLink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.data, this.liveTimer});

  final M3eCardData data;
  final ValueListenable<String?>? liveTimer;

  @override
  Widget build(BuildContext context) {
    final colors = M3eColors.of(context);
    final home = colors.home;
    final scheme = colors.scheme;
    final dotColor = switch (data.dot) {
      M3eDotState.off => home.dotOff,
      M3eDotState.on => home.ok,
      M3eDotState.bad => scheme.role('error'),
      M3eDotState.busy => scheme.role('primary'),
    };

    final state = Row(
      key: M3eCardKeys.state,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(
          key: M3eCardKeys.dot,
          color: dotColor,
          pulse: switch (data.dot) {
            M3eDotState.busy => _DotPulse.busy,
            M3eDotState.on => _DotPulse.live,
            _ => _DotPulse.none,
          },
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            data.providerName,
            key: M3eCardKeys.name,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: M3eFlex.cardName(color: home.ink),
          ),
        ),
      ],
    );

    Widget? trailing;
    if (data.statusVisible) {
      trailing = Semantics(
        container: true,
        liveRegion: true,
        child: Text(
          data.statusText,
          key: M3eCardKeys.why,
          style: M3eFlex.cardWhy(color: scheme.role('error')),
        ),
      );
    } else if (data.timer != null) {
      // Таймер вне живой области: диктор не должен читать его каждую секунду.
      final live = liveTimer;
      trailing = live == null
          ? _Timer(text: data.timer!, color: home.ink2)
          : ValueListenableBuilder<String?>(
              valueListenable: live,
              builder: (context, text, _) =>
                  _Timer(text: text ?? data.timer!, color: home.ink2),
            );
    }

    // Высота шапки 22 dp держится только минимумом: масштаб текста приложения доходит
    // до 1,4 (решение владельца 2026-10-29), строка растёт вместе с текстом, а фиксированные
    // 22 dp резали верх и низ имени и таймера.
    return ConstrainedBox(
      key: M3eCardKeys.head,
      constraints: const BoxConstraints(minHeight: 22),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              if (trailing == null) {
                return Align(alignment: Alignment.centerLeft, child: state);
              }
              final scaler = MediaQuery.textScalerOf(context);
              final trailingStyle =
                  data.statusVisible ? M3eFlex.cardWhy() : M3eFlex.cardTimer();
              final trailingText =
                  data.statusVisible ? data.statusText : (data.timer ?? '');
              // Имя может уйти в многоточие, но не короче 40 % ширины: меньше уже не имя.
              final name = math.min(
                _textWidth(data.providerName, M3eFlex.cardName(), scaler),
                box.maxWidth * 0.4,
              );
              final need = 26 +
                  name +
                  12 +
                  _textWidth(trailingText, trailingStyle, scaler);
              if (need > box.maxWidth) {
                // Крупный шрифт приложения: причина или таймер уходят под имя
                // (на 1,4 «Сервер не отвечает» не помещается рядом), а не вытесняют его.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    state,
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: trailing,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: state,
                    ),
                  ),
                  const SizedBox(width: 12),
                  trailing,
                ],
              );
            },
          ),
          if (!data.statusVisible)
            // Состояние для диктора без места на экране (`dr-sr` у `role=status`).
            Semantics(
              container: true,
              liveRegion: true,
              label: data.statusText,
              // Узел нулевого размера Flutter отбрасывает из дерева доступности,
              // поэтому 1x1: ничего не рисует, диктор его видит.
              child: const SizedBox(width: 1, height: 1),
            ),
        ],
      ),
    );
  }
}

/// Как точка состояния движется.
enum _DotPulse {
  /// Стоит на месте: выключено, ошибка, подписка закрыта.
  none,

  /// Идёт подключение: точка «дышит» 900 мс туда-обратно (`dr-pulse`).
  busy,

  /// Подключено: спокойное кольцо расходится от точки раз в 2 с.
  live,
}

/// Точка 10 dp. При подключении пульсирует (`dr-pulse`), при включённом VPN от неё
/// медленно расходится кольцо: экран «живой», но не мигает.
///
/// Кольцо живёт на двух токенах канона (`canon/material-3-expressive/learn/
/// 06-motion-and-feedback.md`): масштаб — геометрия, идёт по emphasized decelerate
/// (231-261: входящее быстро разгоняется и мягко садится); прозрачность — effects без
/// перелёта (79-80), затухает линейно. Период 2 с = 2 × `extraLong4`: дольше 1 с у
/// канона для пульса нет, а короткий период воспринимался бы как тревога.
class _Dot extends StatefulWidget {
  const _Dot({super.key, required this.color, required this.pulse});

  final Color color;
  final _DotPulse pulse;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  static const Duration _busyPeriod = Duration(milliseconds: 900);
  static const Duration _livePeriod = Duration(milliseconds: 2000);

  /// Кольцо дорастает до 2,6 диаметра точки; дальше оно уже не читается как её часть.
  static const double _ringGrowth = 1.6;
  static const double _ringAlpha = 0.35;

  // Создаётся сразу, а не лениво: в режиме «стоит» к контроллеру никто не обращается,
  // и первое обращение в `dispose` ломало бы поиск `TickerMode` у снятого элемента.
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: _busyPeriod,
      // Старт с полной точки: первый кадр совпадает с эталоном доски, а не с
      // началом пульса (прозрачность .3, масштаб .7).
      value: 1,
    )..addStatusListener(_loop);
  }

  // У свежего контроллера «последний сообщённый статус» — dismissed, поэтому первое
  // `value = 1` в `_sync` приходит сюда как completed. Без режима пульс запускался бы
  // сам и под «меньше движения».
  _DotPulse _mode = _DotPulse.none;

  void _loop(AnimationStatus s) {
    if (_mode != _DotPulse.busy) return;
    if (s == AnimationStatus.completed) {
      _c.reverse();
    } else if (s == AnimationStatus.dismissed) {
      _c.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Dot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final mode = reduce ? _DotPulse.none : widget.pulse;
    if (mode == _mode && (mode == _DotPulse.none || _c.isAnimating)) return;
    // Режим сбрасываем до остановки: `stop` не шлёт статус, но запуск ниже шлёт.
    _mode = _DotPulse.none;
    _c.stop();
    switch (mode) {
      case _DotPulse.none:
        _c.value = 1;
      case _DotPulse.busy:
        _c
          ..duration = _busyPeriod
          ..value = 1;
        _mode = mode;
        _c.reverse();
      case _DotPulse.live:
        _c
          ..duration = _livePeriod
          ..value = 0;
        _mode = mode;
        _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _dot() => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );

  @override
  Widget build(BuildContext context) {
    if (_mode == _DotPulse.none) return _dot();
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (_mode == _DotPulse.live) {
            final t = _c.value;
            final grow = M3eEasing.emphasizedDecelerate.transform(t);
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // В нулевой точке цикла кольцо ещё совпадает с точкой: не рисуем, чтобы
                // кромка сглаживания двух кругов не утолщала контур.
                if (t > 0)
                  Transform.scale(
                    scale: 1 + _ringGrowth * grow,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: widget.color
                            .withValues(alpha: _ringAlpha * (1 - t)),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                _dot(),
              ],
            );
          }
          final t = Curves.easeInOut.transform(_c.value);
          return Opacity(
            opacity: 0.3 + 0.7 * t,
            child: Transform.scale(scale: 0.7 + 0.3 * t, child: _dot()),
          );
        },
      ),
    );
  }
}

/// Таймер сеанса `m:ss`. Меняются только те символы, что поменялись: цифра уходит вверх
/// и гаснет, новая поднимается снизу (по-глифовый roll).
///
/// Движение: сдвиг — геометрия, пружина `M3eSpringStandard.fastSpatial` (канон 71 и
/// 79-80: перемещение на spatial; standard вместо expressive, потому что цифры в строке
/// не должны «подпрыгивать»: перелёт 0,15 % вместо 9,5 %); прозрачность — `fastEffects`
/// без перелёта. Сдвиг — доли высоты глифа, а не dp: он растёт вместе с масштабом
/// текста приложения. Под «меньше движения» и под закрытым маршрутом — обычный `Text`.
class _Timer extends StatelessWidget {
  const _Timer({required this.text, required this.color});

  final String text;
  final Color color;

  /// Доля высоты строки, на которую цифра въезжает и выезжает.
  static const double _shift = 0.4;

  static const Curve _move = M3eSpringCurve(M3eSpringStandard.fastSpatial, 0.2);
  static const Curve _fade = M3eSpringCurve(M3eSpring.fastEffects, 0.12);

  @override
  Widget build(BuildContext context) {
    final style = M3eFlex.cardTimer(color: color);
    final plain = Text(text, maxLines: 1, softWrap: false, style: style);
    final still = (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        !TickerMode.valuesOf(context).enabled;
    if (still) {
      return Text(
        text,
        key: M3eCardKeys.timer,
        maxLines: 1,
        softWrap: false,
        style: style,
      );
    }
    final chars = text.characters.toList();
    // Невидимый полный текст задаёт размер и находится по тексту; глифы лежат поверх.
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Stack(
        key: M3eCardKeys.timer,
        children: [
          Opacity(opacity: 0, child: plain),
          Positioned(
            left: 0,
            top: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < chars.length; i++)
                  // Ключ ячейки — позиция с конца: при смене числа цифр («9:59» →
                  // «10:00») секунды не пересоздаются и не анимируются зря.
                  _TimerGlyph(
                    key: ValueKey<int>(chars.length - 1 - i),
                    char: chars[i],
                    style: style,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerGlyph extends StatelessWidget {
  const _TimerGlyph({super.key, required this.char, required this.style});

  final String char;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final current = ValueKey<String>(char);
    return AnimatedSwitcher(
      duration: M3eDuration.short4,
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      transitionBuilder: (child, animation) {
        final incoming = child.key == current;
        final fade = animation.drive(CurveTween(curve: _Timer._fade));
        final move = animation.drive(CurveTween(curve: _Timer._move));
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: move.drive(
              Tween<Offset>(
                // Новая цифра поднимается снизу, старая уходит вверх.
                begin: Offset(0, incoming ? _Timer._shift : -_Timer._shift),
                end: Offset.zero,
              ),
            ),
            child: child,
          ),
        );
      },
      child: Text(
        char,
        key: current,
        maxLines: 1,
        softWrap: false,
        style: style,
      ),
    );
  }
}

/// Ширина строки [text] стилем [style] с учётом масштаба текста приложения.
///
/// Нужна, чтобы выбрать кегль IP до раскладки: `Text` сам ужимать начертание не умеет.
double _textWidth(String text, TextStyle style, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Диаметр флага рядом с адресом: 18 dp при масштабе 1,0, дальше растёт с текстом,
/// иначе при 1,4–2,0 флаг превращался в точку рядом с крупными цифрами.
double _flagSize(TextScaler scaler) => scaler.scale(18);

/// Место под флаг и зазор 6 перед адресом.
double _flagSlot(TextScaler scaler) => _flagSize(scaler) + 6;

/// Нижняя граница кегля IP: ниже читать трудно, дальше уже многоточие.
const double _ipMinSize = 9;

/// Стиль IP, помещающийся в [avail] (без места под флаг), или `null`, если не помещается
/// даже самый мелкий.
///
/// Порядок как у доски: обычное начертание (wdth 108, кегль 17), затем узкое (wdth 84)
/// с кеглем `clamp(12, 10.5cqi - 3.45, 17)` от ширины колонки. Если и он не влез (крупный
/// шрифт приложения), кегль уменьшается шагом 0,5 до [_ipMinSize]: цифры адреса
/// важнее, чем красота начертания.
TextStyle? _fitIpStyle({
  required String address,
  required bool ipLong,
  required double columnWidth,
  required double avail,
  required TextScaler scaler,
  required Color color,
}) {
  if (!ipLong) {
    final normal = M3eFlex.statValue(color: color);
    if (_textWidth(address, normal, scaler) <= avail) return normal;
  }
  final start = ipLong ? (columnWidth * 0.105 - 3.45).clamp(12.0, 17.0) : 17.0;
  for (var size = start; size >= _ipMinSize; size -= 0.5) {
    final style = M3eFlex.statValueLong(fontSize: size, color: color);
    if (_textWidth(address, style, scaler) <= avail) return style;
  }
  return null;
}

class _Stats extends StatelessWidget {
  const _Stats({required this.data, required this.l});

  final M3eCardData data;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final home = M3eColors.of(context).home;
    final scaler = MediaQuery.textScalerOf(context);

    Widget column(
      int i,
      String label,
      Widget value, {
      double? minWidth,
      bool loading = false,
      String? swapKey,
    }) {
      final col = Column(
        key: M3eCardKeys.stat(i),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: M3eFlex.statKey(color: home.ink2),
          ),
          const SizedBox(height: 2),
          // Строка значения не ниже 22 dp и растёт с текстом: фиксированная высота
          // резала низ цифр при масштабе приложения до 1,4.
          ConstrainedBox(
            key: M3eCardKeys.statValue(i),
            constraints: const BoxConstraints(minHeight: 22),
            child: swapKey == null
                ? value
                : _StatSwap(
                    loading: loading,
                    valueKey: swapKey,
                    child: value,
                  ),
          ),
        ],
      );
      if (minWidth == null) return col;
      // Колонка «Трафик» не уже 72 и по ширине содержимого: `minmax(72px, auto)`;
      // IP забирает остаток. Пинга на карточке нет (решение владельца 2026-10-29).
      return ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: IntrinsicWidth(child: col),
      );
    }

    // Значение трафика не режется многоточием: колонка растёт по тексту.
    Text plain(String text, {Color? color}) => Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: M3eFlex.statValue(color: color ?? home.ink),
        );

    final traffic = column(
      1,
      l.m3eStatTraffic,
      plain(data.trafficText),
      minWidth: 72,
    );

    // Ряд сменяется колонкой, когда адрес не влезает рядом с трафиком (крупный шрифт,
    // длинный IPv6): высота карточки меняется пружиной, а не щелчком.
    final moving = TickerMode.valuesOf(context).enabled &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return _SpringSize(
      moving: moving,
      alignment: Alignment.topLeft,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final k = _textWidth(l.m3eStatTraffic, M3eFlex.statKey(), scaler);
          final v = _textWidth(data.trafficText, M3eFlex.statValue(), scaler);
          final tW =
              (k > v ? k : v).ceilToDouble().clamp(72.0, double.infinity);
          final ipColumn = width - 8 - tW;
          final slot = data.ipFlag == null ? 0.0 : _flagSlot(scaler);
          final fits = _fitIpStyle(
                address: data.ipAddress,
                ipLong: data.ipLong,
                columnWidth: ipColumn,
                avail: ipColumn - slot,
                scaler: scaler,
                color: home.ink,
              ) !=
              null;

          if (fits) {
            return Row(
              key: M3eCardKeys.stats,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, col) => column(
                      0,
                      l.m3eStatIp,
                      _IpValue(data: data, columnWidth: col.maxWidth),
                      loading: data.ipLoading,
                      swapKey: '${data.ipFlag}${data.ipAddress}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                traffic,
              ],
            );
          }
          // Крупный шрифт: адрес не помещается в одну строку с трафиком даже мелким
          // кеглем. IP получает всю ширину карточки, трафик идёт под ним.
          return Column(
            key: M3eCardKeys.stats,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              column(
                0,
                l.m3eStatIp,
                _IpValue(data: data, columnWidth: width),
                loading: data.ipLoading,
                swapKey: '${data.ipFlag}${data.ipAddress}',
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: traffic),
            ],
          );
        },
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

/// Смена значения показателя: загрузка → значение и значение → значение.
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
///   флаг и адрес другой длины не щёлкали, а колонка трафика рядом не дёргалась.
/// Под «меньше движения» остаётся перекрёстное проявление 100 мс без сдвига и без
/// анимации размера; под закрытым маршрутом (нет тикеров) значение меняется сразу.
class _StatSwap extends StatelessWidget {
  const _StatSwap({
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

    return Align(
      alignment: Alignment.centerLeft,
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
          child: loading
              ? const _StatLoading(key: ValueKey<String>('loading'))
              : KeyedSubtree(key: currentKey, child: child),
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
class _StatLoading extends StatelessWidget {
  const _StatLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
    return Semantics(
      container: true,
      label: l.loadingEllipsis,
      child: ExcludeSemantics(child: shape),
    );
  }
}

class _IpValue extends StatelessWidget {
  const _IpValue({required this.data, required this.columnWidth});

  final M3eCardData data;
  final double columnWidth;

  @override
  Widget build(BuildContext context) {
    final home = M3eColors.of(context).home;
    final scaler = MediaQuery.textScalerOf(context);
    final slot = data.ipFlag == null ? 0.0 : _flagSlot(scaler);
    // `clamp(12px, 10.5cqi - 3.45px, 17px)`: cqi это ширина колонки IP (контейнер
    // `.dr-stat:first-child`): 9.5 px строки на 1 px кегля и 31.5 px на флаг с отступом.
    // Крупный шрифт приложения ужимает адрес дальше (см. [_fitIpStyle]); если не помогло,
    // остаётся обычный стиль с многоточием: это крайний случай.
    final style = _fitIpStyle(
          address: data.ipAddress,
          ipLong: data.ipLong,
          columnWidth: columnWidth,
          avail: columnWidth - slot,
          scaler: scaler,
          color: home.ink,
        ) ??
        M3eFlex.statValueLong(fontSize: _ipMinSize, color: home.ink);
    final text = Text(
      data.ipAddress,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (data.ipFlag == null) return text;
    // Ряд по ширине содержимого: иначе рамка значения всегда на всю колонку и
    // [AnimatedSize] в [_StatSwap] нечему анимировать.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniFlag(flag: data.ipFlag!, size: _flagSize(scaler)),
        const SizedBox(width: 6),
        Flexible(child: text),
      ],
    );
  }
}

/// Круглый флаг 18 dp (`.dr-mini-flag`): глиф Twemoji крупнее круга, лишнее срезано.
class _MiniFlag extends StatelessWidget {
  const _MiniFlag({required this.flag, required this.size});

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

class _Sub extends StatelessWidget {
  const _Sub({
    required this.data,
    required this.onRefresh,
    required this.onLink,
  });

  final M3eCardData data;
  final VoidCallback? onRefresh;
  final void Function(Uri uri)? onLink;

  @override
  Widget build(BuildContext context) {
    final home = M3eColors.of(context).home;
    final l = AppLocalizations.of(context);
    return Container(
      key: M3eCardKeys.sub,
      constraints: const BoxConstraints(minHeight: 45),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: home.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _Announce(text: data.announce, onLink: onLink),
            ),
          ),
          if (data.showRefresh) ...[
            const SizedBox(width: 12),
            M3eButton(
              key: M3eCardKeys.refresh,
              label: l.m3eRefresh,
              onPressed: onRefresh,
              size: M3eButtonSize.xs,
              minWidth: 104,
              flexFont: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Текст сайта или объявления; `http(s)://…` до пробела становятся ссылками (`dr-link`).
class _Announce extends StatefulWidget {
  const _Announce({required this.text, required this.onLink});

  final String text;
  final void Function(Uri uri)? onLink;

  @override
  State<_Announce> createState() => _AnnounceState();
}

class _AnnounceState extends State<_Announce> {
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
    final home = M3eColors.of(context).home;
    final primary = M3eColors.of(context).scheme.role('primary');
    // 13/18 wght 400: готового стиля для сайта в M3eFlex нет, берём statKey с весом 400.
    final base = M3eFlex.statKey(color: home.ink2).copyWith(
      fontWeight: FontWeight.w400,
      fontVariations: const [
        FontVariation('wght', 400),
        FontVariation('wdth', 100),
        FontVariation('opsz', 13),
      ],
    );
    _disposeTaps();
    final spans = <InlineSpan>[];
    var from = 0;
    for (final m in _url.allMatches(widget.text)) {
      if (m.start > from) {
        spans.add(TextSpan(text: widget.text.substring(from, m.start)));
      }
      final url = m.group(0)!;
      final tap = TapGestureRecognizer()
        ..onTap = () {
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
    return SizedBox(
      key: M3eCardKeys.site,
      width: double.infinity,
      child: Text.rich(TextSpan(children: spans), style: base),
    );
  }
}
