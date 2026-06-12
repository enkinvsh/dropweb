import 'dart:async';
import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' hide context;

class OpenLogsFolderItem extends ConsumerWidget {
  const OpenLogsFolderItem({super.key});

  Future<void> _openLogsFolder() async {
    try {
      final homePath = await appPath.homeDirPath;
      final logsPath = join(homePath, 'logs');
      final logsDir = Directory(logsPath);

      // Create logs directory if it doesn't exist
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      // Open the folder based on platform
      if (Platform.isWindows) {
        await Process.run('explorer', [logsPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [logsPath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [logsPath]);
      }
    } catch (e) {
      commonPrint.log('Failed to open logs folder: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListItem(
        title: Text(appLocalizations.openLogsFolder),
        leading: HugeIcon(icon: HugeIcons.strokeRoundedFolderOpen, size: 24),
        trailing: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 16),
        onTap: _openLogsFolder,
      );
}

class ResetAppItem extends ConsumerWidget {
  const ResetAppItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListItem(
        title: Text(
          appLocalizations.clearData,
          style: TextStyle(
            color: context.colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: HugeIcon(
          icon: HugeIcons.strokeRoundedDelete01,
          size: 24,
          color: context.colorScheme.error,
        ),
        onTap: () async {
          final res = await globalState.showMessage(
            title: appLocalizations.clearData,
            message: TextSpan(
              text: appLocalizations.clearDataTip,
              style: TextStyle(
                color: context.colorScheme.onSurface,
              ),
            ),
          );
          if (res == true) {
            await globalState.appController.handleClear();
            system.exit();
          }
        },
      );
}

class OverrideProviderSettingsItem extends ConsumerWidget {
  const OverrideProviderSettingsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final overrideProviderSettings = ref.watch(
      appSettingProvider.select((state) => state.overrideProviderSettings),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListItem.switchItem(
          title: Text(appLocalizations.overrideProviderSettings),
          subtitle: Text(appLocalizations.overrideProviderSettingsDesc),
          delegate: SwitchDelegate(
            value: overrideProviderSettings,
            onChanged: (value) {
              ref.read(appSettingProvider.notifier).updateState(
                    (state) => state.copyWith(
                      overrideProviderSettings: value,
                    ),
                  );
            },
          ),
        ),
        if (!overrideProviderSettings)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedInformationCircle,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appLocalizations.managedByProvider,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class CloseConnectionsItem extends ConsumerWidget {
  const CloseConnectionsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final closeConnections = ref.watch(
      appSettingProvider.select((state) => state.closeConnections),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoCloseConnections),
      subtitle: Text(appLocalizations.autoCloseConnectionsDesc),
      delegate: SwitchDelegate(
        value: closeConnections,
        onChanged: (value) async {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  closeConnections: value,
                ),
              );
        },
      ),
    );
  }
}

class UsageItem extends ConsumerWidget {
  const UsageItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final onlyStatisticsProxy = ref.watch(
      appSettingProvider.select((state) => state.onlyStatisticsProxy),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.onlyStatisticsProxy),
      subtitle: Text(appLocalizations.onlyStatisticsProxyDesc),
      delegate: SwitchDelegate(
        value: onlyStatisticsProxy,
        onChanged: (bool value) async {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  onlyStatisticsProxy: value,
                ),
              );
        },
      ),
    );
  }
}

/// Per-color dim for provider-managed (disabled) rows. Replaces a
/// saveLayer-forcing `Opacity(0.5)` wrapper with alpha pushed into the
/// title/subtitle/leading-icon colors (no compositing layer). When [enabled]
/// the record is all-null, so the row renders at full ListTile defaults and
/// the enabled diff is byte-identical to before.
({TextStyle? title, TextStyle? subtitle, Color? icon}) _dimRow(
  BuildContext context,
  bool enabled,
) {
  if (enabled) return (title: null, subtitle: null, icon: null);
  final scheme = context.colorScheme;
  final text = Theme.of(context).textTheme;
  return (
    title: text.bodyLarge?.copyWith(color: scheme.onSurface.opacity50),
    subtitle:
        text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant.opacity50),
    icon: scheme.onSurfaceVariant.opacity50,
  );
}

