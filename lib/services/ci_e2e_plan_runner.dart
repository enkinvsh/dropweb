import 'dart:async';
import 'dart:io';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/services/ci_e2e_plan.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> runCiE2ePlan(String planPath, WidgetRef ref) async {
  CiE2ePlan? plan;
  try {
    plan = CiE2ePlan.parse(await File(planPath).readAsString());
    final bootstrapFailure = await _waitForBootstrap(plan);
    final result = bootstrapFailure ??
        await CiE2ePlanExecutor(
          appVersion:
              '${globalState.packageInfo.version}+${globalState.packageInfo.buildNumber}',
          stepFunctions: {
            CiE2eOperation.importUrl: (step) => _importUrl(step, ref),
            CiE2eOperation.connect: (step) => _connect(step, ref),
            CiE2eOperation.waitFile: runCiE2eWaitFile,
            CiE2eOperation.buildSupportBundle: (step) =>
                _buildSupportBundle(step, ref),
            CiE2eOperation.disconnect: (_) => _disconnect(ref),
          },
        ).execute(plan);
    await writeCiE2eResultAtomically(plan.resultPath, result);
    if (plan.exitAfter) await globalState.appController.handleExit();
  } on CiE2ePlanException catch (error) {
    await _writeInvalidPlan(error);
    await _finishInvalidPlan(error.exitAfter);
  } catch (error) {
    await _writeBoundaryFailure(plan);
    commonPrint.log('[ci-e2e] hook failed (${error.runtimeType})');
    if (plan?.exitAfter == true) {
      await globalState.appController.handleExit();
    } else if (plan == null) {
      await _finishInvalidPlan(null);
    }
  }
}

Future<CiE2ePlanResult?> _waitForBootstrap(
  CiE2ePlan plan,
) async {
  var scaffoldMounted = false;
  var coreReady = false;
  try {
    await globalState.appController
        .waitForImportScaffold()
        .timeout(plan.stepTimeout);
    scaffoldMounted = true;
    await clashCore.ensureCoreReady(timeout: plan.stepTimeout);
    coreReady = true;
    return null;
  } catch (_) {
    final op = plan.steps.isEmpty ? 'plan' : plan.steps.first.opName;
    return CiE2ePlanResult(
      result: CiE2eResultStatus.fail,
      firstFailure: '$op:bootstrap',
      steps: [
        CiE2eStepResult(
          op: op,
          status: CiE2eStepStatus.fail,
          durationMs: 0,
          checks: {
            'homeScaffoldMounted': scaffoldMounted,
            'coreReady': coreReady,
          },
          detail: 'normal bootstrap did not become ready',
        ),
      ],
      appVersion:
          '${globalState.packageInfo.version}+${globalState.packageInfo.buildNumber}',
      ports: const {},
    );
  }
}

Future<CiE2eStepOutcome> _importUrl(
  CiE2ePlanStep step,
  WidgetRef ref,
) async {
  final attemptId = DateTime.now().microsecondsSinceEpoch;
  final marker = '[ci-e2e] import-start $attemptId';
  final endMarker = '[ci-e2e] import-end $attemptId';
  final previousIds =
      ref.read(profilesProvider).map((profile) => profile.id).toSet();
  commonPrint.log(marker);
  final url = (await File(step.urlFile!).readAsString()).trim();
  await globalState.appController.addProfileFormURL(url);
  commonPrint.log(endMarker);

  final current = ref.read(currentProfileProvider);
  final resolvedUrl =
      current == null ? null : await preferences.getProfileUrl(current);
  final currentHost = Uri.tryParse(resolvedUrl ?? '')?.host.toLowerCase();
  final journalChecks = evaluateCiE2eImportJournal(
    await _journalSnapshot(ref, phase: 'ci-e2e-import'),
    marker,
    endMarker: endMarker,
  );
  final checks = <String, Object?>{
    'currentProfileExists': current != null,
    'currentProfileIsNew': current != null && !previousIds.contains(current.id),
    'subscriptionHostMatches': currentHost == step.expectHost,
    'profileValidated': current?.lastUpdateDate != null,
    ...journalChecks,
  };
  final failedCheck = checks.entries
      .where((entry) => entry.value != true)
      .map((entry) => entry.key)
      .firstOrNull;
  if (failedCheck != null) {
    return CiE2eStepOutcome.fail(
      failedCheck: failedCheck,
      checks: checks,
      detail: 'import verification failed',
    );
  }
  return CiE2eStepOutcome.pass(checks: checks);
}

