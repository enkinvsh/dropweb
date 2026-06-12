import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dropweb/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class SendToTvPage extends ConsumerStatefulWidget {

  const SendToTvPage({
    super.key,
    required this.profileUrl,
  });
  final String profileUrl;

  @override
  ConsumerState<SendToTvPage> createState() => _SendToTvPageState();
}

class _SendToTvPageState extends ConsumerState<SendToTvPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanComplete = false;

  Future<void> _handleQrCode(BarcodeCapture capture) async {
    if (_isScanComplete) return;
    setState(() {
      _isScanComplete = true;
    });

    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null) return;

    try {
      final data = jsonDecode(rawValue);
      if (data['type'] == 'dropweb_tv_sync') {
        final ip = data['ip'];
        final port = data['port'];
        final nonce = data['nonce'];
        // Both apps ship together, so a QR without a nonce is an outdated TV
        // app. Require the nonce — the receiver would 403 a nonce-less POST
        // anyway — and surface the generic invalid-QR error (a dedicated
        // "update the TV app" string can't be added without the IDE-plugin
        // l10n codegen, which is unavailable from CLI; see notepad T11).
        if (nonce is! String || nonce.isEmpty) {
          _showResultDialog(
              appLocalizations.errorTitle, appLocalizations.invalidQrMessage);
          return;
        }
        final tvUrl = 'http://$ip:$port/add-profile';
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ));
        // Residual risk: url + nonce travel as cleartext HTTP over the LAN. The
        // nonce blocks blind injection on the receiver but provides no
        // confidentiality — a passive sniffer on the same Wi-Fi can read both.
        // TLS is intentionally out of scope (no PKI on the LAN).
        await dio.post(
          tvUrl,
          data: {'url': widget.profileUrl, 'nonce': nonce},
        );
        _showResultDialog(appLocalizations.successTitle,
            appLocalizations.sentSuccessfullyMessage);
      }
    } catch (e) {
      _showResultDialog(
          appLocalizations.errorTitle, appLocalizations.invalidQrMessage);
    }
  }

  void _showResultDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(appLocalizations.sendToTvTitle)),
      body: MobileScanner(
        controller: _scannerController,
        onDetect: _handleQrCode,
      ),
    );

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}
