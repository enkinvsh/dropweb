/// Pure protocol for the adb debug remote («пульт»): gate, command parsing,
/// name resolution and reply formatting. No Flutter/app imports so it is
/// unit-tested in isolation (`test/common/debug_remote_protocol_test.dart`).
/// The executor lives in `lib/services/debug_remote.dart`; the wire format is
/// documented in `docs/adb-remote.md`.
library;

import 'package:dropweb/common/log_redaction.dart';

/// Why the remote must refuse to run anything, or null when it may run.
///
/// Only ever disables the REMOTE: the Play build and developer-mode-off are
/// reported, nothing else in the app is gated on this.
String? debugRemoteGateError({
  required bool isPlayBuild,
  required bool developerMode,
}) {
  if (isPlayBuild) return 'disabled-in-play-build';
  if (!developerMode) return 'developer-mode-off';
  return null;
}

sealed class DebugCommand {
  const DebugCommand();
}

class HelpCommand extends DebugCommand {
  const HelpCommand();
}

class StatusCommand extends DebugCommand {
  const StatusCommand();
}

class StartCommand extends DebugCommand {
  const StartCommand();
}

class StopCommand extends DebugCommand {
  const StopCommand();
}

class ToggleCommand extends DebugCommand {
  const ToggleCommand();
}

class UpdateCommand extends DebugCommand {
  const UpdateCommand();
}

class ModeCommand extends DebugCommand {
  const ModeCommand({required this.mode, this.country, this.router});

  /// `standard` | `smart` | `country` (a `WorkMode` name).
  final String mode;
  final String? country;
  final String? router;
}

class TunnelCommand extends DebugCommand {
  const TunnelCommand({required this.full});

  final bool full;
}

class SelectCommand extends DebugCommand {
  const SelectCommand({required this.group, required this.node});

  final String group;
  final String node;
}

class GroupsCommand extends DebugCommand {
  const GroupsCommand({this.group});

  final String? group;
}

class PingCommand extends DebugCommand {
  const PingCommand({this.group});

  final String? group;
}

enum DumpKind { diag, config, headers }

class DumpCommand extends DebugCommand {
  const DumpCommand({required this.kind, required this.inline});

  final DumpKind kind;
  final bool inline;
}

class LogsCommand extends DebugCommand {
  const LogsCommand({required this.n});

  final int n;
}

class LogLevelCommand extends DebugCommand {
  const LogLevelCommand({required this.level});

  /// `debug` | `info` | `error` | `off`.
  final String level;
}

class NavCommand extends DebugCommand {
  const NavCommand({required this.page});

  final String page;
}

class DebugParseResult {
  const DebugParseResult({
    required this.cmd,
    this.id,
    this.command,
    this.error,
  });

  /// Normalized command name (lowercase), `?` when absent.
  final String cmd;
  final String? id;
  final DebugCommand? command;
  final String? error;
}

const List<String> debugRemoteCommandNames = [
  'help',
  'status',
  'start',
  'stop',
  'toggle',
  'mode',
  'tunnel',
  'select',
  'groups',
  'ping',
  'update',
  'diag',
  'config',
  'headers',
  'logs',
  'loglevel',
  'nav',
];

const List<String> debugRemoteHelpLines = [
  'help',
  'status',
  'start | stop | toggle',
  'mode value=standard|smart|country [country=<router member>] [router=<router member>]',
  'tunnel value=full|list',
  'select group=<group> node=<member>',
  'groups [group=<group>]',
  'ping [group=<group>]',
  'update',
  'diag [inline=1]',
  'config [inline=1]',
  'headers [inline=1]',
  'logs [n=100]',
  'loglevel value=debug|info|error|off',
  'nav page=<PageLabel>|developer',
  '(every command accepts id=<token>, echoed as DBG[<token>])',
];

const Set<String> _modes = {'standard', 'smart', 'country'};
const Set<String> _logLevels = {'debug', 'info', 'error', 'off'};
const int _maxLogs = 1000;

String? _arg(Map<String, String> extras, String key) {
  final value = extras[key]?.trim();
  return value == null || value.isEmpty ? null : value;
}

bool _flag(String? value) =>
    value != null &&
    const {'1', 'true', 'yes', 'on'}.contains(value.toLowerCase());

