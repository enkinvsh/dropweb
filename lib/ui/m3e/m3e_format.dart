// Форматы значений главной экрана: перенос `gbText`, `pingOf`, `elapsed` и строки тарифа
// из `homeHtml()` в android.js доски (строки 308-316, 407-414). Функции чистые: строки идут
// из `AppLocalizations`, поэтому неразрывный пробел и порядок «число + единица» задаёт arb.

import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import 'widgets/m3e_meter.dart';

/// Десятичное число с [digits] знаками и разделителем локали [locale] (`0,28` в ru).
///
/// Локаль приходит от экрана (`Localizations.localeOf`), а не из `Intl.getCurrentLocale()`:
/// глобальная локаль intl может остаться от другой загрузки (en_US) и дать «344.4 ГБ»
/// в русском интерфейсе. Без [locale] берётся глобальная, чтобы старые вызовы работали.
///
/// Округление через `toStringAsFixed`, как `toFixed` в JS доски; `NumberFormat` округлял бы
/// иначе на границе (0.285), и цифры в кадре разошлись бы с эталоном.
String _decimal(double value, int digits, String? locale) =>
    decimalWithLocale(value.toStringAsFixed(digits), locale);

/// Подставляет в готовую строку числа `123.4` разделитель дробной части локали [locale].
String decimalWithLocale(String fixed, String? locale) {
  final sep = NumberFormat.decimalPattern(locale ?? Intl.getCurrentLocale())
      .symbols
      .DECIMAL_SEP;
  return fixed.replaceFirst('.', sep);
}

/// Трафик: `0,28 ГБ`. Два знака до 10 ГБ, дальше один.
String gbText(AppLocalizations l, double gb, {String? locale}) =>
    l.m3eValueGb(_decimal(gb, gb < 10 ? 2 : 1, locale));

/// Пинг: `44 мс`, без значения `—`.
String pingText(AppLocalizations l, int? ms) =>
    ms == null ? l.m3eStatNone : l.m3eValueMs(ms);

/// Время сеанса: `m:ss`, от часа `h:mm:ss`.
String elapsedText(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s ~/ 60) % 60;
  final ss = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

/// Состояние подписки, влияющее на строку тарифа (`st.sub` в android.js).
enum M3eSubState { ok, expiring, trafficOut, expired }

/// Тон строки тарифа: обычный (ink2), предупреждение, ошибка.
enum M3ePlanTone { normal, warn, bad }

/// Трафик подписки строками, как их присылает провайдер (запятая уже в строке).
class M3eTrafficInfo {
  const M3eTrafficInfo({
    required this.used,
    required this.total,
    required this.left,
    required this.pct,
  });

  final String used;
  final String total;
  final String left;

  /// Расход в процентах, может быть 100 и выше.
  final double pct;
}

/// Строка тарифа под именем и признак «нужна кнопка Обновить».
class M3ePlan {
  const M3ePlan(this.text, this.tone, {this.needsRefresh = false});

  final String text;
  final M3ePlanTone tone;
  final bool needsRefresh;
}

/// Строка тарифа: android.js 410-414.
///
/// Предупреждения заменяют обычную строку «трафик · срок». Кнопка «Обновить» нужна
/// только когда подписка или трафик закончились: купить можно на странице провайдера
/// (Google Play запрещает оплату мимо своей), здесь остаётся только обновление.
M3ePlan planLine(
  AppLocalizations l, {
  M3eTrafficInfo? traffic,
  String? until,
  M3eSubState state = M3eSubState.ok,
  int daysLeft = 2,
}) {
  switch (state) {
    case M3eSubState.expired:
      return M3ePlan(l.m3ePlanExpired, M3ePlanTone.bad, needsRefresh: true);
    case M3eSubState.trafficOut:
      return M3ePlan(l.m3ePlanTrafficOut, M3ePlanTone.bad, needsRefresh: true);
    case M3eSubState.expiring:
      return M3ePlan(l.m3ePlanDaysLeft(daysLeft), M3ePlanTone.warn);
    case M3eSubState.ok:
      break;
  }
  if (traffic != null && traffic.pct > 90) {
    return M3ePlan(l.m3ePlanTrafficLeft(traffic.left), M3ePlanTone.warn);
  }
  final volume = traffic == null
      ? l.m3ePlanUnlimited
      : l.m3ePlanTrafficOf(traffic.used, traffic.total);
  final term = until == null ? l.m3ePlanForever : l.m3ePlanUntil(until);
  return M3ePlan(l.m3ePlanLine(volume, term), M3ePlanTone.normal);
}

/// Тон полосы трафика: от 100 % исчерпан, выше 90 % на исходе.
M3eMeterTone meterToneFor(double pct) => pct >= 100
    ? M3eMeterTone.out
    : pct > 90
        ? M3eMeterTone.low
        : M3eMeterTone.normal;
