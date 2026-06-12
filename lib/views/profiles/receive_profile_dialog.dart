import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dropweb/common/common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;

/// Cryptographically-random, single-use handoff token (32 hex chars / 16 bytes)
/// generated with [Random.secure]. It is embedded in the Send-to-TV QR and must
/// be echoed back on `POST /add-profile`, so only the sender that scanned THIS
/// QR can inject a profile. A non-secure [Random] may be injected for tests.
@visibleForTesting
String generateHandoffNonce([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Outcome of validating an inbound `POST /add-profile` body.
@immutable
class HandoffValidation {
  const HandoffValidation(this.statusCode, [this.url]);

  /// HTTP status to return: 400 (garbage/missing url), 403 (bad nonce), 200 (ok).
  final int statusCode;

  /// The profile URL to import — non-null only when [statusCode] == 200.
  final String? url;
}

/// Pure validation for the Send-to-TV receiver.
///
/// Order matters for the threat model: an unparseable/non-object body is 400,
/// then the [expectedNonce] is checked BEFORE the url so an unauthenticated LAN
/// peer never learns anything about url validity — wrong/missing nonce is always
/// 403. Only a correct nonce with a non-empty url string yields 200.
///
/// Residual risk: the nonce only proves the caller scanned THIS QR; it blocks
/// blind injection but does NOT provide confidentiality. The url + nonce still
/// travel as cleartext HTTP over the LAN and are readable by a passive sniffer
/// on the same Wi-Fi. TLS is intentionally out of scope (no PKI on the LAN).
@visibleForTesting
HandoffValidation validateHandoffBody(String body, String expectedNonce) {
  dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return const HandoffValidation(400);
  }
  if (decoded is! Map) {
    return const HandoffValidation(400);
  }
  final nonce = decoded['nonce'];
  if (nonce is! String || nonce != expectedNonce) {
    return const HandoffValidation(403);
  }
  final url = decoded['url'];
  if (url is! String || url.isEmpty) {
    return const HandoffValidation(400);
  }
  return HandoffValidation(200, url);
}

class ReceiveProfileDialog extends StatefulWidget {
  const ReceiveProfileDialog({super.key});

  @override
  State<ReceiveProfileDialog> createState() => _ReceiveProfileDialogState();
}

class _ReceiveProfileDialogState extends State<ReceiveProfileDialog> {
  HttpServer? _server;
  String? _qrData;
  bool _isLoading = true;

  /// Single-use secret for this dialog instance; required on every POST.
  final String _nonce = generateHandoffNonce();

  /// Set once a valid profile is imported so the nonce cannot be replayed in the
  /// window before [dispose] tears the server down.
  bool _consumed = false;

  @override
  void initState() {
    super.initState();
    _startServerAndGenerateQr();
  }

  Future<void> _startServerAndGenerateQr() async {
    try {
      final ip = await NetworkInfo().getWifiIP();
      const port = 8899;

      final router = shelf_router.Router();
      router.post('/add-profile', (shelf.Request request) async {
        // Single-use: once a profile has been imported, reject everything else
        // (defends against a replayed POST arriving before the dialog disposes).
        if (_consumed) {
          return shelf.Response.forbidden('Handoff already completed');
        }
        final body = await request.readAsString();
        final result = validateHandoffBody(body, _nonce);
        switch (result.statusCode) {
          case 200:
            _consumed = true;
            // Popping the dialog disposes this State, which closes the server
            // (see dispose) — the nonce is thus genuinely single-use.
            if (mounted) Navigator.of(context).pop(result.url);
            return shelf.Response.ok('Link received by TV');
          case 403:
            return shelf.Response.forbidden('Invalid handoff token');
          default:
            return shelf.Response.badRequest(body: 'Bad request');
        }
      });

      _server = await shelf_io.serve(router.call, ip!, port);

      setState(() {
        _qrData = jsonEncode({
          'type': 'dropweb_tv_sync',
          'ip': _server?.address.host,
          'port': _server?.port,
          'nonce': _nonce,
        });
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ReceiveProfile server failed to start: $e');
      }
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _server?.close(force: true);
    if (kDebugMode) {
      debugPrint('ReceiveProfile server stopped');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(appLocalizations.receiveSubscriptionTitle),
      content: SizedBox(
        width: 300,
        height: 300,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _qrData != null
                ? Center(
                    child: QrImageView(
                      data: _qrData!,
                      version: QrVersions.auto,
                      size: 300.0,
                      backgroundColor: Colors.transparent,
                      dataModuleStyle: QrDataModuleStyle(
                        color: theme.colorScheme.onSurface,
                        dataModuleShape: QrDataModuleShape.square,
                      ),
                      eyeStyle: QrEyeStyle(
                        color: theme.colorScheme.onSurface,
                        eyeShape: QrEyeShape.square,
                      ),
                    ),
                  )
                : const Center(child: Text('Could not get IP address')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
      ],
    );
  }
}