Future<CiE2eStepOutcome> _connect(
  CiE2ePlanStep step,
  WidgetRef ref,
) async {
  final marker =
      '[ci-e2e] connect-start ${DateTime.now().microsecondsSinceEpoch}';
  commonPrint.log(marker);
  final requestedTun = ref.read(patchClashConfigProvider).tun.enable;
  await globalState.appController.updateStatus(true);
  final patchConfig = ref.read(patchClashConfigProvider);
  final mixedListening = await _isListening(patchConfig.mixedPort);
  final socksListening = await _isListening(patchConfig.socksPort);
  final journal = await _journalSnapshot(ref, phase: 'ci-e2e-connect');
  final attempt = journal.contains(marker)
      ? journal.substring(journal.indexOf(marker))
      : '';

  return CiE2eStepOutcome.pass(
    checks: {
      'expectTun': step.expectTun,
      'tunRequested': requestedTun,
      'tunEffective': ref.read(realTunEnableProvider),
      'tunListenerFailed':
          attempt.toLowerCase().contains('tun listener failed'),
      'startCompleted': globalState.isStart,
      'mixedListening': mixedListening,
      'socksListening': socksListening,
    },
    ports: {
      'mixed': patchConfig.mixedPort,
      'socks': patchConfig.socksPort,
    },
    detail: 'connection observations recorded',
  );
}

Future<CiE2eStepOutcome> _disconnect(WidgetRef ref) async {
  final patchConfig = ref.read(patchClashConfigProvider);
  await globalState.appController.updateStatus(false);
  final mixedClosed = !await _isListening(patchConfig.mixedPort);
  final socksClosed = !await _isListening(patchConfig.socksPort);
  final checks = <String, Object?>{
    'teardownCompleted': !globalState.isStart,
    'mixedListenerClosed': mixedClosed,
    'socksListenerClosed': socksClosed,
  };
  final failedCheck = checks.entries
      .where((entry) => entry.value != true)
      .map((entry) => entry.key)
      .firstOrNull;
  if (failedCheck != null) {
    return CiE2eStepOutcome.fail(
      failedCheck: failedCheck,
      checks: checks,
      detail: 'disconnect teardown was incomplete',
    );
  }
  return CiE2eStepOutcome.pass(checks: checks);
}

Future<CiE2eStepOutcome> _buildSupportBundle(
  CiE2ePlanStep step,
  WidgetRef ref,
) async {
  final bundle = await fileLogger.buildSupportBundle(
    appVersion:
        '${globalState.packageInfo.version}+${globalState.packageInfo.buildNumber}',
    inAppLines: _inAppLines(ref),
    phase: 'ci-e2e',
    operatingSystem: Platform.operatingSystem,
  );
  final output = File(step.outPath!);
  await output.parent.create(recursive: true);
  await output.writeAsString(bundle, flush: true);
  return CiE2eStepOutcome.pass(
    checks: {
      'bundleWritten': output.existsSync(),
      'bundleNonEmpty': bundle.isNotEmpty,
    },
  );
}

Future<String> _journalSnapshot(WidgetRef ref, {required String phase}) =>
    fileLogger.buildSupportBundle(
      appVersion:
          '${globalState.packageInfo.version}+${globalState.packageInfo.buildNumber}',
      inAppLines: _inAppLines(ref),
      phase: phase,
      operatingSystem: Platform.operatingSystem,
    );

List<String> _inAppLines(WidgetRef ref) => ref
    .read(logsProvider)
    .list
    .map((log) => log.toString())
    .toList(growable: false);

Future<bool> _isListening(int port) async {
  if (port <= 0) return false;
  try {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      port,
      timeout: const Duration(seconds: 2),
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> _writeInvalidPlan(CiE2ePlanException error) async {
  final resultPath = error.resultPath;
  if (resultPath == null) return;
  try {
    await writeCiE2eJsonAtomically(resultPath, planInvalidResult(error));
  } catch (_) {}
}

Future<void> _writeBoundaryFailure(CiE2ePlan? plan) async {
  if (plan == null) return;
  try {
    await writeCiE2eResultAtomically(
      plan.resultPath,
      CiE2ePlanResult(
        result: CiE2eResultStatus.fail,
        firstFailure: 'hook:exception',
        steps: const [],
        appVersion:
            '${globalState.packageInfo.version}+${globalState.packageInfo.buildNumber}',
        ports: const {},
      ),
    );
  } catch (_) {}
}

Future<void> _finishInvalidPlan(bool? exitAfter) async {
  if (exitAfter == false) return;
  if (exitAfter == true) {
    await globalState.appController.handleExit();
    return;
  }
  try {
    await clashCore.shutdown().timeout(const Duration(seconds: 5));
  } catch (_) {}
  exit(1);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
