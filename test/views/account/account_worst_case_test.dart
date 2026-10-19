// Break-ui харнесс экранов аккаунта: каждый сценарий прогоняется на
// демо-данных и на худшем правдоподобном наборе по матрице ширина × масштаб
// шрифта × язык. PNG (контактные листы «Демо | Худший») пишутся только при
// заданной BREAK_UI_OUT; без неё тест лишь проверяет, что демо-набор
// рисуется без исключений и переполнений, а находки худшего набора пишет в
// лог, не роняя прогон.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dropweb/common/app_localizations.dart';
import 'package:dropweb/common/color.dart';
import 'package:dropweb/common/constant.dart';
import 'package:dropweb/common/lumina.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/manager/message_manager.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/account/account_common.dart';
import 'package:dropweb/views/account/account_login_sheet.dart';
import 'package:dropweb/views/account/account_sheet.dart';
import 'package:dropweb/widgets/glass_morph_route.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../support/fake_path_provider.dart';

/// Каталог для PNG; null — рендер выключен, остаются только проверки.
final String? _outDir = Platform.environment['BREAK_UI_OUT'];

/// Pixel 10: 411.43 × 923.43 dp при плотности 2.625.
const _dpr = 2.625;
const _screenHeight = 923.43;
const _wide = 411.43;
const _narrow = 320.0;

/// Системный масштаб 200 % приложение режет до 1.4 (ThemeManager +
/// maxTextScale), поэтому «крупный шрифт» в матрице — это 1.4.
const _bigScale = maxTextScale;

/// Высота клавиатуры в dp для сценариев с открытой клавиатурой.
const _keyboard = 300.0;

class _Variant {
  const _Variant(this.locale, this.width, this.scale, {this.cjk = false});

  final String locale;
  final double width;
  final double scale;

  /// В Onest нет иероглифов: для CJK проверяем только исключения вёрстки.
  final bool cjk;

  /// Рисуем только «углы» матрицы, остальные варианты — только детекторы.
  bool get rendered =>
      !cjk && ((width > 400 && scale == 1.0) || (width < 400 && scale > 1.0));

  Locale get flutterLocale {
    final parts = locale.split('_');
    return parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  }

  String get label =>
      '$locale ${width.toStringAsFixed(0)}dp ×${scale.toStringAsFixed(1)}';
}

/// Сначала рисуемые углы (порядок колонок листа), затем остальная матрица.
const _matrix = [
  _Variant('ru', _wide, 1.0),
  _Variant('ru', _narrow, _bigScale),
  _Variant('en', _wide, 1.0),
  _Variant('en', _narrow, _bigScale),
  _Variant('ru', _narrow, 1.0),
  _Variant('ru', _wide, _bigScale),
  _Variant('en', _narrow, 1.0),
  _Variant('en', _wide, _bigScale),
  _Variant('ja', 360, 1.0, cjk: true),
  _Variant('zh_CN', 360, 1.0, cjk: true),
];

_Variant _variant = _matrix.first;

/// CommonDialog берёт ширину из провайдера размера окна — в приложении его
/// заполняет ThemeManager, здесь отдаём текущий экран варианта.
class _TestViewSize extends ViewSize {
  @override
  Size build() => Size(_variant.width, _screenHeight);
}

// ---------------------------------------------------------------- данные

const _demoEmail = 'anna.petrova@gmail.com';

/// Реалистичный длинный корпоративный адрес.
const _longEmail =
    'aleksandra.wisniewska-kowalczyk.marketing@northwind-industries-holdings.example.com';

/// Почти предел RFC 5321: локальная часть ≤ 64, адрес целиком ≤ 254.
const _rfcEmail =
    'aleksandra.wisniewska-kowalczyk.subscriptions.renewals.vpn-2026@'
    'secure-mail-delivery-gateway-cluster-07.internal-routing.'
    'customer-accounts.northwind-industries-holdings-international.'
    'emea-subsidiary-operations.regional-office.warszawa.example.com';

const _plusEmail = 'first.last+billing-notifications@example.com';
const _idnEmail = 'пользователь@пример.рф';

/// Длинное сообщение сервера: экран показывает только текст по kind.
const _serverMessage =
    'Upstream SMTP relay rejected the message: 550 5.7.1 Recipient address '
    'rejected by policy for domain northwind-industries-holdings.example.com';

const _demoProfile = Profile(
  id: 'demo-profile',
  autoUpdateDuration: Duration(hours: 12),
  providerHeaders: {
    'dropweb-cabinet': 'https://cabinet.example.com',
    'support-url': 'https://t.me/example_support',
  },
);

// ---------------------------------------------------------------- фейк

/// Подмена контроллера: все ответы приходят сразу или по Completer теста.
class _FakeAccount extends Account {
  _FakeAccount(this.initial);

  final AccountState initial;

  /// Ответы requestCode по порядку: CodeRequestResult или исключение.
  final List<Object> requestOutcomes = [];
  Completer<void>? requestGate;
  AccountApiException? verifyError;

  @override
  AccountState build() => initial;

  @override
  Future<bool> unlock(String reason) async => false;

