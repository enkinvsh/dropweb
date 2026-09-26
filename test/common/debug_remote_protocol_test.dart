import 'package:dropweb/common/debug_remote_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

T _cmd<T extends DebugCommand>(Map<String, String> extras) {
  final result = parseDebugCommand(extras);
  expect(result.error, isNull, reason: 'unexpected error: ${result.error}');
  expect(result.command, isA<T>());
  return result.command! as T;
}

String _err(Map<String, String> extras) {
  final result = parseDebugCommand(extras);
  expect(result.command, isNull);
  return result.error!;
}

void main() {
  group('debugRemoteGateError', () {
    test('play build is always disabled, even with developer mode on', () {
      expect(
        debugRemoteGateError(isPlayBuild: true, developerMode: true),
        'disabled-in-play-build',
      );
      expect(
        debugRemoteGateError(isPlayBuild: true, developerMode: false),
        'disabled-in-play-build',
      );
    });

    test('non-play build requires developer mode', () {
      expect(
        debugRemoteGateError(isPlayBuild: false, developerMode: false),
        'developer-mode-off',
      );
      expect(
        debugRemoteGateError(isPlayBuild: false, developerMode: true),
        isNull,
      );
    });
  });

  group('parseDebugCommand', () {
    test('missing cmd is an error, id still echoed', () {
      final result = parseDebugCommand({'id': '7'});
      expect(result.error, 'missing-cmd (try help)');
      expect(result.id, '7');
    });

    test('unknown cmd', () {
      expect(_err({'cmd': 'frobnicate'}), 'unknown-command (try help)');
    });

    test('cmd is case-insensitive and trimmed; id is echoed', () {
      final result = parseDebugCommand({'cmd': ' Status ', 'id': 'a1'});
      expect(result.command, isA<StatusCommand>());
      expect(result.id, 'a1');
      expect(result.cmd, 'status');
    });

    test('simple commands', () {
      _cmd<HelpCommand>({'cmd': 'help'});
      _cmd<StartCommand>({'cmd': 'start'});
      _cmd<StopCommand>({'cmd': 'stop'});
      _cmd<ToggleCommand>({'cmd': 'toggle'});
      _cmd<UpdateCommand>({'cmd': 'update'});
    });

    test('mode', () {
      final standard = _cmd<ModeCommand>({'cmd': 'mode', 'value': 'standard'});
      expect(standard.mode, 'standard');
      expect(standard.country, isNull);
      final country = _cmd<ModeCommand>({
        'cmd': 'mode',
        'value': 'country',
        'country': 'Германия',
        'router': 'VPN',
      });
      expect(country.mode, 'country');
      expect(country.country, 'Германия');
      expect(country.router, 'VPN');
      expect(_err({'cmd': 'mode'}), startsWith('bad-arg value'));
      expect(_err({'cmd': 'mode', 'value': 'gaming'}),
          startsWith('bad-arg value'));
      expect(
        _err({'cmd': 'mode', 'value': 'country'}),
        'missing-arg country',
      );
    });

    test('tunnel', () {
      expect(
          _cmd<TunnelCommand>({'cmd': 'tunnel', 'value': 'full'}).full, true);
      expect(
          _cmd<TunnelCommand>({'cmd': 'tunnel', 'value': 'list'}).full, false);
      expect(
          _err({'cmd': 'tunnel', 'value': 'x'}), startsWith('bad-arg value'));
    });

    test('select requires group and node', () {
      final c =
          _cmd<SelectCommand>({'cmd': 'select', 'group': 'VPN', 'node': 'DE'});
      expect(c.group, 'VPN');
      expect(c.node, 'DE');
      expect(_err({'cmd': 'select', 'node': 'DE'}), 'missing-arg group');
      expect(_err({'cmd': 'select', 'group': 'VPN'}), 'missing-arg node');
    });

    test('groups / ping optional group', () {
      expect(_cmd<GroupsCommand>({'cmd': 'groups'}).group, isNull);
      expect(
          _cmd<GroupsCommand>({'cmd': 'groups', 'group': 'VPN'}).group, 'VPN');
      expect(_cmd<PingCommand>({'cmd': 'ping'}).group, isNull);
      expect(_cmd<PingCommand>({'cmd': 'ping', 'group': 'VPN'}).group, 'VPN');
    });

    test('diag / config / headers with inline flag', () {
      final diag = _cmd<DumpCommand>({'cmd': 'diag'});
      expect(diag.kind, DumpKind.diag);
      expect(diag.inline, false);
      final config = _cmd<DumpCommand>({'cmd': 'config', 'inline': '1'});
      expect(config.kind, DumpKind.config);
      expect(config.inline, true);
      expect(_cmd<DumpCommand>({'cmd': 'headers', 'inline': 'true'}).kind,
          DumpKind.headers);
    });

    test('logs n defaults to 100 and is validated', () {
      expect(_cmd<LogsCommand>({'cmd': 'logs'}).n, 100);
      expect(_cmd<LogsCommand>({'cmd': 'logs', 'n': '20'}).n, 20);
      expect(_cmd<LogsCommand>({'cmd': 'logs', 'n': '99999'}).n, 1000);
      expect(_err({'cmd': 'logs', 'n': 'abc'}), startsWith('bad-arg n'));
      expect(_err({'cmd': 'logs', 'n': '0'}), startsWith('bad-arg n'));
    });

    test('loglevel', () {
      expect(_cmd<LogLevelCommand>({'cmd': 'loglevel', 'value': 'debug'}).level,
          'debug');
      expect(_cmd<LogLevelCommand>({'cmd': 'loglevel', 'value': 'off'}).level,
          'off');
      expect(_err({'cmd': 'loglevel', 'value': 'warning'}),
          startsWith('bad-arg value'));
    });

    test('nav requires page', () {
      expect(_cmd<NavCommand>({'cmd': 'nav', 'page': 'developer'}).page,
          'developer');
      expect(_err({'cmd': 'nav'}), 'missing-arg page');
    });

    test('help lists every command', () {
      final help = debugRemoteHelpLines.join('\n');
      for (final name in debugRemoteCommandNames) {
        expect(help, contains(name));
      }
    });
  });

  group('resolveDebugName', () {
    const names = ['🇩🇪 Германия', '🇩🇪 Германия 2', '🇫🇮 Финляндия', 'VPN'];

    test('exact match wins even if it is also a substring of others', () {
      final r = resolveDebugName('🇩🇪 Германия', names);
      expect(r.name, '🇩🇪 Германия');
      expect(r.error, isNull);
    });

    test('unique case-insensitive substring', () {
      expect(resolveDebugName('финлян', names).name, '🇫🇮 Финляндия');
      expect(resolveDebugName('vpn', names).name, 'VPN');
    });

    test('ambiguous lists candidates', () {
      final r = resolveDebugName('германия', names, what: 'node');
      expect(r.name, isNull);
      expect(r.error, startsWith('ambiguous node "германия":'));
      expect(r.error, contains('🇩🇪 Германия 2'));
    });

    test('ambiguous caps candidate list at 10', () {
      final many = List.generate(15, (i) => 'node-$i');
      final r = resolveDebugName('node', many);
      expect(r.error, contains('node-9'));
      expect(r.error, isNot(contains('node-10,')));
      expect(r.error, contains('+5 more'));
    });

    test('not found', () {
      final r = resolveDebugName('Япония', names, what: 'group');
      expect(r.name, isNull);
      expect(r.error, 'not-found group "Япония"');
    });
  });

  group('formatDebugReply', () {
    test('ok / err shape with id and url redaction', () {
      expect(
        formatDebugReply(id: '5', cmd: 'status', ok: true, details: '{}'),
        'DBG[5] status ok {}',
      );
      expect(
        formatDebugReply(cmd: 'x', ok: false, details: 'boom'),
        'DBG[] x err boom',
      );
      expect(
        formatDebugReply(
          cmd: 'diag',
          ok: true,
          details: 'https://sub.dropweb.org/SECRETTOKEN1234567890',
        ),
        'DBG[] diag ok https://sub.dropweb.org/[REDACTED]',
      );
    });
  });
}
