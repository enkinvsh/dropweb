import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../state.dart';
import '../symbols.g.dart';
import '../theme/m3e_colors_for.dart';
import '../widgets/m3e_dialog.dart';
import 'm3e_about.dart';

/// «Перед подключением»: раскрытие VPN перед первым подключением.
///
/// `true` — «Продолжить» (вызывающий сам запоминает согласие), `false` — «Отмена», «Назад»
/// или касание затемнения. Раскладка доски (значок vpn_key, заголовок, две кнопки).
/// Раскрытие обязательно (Google Play для VpnService, App Store 5.4), но владелец не хочет
/// экран на всю высоту: в диалоге короткий текст с тремя фактами (туннель через разрешение
/// Android, трафик идёт через серверы подписки, что получает провайдер), а полный текст
/// живёт на странице политики; ссылка на неё под текстом диалог не закрывает и согласия
/// не пишет. Текст выделяемый, как в старом диалоге.
///
/// [openUrl] подменяет открытие ссылки в тестах; по умолчанию `globalState.openUrl`
/// (с подтверждением «внешняя ссылка»).
Future<bool> showM3eVpnDisclosure(
  BuildContext context, {
  @visibleForTesting Future<void> Function(String url)? openUrl,
}) async {
  final l = AppLocalizations.of(context);
  final open = openUrl ?? globalState.openUrl;
  final result = await showM3eDialog<bool>(
    context,
    colors: m3eColorsFor(context),
    selectableText: true,
    icon: M3eSymbol.vpnKey,
    title: l.m3eDisclosureTitle,
    text: l.m3eDisclosureBody,
    link: M3eDialogLink(l.m3eAboutPrivacy, () => open(m3ePrivacyUrl())),
    actions: [
      M3eDialogAction(l.cancel, false),
      M3eDialogAction(l.vpnDisclosureContinue, true),
    ],
  );
  return result ?? false;
}

/// «Удалить «{name}»?»: `true` — «Удалить», `false` — «Отмена», «Назад» или затемнение.
///
/// Имя в заголовке переносится по словам, а слово длиннее строки ломается по символам;
/// ширину диалога имя не растягивает.
Future<bool> showM3eDeleteSubscription(
  BuildContext context, {
  required String name,
}) async {
  final l = AppLocalizations.of(context);
  final result = await showM3eDialog<bool>(
    context,
    colors: m3eColorsFor(context),
    icon: M3eSymbol.delete,
    title: l.m3eDeleteTitle(name),
    text: l.m3eDeleteBody,
    actions: [
      M3eDialogAction(l.cancel, false),
      M3eDialogAction(l.delete, true, danger: true),
    ],
  );
  return result ?? false;
}