  @override
  Future<bool> enableBiometric(String reason) async {
    state = state.copyWith(biometricEnabled: true);
    return true;
  }

  @override
  Future<void> disableBiometric() async {
    state = state.copyWith(biometricEnabled: false);
  }

  @override
  Future<SubscriptionSyncResult> syncSubscription() async =>
      SubscriptionSyncResult.alreadyPresent;

  @override
  Future<void> logout() async {
    state = const AccountState(status: AccountStatus.loggedOut);
  }

  @override
  Future<CodeRequestResult> requestCode(String email) async {
    final gate = requestGate;
    if (gate != null) {
      await gate.future;
    }
    final outcome = requestOutcomes.isEmpty
        ? const CodeRequestResult(resendAfter: 60, expiresIn: 600)
        : requestOutcomes.removeAt(0);
    if (outcome is AccountApiException) {
      throw outcome;
    }
    return outcome as CodeRequestResult;
  }

  @override
  Future<SubscriptionSyncResult> verifyCode(String email, String code) async {
    final error = verifyError;
    if (error != null) {
      throw error;
    }
    state = AccountState(
      status: AccountStatus.ready,
      email: email,
      biometricAvailable: true,
    );
    return SubscriptionSyncResult.imported;
  }

  @override
  Future<void> removeFromDevice() async {
    state = const AccountState(status: AccountStatus.loggedOut);
  }
}

// ---------------------------------------------------------------- харнесс

final _boundaryKey = GlobalKey();
final _rowsKey = GlobalKey();
late BuildContext _homeContext;
late ThemeData _theme;

/// Тёмная тема Lumina так же, как её собирает приложение
/// (application.dart `_buildThemeData` + genColorScheme по умолчанию).
ThemeData _luminaTheme() {
  const variant = DynamicSchemeVariant.fidelity;
  const seed = Color(defaultPrimaryColor);
  final filtered = applyColorFilter(seed, variant);
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
    dynamicSchemeVariant: variant,
  ).copyWith(
    primary: filtered,
    onPrimary: ThemeData.estimateBrightnessForColor(filtered) == Brightness.dark
        ? Colors.white
        : Colors.black,
    surface: Lumina.void_,
    surfaceContainerLowest: Lumina.surface1,
    surfaceContainerLow: Lumina.surface2,
    surfaceContainer: Lumina.surface3,
    surfaceContainerHigh: Lumina.surface4,
    surfaceContainerHighest: Lumina.surface5,
  );
  const onest = TextStyle(fontFamily: 'Onest');
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: const TextTheme(
      displayLarge: onest,
      displayMedium: onest,
      displaySmall: onest,
      headlineLarge: onest,
      headlineMedium: onest,
      headlineSmall: onest,
      titleLarge: onest,
      titleMedium: onest,
      titleSmall: onest,
      bodyLarge: onest,
      bodyMedium: onest,
      bodySmall: onest,
      labelLarge: onest,
      labelMedium: onest,
      labelSmall: onest,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: Lumina.glassOpacity),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Lumina.radiusLg),
        side: BorderSide(
          color: Colors.white.withValues(alpha: Lumina.glassBorderOpacity),
        ),
      ),
    ),
  );
}

/// Настоящий Onest вместо тестового шрифта-квадратиков. Под «Roboto» тоже
/// Onest: так текст без явного семейства не превращается в квадраты.
Future<void> _loadFonts() async {
  final files = Directory('assets/fonts')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.contains('Onest-'))
      .toList();
  for (final family in ['Onest', 'Roboto']) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
    await loader.load();
  }
}

Future<void> _applyVariant(WidgetTester tester, _Variant variant) async {
  _variant = variant;
  tester.view
    ..devicePixelRatio = _dpr
    ..physicalSize = Size(variant.width * _dpr, _screenHeight * _dpr)
    ..padding = const FakeViewPadding(top: 32 * _dpr, bottom: 24 * _dpr)
    ..viewPadding = const FakeViewPadding(top: 32 * _dpr, bottom: 24 * _dpr)
    ..viewInsets = FakeViewPadding.zero;
  await tester.runAsync(() => AppLocalizations.load(variant.flutterLocale));
}

/// Клавиатура открыта: снизу inset, нижний отступ системы съеден.
void _openKeyboard(WidgetTester tester) {
  tester.view
    ..viewInsets = const FakeViewPadding(bottom: _keyboard * _dpr)
    ..padding = const FakeViewPadding(top: 32 * _dpr);
}

