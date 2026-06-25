import 'package:dropweb/common/common.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Whether the About page should show the manual "Check for updates" entry.
/// [isAndroid]/[isPlayBuild] are injected so this helper stays testable
/// without mocking `Platform`; production callers pass `Platform.isAndroid`.
@visibleForTesting
bool shouldShowCheckForUpdate({
  required bool isAndroid,
  bool isPlayBuild = kIsPlayBuild,
}) =>
    !isAndroid || !isPlayBuild;

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  List<Widget> _buildMoreSection(BuildContext context) {
    final items = <Widget>[
      ListItem(
        title: Text(appLocalizations.project),
        onTap: () => globalState.openUrl("https://github.com/$repository"),
        trailing: HugeIcon(icon: HugeIcons.strokeRoundedLink01, size: 24),
      ),
      ListItem(
        title: Text(appLocalizations.privacyPolicy),
        onTap: () => globalState.openUrl("https://dropweb.org/privacy"),
        trailing: HugeIcon(icon: HugeIcons.strokeRoundedLink01, size: 24),
      ),
    ];
    return generateSection(
      separated: false,
      // "More" header dropped: with updates + donations moved into Settings,
      // only the project + privacy links remain here — no grouping needed.
      title: null,
      items: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AppHeader(),
            const SizedBox(height: 24),
            Text(
              appLocalizations.desc,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              "Open-source VPN client, GPL-3.0 licensed",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ..._buildMoreSection(context),
    ];
    return Padding(
      padding: kMaterialListPadding.copyWith(top: 16, bottom: 16),
      child: generateListView(items),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            'assets/images/icon.png',
            width: 64,
            height: 64,
          ),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(appName, style: textTheme.headlineSmall),
            Text(
              globalState.packageInfo.version,
              style: textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            const _CoreVersionWidget(),
          ],
        ),
      ],
    );
  }
}

class _CoreVersionWidget extends StatelessWidget {
  const _CoreVersionWidget();

  @override
  Widget build(BuildContext context) {
    final coreVersion = globalState.coreVersion;
    if (coreVersion == null || coreVersion.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      'Core: $coreVersion',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}
