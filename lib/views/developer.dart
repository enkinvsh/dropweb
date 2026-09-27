import 'dart:convert';

import 'package:dropweb/clash/core.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/diagnostics.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/providers/state.dart';
import 'package:dropweb/services/diagnostics_service.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

Future<void> _copy(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  globalState.showNotifier(appLocalizations.copySuccess);
}

class DeveloperView extends ConsumerWidget {
  const DeveloperView({super.key});

  Future<void> _takeDiagnostics(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    await globalState.safeRun(() async {
      final result = await DiagnosticsService.writeAll(container);
      final fileName = result.diagPath.split('/').last;
      // Same save-as flow as controller.exportLogs.
      final saved = await picker.saveFile(
        fileName,
        Uint8List.fromList(utf8.encode(result.text)),
      );
      globalState.showNotifier(
        appLocalizations.devDiagnosticsWritten(saved ?? result.diagPath),
      );
    });
  }

  Widget _diagnosticsSection(BuildContext context) => generateSectionV2(
        title: appLocalizations.devDiagnostics,
        items: [
          Semantics(
            identifier: 'dw_dev_diag',
            child: ListItem(
              title: Text(appLocalizations.devTakeDiagnostics),
              onTap: () => _takeDiagnostics(context),
            ),
          ),
          Semantics(
            identifier: 'dw_dev_config',
            child: ListItem.open(
              title: Text(appLocalizations.devEffectiveConfig),
              delegate: OpenDelegate(
                title: appLocalizations.devEffectiveConfig,
                titleBuilder: (context) =>
                    AppLocalizations.of(context).devEffectiveConfig,
                widget: const _EffectiveConfigViewer(),
                action: IconButton(
                  tooltip: appLocalizations.devCopyAll,
                  onPressed: () async {
                    final text = DiagnosticsService.redactedConfigJson();
                    if (text != null) await _copy(text);
                  },
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCopy01,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            identifier: 'dw_dev_headers',
            child: ListItem.open(
              title: Text(appLocalizations.devSubscriptionHeaders),
              delegate: OpenDelegate(
                title: appLocalizations.devSubscriptionHeaders,
                titleBuilder: (context) =>
                    AppLocalizations.of(context).devSubscriptionHeaders,
                widget: const _HeadersViewer(),
                action: const _CopyAllHeadersButton(),
              ),
            ),
          ),
        ],
      );

  Widget _adbSection(BuildContext context) {
    final pkg = globalState.packageInfo.packageName;
    final command =
        'adb shell am broadcast -p $pkg -a $pkg.DEBUG --es cmd help';
    return generateSectionV2(
      title: appLocalizations.devAdbRemote,
      items: [
        Semantics(
          identifier: 'dw_dev_adb',
          child: ListItem(
            title: Text(
              command,
              style: context.textTheme.bodyMedium?.toJetBrainsMono,
            ),
            subtitle: Text(appLocalizations.devAdbRemoteReplies),
            trailing: const HugeIcon(
              icon: HugeIcons.strokeRoundedCopy01,
              size: 20,
            ),
            onTap: () => _copy(command),
          ),
        ),
      ],
    );
  }

  Widget _otherSection() => generateSectionV2(
        title: appLocalizations.other,
        items: [
          if (!kIsPlayBuild)
            Semantics(
              identifier: 'dw_dev_crash',
              child: ListItem(
                title: Text(appLocalizations.crashTest),
                onTap: () {
                  clashCore.clashInterface.crash();
                },
              ),
            ),
          Semantics(
            identifier: 'dw_dev_clear',
            child: ListItem(
              title: Text(appLocalizations.clearData),
              onTap: () async {
                await globalState.appController.handleClear();
              },
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enable = ref.watch(
      appSettingProvider.select(
        (state) => state.developerMode,
      ),
    );
    return SingleChildScrollView(
      padding: baseInfoEdgeInsets,
      child: Column(
        children: [
          CommonCard(
            type: CommonCardType.filled,
            radius: 18,
            child: ListItem.switchItem(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
              ),
              title: Text(appLocalizations.developerMode),
              delegate: SwitchDelegate(
                value: enable,
                onChanged: (value) {
                  ref.read(appSettingProvider.notifier).updateState(
                        (state) => state.copyWith(
                          developerMode: value,
                        ),
                      );
                },
              ),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          _diagnosticsSection(context),
          if (!kIsPlayBuild) ...[
            const SizedBox(height: 16),
            _adbSection(context),
          ],
          const SizedBox(height: 16),
          _otherSection(),
        ],
      ),
    );
  }
}

/// Read-only, redacted pretty JSON of the last config handed to the core.
class _EffectiveConfigViewer extends StatelessWidget {
  const _EffectiveConfigViewer();

  @override
  Widget build(BuildContext context) {
    final text = DiagnosticsService.redactedConfigJson();
    if (text == null) {
      return NullStatus(label: appLocalizations.devEffectiveConfigEmpty);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        text,
        style: context.textTheme.bodySmall?.toJetBrainsMono,
      ),
    );
  }
}

/// Current profile's subscription response headers, URL tokens redacted.
/// Tap a row to copy its value.
class _HeadersViewer extends ConsumerWidget {
  const _HeadersViewer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = redactHeadersForDiagnostics(
      ref.watch(currentProfileProvider)?.providerHeaders ?? const {},
    );
    if (headers.isEmpty) {
      return NullStatus(label: appLocalizations.noData);
    }
    final entries = headers.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListItem(
          title: Text(entry.key),
          subtitle: Text(
            entry.value,
            style: context.textTheme.bodySmall?.toJetBrainsMono,
          ),
          onTap: () => _copy(entry.value),
        );
      },
    );
  }
}

class _CopyAllHeadersButton extends StatelessWidget {
  const _CopyAllHeadersButton();

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: appLocalizations.devCopyAll,
        onPressed: () => _copy(
          DiagnosticsService.redactedHeadersText(
            ProviderScope.containerOf(context, listen: false),
          ),
        ),
        icon: const HugeIcon(icon: HugeIcons.strokeRoundedCopy01, size: 24),
      );
}