Future<void> _pumpApp(
  WidgetTester tester,
  _FakeAccount account, {
  Profile? profile = _demoProfile,
  Profile? accountProfile = _demoProfile,
  bool loginAvailable = true,
  Widget? home,
}) async {
  // Пустое дерево между вариантами: иначе тот же navigatorKey переиспользует
  // старый Navigator вместе с открытыми шитами.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: ProviderScope(
        overrides: [
          accountProvider.overrideWith(() => account),
          viewSizeProvider.overrideWith(_TestViewSize.new),
          currentProfileProvider.overrideWith((ref) => profile),
          accountProfileProvider.overrideWith((ref) => accountProfile),
          accountLoginAvailableProvider.overrideWith((ref) => loginAvailable),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: globalState.navigatorKey,
          theme: _theme,
          darkTheme: _theme,
          themeMode: ThemeMode.dark,
          locale: _variant.flutterLocale,
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          // Масштаб шрифта ставит ThemeManager приложения — повторяем.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(_variant.scale),
            ),
            child: MessageManager(child: child!),
          ),
          home: Builder(
            builder: (context) {
              _homeContext = context;
              return home ?? const Scaffold();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Кадры вместо pumpAndSettle: спиннеры и обратный отсчёт не дают покоя.
Future<void> _frames(WidgetTester tester, [int count = 5]) async {
  await tester.pump();
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

int _sheetCount() =>
    find.byType(GlassMorphScope, skipOffstage: false).evaluate().length;

int _dialogCount() =>
    find.byType(AlertDialog, skipOffstage: false).evaluate().length;

/// Тексты, упёршиеся в maxLines (многоточие или обрезка).
/// Латинские и кириллические слова, разорванные между строками посередине.
/// CJK не проверяем: там перенос между любыми знаками — норма.
List<String> _brokenWords(WidgetTester tester) {
  final word = RegExp(r'[\p{Script=Latin}\p{Script=Cyrillic}]+', unicode: true);
  final broken = <String>[];
  for (final paragraph
      in tester.allRenderObjects.whereType<RenderParagraph>()) {
    final text = paragraph.text.toPlainText();
    for (final match in word.allMatches(text)) {
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: match.start, extentOffset: match.end),
      );
      final lines = boxes.map((box) => box.top.round()).toSet();
      if (lines.length > 1) broken.add(match.group(0)!);
    }
  }
  return broken;
}

List<String> _truncatedTexts(WidgetTester tester) => [
      for (final paragraph
          in tester.allRenderObjects.whereType<RenderParagraph>())
        if (paragraph.didExceedMaxLines) paragraph.text.toPlainText(),
    ];

final _sourcePattern = RegExp(r'(lib/[\w/]+\.dart:\d+)');

String _describe(FlutterErrorDetails details) {
  var text = details.exceptionAsString().split('\n').first;
  if (text.length > 140) {
    text = '${text.substring(0, 140)}…';
  }
  final info = details.informationCollector
          ?.call()
          .map((node) => node.toString())
          .join('\n') ??
      '';
  final source = _sourcePattern.firstMatch(info)?.group(1);
  return source == null ? text : '$text @ $source';
}

/// SVG-иконки HugeIcon грузятся вне фейкового времени.
Future<void> _settleAsyncPictures(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
}

Future<ui.Image?> _capture(WidgetTester tester, {GlobalKey? key}) async {
  if (_outDir == null) {
    return null;
  }
  await _settleAsyncPictures(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(key ?? _boundaryKey),
  );
  return tester.runAsync(boundary.toImage);
}

class _Shot {
  _Shot(this.label, this.image, {this.crop = true});

  final String label;
  final ui.Image image;

  /// Срезать пустой верх (фон под барьером) — для полноэкранных снимков.
  final bool crop;
}

/// Первая строка пикселей, отличная от однотонного фона.
Future<int> _contentTop(ui.Image image) async {
  final data = await image.toByteData();
  if (data == null) {
    return 0;
  }
  final bytes = data.buffer.asUint8List();
  final width = image.width;
  for (var y = 0; y < image.height; y++) {
    final row = y * width * 4;
    for (var x = 1; x < width; x++) {
      final i = row + x * 4;
      if ((bytes[i] - bytes[row]).abs() > 6 ||
          (bytes[i + 1] - bytes[row + 1]).abs() > 6 ||
          (bytes[i + 2] - bytes[row + 2]).abs() > 6) {
        return y;
      }
    }
  }
  return image.height;
}

void _paintLabel(Canvas canvas, String text, Offset offset, double size) {
  TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Onest',
        fontSize: size,
        color: const Color(0xFFE6E6EA),
      ),
    ),
    textDirection: TextDirection.ltr,
  )
    ..layout()
    ..paint(canvas, offset);
}

