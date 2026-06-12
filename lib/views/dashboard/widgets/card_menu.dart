import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/dev_unlock_counter.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/cabinet/cabinet_browser_entry.dart';
import 'package:dropweb/views/tools.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

// Developer-mode unlock counter for 5 rapid taps on the Settings sheet
// title. Module-level so the streak survives across both menu entry points
// (the subscription card icon and the dashboard swipe-up gesture) within a
// single app session; the 3-second window inside `DevUnlockCounter`
// self-resets stale streaks.
final DevUnlockCounter _devUnlockCounter = DevUnlockCounter();

/// Opens the shared subscription-card menu modal.
///
/// Derives the personal-cabinet URL and support URL from the active profile
/// (the same providers/fields `MetainfoWidget.build` reads) and shows the
/// existing [CommonDialog] with the conditional rows: Личный кабинет,
/// Поддержка, Настройки. Callable from anywhere with a [BuildContext] and a
/// [WidgetRef] — used by both the card menu icon and the dashboard swipe-up
/// gesture.
Future<void> showCardMenu(BuildContext context, WidgetRef ref) {
  final currentProfile = ref.read(currentProfileProvider);
  final cabinetUri = profileCabinetUri(currentProfile);
  final headers = currentProfile?.providerHeaders ?? const {};
  final supportUrl = headers['support-url'];
  final hasSupport = supportUrl != null && supportUrl.isNotEmpty;

  return globalState.showCommonDialog<void>(
    child: CommonDialog(
      title: '',
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cabinetUri != null)
            _buildMenuRow(
              icon: HugeIcons.strokeRoundedUserCircle,
              label: appLocalizations.personalCabinet,
              onTap: () {
                Navigator.of(context).pop();
                openCabinetBrowser(cabinetUri);
              },
            ),
          if (hasSupport)
            _buildMenuRow(
              icon: supportUrl.toLowerCase().contains('t.me')
                  ? HugeIcons.strokeRoundedTelegram
                  : HugeIcons.strokeRoundedCustomerSupport,
              label: appLocalizations.support,
              onTap: () {
                Navigator.of(context).pop();
                globalState.openUrl(supportUrl);
              },
            ),
          if (currentProfile != null)
            _buildMenuRow(
              icon: HugeIcons.strokeRoundedRefresh,
              label: appLocalizations.updateSubscription,
              onTap: () {
                Navigator.of(context).pop();
                final appController = globalState.appController;
                final profile = currentProfile;
                // No `profile.type` guard (see profiles.dart updateProfile):
                // post-migration `type` reports `file` for URL subs, which
                // would silently no-op. update() throws if there's truly no URL.
                globalState.safeRun(silence: false, () async {
                  try {
                    appController
                        .setProfile(profile.copyWith(isUpdating: true));
                    await appController.updateProfile(profile);
                  } catch (e) {
                    appController
                        .setProfile(profile.copyWith(isUpdating: false));
                    rethrow;
                  }
                });
              },
            ),
          _buildMenuRow(
            icon: HugeIcons.strokeRoundedSettings02,
            label: appLocalizations.tools,
            onTap: () {
              Navigator.of(context).pop();
              _openToolsSheet(context, ref);
            },
          ),
        ],
      ),
    ),
  );
}

Widget _buildMenuRow({
  required List<List<dynamic>> icon,
  required String label,
  required VoidCallback onTap,
}) =>
    ListTile(
      leading: HugeIcon(icon: icon, size: 24),
      title: Text(label),
      onTap: onTap,
    );

void _openToolsSheet(BuildContext context, WidgetRef ref) {
  showExtend(
    context,
    builder: (_, type) => AdaptiveSheetScaffold(
      type: type,
      disableBackground: false,
      body: const ToolsView(),
      title: appLocalizations.tools,
      titleBuilder: (context) => AppLocalizations.of(context).tools,
      onTitleTap: () => _onSettingsTitleTap(ref),
    ),
  );
}

// 5 rapid taps on the Settings screen title unlock developer / advanced
// mode (Access Control, Config, Application settings entries).
void _onSettingsTitleTap(WidgetRef ref) {
  if (!_devUnlockCounter.registerTap()) return;
  final alreadyEnabled = ref.read(appSettingProvider).developerMode;
  if (alreadyEnabled) return;
  ref.read(appSettingProvider.notifier).updateState(
        (state) => state.copyWith(developerMode: true),
      );
  globalState.showNotifier(appLocalizations.developerModeEnableTip);
}
