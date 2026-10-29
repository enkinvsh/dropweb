// Последовательность проверки внешнего адреса при подключении: один сброс, один запрос,
// одно появление значения. Время виртуальное (`tester.pump`), сеть подменена.

import 'dart:async';

import 'package:dropweb/ui/m3e/home/m3e_home_providers.dart';
import 'package:dropweb/ui/m3e/home/m3e_ip_session.dart';
import 'package:flutter_test/flutter_test.dart';

class _Rig {
  _Rig({required this.shown, required this.answers}) {
    session = M3eIpSession(
      io: M3eIpRefresh(
        read: () => shown,
        reset: () {
          shown = null;
          events.add('reset');
        },
        checkQuiet: () async {
          await hold?.future;
          final a = _i < answers.length ? answers[_i] : answers.last;
          _i++;
          shown = a;
          events.add('check:${m3eMaskIp(a)}');
        },
      ),
      settle: const Duration(milliseconds: 700),
      connectWait: const Duration(seconds: 3),
      afterBump: const Duration(milliseconds: 300),
      retryPause: const Duration(seconds: 2),
      grace: const Duration(seconds: 5),
      onSettling: ({required settling}) => events.add('settling:$settling'),
      log: logs.add,
    );
  }

  String? shown;

  /// Пока задан, проверка висит: так моделируется «сигнал во время проверки».
  Completer<void>? hold;
  final List<String?> answers;
  final List<String> events = [];
  final List<String> logs = [];
  late final M3eIpSession session;
  int _i = 0;

  /// Сколько раз адрес «появился» на карточке: сессия закончилась с известным адресом.
  int get appearances {
    var n = 0;
    for (var i = 0; i < events.length; i++) {
      if (events[i] == 'settling:false') n++;
    }
    return n;
  }
}

Future<void> _wait(WidgetTester tester, int ms) =>
    tester.pump(Duration(milliseconds: ms));

