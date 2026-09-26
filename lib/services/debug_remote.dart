import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/connect_trace.dart';
import 'package:dropweb/common/debug_remote_protocol.dart';
import 'package:dropweb/common/diagnostics.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/services/diagnostics_service.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/developer.dart';
import 'package:dropweb/views/proxies/common.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// adb remote («пульт») executor. Commands arrive from the Kotlin
/// `DebugReceiver` (guarded by `android.permission.DUMP`, i.e. adb shell only)
/// over [_events]; replies go back over [_channel] and are logged natively
/// under the `dropweb-dbg` logcat tag. Protocol + gate:
/// `lib/common/debug_remote_protocol.dart`; usage: `docs/adb-remote.md`.
///
/// Every command reuses the UI's own code path (see the per-command notes).
class DebugRemote {
  DebugRemote._();

  static const _channel = MethodChannel('app.dropweb/debug');
  static const _events = EventChannel('app.dropweb/debug/events');
  static StreamSubscription<dynamic>? _sub;
  static bool _initialized = false;

  /// Runtime-only (never persisted) mirror of core log lines to `dropweb-dbg`.
  /// Turned on by `loglevel debug|info|error`, off by `loglevel off`.
  static bool _mirrorCoreLogs = false;

  static Future<void> init() async {
    if (_initialized || !Platform.isAndroid) return;
    _initialized = true;
    _sub = _events.receiveBroadcastStream().listen(
      (event) {
        if (event is String) unawaited(_onEvent(event));
      },
      onError: (Object e) {
        developer.log('debug event error: $e', name: 'DebugRemote');
      },
    );
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
    _mirrorCoreLogs = false;
  }

  /// Called by `ClashManager.onLog` with the ALREADY-redacted payload.
  static void mirrorCoreLog(LogLevel level, String redactedPayload) {
    if (!_mirrorCoreLogs) return;
    unawaited(_send('core[${level.name.toUpperCase()}] $redactedPayload'));
  }

  static Future<void> _send(String text) async {
    try {
      await _channel.invokeMethod<void>('reply', redactUrls(text));
    } on MissingPluginException {
      developer.log('reply channel missing', name: 'DebugRemote');
    } on PlatformException catch (e) {
      developer.log('reply failed: ${e.message}', name: 'DebugRemote');
    }
  }

