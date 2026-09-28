import 'dart:async';

import 'package:dropweb/widgets/zoom_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pageKey = Key('page');
const _cardKey = Key('card');

/// Mirrors the macOS shell (application.dart): the app lays out on a 500x800
/// canvas that a FittedBox scales into the 375x600 status-bar popover, while
/// MediaQuery keeps reporting the popover size. The zoom route has to live in
/// canvas coordinates or the page lands in the top-left 75% of the popover.
Future<void> _pumpScaledCanvas(
  WidgetTester tester, {
  required GlobalKey<NavigatorState> navigatorKey,
  required Widget home,
}) async {
  tester.view.physicalSize = const Size(375, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      builder: (_, child) => FittedBox(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 500, height: 800, child: child),
      ),
      home: home,
    ),
  );
}

void main() {
  testWidgets('page fills the whole canvas, not the MediaQuery size',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await _pumpScaledCanvas(
      tester,
      navigatorKey: navigatorKey,
      home: const Scaffold(),
    );

    unawaited(
      navigatorKey.currentState!.push(
        LiquidZoomRoute<void>(
          builder: (_) => const SizedBox.expand(key: _pageKey),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final page = tester.renderObject<RenderBox>(find.byKey(_pageKey));
    expect(page.size, const Size(500, 800));
    expect(tester.getRect(find.byKey(_pageKey)),
        Offset.zero & const Size(375, 600));
  });

  testWidgets('zoom starts exactly on the source card', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    late BuildContext cardContext;
    await _pumpScaledCanvas(
      tester,
      navigatorKey: navigatorKey,
      home: Stack(
        children: [
          Positioned(
            left: 100,
            top: 200,
            width: 200,
            height: 100,
            child: Builder(
              builder: (context) {
                cardContext = context;
                return const ColoredBox(key: _cardKey, color: Colors.green);
              },
            ),
          ),
        ],
      ),
    );

    unawaited(
      navigatorKey.currentState!.push(
        LiquidZoomRoute<void>(
          source: () => zoomSourceRectOf(cardContext),
          builder: (_) => const SizedBox.expand(key: _pageKey),
        ),
      ),
    );
    // Frame 1 is the offstage hero-measuring pass (animation reads complete);
    // frame 2 is the real start of the zoom, at animation 0, where the page's
    // corner must sit on the card's corner.
    await tester.pump();
    await tester.pump();

    expect(
      tester.getTopLeft(find.byKey(_pageKey)),
      tester.getTopLeft(find.byKey(_cardKey)),
    );
  });
}