DebugParseResult parseDebugCommand(Map<String, String> extras) {
  final id = _arg(extras, 'id');
  final cmd = _arg(extras, 'cmd')?.toLowerCase();
  DebugParseResult fail(String error) =>
      DebugParseResult(cmd: cmd ?? '?', id: id, error: error);
  DebugParseResult ok(DebugCommand command) =>
      DebugParseResult(cmd: cmd!, id: id, command: command);

  if (cmd == null) return fail('missing-cmd (try help)');
  switch (cmd) {
    case 'help':
      return ok(const HelpCommand());
    case 'status':
      return ok(const StatusCommand());
    case 'start':
      return ok(const StartCommand());
    case 'stop':
      return ok(const StopCommand());
    case 'toggle':
      return ok(const ToggleCommand());
    case 'update':
      return ok(const UpdateCommand());
    case 'mode':
      final mode = _arg(extras, 'value')?.toLowerCase();
      if (mode == null || !_modes.contains(mode)) {
        return fail('bad-arg value (standard|smart|country)');
      }
      final country = _arg(extras, 'country');
      if (mode == 'country' && country == null) {
        return fail('missing-arg country');
      }
      return ok(ModeCommand(
        mode: mode,
        country: country,
        router: _arg(extras, 'router'),
      ));
    case 'tunnel':
      final value = _arg(extras, 'value')?.toLowerCase();
      if (value != 'full' && value != 'list') {
        return fail('bad-arg value (full|list)');
      }
      return ok(TunnelCommand(full: value == 'full'));
    case 'select':
      final group = _arg(extras, 'group');
      if (group == null) return fail('missing-arg group');
      final node = _arg(extras, 'node');
      if (node == null) return fail('missing-arg node');
      return ok(SelectCommand(group: group, node: node));
    case 'groups':
      return ok(GroupsCommand(group: _arg(extras, 'group')));
    case 'ping':
      return ok(PingCommand(group: _arg(extras, 'group')));
    case 'diag':
    case 'config':
    case 'headers':
      return ok(DumpCommand(
        kind: DumpKind.values.byName(cmd),
        inline: _flag(_arg(extras, 'inline')),
      ));
    case 'logs':
      final raw = _arg(extras, 'n');
      if (raw == null) return ok(const LogsCommand(n: 100));
      final n = int.tryParse(raw);
      if (n == null || n < 1) return fail('bad-arg n (positive integer)');
      return ok(LogsCommand(n: n > _maxLogs ? _maxLogs : n));
    case 'loglevel':
      final level = _arg(extras, 'value')?.toLowerCase();
      if (level == null || !_logLevels.contains(level)) {
        return fail('bad-arg value (debug|info|error|off)');
      }
      return ok(LogLevelCommand(level: level));
    case 'nav':
      final page = _arg(extras, 'page');
      if (page == null) return fail('missing-arg page');
      return ok(NavCommand(page: page));
    default:
      return fail('unknown-command (try help)');
  }
}

class DebugNameResolution {
  const DebugNameResolution.found(String this.name) : error = null;

  const DebugNameResolution.failed(String this.error) : name = null;

  final String? name;
  final String? error;
}

/// Exact match first; otherwise a UNIQUE case-insensitive substring match.
/// Ambiguous → error listing up to 10 candidates; none → not-found error.
DebugNameResolution resolveDebugName(
  String query,
  Iterable<String> candidates, {
  String what = 'node',
}) {
  final all = candidates.toList();
  if (all.contains(query)) return DebugNameResolution.found(query);
  final needle = query.toLowerCase();
  final matches = all.where((c) => c.toLowerCase().contains(needle)).toList();
  if (matches.length == 1) return DebugNameResolution.found(matches.first);
  if (matches.isEmpty) {
    return DebugNameResolution.failed('not-found $what "$query"');
  }
  final shown = matches.take(10).join(', ');
  final more = matches.length > 10 ? ' (+${matches.length - 10} more)' : '';
  return DebugNameResolution.failed('ambiguous $what "$query": $shown$more');
}

/// `DBG[<id>] <cmd> ok|err <details>`, URL-redacted.
String formatDebugReply({
  String? id,
  required String cmd,
  required bool ok,
  String details = '',
}) {
  final head = 'DBG[${id ?? ''}] $cmd ${ok ? 'ok' : 'err'}';
  return redactUrls(details.isEmpty ? head : '$head $details');
}
