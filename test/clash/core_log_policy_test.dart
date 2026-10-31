import 'package:dropweb/common/error_mapper.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/manager/clash_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closed log viewer writes only core errors to the file log', () {
    expect(shouldWriteCoreLog(LogLevel.error, openLogs: false), isTrue);

    for (final level in LogLevel.values.where(
      (level) => level != LogLevel.error,
    )) {
      expect(
        shouldWriteCoreLog(level, openLogs: false),
        isFalse,
        reason: '$level must stay out of the file log when logs are closed',
      );
    }
  });

  test('closed log viewer does not feed the in-app provider', () {
    expect(shouldFeedCoreLogProvider(openLogs: false), isFalse);
  });

  test('open log viewer writes and feeds every core log level', () {
    for (final level in LogLevel.values) {
      expect(shouldWriteCoreLog(level, openLogs: true), isTrue);
    }
    expect(shouldFeedCoreLogProvider(openLogs: true), isTrue);
  });

  test('ICMP relay errors from user ping traffic never notify', () {
    expect(
      shouldNotifyCoreError('receive ICMP echo reply: i/o timeout'),
      isFalse,
    );
    expect(shouldNotifyCoreError('write ICMP echo reply: EOF'), isFalse);
    expect(
      shouldNotifyCoreError('dial tcp 1.2.3.4:443: i/o timeout'),
      isTrue,
    );
    expect(
      shouldNotifyCoreError('[TUN] default interface lost by monitor'),
      isTrue,
    );
  });

  test('жалоба на повторный замер задержки при рабочем узле не даёт тост', () {
    // Первый ответ узла получен, задержка записана — это не потеря связи.
    const payload =
        'Germany failed to get the second response from http://cp.cloudflare.com/generate_204: '
        'Head "http://cp.cloudflare.com/generate_204": EOF';
    expect(shouldNotifyCoreError(payload), isFalse);
    expect(coreErrorToastText(payload), isNull);
    expect(
      coreErrorToastText('Germany failed to get the second response from x'),
      isNull,
    );
  });

  test('тост ошибки ядра — короткая фраза, сырой текст в него не попадает', () {
    expect(
      coreErrorToastText('dial tcp 1.2.3.4:443: i/o timeout'),
      ErrorMapper.mapError('i/o timeout'),
    );
    const unknown = '[panic] recovered: index out of range at hub.go:482';
    expect(coreErrorToastText(unknown), ErrorMapper.generic);
  });
}
