import 'package:dropweb/clash/lib.dart';
import 'package:dropweb/common/error_mapper.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/manager/clash_manager.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/plugins/ios_switch_window.dart';
import 'package:dropweb/plugins/ios_tunnel.dart';
import 'package:dropweb/plugins/ios_tunnel_forwarder.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_path_provider.dart';

const _channel = MethodChannel('dropweb/ios_tunnel');

/// Пуш ядра приложения в том виде, в каком его получает `ClashLibIos`.
ActionResult _corePush(String level, String payload) => ActionResult.fromJson({
      'method': 'message',
      'data': {
        'type': 'log',
        'data': {'LogLevel': level, 'Payload': payload},
      },
    });

/// Тот же путь, что `ClashLibIos` → `ClashMessage` → `ClashManager.onLog`:
/// текст тоста или `null`, если тоста нет.
String? _toastFor(ActionResult result, {List<String>? log}) {
  final filtered = ClashLibIos.filterPlannedSwitchResult(
    result,
    inWindow: IosPlannedSwitchWindow.isActive,
    log: log?.add ?? (_) {},
  );
  final message = AppMessage.fromJson(
    Map<String, Object?>.from(filtered.data as Map),
  );
  final entry = Log.fromJson(Map<String, Object?>.from(message.data as Map));
  if (entry.logLevel != LogLevel.error) return null;
  return coreErrorToastText(entry.payload);
}

// Типичный обрыв health-check группы через расширение, которое мы
// перезапускаем при смене страны (формат строки условный, важен хвост `EOF`).
const _eofPayload = '[UrlTest] 🇩🇪 Germany health check failed: '
    'Head "https://cp.cloudflare.com/generate_204": EOF';

// Текст тоста из ErrorMapper в текущей локали теста.
final _lostText = ErrorMapper.mapError('read: EOF');

