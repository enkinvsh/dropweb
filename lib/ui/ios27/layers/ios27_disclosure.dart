// Раскрытие VPN перед первым подключением на iOS (доска: `st.alert === 'disclosure'`, app.js).

import 'package:dropweb/common/vpn_consent.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/ios27/layers/ios27_alert.dart';
import 'package:dropweb/ui/ios27/layers/ios27_zoom.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart' show Ios27Text;
import 'package:dropweb/ui/m3e/screens/m3e_about.dart' show m3ePrivacyUrl;
import 'package:flutter/material.dart';

/// «Перед подключением»: окно раскрытия VPN перед первым подключением (правило App Store 5.4).
///
/// Возвращает `true` по «Продолжить», `false` по «Отмена»; закрыть окно тапом мимо, жестом или
/// системным «назад» нельзя: решение обязательно. По «Продолжить» согласие записывается здесь
/// же (`vpnConsent.markAccepted`), после закрытия окна; вызывающий код вправе записать его
/// ещё раз, запись идемпотентна.
///
/// Ссылка «Политика конфиденциальности» открывает политику и окно не закрывает; согласием она
/// не считается. Цвет ссылки цвет подписи с подчёркиванием, не акцент провайдера (решение
/// владельца 26.10). Тексты только из `ios27Disclosure*`: строки `m3eDisclosure*` и
/// `vpnDisclosureBody` называют Android, а на iOS их показывать нельзя (App Store 2.3.10).
///
/// [openUrl] подменяет открытие ссылки в тестах; по умолчанию `globalState.openUrl`
/// (с подтверждением «внешняя ссылка»).
Future<bool?> showIos27VpnDisclosure(
  BuildContext context, {
  @visibleForTesting Future<void> Function(String url)? openUrl,
}) async {
  final open = openUrl ?? globalState.openUrl;
  final result = await showIos27Alert<bool>(
    context,
    dismissible: false,
    // Окно вырастает из кнопки питания (app.js 1263); без неё (фон, диплинк) — обычный въезд.
    origin: Ios27ZoomSource.originFor(Ios27ZoomId.power),
    builder: (_) => _Disclosure(onOpenPolicy: () => open(m3ePrivacyUrl())),
  );
  if (result == true) {
    await vpnConsent.markAccepted();
  }
  return result;
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.onOpenPolicy});

  final VoidCallback onOpenPolicy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = ios27ColorsFor(context);
    return Center(
      child: Ios27Alert(
        title: l.ios27DisclosureTitle,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.ios27DisclosureBody),
            // На 8 ниже текста, как `.alert__link{margin:8px 6px 0}`.
            const SizedBox(height: 8),
            Semantics(
              link: true,
              child: GestureDetector(
                key: const ValueKey<String>('ios27.disclosure.policy'),
                behavior: HitTestBehavior.opaque,
                onTap: onOpenPolicy,
                child: Text(
                  l.ios27DisclosurePolicy,
                  style: ios27Text(
                    context,
                    Ios27Text.subhead,
                    color: colors.palette.glassLabel,
                  ).copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: colors.palette.glassLabel,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Ios27AlertButton(
            label: l.cancel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          Ios27AlertButton(
            label: l.vpnDisclosureContinue,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
