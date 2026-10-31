import 'package:dropweb/ui/ios27/a11y/ios27_a11y.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel(Ios27A11y.channelName);

void _mockNative(Future<Object?>? Function(MethodCall call)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

/// Имитирует вызов нативной стороны в Dart (`reduceTransparencyChanged`).
Future<void> _nativeCall(String method, Object? arguments) async {
  final data = const StandardMethodCodec().encodeMethodCall(
    MethodCall(method, arguments),
  );
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(Ios27A11y.channelName, data, (_) {});
}

/// Возврат приложения из фона: `inactive` → `resumed`, как делает iOS. Ждёт, пока чтение канала
/// (микрозадачи mock-обработчика) отработает.
Future<void> _resume() async {
  TestWidgetsFlutterBinding.instance
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await pumpEventQueue();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    _mockNative(null);
    Ios27A11y.debugReset();
  });

  group('Ios27A11y вне iOS', () {
    test('start() и чтение без канала не бросают, значение false', () {
      expect(Ios27A11y.start, returnsNormally);
      expect(Ios27A11y.reduceTransparency, isFalse);
      expect(Ios27A11y.reduceTransparencyListenable.value, isFalse);
    });

    test('debugOverride перекрывает платформу и снимается null', () {
      final seen = <bool>[];
      Ios27A11y.reduceTransparencyListenable
          .addListener(() => seen.add(Ios27A11y.reduceTransparency));

      Ios27A11y.debugOverride = true;
      expect(Ios27A11y.reduceTransparency, isTrue);
      Ios27A11y.debugOverride = false;
      expect(Ios27A11y.reduceTransparency, isFalse);
      Ios27A11y.debugOverride = null;
      expect(Ios27A11y.debugOverride, isNull);
      expect(Ios27A11y.reduceTransparency, isFalse);

      expect(seen, [true, false]);
    });
  });

  group('канал dropweb/accessibility', () {
    test('debugAttach читает начальное значение', () async {
      _mockNative((call) async => call.method == 'reduceTransparency');
      await Ios27A11y.debugAttach();
      expect(Ios27A11y.reduceTransparency, isTrue);
    });

    test('событие reduceTransparencyChanged меняет значение и будит слушателей',
        () async {
      _mockNative((call) async => false);
      await Ios27A11y.debugAttach();
      expect(Ios27A11y.reduceTransparency, isFalse);

      var notified = 0;
      Ios27A11y.reduceTransparencyListenable.addListener(() => notified++);

      await _nativeCall('reduceTransparencyChanged', true);
      expect(Ios27A11y.reduceTransparency, isTrue);
      await _nativeCall('reduceTransparencyChanged', false);
      expect(Ios27A11y.reduceTransparency, isFalse);
      expect(notified, 2);
    });

    test('нативной части нет: MissingPluginException не бросается наружу',
        () async {
      await expectLater(Ios27A11y.debugAttach(), completes);
      expect(Ios27A11y.reduceTransparency, isFalse);
    });

    test('ошибка платформы не бросается наружу, значение остаётся false',
        () async {
      _mockNative((call) async {
        throw PlatformException(code: 'boom');
      });
      await expectLater(Ios27A11y.debugAttach(), completes);
      expect(Ios27A11y.reduceTransparency, isFalse);
    });

    test('подмена сильнее платформы, после сброса возвращается платформа',
        () async {
      _mockNative((call) async => true);
      await Ios27A11y.debugAttach();
      Ios27A11y.debugOverride = false;
      expect(Ios27A11y.reduceTransparency, isFalse);
      Ios27A11y.debugOverride = null;
      expect(Ios27A11y.reduceTransparency, isTrue);
    });
  });

  group('повтор чтения после неудачи', () {
    test('возврат из фона повторяет чтение: первый провал, второй успех',
        () async {
      var calls = 0;
      _mockNative((call) async {
        calls++;
        if (calls == 1) {
          throw PlatformException(code: 'not-ready');
        }
        return true;
      });

      await Ios27A11y.debugAttach();
      expect(Ios27A11y.reduceTransparency, isFalse);
      expect(calls, 1);

      await _resume();
      expect(calls, 2);
      expect(Ios27A11y.reduceTransparency, isTrue);

      // Значение получено: следующие возвраты из фона канал не трогают.
      await _resume();
      await _resume();
      expect(calls, 2);
    });

    test('MissingPluginException при старте тоже повторяется', () async {
      var calls = 0;
      _mockNative((call) async {
        calls++;
        if (calls == 1) {
          throw MissingPluginException();
        }
        return true;
      });

      await Ios27A11y.debugAttach();
      expect(Ios27A11y.reduceTransparency, isFalse);

      await _resume();
      expect(Ios27A11y.reduceTransparency, isTrue);
    });

    testWidgets('после ближайшего кадра чтение повторяется само',
        (tester) async {
      var calls = 0;
      _mockNative((call) async {
        calls++;
        if (calls == 1) {
          throw PlatformException(code: 'not-ready');
        }
        return true;
      });

      await tester.runAsync(Ios27A11y.debugAttach);
      expect(Ios27A11y.reduceTransparency, isFalse);
      expect(calls, 1);

      // Кадр запускает отложенный повтор; ответ канала приходит микрозадачами.
      await tester.pump();
      await tester.pump();
      expect(calls, 2);
      expect(Ios27A11y.reduceTransparency, isTrue);

      // Повтор разовый: ещё кадры и возвраты из фона ничего не добавляют.
      await tester.pump();
      await tester.runAsync(_resume);
      expect(calls, 2);
    });

    test('число повторов ограничено, опроса по таймеру нет', () async {
      var calls = 0;
      _mockNative((call) async {
        calls++;
        throw PlatformException(code: 'not-ready');
      });

      await Ios27A11y.debugAttach();
      for (var i = 0; i < 10; i++) {
        await _resume();
      }

      // Первый запрос и три повтора, дальше канал не дёргают.
      expect(calls, 4);
      expect(Ios27A11y.debugRetriesLeft, 0);
      expect(Ios27A11y.reduceTransparency, isFalse);

      // Событие нативной стороны после исчерпания попыток всё равно принимается.
      await _nativeCall('reduceTransparencyChanged', true);
      expect(Ios27A11y.reduceTransparency, isTrue);
    });

    test('событие от нативной стороны отменяет повторы', () async {
      var calls = 0;
      _mockNative((call) async {
        calls++;
        throw PlatformException(code: 'not-ready');
      });

      await Ios27A11y.debugAttach();
      await _nativeCall('reduceTransparencyChanged', true);
      expect(Ios27A11y.reduceTransparency, isTrue);

      await _resume();
      expect(calls, 1);
    });

    test('успешное первое чтение повторов не заводит', () async {
      var calls = 0;
      _mockNative((call) async {
        calls++;
        return false;
      });

      await Ios27A11y.debugAttach();
      await _resume();
      await _resume();
      expect(calls, 1);
      expect(Ios27A11y.debugRetriesLeft, 3);
    });

    test('сброс отменяет отложенный повтор', () async {
      var calls = 0;
      _mockNative((call) async {
        calls++;
        throw PlatformException(code: 'not-ready');
      });

      await Ios27A11y.debugAttach();
      Ios27A11y.debugReset();

      await _resume();
      expect(calls, 1);
      expect(Ios27A11y.debugRetriesLeft, 3);
    });
  });

  group('Ios27A11yBuilder', () {
    testWidgets('отдаёт Reduce Transparency и аспекты MediaQuery',
        (tester) async {
      Ios27A11yData? last;
      Widget app() => MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
              highContrast: true,
              boldText: true,
            ),
            child: Ios27A11yBuilder(
              builder: (context, data) {
                last = data;
                return const SizedBox();
              },
            ),
          );

      await tester.pumpWidget(app());
      expect(
        last,
        const Ios27A11yData(
          reduceMotion: true,
          highContrast: true,
          boldText: true,
        ),
      );

      Ios27A11y.debugOverride = true;
      await tester.pump();
      expect(last?.reduceTransparency, isTrue);
    });
  });
}
