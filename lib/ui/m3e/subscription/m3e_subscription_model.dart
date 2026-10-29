// Модель листа «Подписка»: чистые данные без Riverpod и без globalState. Лист строится
// из неё, а golden и виджет-тесты подают её напрямую (m3eSubModelProvider.overrideWithValue).

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/profile.dart';
import 'package:dropweb/views/dashboard/widgets/corner_badge.dart'
    show decodeLogoUrl;
import 'package:flutter/foundation.dart';

/// Одна подписка в списке «Все подписки».
@immutable
class M3eSubProfile {
  const M3eSubProfile({
    required this.id,
    required this.name,
    this.host,
    this.logoUrl,
    String? initials,
  }) : initialsOverride = initials;

  final String id;

  /// Имя для людей (`Profile.serviceName`, не пустое).
  final String name;

  /// Адрес страницы провайдера без схемы и пути; `null`, когда провайдер его не отдал.
  final String? host;

  /// Адрес логотипа из заголовка `dropweb-logo`; `null` — аватар с инициалами.
  final String? logoUrl;

  final String? initialsOverride;

  /// Инициалы аватара: первые буквы двух первых слов (`initials` доски, app.js:298).
  String get initials => initialsOverride ?? m3eSubInitials(name);

  @override
  bool operator ==(Object other) =>
      other is M3eSubProfile &&
      other.id == id &&
      other.name == name &&
      other.host == host &&
      other.logoUrl == logoUrl &&
      other.initialsOverride == initialsOverride;

  @override
  int get hashCode => Object.hash(id, name, host, logoUrl, initialsOverride);
}

/// Что показывает лист: подписки, текущая и необязательные пункты провайдера.
@immutable
class M3eSubModel {
  const M3eSubModel({
    required this.profiles,
    required this.currentId,
    this.updatedAt,
    this.refreshing = false,
    this.supportUrl,
    this.renewUrl,
    this.topUpUrl,
  });

  final List<M3eSubProfile> profiles;
  final String? currentId;

  /// Когда текущая подписка обновлялась в последний раз; `null` — ещё ни разу.
  final DateTime? updatedAt;

  /// Текущая подписка прямо сейчас обновляется (флаг `Profile.isUpdating`).
  final bool refreshing;

  /// `support-url` провайдера. Пустой — пункта «Справочная» нет, как в меню старой
  /// главной.
  final String? supportUrl;

  /// `dropweb-renew-url` и `dropweb-topup-url`; в магазинной сборке всегда `null`.
  /// Аккаунта и личного кабинета в листе нет вовсе: решение владельца 2026-10-29,
  /// Android-редизайн M3E и есть магазинный.
  final String? renewUrl;
  final String? topUpUrl;

  M3eSubProfile? get current {
    for (final p in profiles) {
      if (p.id == currentId) return p;
    }
    return null;
  }

  /// Хост страницы провайдера для пункта «Справочная».
  String? get supportHost =>
      supportUrl == null ? null : m3eSubHostOf(supportUrl!);

  bool get hasExtras => renewUrl != null || topUpUrl != null;

  @override
  bool operator ==(Object other) =>
      other is M3eSubModel &&
      listEquals(other.profiles, profiles) &&
      other.currentId == currentId &&
      other.updatedAt == updatedAt &&
      other.refreshing == refreshing &&
      other.supportUrl == supportUrl &&
      other.renewUrl == renewUrl &&
      other.topUpUrl == topUpUrl;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(profiles),
        currentId,
        updatedAt,
        refreshing,
        supportUrl,
        renewUrl,
        topUpUrl,
      );
}

/// Хост адреса: `https://cfgpull.com/ru` → `cfgpull.com`. Не адрес — строка как есть.
String m3eSubHostOf(String url) {
  final trimmed = url.trim();
  final host = Uri.tryParse(trimmed)?.host ?? '';
  return host.isNotEmpty ? host : trimmed;
}

/// Инициалы аватара: первые буквы первых двух слов заглавными, как `initials` доски.
String m3eSubInitials(String name) {
  final words = RegExp(r'[\p{L}\p{N}]+', unicode: true)
      .allMatches(name)
      .map((m) => m.group(0)!)
      .take(2);
  if (words.isEmpty) return '?';
  return words
      .map((w) => String.fromCharCode(w.runes.first))
      .join()
      .toUpperCase();
}

/// «Обновлено 4 минуты назад»: подпись пункта «Обновить». `null` — подписка ещё не
/// обновлялась, подписи нет.
String? m3eUpdatedAgo(AppLocalizations l, DateTime? at, DateTime now) {
  if (at == null) return null;
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return l.m3eUpdatedJustNow;
  if (diff.inHours < 1) return l.m3eUpdatedMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l.m3eUpdatedHoursAgo(diff.inHours);
  return l.m3eUpdatedDaysAgo(diff.inDays);
}

/// Подписка списка из профиля приложения. Хост берётся из `profile-web-page-url`, затем
/// из `support-url`: `Profile.url` после миграции шифрования пуст, а токен в нём лишний.
///
/// Логотип берётся из `dropweb-logo` всегда: переключатель «Лого из подписки»
/// (`applySubscriptionLogo`) относится к старому оформлению и в M3E-листе не действует,
/// а у владельца он мог остаться выключенным.
M3eSubProfile m3eSubProfileOf(Profile profile) {
  final headers = profile.providerHeaders;
  final site = _nonEmpty(headers['profile-web-page-url']) ??
      _nonEmpty(headers['support-url']);
  final logo = _nonEmpty(decodeLogoUrl(headers['dropweb-logo']));
  return M3eSubProfile(
    id: profile.id,
    name: profile.serviceName,
    host: site == null ? null : m3eSubHostOf(site),
    logoUrl: logo,
  );
}

/// Модель листа из состояния приложения.
///
/// Продление и пополнение гейтятся так же, как у старой главной: заголовок есть и сборка
/// не магазинная (`system.isStoreBuild`). [storeBuild] передаёт тест.
M3eSubModel m3eSubModelOf({
  required List<Profile> profiles,
  required String? currentId,
  required bool storeBuild,
}) {
  Profile? current;
  for (final p in profiles) {
    if (p.id == currentId) current = p;
  }
  final headers = current?.providerHeaders ?? const <String, String>{};
  return M3eSubModel(
    profiles: [
      for (final p in profiles) m3eSubProfileOf(p),
    ],
    currentId: currentId,
    updatedAt: current?.lastUpdateDate,
    refreshing: current?.isUpdating ?? false,
    supportUrl: _nonEmpty(headers['support-url']),
    renewUrl: storeBuild ? null : _http(headers['dropweb-renew-url']),
    topUpUrl: storeBuild ? null : _http(headers['dropweb-topup-url']),
  );
}

String? _nonEmpty(String? value) {
  final v = value?.trim();
  return (v == null || v.isEmpty) ? null : v;
}

/// Ссылка продления и пополнения: только http(s) с хостом, остальное отбрасывается.
String? _http(String? value) {
  final v = _nonEmpty(value);
  if (v == null) return null;
  final uri = Uri.tryParse(v);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return v;
}