/// Контактный лист: строки снимков с подписями, общий срез пустого верха.
Future<void> _writeSheet(
  WidgetTester tester,
  String name,
  String title,
  List<List<_Shot>> rows,
) async {
  final dir = _outDir;
  if (dir == null || rows.every((row) => row.isEmpty)) {
    return;
  }
  await tester.runAsync(() async {
    final shots = rows.expand((row) => row).toList();
    var top = 1 << 30;
    for (final shot in shots.where((shot) => shot.crop)) {
      top = math.min(top, await _contentTop(shot.image));
    }
    final crop = top == 1 << 30 ? 0 : math.max(0, top - 24);
    int cropOf(_Shot shot) => shot.crop ? crop : 0;

    const gap = 12.0;
    const labelHeight = 26.0;
    const header = 40.0;
    final cellWidth = shots.map((shot) => shot.image.width).reduce(math.max);
    final columns = rows.map((row) => row.length).reduce(math.max);
    final rowHeights = [
      for (final row in rows)
        row.isEmpty
            ? 0.0
            : row
                    .map((shot) => shot.image.height - cropOf(shot))
                    .reduce(math.max) +
                labelHeight,
    ];
    final width = gap + columns * (cellWidth + gap);
    final height =
        header + rowHeights.fold<double>(0, (sum, h) => sum + h + gap) + gap;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = const Color(0xFF3A3A40),
      );
    _paintLabel(canvas, title, const Offset(gap, 10), 18);
    var y = header;
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        final shot = rows[r][c];
        final x = gap + c * (cellWidth + gap);
        final cut = cropOf(shot);
        final w = shot.image.width.toDouble();
        final h = (shot.image.height - cut).toDouble();
        _paintLabel(canvas, shot.label, Offset(x, y + 4), 14);
        final dst = Rect.fromLTWH(x, y + labelHeight, w, h);
        canvas
          ..drawImageRect(
            shot.image,
            Rect.fromLTWH(0, cut.toDouble(), w, h),
            dst,
            Paint(),
          )
          ..drawRect(
            dst,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = const Color(0x66FFFFFF),
          );
      }
      y += rowHeights[r] + gap;
    }
    final image =
        await recorder.endRecording().toImage(width.ceil(), height.ceil());
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void _log(String line) {
  final dir = _outDir;
  if (dir != null) {
    File('$dir/log.txt').writeAsStringSync('$line\n', mode: FileMode.append);
  }
  // ignore: avoid_print
  print(line);
}

// ---------------------------------------------------------------- прогон

class _Run {
  _Run(this.variant, {required this.worst});

  final _Variant variant;
  final bool worst;
  final errors = <String>[];
  final truncated = <String>[];
  int sheets = 0;
  int dialogs = 0;
  ui.Image? image;

  String get dataset => worst ? 'worst' : 'demo';
}

class _Scenario {
  const _Scenario(this.id, this.title, this.drive);

  final String id;
  final String title;
  final Future<void> Function(WidgetTester tester, {required bool worst}) drive;
}

Future<_Run> _execute(
  WidgetTester tester,
  _Scenario scenario,
  _Variant variant, {
  required bool worst,
}) async {
  final run = _Run(variant, worst: worst);
  final saved = FlutterError.onError;
  var phase = 'render';
  FlutterError.onError = (details) {
    run.errors.add('[$phase] ${_describe(details)}');
  };
  try {
    await _applyVariant(tester, variant);
    try {
      await scenario.drive(tester, worst: worst);
    } on Object catch (error) {
      run.errors.add('[scenario] ${error.toString().split('\n').first}');
    }
    run
      ..truncated.addAll(_truncatedTexts(tester))
      ..sheets = _sheetCount()
      ..dialogs = _dialogCount();
    if (variant.rendered) {
      run.image = await _capture(tester);
    }
    // Тосты MessageManager живут на таймерах 1 + 3 с — дожигаем при живом
    // дереве, иначе останутся висящие таймеры.
    phase = 'flush';
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  } finally {
    FlutterError.onError = saved;
    tester.view
      ..resetViewInsets()
      ..resetPadding();
  }
  _log(
    '${scenario.id} | ${run.dataset} | ${variant.label} | '
    'sheets=${run.sheets} dialogs=${run.dialogs} | '
    'errors=${run.errors.isEmpty ? '-' : run.errors.join(' ;; ')} | '
    'truncated=${run.truncated.isEmpty ? '-' : run.truncated.join(' ;; ')}',
  );
  return run;
}

void _scenarioTest(_Scenario scenario) {
  testWidgets(scenario.id, (tester) async {
    addTearDown(tester.view.reset);
    final runs = <_Run>[];
    for (final variant in _matrix) {
      for (final worst in [false, true]) {
        runs.add(await _execute(tester, scenario, variant, worst: worst));
      }
    }
    final rendered = runs.where((run) => run.image != null).toList();
    await _writeSheet(tester, scenario.id, scenario.title, [
      for (final worst in [false, true])
        [
          for (final run in rendered.where((run) => run.worst == worst))
            _Shot('${run.dataset} · ${run.variant.label}', run.image!),
        ],
    ]);
    // Демо-набор обязан рисоваться чисто; худший — только в отчёт.
    final demoErrors = [
      for (final run in runs.where((run) => !run.worst))
        for (final error in run.errors) '${run.variant.label}: $error',
    ];
    expect(demoErrors, isEmpty);
  });
}

// ---------------------------------------------------------------- сценарии

Future<_FakeAccount> _accountSheet(
  WidgetTester tester,
  AccountState state, {
  Profile? profile = _demoProfile,
  bool loginAvailable = true,
  void Function(_FakeAccount account)? setup,
}) async {
  final account = _FakeAccount(state);
  setup?.call(account);
  await _pumpApp(
    tester,
    account,
    profile: profile,
    loginAvailable: loginAvailable,
  );
  unawaited(openAccountSheet(_homeContext));
  await _frames(tester);
  return account;
}

AccountState _ready(String? email, {bool biometricEnabled = false}) =>
    AccountState(
      status: AccountStatus.ready,
      email: email,
      biometricAvailable: true,
      biometricEnabled: biometricEnabled,
    );

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(LiquidMoreMenu));
  await _frames(tester, 3);
}

