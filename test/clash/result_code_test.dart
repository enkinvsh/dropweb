import 'dart:async';
import 'dart:convert';

import 'package:dropweb/clash/interface.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// A handler that answers every [invoke] immediately with a caller-chosen
/// `code`/`data` pair. Both the real [ClashHandlerInterface.invoke] and the real
/// [ClashHandlerInterface.handleResult] run, so these tests observe the actual
/// dispatch boundary rather than a re-implementation of it.
class _ReplyingHandler extends ClashHandlerInterface {
  _ReplyingHandler({required this.code, required this.data});

  final ResultType code;
  final dynamic data;

  @override
  void sendMessage(String message) {
    final id = (json.decode(message) as Map<String, dynamic>)['id'] as String;
    final method = ActionMethod.values.byName(id.split('#').first);
    unawaited(
      handleResult(
        ActionResult(id: id, method: method, data: data, code: code),
      ),
    );
  }

  @override
  void reStart() {}

  @override
  FutureOr<bool> destroy() => true;

  @override
  Future<bool> preload() async => true;
}

void main() {
  group('a core reply with code != success is a failed call', () {
    test('the error body is raised, not returned as the payload', () async {
      // The core reports its error paths (a recovered panic in handleAction, an
      // unsupported method, invalid setState params) as code = -1 with the cause
      // in `data`. Returning that cause as the value means getCountryCode
      // answers "panic: ..." and the caller renders it as a country.
      final handler = _ReplyingHandler(
        code: ResultType.error,
        data: 'panic: runtime error: index out of range',
      );

      await expectLater(
        handler.invoke<String>(
          method: ActionMethod.getCountryCode,
          data: '1.1.1.1',
        ),
        throwsA('panic: runtime error: index out of range'),
        reason: 'the raw core text must survive: safeRun feeds e.toString() '
            'to ErrorMapper, which pattern-matches on it',
      );
    });

    test('a non-String error body is stringified rather than dropped',
        () async {
      final handler = _ReplyingHandler(
        code: ResultType.error,
        data: {'message': 'boom'},
      );

      await expectLater(
        handler.invoke<String>(
          method: ActionMethod.changeProxy,
          data: '{}',
        ),
        throwsA('{message: boom}'),
      );
    });

    test('a successful reply still resolves with its payload', () async {
      final handler = _ReplyingHandler(
        code: ResultType.success,
        data: 'NL',
      );

      expect(
        await handler.invoke<String>(
          method: ActionMethod.getCountryCode,
          data: '1.1.1.1',
        ),
        'NL',
        reason: 'the success path must be untouched',
      );
    });

    test('getConfig keeps reporting a core error as Result.error, not a throw',
        () async {
      // getConfig already reads `code` honestly through `toResult`, and
      // ClashCore.getConfig turns that into `throw res.message`. It stays in its
      // own switch arm so this fix cannot change it.
      final handler = _ReplyingHandler(
        code: ResultType.error,
        data: 'open /x/y.yaml: no such file or directory',
      );

      final result = await handler.invoke<Result>(
        method: ActionMethod.getConfig,
        data: '/x/y.yaml',
      );

      expect(result.isError, isTrue);
      expect(result.message, 'open /x/y.yaml: no such file or directory');
    });
  });
}