  static Future<void> _onEvent(String raw) async {
    Map<String, String> extras;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await _send(
            formatDebugReply(cmd: '?', ok: false, details: 'bad-event'));
        return;
      }
      extras = {
        for (final e in decoded.entries) e.key.toString(): '${e.value}',
      };
    } on FormatException catch (e) {
      await _send(formatDebugReply(
        cmd: '?',
        ok: false,
        details: 'bad-event ${e.message}',
      ));
      return;
    }
    await handle(extras);
  }

  /// Commands queued natively before a cold start are flushed as soon as Dart
  /// subscribes — usually before the first frame. Give the UI a moment.
  static Future<BuildContext?> _awaitUiContext() async {
    for (var i = 0; i < 50; i++) {
      final context = globalState.navigatorKey.currentContext;
      if (context != null) return context;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return null;
  }

  static String _summary(Object e) {
    final text = e.toString().replaceAll('\n', ' ');
    return text.length > 300 ? '${text.substring(0, 300)}…' : text;
  }

  /// Parses, gates and runs one command; always replies, never throws.
  static Future<void> handle(Map<String, String> extras) async {
    final rawCmd = extras['cmd']?.trim().toLowerCase() ?? '?';
    final id = extras['id']?.trim();
    Future<void> reply({
      required bool ok,
      required String details,
      String? cmd,
    }) =>
        _send(
          formatDebugReply(
            id: id,
            cmd: cmd ?? rawCmd,
            ok: ok,
            details: details,
          ),
        );

    // Gate FIRST: in the Play build nothing is parsed or executed.
    final gate = debugRemoteGateError(
      isPlayBuild: kIsPlayBuild,
      developerMode: globalState.config.appSetting.developerMode,
    );
    if (gate != null) {
      await reply(ok: false, details: gate);
      return;
    }
    final parsed = parseDebugCommand(extras);
    final command = parsed.command;
    if (command == null) {
      await reply(
        ok: false,
        details: parsed.error ?? 'bad-command',
        cmd: parsed.cmd,
      );
      return;
    }
    try {
      final context = await _awaitUiContext();
      if (context == null || !context.mounted) {
        await reply(ok: false, details: 'ui-not-ready', cmd: parsed.cmd);
        return;
      }
      final container = ProviderScope.containerOf(context, listen: false);
      final details = await _run(command, container);
      await reply(ok: true, details: details, cmd: parsed.cmd);
    } on _RemoteError catch (e) {
      await reply(ok: false, details: e.message, cmd: parsed.cmd);
    } catch (e, st) {
      commonPrint.log('[debug-remote] ${parsed.cmd} failed: $e\n$st');
      await reply(ok: false, details: _summary(e), cmd: parsed.cmd);
    }
  }

  static Future<String> _run(
    DebugCommand command,
    ProviderContainer c,
  ) async =>
      switch (command) {
        HelpCommand() => '\n${debugRemoteHelpLines.join('\n')}',
        StatusCommand() =>
          jsonEncode(await DiagnosticsService.statusMap(c), toEncodable: _str),
        StartCommand() => _setRunning(c, true),
        StopCommand() => _setRunning(c, false),
        ToggleCommand() => _setRunning(c, c.read(runTimeProvider) == null),
        ModeCommand() => _mode(c, command),
        TunnelCommand() => _tunnel(c, command.full),
        SelectCommand() => _select(c, command),
        GroupsCommand() => _groups(c, command.group),
        PingCommand() => _ping(c, command.group),
        UpdateCommand() => _update(c),
        DumpCommand() => _dump(c, command),
        LogsCommand() => _logs(c, command.n),
        LogLevelCommand() => _logLevel(c, command.level),
        NavCommand() => _nav(c, command.page),
      };

  static Object? _str(Object? o) => o.toString();

  static Profile _profile(ProviderContainer c) {
    final profile = c.read(currentProfileProvider);
    if (profile == null) throw const _RemoteError('no-profile');
    return profile;
  }

  // ── start / stop / toggle: mirrors StartButton.handleSwitchStart ─────────

  static Future<String> _setRunning(ProviderContainer c, bool start) async {
    final controller = globalState.appController;
    if (!start) {
      await controller.updateStatus(false);
      return 'running=${c.read(runTimeProvider) != null}';
    }
    _profile(c);
    // Same consent gate the dashboard button and the controller use. The
    // remote cannot show the disclosure dialog, so it refuses instead.
    if (!await vpnConsent.isAccepted()) {
      throw const _RemoteError(
        'vpn-consent-not-accepted (tap connect once in the UI)',
      );
    }
    ConnectTrace.start();
    await controller.updateStatus(true);
    return 'running=${c.read(runTimeProvider) != null}';
  }

  // ── mode: mirrors ModesContent._apply / _openCountryDeep ──────────────────

  static Future<Group> _routerGroup(ProviderContainer c) async {
    final router = await DiagnosticsService.primaryRouter(c);
    if (router == null) throw const _RemoteError('no-primary-router');
    final group = c.read(groupsProvider).getGroup(router);
    if (group == null) throw _RemoteError('router-not-loaded "$router"');
    return group;
  }

  static String _resolve(
    String query,
    Iterable<String> names, {
    required String what,
  }) {
    final r = resolveDebugName(query, names, what: what);
    final name = r.name;
    if (name == null) throw _RemoteError(r.error ?? 'not-found $what');
    return name;
  }

  static Future<String> _mode(ProviderContainer c, ModeCommand cmd) async {
    _profile(c);
    final mode = WorkMode.values.byName(cmd.mode);
    String? staticCountry;
    String? routerPin;
    Group? router;
    if (cmd.country != null || cmd.router != null) {
      router = await _routerGroup(c);
      final members = router.all.map((p) => p.name);
      if (mode == WorkMode.country) {
        // Country picker: staticCountry and routerPin are both the router
        // member the user tapped (`_openCountryDeep` onSelected).
        staticCountry = _resolve(cmd.country!, members, what: 'country');
        routerPin = staticCountry;
      }
      if (cmd.router != null) {
        routerPin = _resolve(cmd.router!, members, what: 'router member');
      }
    }
    final controller = globalState.appController;
    if (router != null && routerPin != null) {
      // ProxySelectorSheet row tap: write the pick first, then apply the mode.
      controller
        ..updateCurrentSelectedMap(router.name, routerPin)
        ..changeProxyDebounce(router.name, routerPin);
    }
    await controller.applyWorkMode(
      mode,
      staticCountry: staticCountry,
      routerPin: routerPin,
    );
    final after = c.read(currentProfileProvider);
    final applied = after?.workMode == mode;
    return 'workMode=${after?.workMode.name} '
        'staticCountry=${after?.staticCountry ?? '-'} '
        'routerPin=${routerPin ?? '-'}'
        '${applied ? '' : ' (rolled back)'}';
  }

  // ── tunnel: mirrors ModesContent._setFullTunnel ───────────────────────────

  static Future<String> _tunnel(ProviderContainer c, bool full) async {
    _profile(c);
    await globalState.appController.setFullTunnel(enabled: full);
    final after = c.read(currentProfileProvider)?.fullTunnel;
    return 'fullTunnel=$after${after == full ? '' : ' (rolled back)'}';
  }

  // ── select: mirrors proxies/card.dart _changeProxy ────────────────────────

  static Group _group(ProviderContainer c, String query) {
    final groups = c.read(groupsProvider);
    final name = _resolve(query, groups.map((g) => g.name), what: 'group');
    return groups.getGroup(name)!;
  }

  static Future<String> _select(ProviderContainer c, SelectCommand cmd) async {
    final group = _group(c, cmd.group);
    final node = _resolve(
      cmd.node,
      group.all.map((p) => p.name),
      what: 'node',
    );
    final type = group.type;
    if (type != GroupType.Selector && !type.isComputedSelected) {
      throw _RemoteError('not-selectable group type ${type.name}');
    }
    // Computed groups toggle the pin off when re-picking the pinned member,
    // exactly like the proxies card.
    final current = c.read(getProxyNameProvider(group.name));
    final next = type.isComputedSelected && current == node ? '' : node;
    globalState.appController
      ..updateCurrentSelectedMap(group.name, next)
      ..changeProxyDebounce(group.name, next);
    return '"${group.name}" [${type.name}] -> '
        '${next.isEmpty ? '(unpinned)' : '"$next"'}';
  }

  // ── groups / ping ─────────────────────────────────────────────────────────

  static Future<String> _groups(ProviderContainer c, String? query) async {
    if (query == null) {
      final lines = c
          .read(groupsProvider)
          .map((g) => '${g.name} [${g.type.name}] now=${g.now ?? '-'} '
              'members=${g.all.length}${g.hidden == true ? ' hidden' : ''}')
          .toList();
      return '${lines.length} groups\n${lines.join('\n')}';
    }
    final group = _group(c, query);
    String line(Proxy p) {
      final delay = DiagnosticsService.delayOf(c, group, p.name);
      final mark = p.name == group.now ? '*' : ' ';
      return '$mark ${p.name} [${p.type}] ${formatDiagnosticsDelay(delay)}';
    }

    final lines = group.all.map(line).toList();
    return '"${group.name}" [${group.type.name}] now=${group.now ?? '-'}\n'
        '${lines.join('\n')}';
  }

  static Future<String> _ping(ProviderContainer c, String? query) async {
    final group = query == null ? await _routerGroup(c) : _group(c, query);
    if (group.all.isEmpty) throw _RemoteError('empty group "${group.name}"');
    // Same call the country sheet uses (`ProxySelectorSheet._pingMembers`).
    await delayTest(group.all, group.testUrl);
    final results = [
      for (final p in group.all)
        (p.name, DiagnosticsService.delayOf(c, group, p.name)),
    ]..sort((a, b) {
        int rank(int? d) => d == null || d == 0 ? 2 : (d < 0 ? 1 : 0);
        final r = rank(a.$2).compareTo(rank(b.$2));
        if (r != 0) return r;
        return (a.$2 ?? 0).compareTo(b.$2 ?? 0);
      });
    final shown =
        results.take(30).map((r) => '${r.$1}: ${formatDiagnosticsDelay(r.$2)}');
    final more = results.length > 30 ? '\n(+${results.length - 30} more)' : '';
    return '"${group.name}" ${results.length} members\n'
        '${shown.join('\n')}$more';
  }

  // ── update: mirrors card_menu «Обновить подписку» ────────────────────────

  static Future<String> _update(ProviderContainer c) async {
    final profile = _profile(c);
    final controller = globalState.appController;
    try {
      controller.updateProfileById(
          profile.id, (p) => p.copyWith(isUpdating: true));
      await controller.updateProfile(profile);
    } catch (_) {
      controller.updateProfileById(
          profile.id, (p) => p.copyWith(isUpdating: false));
      rethrow;
    }
    final after = c.read(currentProfileProvider);
    return 'lastUpdateDate=${after?.lastUpdateDate?.toIso8601String()}';
  }

  // ── diag / config / headers ──────────────────────────────────────────────

  static Future<String> _dump(ProviderContainer c, DumpCommand cmd) async {
    final String path;
    final String text;
    final bool isExternal;
    switch (cmd.kind) {
      case DumpKind.diag:
        final result = await DiagnosticsService.writeAll(c);
        (path, text, isExternal) =
            (result.diagPath, result.text, result.isExternal);
      case DumpKind.config:
        (path, text, isExternal) = await DiagnosticsService.writeConfig();
      case DumpKind.headers:
        (path, text, isExternal) = await DiagnosticsService.writeHeaders(c);
    }
    final where = isExternal
        ? path
        : '$path (external dir unavailable: app-private, not adb-pullable)';
    return cmd.inline ? '$where\n$text' : where;
  }

  static Future<String> _logs(ProviderContainer c, int n) async {
    final list = c.read(logsProvider).list;
    final tail = list.length > n ? list.sublist(list.length - n) : list;
    return '${tail.length}/${list.length}\n'
        '${tail.map(DiagnosticsService.formatLog).join('\n')}';
  }

  // ── loglevel: same providers the «Журналирование» / log-level items use ──

  static Future<String> _logLevel(ProviderContainer c, String level) async {
    final setting = c.read(appSettingProvider.notifier);
    if (level == 'off') {
      setting.updateState((s) => s.copyWith(openLogs: false));
      _mirrorCoreLogs = false;
      return 'openLogs=false mirror=off';
    }
    final requested = LogLevel.values.byName(level);
    setting.updateState((s) => s.copyWith(openLogs: true));
    c
        .read(patchClashConfigProvider.notifier)
        .updateState((s) => s.copyWith(logLevel: requested));
    _mirrorCoreLogs = true;
    final core = coreLogLevel(openLogs: true, requested: requested).name;
    return 'openLogs=true logLevel=${requested.name} core=$core mirror=on';
  }

  // ── nav ───────────────────────────────────────────────────────────────────

  static Future<String> _nav(ProviderContainer c, String page) async {
    // Pages/sheets pushed on top (developer, config viewer...) would hide the
    // target tab and stack on repeat — always start from the root route.
    globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (page.toLowerCase() == 'developer') {
      final context = globalState.navigatorKey.currentContext;
      if (context == null) throw const _RemoteError('ui-not-ready');
      // Same sheet route `_DeveloperItem` opens (ListItem.open → showExtend on
      // the non-OpenContainer path).
      unawaited(showExtend(
        context,
        builder: (_, type) => AdaptiveSheetScaffold(
          type: type,
          body: const SafeArea(child: DeveloperView()),
          title: appLocalizations.developerMode,
          titleBuilder: (context) => AppLocalizations.of(context).developerMode,
        ),
      ));
      return 'developer';
    }
    final label = _resolve(
      page,
      PageLabel.values.map((p) => p.name),
      what: 'page',
    );
    globalState.appController.toPage(PageLabel.values.byName(label));
    return 'page=${c.read(currentPageLabelProvider).name}';
  }
}

class _RemoteError implements Exception {
  const _RemoteError(this.message);

  final String message;

  @override
  String toString() => message;
}
