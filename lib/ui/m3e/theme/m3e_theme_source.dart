import 'package:flutter/material.dart' show DynamicSchemeVariant;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/constant.dart' show defaultPrimaryColor;
import '../../../providers/config.dart';

/// Исходные данные цвета новых экранов: акцент `#RRGGBB` и фильтр схемы доски.
class M3eThemeSource {
  const M3eThemeSource({required this.seed, required this.filter});

  final String seed;
  final String filter;

  @override
  bool operator ==(Object other) =>
      other is M3eThemeSource && other.seed == seed && other.filter == filter;

  @override
  int get hashCode => Object.hash(seed, filter);
}

/// Фильтр доски по варианту схемы приложения. Четыре варианта дают свои схемы spec 2025,
/// остальные (fidelity, content, rainbow, fruitSalad, monochrome) уходят в CMF spec 2026:
/// так `VARIANTS[filter] || CMF` решает в android.js.
String m3eFilterFor(DynamicSchemeVariant variant) => switch (variant) {
      DynamicSchemeVariant.tonalSpot => 'tonal_spot',
      DynamicSchemeVariant.vibrant => 'vibrant',
      DynamicSchemeVariant.expressive => 'expressive',
      DynamicSchemeVariant.neutral => 'neutral',
      DynamicSchemeVariant.fidelity ||
      DynamicSchemeVariant.content ||
      DynamicSchemeVariant.rainbow ||
      DynamicSchemeVariant.fruitSalad ||
      DynamicSchemeVariant.monochrome =>
        'fidelity',
    };

/// Акцент темы M3E по умолчанию: провайдер «Голубой» доски
/// (`fidelity,#38BDF8,#6366F1,#22D3EE,3`, провайдер 1 в `kBoardProviders` / `app.js`).
/// Решение владельца 2026-10-29: неоновый #29FF76 по умолчанию не нужен.
/// Фильтр у «Голубого» тоже fidelity, а это и есть дефолтный `schemeVariant` конфига.
const String m3eDefaultSeed = '#38BDF8';

/// `#RRGGBB` из ARGB-целого.
///
/// `null` и `defaultPrimaryColor` (0xFF29FF76) дают [m3eDefaultSeed]: 0xFF29FF76 — дефолт
/// приложения, его пишут и конфиг (`defaultThemeProps`), и `resetSubscriptionTheme` при
/// подписке без заголовка `dropweb-theme`, так что «заголовка нет» неотличимо от «провайдер
/// прислал ровно #29FF76». Заголовок `fidelity,#29FF76,…` (его шлёт панель dropweb)
/// поэтому тоже даёт «Голубой» — так решил владелец. Общий `defaultPrimaryColor` не
/// меняем: он нужен Lumina, iOS и десктопу.
String m3eSeedFor(int? primaryColor) =>
    primaryColor == null || primaryColor == defaultPrimaryColor
        ? m3eDefaultSeed
        : m3eHexOf(primaryColor);

/// `#RRGGBB` верхним регистром без подмены дефолта: так пишется выбранный вручную цвет,
/// и #29FF76 из палитры остаётся #29FF76.
String m3eHexOf(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Источник seed/filter от провайдера подписки: акцент и вариант схемы лежат в
/// `themeSettingProvider`, их туда пишет разбор заголовка `dropweb-theme`.
/// Свой цвет пользователя сюда не входит: он нужен образцу «Цвет провайдера»
/// и значению по умолчанию для «Свой цвет».
final m3eProviderSourceProvider = Provider<M3eThemeSource>((ref) {
  final (primary, variant) = ref.watch(
    themeSettingProvider.select((t) => (t.primaryColor, t.schemeVariant)),
  );
  return M3eThemeSource(
      seed: m3eSeedFor(primary), filter: m3eFilterFor(variant));
});

/// Фильтр для своего цвета. Доска в `applyScheme` берёт `'cmf'`, но этого имени нет среди
/// четырёх фильтров spec 2025, а `scheme()` любое незнакомое имя отправляет в CMF spec 2026,
/// как и `'fidelity'`. Схема получается одна и та же; берём `'fidelity'`, чтобы ключ кэша
/// `scheme()` совпадал с схемой подписки по умолчанию. У CMF primary-container равен
/// выбранному цвету, поэтому образец и схема совпадают.
const String m3eOwnColorFilter = 'fidelity';

/// Итоговый источник для новых экранов: выбранный свой цвет побеждает цвет провайдера.
final m3eThemeSourceProvider = Provider<M3eThemeSource>((ref) {
  final (enabled, own) = ref.watch(
    themeSettingProvider.select((t) => (t.m3eOwnColorEnabled, t.m3eOwnColor)),
  );
  if (enabled && own != null) {
    return M3eThemeSource(seed: m3eHexOf(own), filter: m3eOwnColorFilter);
  }
  return ref.watch(m3eProviderSourceProvider);
});
