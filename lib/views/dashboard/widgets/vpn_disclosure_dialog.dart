import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/m3e/screens/m3e_dialogs.dart';
import 'package:dropweb/widgets/dialog.dart';
import 'package:flutter/material.dart';

/// First-run VPN disclosure shown before the very first connection attempt.
///
/// Resolves to:
///   * `true`  — user pressed Continue (caller must persist consent).
///   * `false` — user pressed Cancel.
///   * `null`  — dialog dismissed without an explicit choice (treat as cancel).
///
/// Текст фактический и должен совпадать с политикой приложения
/// (dropweb.org/app/privacy): что делает VPN, куда уходит трафик, что получает
/// провайдер подписки (IP, HWID, модель устройства) и что приложение сам
/// содержимое трафика не смотрит и не отправляет. Он НЕ обещает «no logs»
/// и «anonymous»: локальные логи приложение ведёт, а серверы пользователя
/// живут по своим правилам. Меняешь текст — сверь с политикой.
Future<bool?> showVpnDisclosureDialog(BuildContext context) {
  if (Platform.isAndroid) return showM3eVpnDisclosure(context);
  return globalState.showCommonDialog<bool>(
    dismissible: false,
    child: const _VpnDisclosureDialog(),
  );
}

class _VpnDisclosureDialog extends StatelessWidget {
  const _VpnDisclosureDialog();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return CommonDialog(
      title: appLocalizations.vpnDisclosureTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop<bool>(false),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop<bool>(true),
          child: Text(appLocalizations.vpnDisclosureContinue),
        ),
      ],
      child: SelectableText(
        // App Store (правило 2.3.10) отклоняет упоминания других платформ,
        // поэтому у iOS свой текст без «Android».
        Platform.isIOS
            ? appLocalizations.vpnDisclosureBodyIos
            : appLocalizations.vpnDisclosureBody,
        style: textTheme.bodyMedium,
      ),
    );
  }
}
