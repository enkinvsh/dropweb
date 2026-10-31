// Общая заготовка тестов экрана «Добавить подписку»: оба входа, подмена импорта и сканера, клавиатура.

import 'dart:async';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/home/ios27_empty_home.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_backdrop.dart';
import 'package:dropweb/ui/ios27/layers/ios27_sheet.dart';
import 'package:dropweb/ui/ios27/screens/add/ios27_add_sheet.dart';
import 'package:dropweb/ui/ios27/screens/add/ios27_add_step.dart';
import 'package:dropweb/ui/m3e/screens/m3e_add_subscription.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden.dart';
import 'support/home_harness.dart';
import 'support/layer_harness.dart';
import 'support/surface.dart';

/// Вход на экран: отдельный лист с пустой главной или шаг листа «Подписка».
enum AddEntry { sheet, step }

/// Что случилось с подменёнными действиями.
class AddSpy {
  final List<String> imported = [];
  int scans = 0;
}

/// Корень листа «Подписка» в тестах: сразу кладёт поверх себя шаг «Добавить подписку».
class _StepRoot extends StatefulWidget {
  const _StepRoot({required this.auto});

  final bool auto;

  @override
  State<_StepRoot> createState() => _StepRootState();
}

class _StepRootState extends State<_StepRoot> {
  @override
  void initState() {
    super.initState();
    if (widget.auto) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(pushIos27AddStep(context));
      });
    }
  }

  @override
  Widget build(BuildContext context) => Ios27SheetScaffold(
        title: AppLocalizations.of(context).m3eSubTitle,
        body: GestureDetector(
          key: const ValueKey<String>('test.stepRoot.open'),
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(pushIos27AddStep(context)),
          child: const SizedBox.expand(),
        ),
      );
}

/// Главная под листом: пустая для отдельного листа, обычная для шага.
Widget _homeBehind(AddEntry entry) => entry == AddEntry.sheet
    ? Ios27EmptyView(onSettings: () {}, onPaste: () {}, onScan: () {})
    : ios27HomeFrame(input: homeInputFor('home-off'));

Widget addApp(
  AddEntry entry, {
  AddSpy? spy,
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  bool disableAnimations = true,
  bool reduceTransparency = true,
  Ios27Device device = kIos27BoardDevice,
}) {
  final s = spy ?? AddSpy();
  return ios27BoardApp(
    brightness: brightness,
    theme: homeProviderTheme(0),
    textScale: textScale,
    disableAnimations: disableAnimations,
    reduceTransparency: reduceTransparency,
    device: device,
    overrides: [
      ...layerOverrides(),
      m3eAddImportProvider
          .overrideWithValue((url) async => s.imported.add(url)),
      m3eAddScanProvider.overrideWithValue((context) async => s.scans++),
    ],
    child: _homeBehind(entry),
  );
}

/// Выводит главную, прогревает фон и открывает форму выбранным входом.
Future<void> pumpAdd(
  WidgetTester tester,
  AddEntry entry, {
  AddSpy? spy,
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  bool disableAnimations = true,
  bool reduceTransparency = true,
  Ios27Device device = kIos27BoardDevice,
  String? initialUrl,
  bool backdrop = false,
}) async {
  if (backdrop) {
    await prewarmHomeBackdrop(
      tester,
      homeColors(0, brightness),
      Ios27BackdropState.off,
    );
  }
  await pumpIos27Board(
    tester,
    addApp(
      entry,
      spy: spy,
      brightness: brightness,
      textScale: textScale,
      disableAnimations: disableAnimations,
      reduceTransparency: reduceTransparency,
      device: device,
    ),
    device: device,
  );
  if (backdrop) await settleHomeBackdrop(tester);
  final root = tester.element(find.byType(Navigator).first);
  if (entry == AddEntry.sheet) {
    unawaited(showIos27AddSheet(root, initialUrl: initialUrl));
  } else {
    unawaited(
      showIos27Sheet<void>(
        root,
        builder: (_) => const _StepRoot(auto: true),
      ),
    );
  }
  await settleAdd(tester);
}

Future<void> settleAdd(WidgetTester tester, [int ms = 1000]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(Duration(milliseconds: ms));
}

/// Высота клавиатуры теста, dp.
const double kAddKeyboard = 336;

void showKeyboard(WidgetTester tester, Ios27Device device) {
  tester.view.viewInsets = FakeViewPadding(bottom: kAddKeyboard * device.dpr);
  addTearDown(tester.view.resetViewInsets);
}

Rect rectOf(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero) & box.size;
}

const Key addFieldInput = ValueKey<String>('sheet.fieldInput');
const Key addButton = ValueKey<String>('sheet.addBtn');
