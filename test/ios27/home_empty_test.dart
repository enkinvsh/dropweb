// Пустая главная iOS (сцена `empty`): golden против эталонов доски, рамки (G4), действия, a11y.

import 'package:dropweb/ui/ios27/home/ios27_empty_home.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_screen.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden.dart';
import 'support/home_harness.dart';
import 'support/layout.dart';
import 'support/surface.dart';

Finder _prefix(String p) => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(p),
    );

Map<String, Finder> _elements() => {
      'settings': find.byKey(Ios27HomeKeys.settings),
      'empty': find.byKey(Ios27EmptyKeys.empty),
      'empty.icon': find.byKey(Ios27EmptyKeys.icon),
      'empty.title': find.byKey(Ios27EmptyKeys.title),
      'empty.actions': find.byKey(Ios27EmptyKeys.actions),
      'empty.btn': _prefix('empty.btn#'),
    };

Future<void> _pumpEmpty(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  int provider = 0,
  double textScale = 1.0,
  Ios27Device device = kIos27BoardDevice,
  bool backdrop = true,
  VoidCallback? onSettings,
  VoidCallback? onPaste,
  VoidCallback? onScan,
}) async {
  if (backdrop) {
    await prewarmHomeBackdrop(
      tester,
      homeColors(provider, brightness),
      Ios27BackdropState.off,
    );
  }
  await pumpIos27Board(
    tester,
    ios27BoardApp(
      brightness: brightness,
      theme: homeProviderTheme(provider),
      disableAnimations: true,
      textScale: textScale,
      device: device,
      child: Ios27EmptyView(
        onSettings: onSettings ?? () {},
        onPaste: onPaste ?? () {},
        onScan: onScan ?? () {},
      ),
    ),
    device: device,
  );
  if (backdrop) {
    await settleHomeBackdrop(tester);
  }
}

void main() {
  for (final brightness in Brightness.values) {
    final mode = brightness.name;
    for (final provider in [0, 5]) {
      testWidgets('golden: empty / $mode / p$provider', (tester) async {
        try {
          await _pumpEmpty(tester, brightness: brightness, provider: provider);
          expect(tester.takeException(), isNull);
          await expectIos27Golden(tester, 'home_empty_${mode}_p$provider');
        } finally {
          await tester.pumpWidget(const SizedBox());
        }
      });
    }

    testWidgets('рамки: empty / $mode', (tester) async {
      try {
        await _pumpEmpty(tester, brightness: brightness, backdrop: false);
        expectIos27Parity(
            ios27Parity(tester, 'empty-$mode-rt-p0', _elements()));
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    });
  }

  testWidgets('кнопки и шестерёнка вызывают свои действия', (tester) async {
    var settings = 0, paste = 0, scan = 0;
    try {
      await _pumpEmpty(
        tester,
        backdrop: false,
        onSettings: () => settings++,
        onPaste: () => paste++,
        onScan: () => scan++,
      );
      await tester.tap(find.byKey(Ios27EmptyKeys.paste));
      await tester.tap(find.byKey(Ios27EmptyKeys.scan));
      await tester.tap(find.byKey(Ios27HomeKeys.settings));
      expect([settings, paste, scan], [1, 1, 1]);
      expect(find.text('Добавьте подписку'), findsOneWidget);
      expect(find.text('Вставить ссылку'), findsOneWidget);
      expect(find.text('Сканировать QR-код'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('крупный шрифт на SE: нет переполнения, блок прокручивается',
      (tester) async {
    try {
      for (final scale in [0.8, 1.4, 2.0]) {
        await _pumpEmpty(
          tester,
          textScale: scale,
          device: kIos27IphoneSmall,
          backdrop: false,
        );
        expect(tester.takeException(), isNull, reason: 'x$scale');
        final actions = tester.getRect(find.byKey(Ios27EmptyKeys.actions));
        expect(actions.bottom, lessThanOrEqualTo(667));
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
      'пустая главная: блок иконки не заходит на кнопки на всей матрице',
      (tester) async {
    try {
      for (final device in kIos27Iphones) {
        for (final scale in [0.8, 1.0, 1.4, 2.0]) {
          await _pumpEmpty(
            tester,
            textScale: scale,
            device: device,
            backdrop: false,
          );
          expect(tester.takeException(), isNull);
          final area = tester.getRect(find.byKey(Ios27EmptyKeys.empty));
          final actions = tester.getRect(find.byKey(Ios27EmptyKeys.actions));
          // Блок иконки и заголовка прокручивается внутри своей области, которая кончается
          // выше кнопок; кнопки целиком на экране.
          expect(area.bottom, lessThanOrEqualTo(actions.top),
              reason: '${device.name} x$scale');
          expect(actions.bottom, lessThanOrEqualTo(device.size.height));
        }
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });
}
