import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Ширина, которую LiquidMoreMenu отдаёт GlassMenu при данных подписях.
Future<double> _menuWidth(
  WidgetTester tester,
  List<String> titles, {
  double scale = 1,
  double screenWidth = 411,
}) async {
  tester.view.physicalSize = Size(screenWidth, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => LiquidMoreMenu(
            items: [
              for (final title in titles)
                liquidMenuItem(
                  context,
                  title: title,
                  icon: HugeIcons.strokeRoundedDelete02,
                  onTap: () {},
                ),
            ],
          ),
        ),
      ),
    ),
  );
  return tester.widget<GlassMenu>(find.byType(GlassMenu)).menuWidth;
}

/// Шит с одной строкой ввода, как вход по почте.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showLiquidSheet<void>(
                context,
                builder: (_) => const LiquidSheetBody(
                  children: [TextField()],
                ),
                // Нарочно мимо: шит должен подстроиться под контент сам.
                halfSize: 400,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sheet fits its content height', (tester) async {
    await _openSheet(tester);

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final field = tester.getRect(find.byType(TextField));
    // Сверху поле отделяет только отступ под ручкой, а не пустые 400 px.
    expect(screen.height - field.top, lessThan(200));
  });

  testWidgets('sheet rises above the keyboard', (tester) async {
    await _openSheet(tester);

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    // GlassModalSheet сам клавиатуру не обходит: без подъёма поле ввода
    // оказалось бы под ней.
    const keyboard = 300.0;
    tester.view.viewInsets = FakeViewPadding(
      bottom: keyboard * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final field = tester.getRect(find.byType(TextField));
    expect(field.bottom, lessThanOrEqualTo(screen.height - keyboard));
    expect(field.top, greaterThan(0));
  });

  testWidgets('«⋯» menu keeps 240 for short labels', (tester) async {
    // Подписи меню «Подписки»: его вид не должен меняться.
    expect(await _menuWidth(tester, ['Обновить', 'Поддержка', 'Удалить']), 240);
  });

  testWidgets('«⋯» menu grows for a long label, but stays on screen',
      (tester) async {
    final width = await _menuWidth(
      tester,
      ['Выйти', 'Удалить аккаунт'],
      scale: 1.4,
      screenWidth: 320,
    );
    expect(width, greaterThan(240));
    expect(width, lessThanOrEqualTo(320 - 32));
  });

  // Пакет резервирует высоту под maxLines строк у каждого пункта, даже если
  // текст влез в одну: на Pixel меню «⋯» получило пустую полосу снизу.
  testWidgets('«⋯» menu: a label that fits stays one line', (tester) async {
    await _menuWidth(tester, ['Выйти', 'Удалить']);
    final items = tester.widget<GlassMenu>(find.byType(GlassMenu)).items;
    expect(items.whereType<GlassMenuItem>().map((i) => i.maxLines), [1, 1]);
  });

  testWidgets('«⋯» menu: only a label wider than the screen gets two lines',
      (tester) async {
    await _menuWidth(
      tester,
      ['Выйти', 'Удалить с устройства'],
      scale: 1.4,
      screenWidth: 320,
    );
    final items = tester.widget<GlassMenu>(find.byType(GlassMenu)).items;
    expect(items.whereType<GlassMenuItem>().map((i) => i.maxLines), [1, 2]);
  });
}
