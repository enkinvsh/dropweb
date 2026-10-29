import 'package:dropweb/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../color/color.dart';
import '../symbols.g.dart';
import '../theme/m3e_text.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import '../widgets/m3e_page.dart';
import '../widgets/m3e_round_button.dart';
import '../widgets/m3e_symbol.dart';

/// Ключи частей экрана камеры (для тестов).
const Key kM3eScanFrameKey = ValueKey<String>('m3e.scan.frame');
const Key kM3eScanCaptionKey = ValueKey<String>('m3e.scan.caption');
const Key kM3eScanTorchKey = ValueKey<String>('m3e.scan.torch');
const Key kM3eScanGalleryKey = ValueKey<String>('m3e.scan.gallery');
const Key kM3eScanErrorKey = ValueKey<String>('m3e.scan.error');

/// Обвязка экрана сканирования QR: строка 64 с «Назад», скрим вокруг видоискателя,
/// рамка со скруглением 28 цвета primary, подпись под рамкой и тональные кнопки
/// фонарика и галереи.
///
/// Камеру не знает: она приходит готовым виджетом [camera] (в тестах — заглушка), а окно
/// сканирования [window] задаёт вызывающий — тот же прямоугольник, что передан плагину как
/// `scanWindow`, иначе рамка и зона распознавания разойдутся. При [error] вместо камеры и
/// рамки показывается состояние ошибки (например, нет доступа к камере).
///
/// Рамка статична: ни анимаций, ни таймеров нет, поэтому за закрытым экраном ничего не
/// крутится и «меньше движения» учитывать нечего.
class M3eScanView extends StatelessWidget {
  const M3eScanView({
    super.key,
    required this.camera,
    required this.window,
    required this.onBack,
    required this.onTorch,
    required this.onGallery,
    this.torchOn,
    this.error,
  });

  /// Живое изображение камеры на весь экран.
  final Widget camera;

  /// Окно видоискателя в координатах экрана.
  final Rect window;

  final VoidCallback onBack;
  final VoidCallback onTorch;
  final VoidCallback onGallery;

  /// Состояние фонарика: `true` горит, `false` выключен, `null` недоступен.
  final bool? torchOn;

  /// Текст ошибки камеры; `null` — камера работает.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = M3eColors.of(context);
    final scheme = colors.scheme;
    final media = MediaQuery.of(context);
    final failed = error != null;
    // Содержимое лежит поверх изображения камеры, а не поверх поверхности темы, поэтому
    // цвет не зависит от светлой или тёмной темы: всегда светлый.
    const onCamera = Colors.white;
    final content = failed ? scheme.onSurfaceVariant : onCamera;

    final overlay = failed
        ? (colors.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        : SystemUiOverlayStyle.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Material(
        color: Colors.black,
        child: Stack(
          children: [
            // Камера остаётся в дереве и при ошибке: виджет плагина владеет запуском
            // контроллера, а состояние ошибки просто закрывает его сверху.
            Positioned.fill(child: camera),
            if (failed)
              Positioned.fill(
                child: ColoredBox(
                  color: scheme.surface,
                  child: _ErrorPane(message: error!, scheme: scheme),
                ),
              )
            else ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _FramePainter(
                      window: window,
                      scrim: scheme.scrim.withValues(alpha: 0.5),
                      // Рамка лежит на тёмном скриме при любой теме. Светлый primary
                      // (тон 80) есть только в тёмной схеме, в светлой берём
                      // primaryContainer (тон 90): тёмный primary терялся бы.
                      frame: colors.brightness == Brightness.dark
                          ? scheme.primary
                          : scheme.primaryContainer,
                    ),
                  ),
                ),
              ),
              // Невидимая метка рамки для тестов и инспекции: сама рамка нарисована.
              Positioned.fromRect(
                rect: window,
                child: const SizedBox.expand(key: kM3eScanFrameKey),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: window.bottom + 16,
                child: Text(
                  l10n.scanQrCode,
                  key: kM3eScanCaptionKey,
                  textAlign: TextAlign.center,
                  style: m3eTextStyle(M3eType.bodyLarge, color: onCamera),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 32 + media.padding.bottom,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    M3eTonalIconButton(
                      key: kM3eScanTorchKey,
                      size: 48,
                      semanticLabel: l10n.m3eScanTorch,
                      icon: Icon(
                        torchOn == true ? Icons.flash_on : Icons.flash_off,
                      ),
                      onPressed: onTorch,
                    ),
                    const SizedBox(width: 24),
                    M3eTonalIconButton(
                      key: kM3eScanGalleryKey,
                      size: 48,
                      semanticLabel: l10n.m3eScanGallery,
                      icon: const Icon(Icons.image_outlined),
                      onPressed: onGallery,
                    ),
                  ],
                ),
              ),
            ],
            // Верхняя строка поверх всего: «Назад» нужен и при ошибке камеры.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Padding(
                padding: EdgeInsets.only(top: media.padding.top),
                child: SizedBox(
                  key: kM3ePageBarKey,
                  height: 64,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      _BackButton(
                        color: content,
                        label: l10n.m3eA11yBack,
                        onPressed: onBack,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Кнопка «Назад» 40 без заливки: значок поверх камеры.
class _BackButton extends StatelessWidget {
  const _BackButton({
    required this.color,
    required this.label,
    required this.onPressed,
  });

  final Color color;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: label,
        onTap: onPressed,
        excludeSemantics: true,
        child: SizedBox.square(
          key: kM3ePageBackKey,
          dimension: 40,
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              splashColor: color.withValues(alpha: M3eState.pressed),
              highlightColor: Colors.transparent,
              child: Center(
                child: M3eSymbolIcon(M3eSymbol.arrowBack, color: color),
              ),
            ),
          ),
        ),
      );
}

/// Скрим вокруг окна и рамка primary 4 dp со скруглением 28 (`M3eShape.extraLarge`).
class _FramePainter extends CustomPainter {
  const _FramePainter({
    required this.window,
    required this.scrim,
    required this.frame,
  });

  final Rect window;
  final Color scrim;
  final Color frame;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      window,
      const Radius.circular(M3eShape.extraLarge),
    );
    final shade = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(rrect),
    );
    canvas
      ..drawPath(shade, Paint()..color = scrim)
      ..drawRRect(
        rrect,
        Paint()
          ..color = frame
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      window != old.window || scrim != old.scrim || frame != old.frame;
}

/// Состояние «камера недоступна»: значок, текст ошибки. Выход — «Назад» в верхней строке.
class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.scheme});

  final String message;
  final M3eScheme scheme;

  @override
  Widget build(BuildContext context) => Center(
        key: kM3eScanErrorKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              M3eSymbolIcon(
                M3eSymbol.photoCamera,
                size: 48,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: m3eTextStyle(
                  M3eType.bodyLarge,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
}