Future<void> _openRemoveDialog(WidgetTester tester) async {
  await _openMenu(tester);
  await tester.tap(find.text(appLocalizations.accountRemoveFromDevice).last);
  await _frames(tester, 3);
}

Future<_FakeAccount> _loginSheet(
  WidgetTester tester, {
  String? initialEmail,
  bool keyboard = false,
  void Function(_FakeAccount account)? setup,
}) async {
  final account = _FakeAccount(
    const AccountState(status: AccountStatus.loggedOut),
  );
  setup?.call(account);
  await _pumpApp(tester, account);
  if (keyboard) {
    _openKeyboard(tester);
  }
  unawaited(openAccountLoginSheet(_homeContext, email: initialEmail));
  await _frames(tester);
  return account;
}

Future<void> _submitEmail(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextField).first, email);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.go);
  await _frames(tester);
}

Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField).last, code);
  await _frames(tester);
}

AccountApiException _rateLimited(int seconds) => AccountApiException(
      AccountApiErrorKind.rateLimited,
      statusCode: 429,
      retryAfter: seconds,
    );

final _scenarios = <_Scenario>[
  _Scenario(
    'sheet-unknown',
    'AccountView · unknown (восстановление сессии)',
    (tester, {required worst}) async {
      await _accountSheet(
        tester,
        const AccountState(),
        loginAvailable: !worst,
      );
    },
  ),
  _Scenario(
    'sheet-loggedout',
    'AccountView · loggedOut (демо: вход доступен, худший: вход недоступен)',
    (tester, {required worst}) async {
      await _accountSheet(
        tester,
        const AccountState(status: AccountStatus.loggedOut),
        loginAvailable: !worst,
      );
    },
  ),
  _Scenario(
    'sheet-locked',
    'AccountView · locked (худший: email отсутствует)',
    (tester, {required worst}) async {
      await _accountSheet(
        tester,
        AccountState(
          status: AccountStatus.locked,
          email: worst ? null : _demoEmail,
          biometricAvailable: true,
          biometricEnabled: true,
        ),
      );
    },
  ),
  _Scenario(
    'sheet-ready',
    'AccountView · ready (худший: длинный корпоративный email)',
    (tester, {required worst}) async {
      await _accountSheet(
        tester,
        _ready(worst ? _longEmail : _demoEmail, biometricEnabled: true),
      );
    },
  ),
  _Scenario(
    'sheet-menu',
    'AccountView · ready + меню «⋯» (худший: email у предела RFC, 254)',
    (tester, {required worst}) async {
      await _accountSheet(tester, _ready(worst ? _rfcEmail : _demoEmail));
      await _openMenu(tester);
    },
  ),
  _Scenario(
    'sheet-remove-dialog',
    'AccountView · подтверждение удаления с устройства (худший: IDN email)',
    (tester, {required worst}) async {
      await _accountSheet(tester, _ready(worst ? _idnEmail : _demoEmail));
      await _openRemoveDialog(tester);
    },
  ),
  _Scenario(
    'login-s1-empty',
    'AccountLoginView · шаг 1 (худший: предзаполнен email у предела RFC)',
    (tester, {required worst}) async {
      await _loginSheet(tester, initialEmail: worst ? _rfcEmail : null);
    },
  ),
  _Scenario(
    'login-s1-keyboard',
    'AccountLoginView · шаг 1 + клавиатура 300dp (худший: 429 на 86400 с)',
    (tester, {required worst}) async {
      await _loginSheet(
        tester,
        keyboard: true,
        setup: (account) {
          if (worst) {
            account.requestOutcomes.add(_rateLimited(86400));
          }
        },
      );
      if (worst) {
        await _submitEmail(tester, _plusEmail);
      }
    },
  ),
  _Scenario(
    'login-s1-invalid',
    'AccountLoginView · неверный email (худший: длинный адрес без TLD)',
    (tester, {required worst}) async {
      await _loginSheet(tester);
      await _submitEmail(
        tester,
        worst
            ? 'aleksandra.wisniewska-kowalczyk.marketing@northwind-industries-holdings'
            : 'anna.petrova@gmail',
      );
    },
  ),
  _Scenario(
    'login-s1-sending',
    'AccountLoginView · отправка (спиннер) (худший: IDN email)',
    (tester, {required worst}) async {
      final gate = Completer<void>();
      await _loginSheet(
        tester,
        setup: (account) => account.requestGate = gate,
      );
      await _submitEmail(tester, worst ? _idnEmail : _demoEmail);
      addTearDown(gate.complete);
    },
  ),
  _Scenario(
    'login-s1-network',
    'AccountLoginView · сетевая ошибка (худший: 500 с длинным message)',
    (tester, {required worst}) async {
      await _loginSheet(
        tester,
        setup: (account) => account.requestOutcomes.add(
          worst
              ? const AccountApiException(
                  AccountApiErrorKind.server,
                  statusCode: 500,
                  message: _serverMessage,
                )
              : const AccountApiException(AccountApiErrorKind.network),
        ),
      );
      await _submitEmail(tester, worst ? _longEmail : _demoEmail);
    },
  ),
  _Scenario(
    'login-s1-ratelimited',
    'AccountLoginView · 429 (демо: 30 с, худший: 3600 с)',
    (tester, {required worst}) async {
      await _loginSheet(
        tester,
        setup: (account) =>
            account.requestOutcomes.add(_rateLimited(worst ? 3600 : 30)),
      );
      await _submitEmail(tester, _demoEmail);
    },
  ),
  _Scenario(
    'login-s2-countdown',
    'AccountLoginView · шаг 2, отсчёт (худший: resendAfter 86400 + длинный email)',
    (tester, {required worst}) async {
      await _loginSheet(
        tester,
        setup: (account) => account.requestOutcomes.add(
          CodeRequestResult(resendAfter: worst ? 86400 : 60, expiresIn: 600),
        ),
      );
      await _submitEmail(tester, worst ? _longEmail : _demoEmail);
    },
  ),
  _Scenario(
    'login-s2-keyboard',
    'AccountLoginView · шаг 2 + клавиатура (худший: email у предела RFC + неверный код)',
    (tester, {required worst}) async {
      await _loginSheet(
        tester,
        keyboard: true,
        setup: (account) {
          if (worst) {
            account.verifyError = const AccountApiException(
              AccountApiErrorKind.invalidCode,
              statusCode: 400,
            );
          }
        },
      );
      await _submitEmail(tester, worst ? _rfcEmail : _demoEmail);
      if (worst) {
        await _enterCode(tester, '123456');
      }
    },
  ),
  _Scenario(
    'login-s2-resend',
    'AccountLoginView · шаг 2, можно отправить снова (худший: email у предела RFC)',
    (tester, {required worst}) async {
      await _loginSheet(
        tester,
        setup: (account) => account.requestOutcomes.add(
          const CodeRequestResult(resendAfter: 0, expiresIn: 600),
        ),
      );
      await _submitEmail(tester, worst ? _rfcEmail : _demoEmail);
    },
  ),
  _Scenario(
    'login-s2-invalid',
    'AccountLoginView · неверный код (худший: 429 без retryAfter при доступной переотправке)',
    (tester, {required worst}) async {
      await _loginSheet(
        tester,
        setup: (account) {
          account
            ..requestOutcomes.add(
              const CodeRequestResult(resendAfter: 0, expiresIn: 600),
            )
            ..verifyError = worst
                ? _rateLimited(0)
                : const AccountApiException(
                    AccountApiErrorKind.invalidCode,
                    statusCode: 400,
                  );
        },
      );
      await _submitEmail(tester, _demoEmail);
      await _enterCode(tester, '123456');
    },
  ),
  _Scenario(
    'login-s2-expired',
    'AccountLoginView · код истёк (худший: переотправка заблокирована на 3600 с)',
    (tester, {required worst}) async {
      await _loginSheet(
        tester,
        setup: (account) {
          account
            ..requestOutcomes.add(
              CodeRequestResult(resendAfter: worst ? 3600 : 0, expiresIn: 600),
            )
            ..verifyError = const AccountApiException(
              AccountApiErrorKind.codeExpiredOrLocked,
              statusCode: 410,
            );
        },
      );
      await _submitEmail(tester, _demoEmail);
      await _enterCode(tester, '123456');
    },
  ),
  _Scenario(
    'login-s2-resend-blocked',
    'AccountLoginView · 429 на переотправке, через 3 с (демо: 30 с, худший: 86400 с)',
    (tester, {required worst}) async {
      await _loginSheet(
        tester,
        setup: (account) => account.requestOutcomes
          ..add(const CodeRequestResult(resendAfter: 0, expiresIn: 600))
          ..add(_rateLimited(worst ? 86400 : 30)),
      );
      await _submitEmail(tester, worst ? _longEmail : _demoEmail);
      await tester.tap(find.text(appLocalizations.accountResend));
      await _frames(tester);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    },
  ),
  _Scenario(
    'sheet-ready-noemail',
    'AccountView · ready (худший: email отсутствует)',
    (tester, {required worst}) async {
      await _accountSheet(tester, _ready(worst ? null : _demoEmail));
    },
  ),
];

