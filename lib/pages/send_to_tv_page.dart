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
        final statusUrl = 'http://$ip:$port/status';
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ));
        // Residual risk: url + nonce travel as cleartext HTTP over the LAN. The
        // nonce blocks blind injection on the receiver but provides no
        // confidentiality — a passive sniffer on the same Wi-Fi can read both.
        // TLS is intentionally out of scope (no PKI on the LAN).
        try {
          await dio.post(
            tvUrl,
            data: {'url': widget.profileUrl, 'nonce': nonce},
          );
          _showResultDialog(appLocalizations.successTitle,
              appLocalizations.sentSuccessfullyMessage);
        } on DioException catch (_) {
          // The POST got no clean response. The TV might still have imported
          // this profile (e.g. from an earlier attempt), or be genuinely
          // unreachable. Poll the read-only /status probe — which exposes only
          // waiting/received, never the nonce — to tell the two apart and
          // report a definite outcome instead of a misleading error.
          final received = await _pollTvStatus(dio, statusUrl);
          if (!mounted) return;
          _showResultDialog(
            received
                ? appLocalizations.successTitle
                : appLocalizations.errorTitle,
            received
                ? appLocalizations.sentSuccessfullyMessage
                : appLocalizations.invalidQrMessage,
          );
        }
      }
    } catch (e) {
      _showResultDialog(
          appLocalizations.errorTitle, appLocalizations.invalidQrMessage);
    }
  }

  /// Poll the TV's read-only /status probe up to 10 times (1s apart) after a
  /// failed POST, returning true once the TV reports a profile was received.
  /// /status exposes only waiting/received — never the nonce — so reading it
  /// here leaks nothing.
  Future<bool> _pollTvStatus(Dio dio, String statusUrl) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        final resp = await dio.get<dynamic>(statusUrl);
        final data = resp.data;
        final decoded = data is String ? jsonDecode(data) : data;
        if (decoded is Map && decoded['state'] == 'received') {
          return true;
        }
      } catch (_) {
        // TV unreachable on this attempt; keep trying until the budget runs out.
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return false;
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
