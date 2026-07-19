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
}
