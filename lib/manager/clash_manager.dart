import 'dart:async';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/error_mapper.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/app.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/providers/state.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool shouldWriteCoreLog(LogLevel level, {required bool openLogs}) =>
    openLogs || level == LogLevel.error;

bool shouldFeedCoreLogProvider({required bool openLogs}) => openLogs;

class ClashManager extends ConsumerStatefulWidget {
  const ClashManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  ConsumerState<ClashManager> createState() => _ClashContainerState();
}

class _ClashContainerState extends ConsumerState<ClashManager>
    with AppMessageListener {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void initState() {
    super.initState();
    clashMessage.addListener(this);
    ref.listenManual(needSetupProvider, (prev, next) {
      if (prev == next || globalState.profileCommitInProgress) return;
      unawaited(_handleChangeProfile());
    });
    ref.listenManual(coreStateProvider, (prev, next) async {
      if (prev != next) {
        await clashCore.setState(next);
      }
    });
    ref.listenManual(updateParamsProvider, (prev, next) {
      if (prev != next) {
        globalState.appController.updateClashConfigDebounce();
      }
    });
  }

  Future<void> _handleChangeProfile() async {
    try {
      await globalState.appController.handleChangeProfile();
    } catch (error, stackTrace) {
      commonPrint.log(
        '[profile] listener apply failed: $error\n$stackTrace',
      );
    }
  }

  @override
  Future<void> dispose() async {
    clashMessage.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onDelay(Delay delay) async {
    super.onDelay(delay);
    final appController = globalState.appController;
    appController.setDelay(delay);
    debouncer.call(
      FunctionTag.updateDelay,
      () async {
        appController.updateGroupsDebounce();
      },
      duration: const Duration(milliseconds: 5000),
    );
  }

  @override
  void onLog(Log log) {
    final openLogs = ref.read(appSettingProvider).openLogs;
    final writeToFile = shouldWriteCoreLog(
      log.logLevel,
      openLogs: openLogs,
    );
    final feedProvider = shouldFeedCoreLogProvider(openLogs: openLogs);
    if (!writeToFile && !feedProvider) {
      return;
    }

    // SECURITY: mihomo core log payloads can include outbound URLs from
    // proxy/provider activity. Redact at the boundary so the in-app log
    // viewer (`logsProvider`), the on-disk log file (`fileLogger`), and
    // the user-facing error notifier never receive raw tokens.
    final redactedPayload = redactUrls(log.payload);
    if (feedProvider) {
      ref.read(logsProvider.notifier).addLog(
            log.copyWith(payload: redactedPayload),
          );
    }

    if (writeToFile) {
      fileLogger.log(
        "[${log.logLevel.name.toUpperCase()}] $redactedPayload",
      );
    }

    if (log.logLevel == LogLevel.error) {
      // Matched against the ORIGINAL payload so the existing regexes (e.g.
      // `DioException.*connection error`) still hit; the redacted copy is what
      // reaches the log viewer and the file above.
      final message = ErrorMapper.mapError(log.payload);

      // An error we have written no copy for is NOT shown. It used to fall back
      // to the payload itself, and the owner caught what that looks like in the
      // field — a toast over the dashboard reading:
      //
      //   🇩🇪 Германия 🎮 failed to get the second response from
      //   http://meow.dropweb.org:8090/health: Head "...": context canceled
      //
      // That is a health probe of the 🎵 Meowzic fallback group failing on one
      // node, which is ROUTINE — the group probes every 60s precisely so a
      // flagged node can be stepped over, and a probe failing is the mechanism
      // working, not a fault. Even when the underlying error is real, a Go
      // error string is untranslated, names internal hosts, and tells the
      // listener nothing they can act on.
      //
      // Nothing is lost: every core error still reaches `logsProvider` and the
      // log file above. What changes is that the user stops being the fallback
      // renderer for diagnostics we have not triaged. When a core error IS
      // worth telling somebody about, it earns a pattern in [ErrorMapper] and
      // human copy with it.
      if (message != null) globalState.showNotifier(message);
    }
    super.onLog(log);
  }

  @override
  Future<void> onRequest(Connection connection) async {
    ref.read(requestsProvider.notifier).addRequest(connection);
    super.onRequest(connection);
  }

  @override
  Future<void> onLoaded(String providerName) async {
    ref.read(providersProvider.notifier).setProvider(
          await clashCore.getExternalProvider(
            providerName,
          ),
        );
    globalState.appController.updateGroupsDebounce();
    super.onLoaded(providerName);
  }

  @override
  void onTun(Map<String, dynamic> data) {
    super.onTun(data);
    final status = data['status']?.toString();
    if (status == 'ready') {
      // null error == TUN listener is up; honest connected state can proceed.
      globalState.completeTunAck(null);
    } else if (status == 'error') {
      final message = data['message']?.toString() ?? 'tun error';
      globalState.completeTunAck(message);
    } else {
      commonPrint.log('onTun: unexpected status payload: $data');
    }
    // If no start transition is in flight, completeTunAck() is a no-op — a late
    // TUN status (e.g. tunnel death, not currently emitted) just gets logged.
  }
}
