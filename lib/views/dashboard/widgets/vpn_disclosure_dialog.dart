import 'package:dropweb/common/common.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/dialog.dart';
import 'package:flutter/material.dart';

/// First-run VPN disclosure shown before the very first connection attempt.
///
/// Resolves to:
///   * `true`  — user pressed Continue (caller must persist consent).
///   * `false` — user pressed Cancel.
///   * `null`  — dialog dismissed without an explicit choice (treat as cancel).
///
/// The wording is intentionally factual and moderation-safe: it describes
/// what the VPN does, that the user controls it, and that optional
/// diagnostics/account flows are disclosed separately. It does NOT claim
/// "no logs" or "anonymous".
Future<bool?> showVpnDisclosureDialog(BuildContext context) =>
    globalState.showCommonDialog<bool>(
      dismissible: false,
      child: const _VpnDisclosureDialog(),
    );

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
        appLocalizations.vpnDisclosureBody,
        style: textTheme.bodyMedium,
      ),
    );
  }
}
