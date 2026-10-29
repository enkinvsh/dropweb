import 'package:dropweb/ui/m3e/color/color.dart';
import 'package:dropweb/ui/m3e/screens/m3e_scan.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/board_fixtures.dart';
import 'support/golden.dart';

/// Окно видоискателя как в `ScanPage`: сторона min(400, 0.67 ширины), центр экрана.
Rect get _window => Rect.fromCenter(
      center: const Offset(411 / 2, 914 / 2),
      width: 411 * 0.67,
      height: 411 * 0.67,
    );

/// Заглушка камеры: однотонный тёмно-серый прямоугольник.
const Widget _camera = ColoredBox(color: Color(0xFF3A3F44));

Widget _view({
  VoidCallback? onBack,
  VoidCallback? onTorch,
  VoidCallback? onGallery,
  bool? torchOn = false,
  String? error,
}) =>
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: M3eScanView(
          camera: _camera,
          window: _window,
          onBack: onBack ?? () {},
          onTorch: onTorch ?? () {},
          onGallery: onGallery ?? () {},
          torchOn: torchOn,
          error: error,
        ),
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  final h = parseDropwebTheme(kBoardProviders[0].theme);
  await pumpM3eBoard(
    tester,
    m3eBoardApp(
      seed: h.accent,
      filter: h.filter,
      brightness: brightness,
      child: child,
    ),
  );
}

void main() {
  group('golden', () {
    testWidgets('scan_light_p0', (tester) async {
      await _pump(tester, _view());
      await expectM3eGolden(tester, 'scan_light_p0');
    });
    testWidgets('scan_dark_p0', (tester) async {
      await _pump(tester, _view(torchOn: true), brightness: Brightness.dark);
      await expectM3eGolden(tester, 'scan_dark_p0');
    });
    testWidgets('scan_error_light_p0', (tester) async {
      await _pump(tester, _view(error: 'Доступ к камере запрещён'));
      await expectM3eGolden(tester, 'scan_error_light_p0');
    });
  });

  group('раскладка', () {
    testWidgets('строка 64, «Назад» 40, рамка в окне, подпись под рамкой',
        (tester) async {
      await _pump(tester, _view());
      final bar = tester.getRect(find.byKey(kM3ePageBarKey));
      expect(bar.top, 44);
      expect(bar.height, 64);
      final back = tester.getRect(find.byKey(kM3ePageBackKey));
      expect((back.left, back.top, back.width, back.height),
          (8.0, 56.0, 40.0, 40.0));
      final frame = tester.getRect(find.byKey(kM3eScanFrameKey));
      expect(frame, _window);
      final caption = tester.getRect(find.byKey(kM3eScanCaptionKey));
      expect(caption.top, closeTo(_window.bottom + 16, 0.5));
      expect(find.text('Сканировать QR-код'), findsOneWidget);
      // Кнопки 48 внизу, на расстоянии 24 друг от друга.
      final torch = tester.getRect(find.byKey(kM3eScanTorchKey));
      final gallery = tester.getRect(find.byKey(kM3eScanGalleryKey));
      expect(torch.size, const Size(48, 48));
      expect(gallery.left - torch.right, 24);
      expect(torch.center.dy, gallery.center.dy);
      expect(914 - 24 - torch.bottom, 32);
    });
  });

  group('поведение', () {
    testWidgets('«Назад», фонарик и галерея зовут колбэки', (tester) async {
      var back = 0, torch = 0, gallery = 0;
      await _pump(
        tester,
        _view(
          onBack: () => back++,
          onTorch: () => torch++,
          onGallery: () => gallery++,
        ),
      );
      await tester.tap(find.byKey(kM3ePageBackKey));
      await tester.tap(find.byKey(kM3eScanTorchKey));
      await tester.tap(find.byKey(kM3eScanGalleryKey));
      expect((back, torch, gallery), (1, 1, 1));
    });

    testWidgets('семантика кнопок', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _view());
      expect(find.bySemanticsLabel('Назад'), findsOneWidget);
      expect(find.bySemanticsLabel('Фонарик'), findsOneWidget);
      expect(find.bySemanticsLabel('Выбрать из галереи'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('нет доступа к камере: текст и «Назад», рамки и кнопок нет',
        (tester) async {
      var back = 0;
      await _pump(
        tester,
        _view(error: 'Доступ к камере запрещён', onBack: () => back++),
      );
      expect(find.byKey(kM3eScanErrorKey), findsOneWidget);
      expect(find.text('Доступ к камере запрещён'), findsOneWidget);
      expect(find.byKey(kM3eScanTorchKey), findsNothing);
      expect(find.byKey(kM3eScanGalleryKey), findsNothing);
      expect(find.byKey(kM3eScanCaptionKey), findsNothing);
      await tester.tap(find.byKey(kM3ePageBackKey));
      expect(back, 1);
    });

    testWidgets('рамка статична: после паузы кадров нет ожидающих анимаций',
        (tester) async {
      await _pump(tester, _view());
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('WORST', () {
    testWidgets('шрифт 2.0 без overflow', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(2),
            ),
            child: M3eScanView(
              camera: _camera,
              window: _window,
              onBack: () {},
              onTorch: () {},
              onGallery: () {},
              error: null,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('длинный текст ошибки без overflow', (tester) async {
      await _pump(tester, _view(error: 'Камера недоступна. ' * 30));
      expect(tester.takeException(), isNull);
    });
  });
}