void main() {
  // Журнал приложения пишет в каталог из path_provider. Мок канала не годится: на Linux
  // `getDownloadsDirectory()` бросает UnsupportedError раньше канала, и ошибка падает на
  // первый тест, который тронул `appPath`.
  useFakePathProvider();
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(IosPlannedSwitchWindow.reset);
  tearDown(IosPlannedSwitchWindow.reset);

  test('вне переключения EOF ядра по-прежнему даёт тост «потеряно»', () {
    final toast = _toastFor(_corePush('error', _eofPayload));
    expect(toast, _lostText);
  });

  group('перезапуск туннеля при смене страны', () {
    late int status;
    late List<String?> toastsDuringRestart;
    final logLines = <String>[];

    setUp(() {
      status = 3;
      toastsDuringRestart = [];
      logLines.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
        switch (call.method) {
          case 'status':
            return status;
          case 'stop':
            status = 1;
            return null;
        }
        return null;
      });
      globalState.startTime =
          DateTime.now().subtract(const Duration(minutes: 1));
      globalState.iosTunnelSignatureForTest = 'A';
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
      globalState.iosTunnelSyncHooks = null;
      globalState.startTime = null;
      globalState.isConnecting.value = false;
      globalState.iosTunnelSignatureForTest = null;
    });

    IosTunnelSyncHooks hooks({required bool startOk, List<String>? notes}) =>
        IosTunnelSyncHooks(
          buildPayload: () async => (
            init: '{}',
            setup: '{}',
            state: '{}',
            signature: 'B',
            stillRemote: <String>[],
          ),
          restarter: () => IosTunnelRestarter(
            log: (_) {},
            tunnel: IosTunnel.instance,
            stopTimeout: const Duration(milliseconds: 200),
            pollInterval: const Duration(milliseconds: 5),
            statusTimeout: const Duration(milliseconds: 50),
          ),
          startTunnel: (_) async {
            // Пока расширение поднимается, health-check ядра приложения
            // ловит обрыв своего соединения.
            toastsDuringRestart.add(
              _toastFor(_corePush('error', _eofPayload), log: logLines),
            );
            if (startOk) status = 3;
            return startOk;
          },
          onRestarted: () {},
          teardown: () async => globalState.startTime = null,
          notify: notes?.add ?? (_) {},
        );

    test('EOF во время перезапуска: тоста нет, строка в журнале', () async {
      globalState.iosTunnelSyncHooks = hooks(startOk: true);

      await globalState.syncIosTunnelConfig(reason: 'test');

      expect(toastsDuringRestart, [null]);
      expect(
        logLines.single,
        contains('[ios-tunnel] core error during planned switch'),
      );
      // Досыпающиеся после перезапуска ошибки тоже не тостятся.
      expect(_toastFor(_corePush('error', _eofPayload)), isNull);
    });

    test('после запаса окна EOF снова тостится', () async {
      globalState.iosTunnelSyncHooks = hooks(startOk: true);
      await globalState.syncIosTunnelConfig(reason: 'test');

      final later = DateTime.now()
          .add(IosPlannedSwitchWindow.grace + const Duration(seconds: 1));
      IosPlannedSwitchWindow.now = () => later;

      expect(
        _toastFor(_corePush('error', _eofPayload)),
        _lostText,
      );
    });

    test('провал перезапуска: честный тост vpnStartFailed остаётся', () async {
      final notes = <String>[];
      globalState.iosTunnelSyncHooks = hooks(startOk: false, notes: notes);

      await globalState.syncIosTunnelConfig(reason: 'test');

      expect(notes, [ErrorMapper.vpnStartFailed]);
      expect(globalState.startTime, isNull);
    });
  });

  test('запуск туннеля: EOF замеров глушится в окне и после ошибки запуска',
      () async {
    // handleStart на iOS оборачивает подъём туннеля в around: маршрут
    // приложения меняется «напрямую → через расширение», идущие замеры рвутся.
    String? duringStart;
    await IosPlannedSwitchWindow.around(() async {
      duringStart = _toastFor(_corePush('error', _eofPayload));
    });
    expect(duringStart, isNull);
    // Запас после конца запуска.
    expect(_toastFor(_corePush('error', _eofPayload)), isNull);

    IosPlannedSwitchWindow.reset();
    await expectLater(
      IosPlannedSwitchWindow.around<void>(() async => throw StateError('x')),
      throwsStateError,
    );
    // Исключение не оставляет окно открытым навсегда: после запаса — снова тост.
    final later = DateTime.now()
        .add(IosPlannedSwitchWindow.grace + const Duration(seconds: 1));
    IosPlannedSwitchWindow.now = () => later;
    expect(_toastFor(_corePush('error', _eofPayload)), _lostText);
  });

  test('ошибки настройки в окне не глушатся', () {
    IosPlannedSwitchWindow.begin();
    expect(
      _toastFor(_corePush(
        'error',
        'Start Mixed(http+socks) server error: '
            'listen tcp 127.0.0.1:37730: bind: address already in use',
      )),
      isNotNull,
    );
    expect(
      _toastFor(_corePush('error', 'dial tcp 1.2.3.4:443: i/o timeout')),
      isNotNull,
    );
    IosPlannedSwitchWindow.end();
  });

  test('слово с «eof» внутри не считается обрывом', () {
    expect(isPlannedSwitchDropError('typeof x is wrong'), isFalse);
    expect(isPlannedSwitchDropError('read: unexpected EOF'), isTrue);
    expect(isPlannedSwitchDropError('write: broken pipe'), isTrue);
  });

  test('вложенные begin/end: окно открыто до последнего end + запас', () {
    IosPlannedSwitchWindow.begin();
    IosPlannedSwitchWindow.begin();
    IosPlannedSwitchWindow.end();
    expect(IosPlannedSwitchWindow.isActive, isTrue);
    IosPlannedSwitchWindow.end();
    final later = DateTime.now()
        .add(IosPlannedSwitchWindow.grace + const Duration(seconds: 1));
    IosPlannedSwitchWindow.now = () => later;
    expect(IosPlannedSwitchWindow.isActive, isFalse);
  });

  test('окно закрыто (Android/десктоп его не открывают): фильтр не трогает',
      () {
    final push = _corePush('error', _eofPayload);
    final out = ClashLibIos.filterPlannedSwitchResult(
      push,
      inWindow: false,
      log: (_) => fail('не должно логировать'),
    );
    expect(identical(out, push), isTrue);
  });
}