class MinimizeItem extends ConsumerWidget {
  const MinimizeItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minimizeOnExit = ref.watch(
      appSettingProvider.select((state) => state.minimizeOnExit),
    );
    final overrideProviderSettings = ref.watch(
      appSettingProvider.select((state) => state.overrideProviderSettings),
    );
    final isEnabled = overrideProviderSettings;
    final dim = _dimRow(context, isEnabled);
    return ListItem.switchItem(
      titleTextStyle: dim.title,
      subtitleTextStyle: dim.subtitle,
      title: Text(appLocalizations.minimizeOnExit),
      subtitle: Text(appLocalizations.minimizeOnExitDesc),
      delegate: SwitchDelegate(
        value: minimizeOnExit,
        onChanged: isEnabled
            ? (bool value) {
                ref.read(appSettingProvider.notifier).updateState(
                      (state) => state.copyWith(
                        minimizeOnExit: value,
                      ),
                    );
              }
            : null,
      ),
    );
  }
}

class AutoLaunchItem extends ConsumerWidget {
  const AutoLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoLaunch = ref.watch(
      appSettingProvider.select((state) => state.autoLaunch),
    );
    // Launch-at-login is independent of provider-config overrides; it must
    // stay interactive on every desktop platform (the previous
    // `overrideProviderSettings` gating left the macOS toggle permanently
    // disabled, so login-item registration could never be triggered).
    return ListItem.switchItem(
      title: Text(appLocalizations.autoLaunch),
      subtitle: Text(appLocalizations.autoLaunchDesc),
      delegate: SwitchDelegate(
        value: autoLaunch,
        onChanged: (bool value) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  autoLaunch: value,
                ),
              );
        },
      ),
    );
  }
}

class SilentLaunchItem extends ConsumerWidget {
  const SilentLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final silentLaunch = ref.watch(
      appSettingProvider.select((state) => state.silentLaunch),
    );
    final overrideProviderSettings = ref.watch(
      appSettingProvider.select((state) => state.overrideProviderSettings),
    );
    final isEnabled = overrideProviderSettings;
    final dim = _dimRow(context, isEnabled);
    return ListItem.switchItem(
      titleTextStyle: dim.title,
      subtitleTextStyle: dim.subtitle,
      title: Text(appLocalizations.silentLaunch),
      subtitle: Text(appLocalizations.silentLaunchDesc),
      delegate: SwitchDelegate(
        value: silentLaunch,
        onChanged: isEnabled
            ? (bool value) {
                ref.read(appSettingProvider.notifier).updateState(
                      (state) => state.copyWith(
                        silentLaunch: value,
                      ),
                    );
              }
            : null,
      ),
    );
  }
}

class AutoRunItem extends ConsumerWidget {
  const AutoRunItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoRun = ref.watch(
      appSettingProvider.select((state) => state.autoRun),
    );
    final overrideProviderSettings = ref.watch(
      appSettingProvider.select((state) => state.overrideProviderSettings),
    );
    final isEnabled = overrideProviderSettings;
    final dim = _dimRow(context, isEnabled);
    return ListItem.switchItem(
      titleTextStyle: dim.title,
      subtitleTextStyle: dim.subtitle,
      title: Text(appLocalizations.autoRun),
      subtitle: Text(appLocalizations.autoRunDesc),
      delegate: SwitchDelegate(
        value: autoRun,
        onChanged: isEnabled
            ? (bool value) {
                ref.read(appSettingProvider.notifier).updateState(
                      (state) => state.copyWith(
                        autoRun: value,
                      ),
                    );
              }
            : null,
      ),
    );
  }
}

class HiddenItem extends ConsumerWidget {
  const HiddenItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(
      appSettingProvider.select((state) => state.hidden),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.exclude),
      subtitle: Text(appLocalizations.excludeDesc),
      delegate: SwitchDelegate(
        value: hidden,
        onChanged: (value) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  hidden: value,
                ),
              );
        },
      ),
    );
  }
}

