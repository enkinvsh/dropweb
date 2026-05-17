import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/pages/scan.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'receive_profile_dialog.dart';

class AddProfileView extends StatelessWidget {
  const AddProfileView({
    super.key,
    required this.context,
  });
  final BuildContext context;

  Future<void> _handleAddProfileFormFile() async {
    await globalState.appController.addProfileFormFile();
  }

  Future<void> _handleReceiveFromPhone() async {
    final url = await showDialog<String>(
      context: context,
      builder: (_) => const ReceiveProfileDialog(),
    );
    if (url != null && url.isNotEmpty) {
      await addProfileFromUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: system.isAndroidTV,
        builder: (context, snapshot) {
          final isTV = snapshot.data ?? false;
          return ListView(
            children: [
              if (isTV)
                ListItem(
                  leading: const HugeIcon(
                      icon: HugeIcons.strokeRoundedTv01, size: 24),
                  title: Text(appLocalizations.addFromPhoneTitle),
                  subtitle: Text(appLocalizations.addFromPhoneSubtitle),
                  onTap: _handleReceiveFromPhone,
                ),
              ListItem(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedQrCode, size: 24),
                title: Text(appLocalizations.qrcode),
                subtitle: Text(appLocalizations.qrcodeDesc),
                onTap: () => scanProfileQrCode(context),
              ),
              ListItem(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedFileUpload, size: 24),
                title: Text(appLocalizations.file),
                subtitle: Text(appLocalizations.fileDesc),
                onTap: _handleAddProfileFormFile,
              ),
              ListItem(
                leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCloudDownload, size: 24),
                title: Text(appLocalizations.url),
                subtitle: Text(appLocalizations.urlDesc),
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
