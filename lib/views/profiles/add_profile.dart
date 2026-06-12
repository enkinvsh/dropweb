import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/pages/scan.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'receive_profile_dialog.dart';

class AddProfileView extends StatefulWidget {
  const AddProfileView({
    super.key,
    required this.context,
  });
  final BuildContext context;

  @override
  State<AddProfileView> createState() => _AddProfileViewState();
}

class _AddProfileViewState extends State<AddProfileView> {
  /// Subscription URL detected in the clipboard on sheet open, or null when
  /// the clipboard held nothing importable. Drives the highlighted top entry.
  String? _clipboardCandidate;

  @override
  void initState() {
    super.initState();
    // The user just chose "add" → the first-run hint has served its purpose
    // and must never re-appear (it would otherwise sit behind this sheet).
    unawaited(onboardingState.markHintSeen());
    // Privacy: read the clipboard EXACTLY once, here, tied to the explicit
    // "Add" intent — never at app launch/resume. Ties the Android-12 system
    // clipboard toast to a user-authored action. See onboarding-brief §2.
    unawaited(_checkClipboard());
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final candidate = extractSubscriptionUrl(data?.text);
      if (!mounted || candidate == null) return;
      setState(() => _clipboardCandidate = candidate);
    } catch (e) {
      // Clipboard access can throw (permission/host exceptions) — treat as
      // no-match; never surface into the UI.
      commonPrint.log('[onboarding] clipboard read failed: $e');
    }
  }

  Future<void> _handleReceiveFromPhone() async {
    final url = await showDialog<String>(
      context: widget.context,
      builder: (_) => const ReceiveProfileDialog(),
    );
    if (url != null && url.isNotEmpty) {
      await addProfileFromUrl(url);
    }
  }

  void _handleClipboardImport() {
    final candidate = _clipboardCandidate;
    if (candidate == null) return;
    // Close the sheet first; addProfileFormURL then drives the dashboard
    // loading flow via the global navigator (not this sheet's context).
    Navigator.pop(context);
    unawaited(addProfileFromUrl(candidate));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: system.isAndroidTV,
        builder: (context, snapshot) {
          final isTV = snapshot.data ?? false;
          final candidate = _clipboardCandidate;
          return ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (candidate != null)
                _ClipboardImportEntry(
                  host: Uri.tryParse(candidate)?.host ?? '',
                  onTap: _handleClipboardImport,
                ),
              if (isTV)
                ListItem(
                  leading: const HugeIcon(
                      icon: HugeIcons.strokeRoundedTv01, size: 24),
                  title: Text(appLocalizations.addFromPhoneTitle),
                  subtitle: Text(appLocalizations.addFromPhoneSubtitle),
                  onTap: _handleReceiveFromPhone,
                ),
              if (system.supportsQrFromImage)
                ListItem(
                  leading: const HugeIcon(
                      icon: HugeIcons.strokeRoundedQrCode, size: 24),
                  title: Text(appLocalizations.qrcode),
                  onTap: () => scanProfileQrCode(context),
                ),
              ListItem(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCloudDownload, size: 24),
                title: Text(appLocalizations.url),
                onTap: () => showProfileUrlDialog(context),
              ),
            ],
          );
        },
      );
}

/// Highlighted "paste subscription from clipboard" entry promoted to the top
/// of the Add sheet when a subscription URL is detected in the clipboard.
/// Promoted via [Lumina.glass] + a primary-tinted leading icon so it reads as
/// the recommended action — still the same [ListItem] atom as every other row.
class _ClipboardImportEntry extends StatelessWidget {
  const _ClipboardImportEntry({
    required this.host,
    required this.onTap,
  });

  final String host;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final desc = appLocalizations.onboardingClipboardImportDesc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: DecoratedBox(
        decoration: Lumina.glass(radius: Lumina.radiusMd),
        child: ListItem(
          leading: HugeIcon(
            icon: HugeIcons.strokeRoundedClipboard,
            size: 24,
            color: colorScheme.primary,
          ),
          title: Text(appLocalizations.onboardingClipboardImport),
          subtitle: Text(host.isEmpty ? desc : '$desc $host'),
          onTap: onTap,
        ),
      ),
    );
  }
}

Future<void> addProfileFromUrl(String url) async {
  await globalState.appController.addProfileFormURL(url);
}

Future<void> scanProfileQrCode(BuildContext context) async {
  if (system.isDesktop) {
    await globalState.appController.addProfileFormQrCode();
    return;
  }
  final url = await BaseNavigator.push<String>(
    context,
    const ScanPage(),
  );
  if (url != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(addProfileFromUrl(url));
    });
  }
}

Future<void> showProfileUrlDialog(BuildContext context) async {
  final url = await globalState.showCommonDialog<String>(
    child: const URLFormDialog(),
  );
  if (url != null) {
    await addProfileFromUrl(url);
  }
}

class URLFormDialog extends StatefulWidget {
  const URLFormDialog({super.key});

  @override
  State<URLFormDialog> createState() => _URLFormDialogState();
}

class _URLFormDialogState extends State<URLFormDialog> {
  final urlController = TextEditingController();

  void _handleSubmit() {
    final url = urlController.text.trim();
    if (url.isNotEmpty) {
      Navigator.of(context).pop<String>(url);
    }
  }

  Future<void> _handlePaste() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      urlController.text = clipboardData!.text!;
    }
  }

  @override
  Widget build(BuildContext context) => CommonDialog(
        title: appLocalizations.importFromURL,
        actions: [
          TextButton(
            onPressed: _handlePaste,
            child: Text(appLocalizations.pasteFromClipboard),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _handleSubmit,
            child: Text(appLocalizations.submit),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: TextField(
            controller: urlController,
            keyboardType: TextInputType.url,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            onSubmitted: (_) => _handleSubmit(),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: appLocalizations.url,
            ),
          ),
        ),
      );
}