class AlwaysOnVpnItem extends ConsumerWidget {
  const AlwaysOnVpnItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AppLocalizations.of(context) (not the appLocalizations global) so this
    // const-instantiated row registers a Localizations dependency and rebuilds
    // when the app language changes — the global getter alone gives fresh
    // strings only on rebuild, and nothing else rebuilds this row.
    final l10n = AppLocalizations.of(context);
    return ListItem(
      title: Text(l10n.alwaysOnVpn),
      leading: HugeIcon(icon: HugeIcons.strokeRoundedShield01, size: 24),
      trailing: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 16),
      onTap: () async {
        final ok = await app?.openVpnSettings() ?? false;
        if (!ok) {
          globalState.showNotifier(l10n.alwaysOnVpnOpenFailed);
        }
      },
    );
  }
}

class AnimateTabItem extends ConsumerWidget {
  const AnimateTabItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAnimateToPage = ref.watch(
      appSettingProvider.select((state) => state.isAnimateToPage),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.tabAnimation),
      subtitle: Text(appLocalizations.tabAnimationDesc),
      delegate: SwitchDelegate(
        value: isAnimateToPage,
        onChanged: (value) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  isAnimateToPage: value,
                ),
              );
        },
      ),
    );
  }
}

class OpenLogsItem extends ConsumerWidget {
  const OpenLogsItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openLogs = ref.watch(
      appSettingProvider.select((state) => state.openLogs),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.logcat),
      subtitle: Text(appLocalizations.logcatDesc),
      delegate: SwitchDelegate(
        value: openLogs,
        onChanged: (bool value) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  openLogs: value,
                ),
              );
        },
      ),
    );
  }
}

class AutoCheckUpdateItem extends ConsumerWidget {
  const AutoCheckUpdateItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoCheckUpdate = ref.watch(
      appSettingProvider.select((state) => state.autoCheckUpdate),
    );
    final overrideProviderSettings = ref.watch(
      appSettingProvider.select((state) => state.overrideProviderSettings),
    );
    final isEnabled = overrideProviderSettings;
    final dim = _dimRow(context, isEnabled);
    return ListItem.switchItem(
      titleTextStyle: dim.title,
      subtitleTextStyle: dim.subtitle,
      title: Text(appLocalizations.autoCheckUpdate),
      subtitle: Text(appLocalizations.autoCheckUpdateDesc),
      delegate: SwitchDelegate(
        value: autoCheckUpdate,
        onChanged: isEnabled
            ? (bool value) {
                ref.read(appSettingProvider.notifier).updateState(
                      (state) => state.copyWith(
                        autoCheckUpdate: value,
                      ),
                    );
              }
            : null,
      ),
    );
  }
}


class ApplicationSettingView extends StatelessWidget {
  const ApplicationSettingView({super.key});

  String getLocaleString(Locale? locale) {
    if (locale == null) return appLocalizations.defaultText;
    return Intl.message(locale.toString());
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [
      OverrideProviderSettingsItem(),
      MinimizeItem(),
      if (system.isDesktop) ...[
        AutoLaunchItem(),
        SilentLaunchItem(),
      ],
      AutoRunItem(),
      if (Platform.isAndroid) ...[
        HiddenItem(),
      ],
      AnimateTabItem(),
      OpenLogsItem(),
      CloseConnectionsItem(),
      UsageItem(),
      // Android is the Google Play target: in-app GitHub update checks are
      // disabled there (see `shouldRunAutoUpdateCheck`), so the setting
      // would be a misleading no-op.
      if (!Platform.isAndroid) AutoCheckUpdateItem(),
      if (system.isDesktop) ...[
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: OpenLogsFolderItem(),
        ),
      ],
      Padding(
        padding: EdgeInsets.only(top: system.isDesktop ? 0 : 16),
        child: ResetAppItem(),
      ),
    ];
    return ListView.separated(
      itemBuilder: (_, index) => items[index],
      separatorBuilder: (_, __) => const Divider(
        height: 0,
      ),
      itemCount: items.length,
    );
  }
}
