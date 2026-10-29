import 'dart:convert';

import '../../../l10n/l10n.dart';
import '../color/color.dart';
import '../theme/m3e_theme_source.dart';

/// Версия формата: Kotlin (`WidgetStyleStore`) отбрасывает payload другой версии и
/// остаётся на встроенных значениях, а не гадает по чужим полям.
const int kM3eWidgetPayloadVersion = 1;

/// Имя сервиса, когда профиля ещё нет.
const String kM3eWidgetFallbackName = 'dropweb';

/// Цвета виджета одной яркости: кнопка выключена (`off*`), включена (`on*`), плашка 2×1
/// (`bg`) и два текста. Роли те же, что у кнопки подключения на главной
/// (`m3e_hero_button.dart`), чтобы виджет и экран не расходились.
Map<String, String> m3eWidgetColors(M3eThemeSource source, {required bool dark}) {
  final s = scheme(source.seed, source.filter, dark: dark);
  final h = homeVars(source.seed, source.filter, dark: dark);
  return {
    'bg': s.hex('surfaceContainer'),
    'title': s.hex('onSurface'),
    'sub': s.hex('onSurfaceVariant'),
    'offBg': s.hex('primaryContainer'),
    'offFg': s.hex('onPrimaryContainer'),
    'onBg': h.hex('hero-on'),
    'onFg': h.hex('on-hero-on'),
  };
}

/// Данные для виджета рабочего стола: цвета обеих яркостей и подписи на языке
/// приложения. Виджет рисует система, у неё нет ни наших схем, ни локали приложения,
/// поэтому всё готовое уходит в нативную часть одним JSON.
Map<String, Object?> m3eWidgetPayload({
  required M3eThemeSource source,
  required String serviceName,
  required AppLocalizations l10n,
}) {
  final name = serviceName.trim();
  return {
    'v': kM3eWidgetPayloadVersion,
    'name': name.isEmpty ? kM3eWidgetFallbackName : name,
    'texts': {
      'on': l10n.m3eStatusConnected,
      'off': l10n.m3eStatusDisconnected,
      'pending': l10n.m3eStatusConnecting,
      'cdOn': l10n.m3eA11yDisconnect,
      'cdOff': l10n.m3eA11yConnect,
      'cdPending': l10n.m3eA11yCancel,
    },
    'light': m3eWidgetColors(source, dark: false),
    'dark': m3eWidgetColors(source, dark: true),
  };
}

/// JSON payload'а. Ключи в фиксированном порядке: по строке работает дедупликация
/// отправок.
String m3eWidgetPayloadJson({
  required M3eThemeSource source,
  required String serviceName,
  required AppLocalizations l10n,
}) =>
    jsonEncode(
      m3eWidgetPayload(source: source, serviceName: serviceName, l10n: l10n),
    );