void main() {
  test('маска адреса прячет хвост', () {
    expect(m3eMaskIp('152.53.9.10'), '152.53.x.x');
    expect(m3eMaskIp('2a01:4f8:1:2::3'), '2a01:4f8:x');
    expect(m3eMaskIp(null), '—');
  });

  testWidgets(
      'connect: туннель, переприменение профиля, смена узла, сигнал — один '
      'сброс, один запрос, одно появление', (tester) async {
    final r = _Rig(shown: '95.24.118.7', answers: ['152.53.9.10']);
    // T: туннель поднят.
    r.session.tunnelChanged(on: true);
    expect(r.events, ['settling:true', 'reset']);
    // T+0,65 с: переприменение профиля подставляет узел (null→X, потом X→Y).
    await _wait(tester, 650);
    r.session.routeChanged();
    await _wait(tester, 50);
    r.session.routeChanged();
    // T+1,33 с: контроллер сообщил, что маршрут применён.
    await _wait(tester, 630);
    expect(r.events, ['settling:true', 'reset'],
        reason: 'до сигнала контроллера запросов нет');
    r.session.bump();
    await _wait(tester, 299);
    expect(r.events.where((e) => e.startsWith('check')), isEmpty);
    await _wait(tester, 2);
    expect(r.events,
        ['settling:true', 'reset', 'check:152.53.x.x', 'settling:false']);
    await _wait(tester, 10000);
    expect(r.events.where((e) => e == 'reset'), hasLength(1));
    expect(r.events.where((e) => e.startsWith('check')), hasLength(1));
    expect(r.appearances, 1);
    expect(r.shown, '152.53.9.10');
    expect(r.logs.any((l) => l.contains('route ignored')), isTrue);
    expect(r.logs.any((l) => l.contains('152.53.9.10')), isFalse,
        reason: 'полный адрес в журнал не попадает');
    r.session.dispose();
  });

  testWidgets('сигнала контроллера нет: проверка по потолку ожидания',
      (tester) async {
    final r = _Rig(shown: '95.24.118.7', answers: ['152.53.9.10']);
    r.session.tunnelChanged(on: true);
    await _wait(tester, 2999);
    expect(r.events.where((e) => e.startsWith('check')), isEmpty);
    await _wait(tester, 2);
    expect(r.events.where((e) => e.startsWith('check')), hasLength(1));
    expect(r.appearances, 1);
    r.session.dispose();
  });

  testWidgets(
      'сигнал пришёл после проверки: тихая сверка, тот же адрес не '
      'перепоказывается', (tester) async {
    final r = _Rig(shown: '95.24.118.7', answers: ['152.53.9.10']);
    r.session.tunnelChanged(on: true);
    await _wait(tester, 3100);
    expect(r.appearances, 1);
    r.events.clear();
    r.session.bump();
    await _wait(tester, 10);
    expect(r.events, ['check:152.53.x.x'],
        reason: 'без сброса и без индикатора');
    expect(r.logs.last, contains('quiet unchanged'));
    r.session.dispose();
  });

  testWidgets('сигнал во время проверки: после неё одна тихая сверка',
      (tester) async {
    final r = _Rig(shown: '95.24.118.7', answers: ['152.53.9.10'])
      ..hold = Completer<void>();
    r.session.tunnelChanged(on: true);
    await _wait(tester, 3001);
    expect(r.events.where((e) => e.startsWith('check')), isEmpty,
        reason: 'проверка идёт и ещё не ответила');
    r.session.bump();
    r.hold!.complete();
    r.hold = null;
    await _wait(tester, 10);
    expect(r.events.where((e) => e == 'reset'), hasLength(1));
    expect(r.appearances, 1);
    // Основная проверка и одна тихая сверка; сброса и второго появления нет.
    expect(r.events.where((e) => e.startsWith('check')), hasLength(2));
    r.session.dispose();
  });

  testWidgets('смена страны при включённом VPN вне подключения: один цикл',
      (tester) async {
    final r = _Rig(shown: '152.53.9.10', answers: ['91.2.3.4']);
    r.session.routeChanged();
    expect(r.events, ['settling:true', 'reset']);
    // Смена узла даёт и свой сигнал контроллера: он схлопывается в тот же цикл.
    await _wait(tester, 400);
    r.session.bump();
    await _wait(tester, 301);
    expect(r.events.where((e) => e.startsWith('check')), hasLength(1));
    await _wait(tester, 10000);
    expect(r.events.where((e) => e == 'reset'), hasLength(1));
    expect(r.appearances, 1);
    expect(r.shown, '91.2.3.4');
    r.session.dispose();
  });

  testWidgets('выключение VPN: сброс, затем настоящий адрес', (tester) async {
    final r = _Rig(shown: '152.53.9.10', answers: ['95.24.118.7']);
    r.session.tunnelChanged(on: false);
    expect(r.events, ['settling:true', 'reset']);
    expect(r.shown, isNull);
    await _wait(tester, 701);
    expect(r.shown, '95.24.118.7');
    expect(r.appearances, 1);
    r.session.dispose();
  });

  testWidgets('адрес прежний: два повтора с паузой, индикатор до конца',
      (tester) async {
    final r = _Rig(shown: '1.1.1.1', answers: ['1.1.1.1']);
    r.session.tunnelChanged(on: true);
    r.session.bump();
    await _wait(tester, 301);
    expect(r.events.where((e) => e.startsWith('check')), hasLength(1));
    expect(r.appearances, 0, reason: 'индикатор держится на повторах');
    await _wait(tester, 2000);
    await _wait(tester, 2000);
    expect(r.events.where((e) => e.startsWith('check')), hasLength(3));
    expect(r.appearances, 1);
    await _wait(tester, 20000);
    expect(r.events.where((e) => e.startsWith('check')), hasLength(3));
    r.session.dispose();
  });

  testWidgets('новое событие обрывает прежний цикл повторов', (tester) async {
    final r = _Rig(shown: '1.1.1.1', answers: ['1.1.1.1']);
    r.session.tunnelChanged(on: true);
    r.session.bump();
    await _wait(tester, 301);
    r.session.tunnelChanged(on: false);
    r.events.clear();
    await _wait(tester, 701);
    expect(r.events.where((e) => e.startsWith('check')), hasLength(1));
    await _wait(tester, 2100);
    expect(r.events.where((e) => e.startsWith('check')), hasLength(2),
        reason: 'повторы нового цикла, прежний молчит');
    r.session.dispose();
  });

  testWidgets('старт экрана: запрос только без адреса', (tester) async {
    final known = _Rig(shown: '1.1.1.1', answers: ['2.2.2.2']);
    known.session.start();
    await _wait(tester, 10);
    expect(known.events, isEmpty);
    final empty = _Rig(shown: null, answers: ['2.2.2.2']);
    empty.session.start();
    await _wait(tester, 10);
    expect(empty.events, ['check:2.2.x.x'], reason: 'без сброса и индикатора');
    known.session.dispose();
    empty.session.dispose();
  });

  testWidgets('dispose гасит таймеры: после него ничего не происходит',
      (tester) async {
    final r = _Rig(shown: '1.1.1.1', answers: ['2.2.2.2']);
    r.session.tunnelChanged(on: true);
    r.session.dispose();
    await _wait(tester, 10000);
    expect(r.events.where((e) => e.startsWith('check')), isEmpty);
  });
}