// ---------------------------------------------------------------- регрессии

/// Самый тесный реальный случай: 320 dp и потолок масштаба 1.4.
const _tight = [
  _Variant('ru', _narrow, _bigScale),
  _Variant('en', _narrow, _bigScale),
];

/// Прогоняет [drive] в тесных вариантах и отдаёт ошибки вёрстки и обрезанные
/// тексты по каждому варианту.
Future<void> _tightCheck(
  WidgetTester tester,
  Future<void> Function() drive,
  void Function(List<String> errors, List<String> truncated) check,
) async {
  for (final variant in _tight) {
    await _applyVariant(tester, variant);
    final errors = <String>[];
    final saved = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(_describe(details));
    try {
      await drive();
      check(errors, _truncatedTexts(tester));
      await _flush(tester);
    } finally {
      FlutterError.onError = saved;
    }
  }
}

// ---------------------------------------------------------------- стек шитов

/// Снимает число стеклянных шитов и диалогов на кадрах перехода.
Future<List<_Shot>> _traceTransition(
  WidgetTester tester,
  String id,
  Future<void> Function() trigger,
) async {
  final shots = <_Shot>[];
  final counts = <String>[];
  await trigger();
  var elapsed = 0;
  for (final step in [0, 100, 150, 250, 500, 1000]) {
    await tester.pump(Duration(milliseconds: step));
    elapsed += step;
    counts
        .add('${elapsed}ms: шитов=${_sheetCount()} диалогов=${_dialogCount()}');
    if (elapsed == 250 || elapsed == 2000) {
      final image = await _capture(tester);
      if (image != null) {
        shots.add(
          _Shot(
            '$id · ${elapsed}ms · шитов ${_sheetCount()} · диалогов ${_dialogCount()}',
            image,
          ),
        );
      }
    }
  }
  _log('stacking | $id | ${counts.join(' | ')}');
  return shots;
}

