import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/ui/m3e/screens/m3e_scan.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_toast_kind.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanComplete = false;

  void _handleBarcode(BarcodeCapture capture) {
    if (_isScanComplete) return;

    final rawValue = capture.barcodes.first.rawValue;

    if (rawValue != null && rawValue.isNotEmpty) {
      setState(() {
        _isScanComplete = true;
      });
      Navigator.pop<String>(context, rawValue);
    }
  }

  Future<void> _scanFromImage() async {
    if (!system.supportsQrFromImage) {
      if (mounted) {
        context.showNotifier(
          appLocalizations.qrScanFromImageUnsupported,
          kind: M3eToastKind.alert,
        );
      }
      return;
    }

    String? imagePath;

    if (system.isDesktop) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null && result.files.single.path != null) {
        imagePath = result.files.single.path;
      }
    } else {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        imagePath = image.path;
      }
    }

    if (imagePath != null) {
      final result = await _scannerController.analyzeImage(imagePath);
      if (result != null && result.barcodes.isNotEmpty) {
        _handleBarcode(result);
      } else {
        if (mounted) {
          context.showNotifier(
            appLocalizations.qrNotFound,
            kind: M3eToastKind.alert,
          );
        }
      }
    }
  }

  // Replaces the plugin's hardcoded English default ("Camera permission
  // denied.") with a localized string so the scanner isn't a lone English
  // pane inside an otherwise Russian UI. Non-permission codes keep the
  // plugin's own message (rare edge cases, not the audit finding).
  String _errorMessage(MobileScannerException error) =>
      error.errorCode == MobileScannerErrorCode.permissionDenied
          ? appLocalizations.cameraPermissionDenied
          : error.errorCode.message;

  Widget _buildScannerError(
    BuildContext context,
    MobileScannerException error,
  ) {
    final message = _errorMessage(error);
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sideLength =
        min(400, MediaQuery.of(context).size.width * 0.67);

    final screenSize = MediaQuery.of(context).size;
    final scanWindow = Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 2),
      width: sideLength,
      height: sideLength,
    );

    // Android: та же камера и тот же контроллер, но в обвязке M3E. Ошибку камеры рисует
    // сама обвязка (плагинный errorBuilder прячем), результат и разбор файла — прежние.
    if (Platform.isAndroid) {
      return M3eThemeScope(
        child: ValueListenableBuilder<MobileScannerState>(
          valueListenable: _scannerController,
          builder: (context, state, _) {
            final error = state.error;
            return M3eScanView(
              camera: MobileScanner(
                controller: _scannerController,
                scanWindow: scanWindow,
                onDetect: _handleBarcode,
                errorBuilder: (_, __) => const SizedBox.shrink(),
              ),
              window: scanWindow,
              error: error == null ? null : _errorMessage(error),
              torchOn: switch (state.torchState) {
                TorchState.on => true,
                TorchState.off => false,
                _ => null,
              },
              onBack: () => Navigator.of(context).pop(),
              onTorch: _scannerController.toggleTorch,
              onGallery: _scanFromImage,
            );
          },
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            scanWindow: scanWindow,
            onDetect: _handleBarcode,
            errorBuilder: _buildScannerError,
          ),
          CustomPaint(
            painter: ScannerOverlay(scanWindow: scanWindow),
          ),
          AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 24,
                  color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                color: Colors.white,
                icon: ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _scannerController,
                  builder: (context, state, child) {
                    switch (state.torchState) {
                      case TorchState.off:
                        return HugeIcon(
                            icon: HugeIcons.strokeRoundedFlashOff,
                            size: 24,
                            color: Colors.grey);
                      case TorchState.on:
                        return HugeIcon(
                            icon: HugeIcons.strokeRoundedFlash,
                            size: 24,
                            color: Colors.yellow);
                      case TorchState.unavailable:
                      default:
                        return HugeIcon(
                            icon: HugeIcons.strokeRoundedFlashOff,
                            size: 24,
                            color: Colors.grey);
                    }
                  },
                ),
                onPressed: _scannerController.toggleTorch,
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: IconButton(
                color: Colors.white,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                      Colors.black.withValues(alpha: 0.5)),
                ),
                padding: const EdgeInsets.all(16),
                iconSize: 32.0,
                onPressed: _scanFromImage,
                icon: HugeIcon(icon: HugeIcons.strokeRoundedImage01, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlay extends CustomPainter {
  const ScannerOverlay({
    required this.scanWindow,
    this.borderRadius = 12.0,
  });

  final Rect scanWindow;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.largest);

    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          scanWindow,
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
      );

    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final borderRect = RRect.fromRectAndCorners(
      scanWindow,
      topLeft: Radius.circular(borderRadius),
      topRight: Radius.circular(borderRadius),
      bottomLeft: Radius.circular(borderRadius),
      bottomRight: Radius.circular(borderRadius),
    );

    canvas.drawPath(backgroundWithCutout, backgroundPaint);
    canvas.drawRRect(borderRect, borderPaint);
  }

  @override
  bool shouldRepaint(ScannerOverlay oldDelegate) =>
      scanWindow != oldDelegate.scanWindow ||
      borderRadius != oldDelegate.borderRadius;
}
