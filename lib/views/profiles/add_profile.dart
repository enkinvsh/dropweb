import 'dart:async';
import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/pages/scan.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/account/account_common.dart';
import 'package:dropweb/views/account/account_login_sheet.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  /// Subscription URL detected in the clipboard when the sheet opened, or
  /// null. A detected candidate renders the clipboard row as a NAMED one-tap
  /// import — «Добавить sub.example.com» — so the user sees WHAT will be
  /// imported before tapping (owner requirement: the service identity must be
  /// visible up front, a blind "paste" row is not).
  String? _clipboardCandidate;

  @override
  void initState() {
    super.initState();
    // Owner decision (2026-07-03): read the clipboard ONCE at sheet open.
    // This sheet only ever opens from an explicit add tap, so the read is
    // tied to a user-authored intent — the Android 12+ clipboard toast is
    // acceptable in this context, and the payoff is the named import row
    // above. NEVER read at app launch/resume (that was the Wave 1 finding).
    unawaited(_checkClipboard());
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final candidate = extractSubscriptionUrl(data?.text);
      if (!mounted || candidate == null) return;
      setState(() => _clipboardCandidate = candidate);
    } catch (e) {
      // Clipboard access can throw (host/permission) — treat as no-match;
      // the row degrades to the read-on-tap fallback.
      commonPrint.log('[add-profile] clipboard read failed: $e');
    }
  }

  /// One-tap import of the candidate detected at sheet open.
  void _handleCandidateImport() {
    final candidate = _clipboardCandidate;
    if (candidate == null) return;
    // Close the sheet first; addProfileFromUrl drives the dashboard loading
    // flow via the global navigator (not this sheet's context).
    Navigator.pop(context);
    unawaited(addProfileFromUrl(candidate));
  }

  /// Вход открываем от контекста экрана, открывшего этот лист: контекст
  /// самого листа уходит вместе с ним при `Navigator.pop`. Ждём, пока лист
  /// доедет вниз (`completed` маршрута), иначе на полсекунды видны два листа.
  Future<void> _handleAccountLogin() async {
    final route = ModalRoute.of(context);
    final parent = widget.context;
    Navigator.pop(context);
    await route?.completed;
    if (!parent.mounted) {
      return;
    }
    await openAccountLoginSheet(parent);
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

  /// Fallback for the clipboard row when nothing was detected at sheet open:
  /// re-reads on tap (the clipboard may have changed since). If the text is a
  /// subscription URL, import it via the same path the other rows use; else
  /// hand it to the URL dialog prefilled, so a near-miss (extra whitespace, a
  /// wrapped/deep link, a page URL) is one edit away, not a dead end.
  Future<void> _handlePasteFromClipboard() async {
    String? text;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      text = data?.text;
    } catch (e) {
      // Clipboard access can throw (host/permission) — treat as empty and fall
      // through to the URL dialog; never surface a raw exception to the user.
      commonPrint.log('[add-profile] clipboard read failed: $e');
    }
    if (!mounted) return;
    final subscription = extractSubscriptionUrl(text);
    // Close the sheet first: both downstream paths drive the dashboard via the
    // global navigator, not this sheet's context (which is about to pop).
    Navigator.pop(context);
    if (subscription != null) {
      unawaited(addProfileFromUrl(subscription));
    } else {
      unawaited(showProfileUrlDialog(widget.context, initialText: text));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: system.isAndroidTV,
        builder: (context, snapshot) {
          final isTV = snapshot.data ?? false;
          return ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Вход по почте — первой строкой: для нового пользователя это
              // самый короткий путь, подписка импортируется сама. Строки нет,
              // если провайдер не объявил бэкенд входа или сессия уже есть
              // (условие — accountLoginEntryVisible).
              // `!kIsPlayBuild` — const: в Play аккаунта нет вовсе (решение
              // владельца 2026-10-29), строка и вход выпадают из сборки.
              if (!kIsPlayBuild && Platform.isAndroid)
                Consumer(
                  builder: (context, ref, _) {
                    final status = ref.watch(
                      accountProvider.select((state) => state.status),
                    );
                    if (!accountLoginEntryVisible(
                      isAndroid: true,
                      status: status,
                      loginAvailable: ref.watch(accountLoginAvailableProvider),
                    )) {
                      return const SizedBox.shrink();
                    }
                    return ListItem(
                      leading: const HugeIcon(
                        icon: HugeIcons.strokeRoundedMail01,
                        size: 24,
                      ),
                      title: Text(appLocalizations.accountLoginByEmail),
                      onTap: _handleAccountLogin,
                    );
                  },
                ),
              // Clipboard row — ALWAYS present, a plain ListItem matching the
              // QR/URL rows. With a candidate detected at sheet open it names
              // the service («Добавить sub.example.com», one tap = import);
              // without one it is a generic paste row that reads on tap. No
              // subtitle: the title carries the whole intent.
              Builder(builder: (context) {
                final candidate = _clipboardCandidate;
                final host =
                    candidate != null ? Uri.tryParse(candidate)?.host : null;
                return ListItem(
                  leading: const HugeIcon(
                      icon: HugeIcons.strokeRoundedClipboard, size: 24),
                  title: Text(
                    host != null && host.isNotEmpty
                        ? appLocalizations.addNamedSubscription(host)
                        : appLocalizations.onboardingClipboardImport,
                  ),
                  onTap: candidate != null
                      ? _handleCandidateImport
                      : _handlePasteFromClipboard,
                );
              }),
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

Future<void> showProfileUrlDialog(
  BuildContext context, {
  String? initialText,
}) async {
  final url = await globalState.showCommonDialog<String>(
    child: URLFormDialog(initialText: initialText),
  );
  if (url != null) {
    await addProfileFromUrl(url);
  }
}

class URLFormDialog extends StatefulWidget {
  const URLFormDialog({super.key, this.initialText});

  /// Optional prefill for the URL field. The Add sheet's clipboard row hands
  /// the raw clipboard text here when it is NOT a bare subscription URL, so a
  /// near-miss (wrapped link, stray whitespace, a page URL) lands editable
  /// instead of dead-ending. Null/empty → empty field (the normal path).
  final String? initialText;

  @override
  State<URLFormDialog> createState() => _URLFormDialogState();
}

class _URLFormDialogState extends State<URLFormDialog> {
  late final TextEditingController urlController;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }

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
              // Neutral shape-of-input hint (provider-agnostic): renders only
              // while the field is empty, guiding a fresh user without naming
              // or linking any provider. Prefilled clipboard text hides it.
              hintText: appLocalizations.importFromUrlHint,
            ),
          ),
        ),
      );
}