Future<void> _flush(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

// ---------------------------------------------------------------- main

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Тост MessageManager пишет в FileLogger, а тот спрашивает path_provider.
  useFakePathProvider();

  setUpAll(() async {
    await _loadFonts();
    _theme = _luminaTheme();
    await AppLocalizations.load(const Locale('ru'));
    final dir = _outDir;
    if (dir != null) {
      Directory(dir).createSync(recursive: true);
    }
    assert(
      _rfcEmail.length <= 254 && _rfcEmail.split('@').first.length <= 64,
      'RFC-адрес должен укладываться в 254 символа и 64 в локальной части',
    );
  });

  for (final scenario in _scenarios) {
    _scenarioTest(scenario);
  }

  group('320dp ×1.4 (Onest)', () {
    testWidgets('шаг 2: email в подвале не схлопывается рядом с отсчётом',
        (tester) async {
      addTearDown(tester.view.reset);
      await _tightCheck(
        tester,
        () async {
          await _loginSheet(
            tester,
            setup: (account) => account.requestOutcomes.add(
              const CodeRequestResult(resendAfter: 60, expiresIn: 600),
            ),
          );
          await _submitEmail(tester, _demoEmail);
        },
        (errors, truncated) {
          expect(errors, isEmpty);
          expect(find.text(accountEmailDisplay(_demoEmail)), findsOneWidget);
          expect(truncated.where((text) => text.contains('@')), isEmpty);
        },
      );
    });

    testWidgets('шаг 2: подсказка поля кода видна целиком', (tester) async {
      addTearDown(tester.view.reset);
      await _tightCheck(
        tester,
        () async {
          await _loginSheet(
            tester,
            setup: (account) => account.requestOutcomes.add(
              const CodeRequestResult(resendAfter: 60, expiresIn: 600),
            ),
          );
          await _submitEmail(tester, _demoEmail);
        },
        (errors, truncated) {
          expect(errors, isEmpty);
          // «Код из письма» / «Code from the email» не влезали в поле и резались.
          final hint = appLocalizations.accountCodeLabel;
          expect(find.text(hint), findsOneWidget);
          expect(truncated, isNot(contains(hint)));
        },
      );
    });

    testWidgets('лист аккаунта: заголовки строк и email целиком, без обрезки',
        (tester) async {
      addTearDown(tester.view.reset);
      await _tightCheck(
        tester,
        () => _accountSheet(tester, _ready(_demoEmail)),
        (errors, truncated) {
          expect(errors, isEmpty);
          expect(truncated, isEmpty);
          final scrollable = find.descendant(
            of: find.byType(GlassMorphScope),
            matching: find.byType(Scrollable),
          );
          final position = tester.state<ScrollableState>(scrollable.first);
          expect(position.position.maxScrollExtent, lessThan(1));
        },
      );
    });

    testWidgets('лист аккаунта locked: слово не рвётся посередине',
        (tester) async {
      addTearDown(tester.view.reset);
      await _tightCheck(
        tester,
        () => _accountSheet(
          tester,
          const AccountState(
            status: AccountStatus.locked,
            email: _demoEmail,
            biometricAvailable: true,
            biometricEnabled: true,
          ),
        ),
        (errors, truncated) {
          expect(errors, isEmpty);
          // «Разблокировать» на 320 dp ×1.4 шире строки: перенос по двум
          // строкам давал «Разблокироват / ь».
          expect(_brokenWords(tester), isEmpty);
        },
      );
    });

    testWidgets('меню «⋯» аккаунта: пункты не обрезаны', (tester) async {
      addTearDown(tester.view.reset);
      await _tightCheck(
        tester,
        () async {
          await _accountSheet(tester, _ready(_demoEmail));
          await _openMenu(tester);
        },
        (errors, truncated) {
          expect(errors, isEmpty);
          expect(truncated, isEmpty);
        },
      );
    });

    testWidgets('меню «⋯» подписки остаётся 240', (tester) async {
      addTearDown(tester.view.reset);
      final widths = <double>[];
      await _tightCheck(
        tester,
        () => _pumpApp(
          tester,
          _FakeAccount(const AccountState(status: AccountStatus.loggedOut)),
          home: Builder(
            builder: (context) {
              // Те же пункты, что в _ActionsMenu subscription_page.dart.
              widths.add(
                liquidMenuWidth(context, [
                  liquidMenuItem(
                    context,
                    title: appLocalizations.update,
                    subtitle: '${appLocalizations.updated} 5 минут назад',
                    icon: HugeIcons.strokeRoundedRefresh,
                    onTap: () {},
                  ),
                  liquidMenuItem(
                    context,
                    title: appLocalizations.support,
                    icon: HugeIcons.strokeRoundedTelegram,
                    onTap: () {},
                  ),
                  liquidMenuItem(
                    context,
                    title: appLocalizations.delete,
                    icon: HugeIcons.strokeRoundedDelete02,
                    isDestructive: true,
                    onTap: () {},
                  ),
                ]),
              );
              return const Scaffold();
            },
          ),
        ),
        (errors, truncated) => expect(errors, isEmpty),
      );
      expect(widths, isNotEmpty);
      expect(widths.toSet(), {kLiquidMenuWidth});
    });
  });

  testWidgets('overlay-stacking', (tester) async {
    addTearDown(tester.view.reset);
    await _applyVariant(tester, _matrix.first);
    final rows = <List<_Shot>>[];

    // а) locked → «Войти по коду».
    await _accountSheet(
      tester,
      const AccountState(
        status: AccountStatus.locked,
        email: _demoEmail,
        biometricAvailable: true,
        biometricEnabled: true,
      ),
    );
    rows.add(
      await _traceTransition(
        tester,
        'locked→код',
        () => tester.tap(find.text(appLocalizations.accountSignInWithCode)),
      ),
    );
    await _flush(tester);

    // б) loggedOut → «Войти по почте».
    await _accountSheet(
      tester,
      const AccountState(status: AccountStatus.loggedOut),
    );
    rows.add(
      await _traceTransition(
        tester,
        'loggedOut→вход',
        () => tester.tap(find.text(appLocalizations.accountLoginByEmail)),
      ),
    );
    await _flush(tester);

    // в) успешный вход → предложение отпечатка.
    await _loginSheet(tester);
    await _submitEmail(tester, _demoEmail);
    rows.add(
      await _traceTransition(
        tester,
        'вход→отпечаток',
        () => tester.enterText(find.byType(TextField).last, '123456'),
      ),
    );
    await _flush(tester);

    // г) удаление с устройства → диалог → шит закрывается.
    await _accountSheet(tester, _ready(_demoEmail));
    await _openRemoveDialog(tester);
    rows.add(
      await _traceTransition(
        tester,
        'удаление→закрытие',
        () => tester.tap(find.text(appLocalizations.delete).last),
      ),
    );
    await _flush(tester);

    await _writeSheet(
      tester,
      'overlay-stacking',
      'Стек оверлеев: снимок на 250 мс и после 2000 мс',
      [
        [...rows[0], ...rows[1]],
        [...rows[2], ...rows[3]],
      ],
    );
  });

  testWidgets('entry-rows', (tester) async {
    addTearDown(tester.view.reset);
    final rows = <List<_Shot>>[];
    for (final scale in [1.0, _bigScale]) {
      final shots = <_Shot>[];
      for (final locale in ['ru', 'en', 'ja']) {
        final variant = _Variant(locale, scale > 1 ? _narrow : _wide, scale);
        await _applyVariant(tester, variant);
        final errors = <String>[];
        final saved = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(_describe(details));
        try {
          await _pumpApp(
            tester,
            _FakeAccount(const AccountState(status: AccountStatus.loggedOut)),
            home: Builder(
              builder: (context) {
                final theme = Theme.of(context);
                final colorScheme = theme.colorScheme;
                // Копии строк из add_profile.dart:141 и card_menu.dart:167:
                // обе завязаны на Platform.isAndroid и на хосте не рисуются.
                return Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: RepaintBoundary(
                      key: _rowsKey,
                      child: ColoredBox(
                        color: colorScheme.surface,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListItem(
                              leading: const HugeIcon(
                                icon: HugeIcons.strokeRoundedMail01,
                                size: 24,
                              ),
                              title: Text(appLocalizations.accountLoginByEmail),
                              onTap: () {},
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: 264,
                              child: GlassMenuItem(
                                title: appLocalizations.account,
                                icon: HugeIcon(
                                  icon: HugeIcons.strokeRoundedUserAccount,
                                  size: 20,
                                  color: colorScheme.onSurface,
                                ),
                                iconColor: colorScheme.onSurface,
                                titleStyle: theme.textTheme.bodyLarge
                                    ?.copyWith(color: colorScheme.onSurface),
                                onTap: () {},
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
          await _frames(tester, 1);
          final truncated = _truncatedTexts(tester);
          final image = await _capture(tester, key: _rowsKey);
          if (image != null) {
            shots.add(_Shot(variant.label, image, crop: false));
          }
          _log(
            'entry-rows | ${variant.label} | '
            'errors=${errors.isEmpty ? '-' : errors.join(' ;; ')} | '
            'truncated=${truncated.isEmpty ? '-' : truncated.join(' ;; ')}',
          );
          await _flush(tester);
        } finally {
          FlutterError.onError = saved;
        }
      }
      rows.add(shots);
    }
    await _writeSheet(
      tester,
      'entry-rows',
      'Точки входа: строка add_profile и пункт меню карточки (264dp)',
      rows,
    );
  });
}
