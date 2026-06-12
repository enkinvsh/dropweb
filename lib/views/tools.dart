import 'dart:async';
import 'dart:io';

import 'package:dropweb/common/access_control_visibility.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/about.dart';
import 'package:dropweb/views/access.dart';
import 'package:dropweb/views/application_setting.dart';
import 'package:dropweb/views/config/config.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' show dirname, join;

import 'developer.dart';
import 'theme.dart';

class ToolsView extends ConsumerStatefulWidget {
  const ToolsView({super.key});

  @override
  ConsumerState<ToolsView> createState() => _ToolboxViewState();
}

class _ToolboxViewState extends ConsumerState<ToolsView> {
  ListItem<dynamic> _buildNavigationMenuItem(NavigationItem navigationItem) =>
      ListItem.open(
        leading: navigationItem.icon,
        title: Text(Intl.message(navigationItem.label.name)),
        delegate: OpenDelegate(
          title: Intl.message(navigationItem.label.name),
          titleBuilder: (context) {
            // Subscribe to Localizations so the pushed page re-resolves its
            // header when the app language changes.
            Localizations.localeOf(context);
            return Intl.message(navigationItem.label.name);
          },
          widget: navigationItem.view,
        ),
      );

  Widget _buildNavigationMenu(List<NavigationItem> navigationItems) => Column(
        children: [
          for (final navigationItem in navigationItems) ...[
            _buildNavigationMenuItem(navigationItem),
            navigationItems.last != navigationItem
                ? const Divider(
                    height: 0,
                  )
                : Container(),
          ]
        ],
      );

  List<Widget> _getOtherList(BuildContext context, bool enableDeveloperMode) =>
      generateSection(
        title: AppLocalizations.of(context).other,
        items: [
          const _DisclaimerItem(),
          if (enableDeveloperMode) const _DeveloperItem(),
          const _InfoItem(),
        ],
      );

  List<Widget> _getSettingList(
    BuildContext context,
    bool enableDeveloperMode,
  ) =>
      generateSection(
        title: null,
        items: [
          const _LocaleItem(),
          const _ThemeItem(),
          if (Platform.isAndroid) const AlwaysOnVpnItem(),
          // Hotkey Management entry was removed for the Play readiness
          // wave together with the runtime global-hotkey registration
          // (see `Application._buildPlatformState`). The `HotKeyView`
          // source and persisted bindings remain on disk so the entry
          // can be re-introduced cleanly when we ship a curated set.
          if (Platform.isWindows) const _LoopbackItem(),
          // Access Control / per-app proxy is an advanced Android surface
          // (installed-package enumeration + split-tunnel rules). Hidden by
          // default on the Play target and only re-exposed after the
          // existing developer-mode unlock — matches `_ConfigItem` /
          // `_SettingItem` gating below. See `shouldShowAccessControl`.
          if (shouldShowAccessControl(
            isAndroid: Platform.isAndroid,
            developerMode: enableDeveloperMode,
          ))
            const _AccessItem(),
          // The settings-page Connect TV / Send to TV entry only ever
          // lived on Android. Android (Play target) now hides the
          // Send to TV / LAN subscription-sharing flow entirely (see
          // `shouldShowSendToTv`), so the menu item is dropped here.
          if (enableDeveloperMode) const _ConfigItem(),
          if (enableDeveloperMode) const _SettingItem(),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final vm2 = ref.watch(
      appSettingProvider.select(
        (state) => VM2(a: state.locale, b: state.developerMode),
      ),
    );
    final appLocale = AppLocalizations.of(context);
    final items = [
      Consumer(
        builder: (_, ref, __) {
          final state = ref.watch(moreToolsSelectorStateProvider);
          if (state.navigationItems.isEmpty) {
            return Container();
          }
          return Column(
            children: [
              ListHeader(title: appLocale.more),
              _buildNavigationMenu(state.navigationItems)
            ],
          );
        },
      ),
      ..._getSettingList(context, vm2.b),
      ..._getOtherList(context, vm2.b),
    ];
    // Bottom nav-bar (64px) + its 16px outer margin + system gesture
    // inset — leave enough space so the last list item doesn't sit
    // under the floating nav bar (visible after dev-mode unlocks extra
    // entries that push the list past the viewport).
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, index) => items[index],
      padding: EdgeInsets.only(bottom: 96 + bottomInset),
    );
  }
}

class _LocaleItem extends ConsumerWidget {
  const _LocaleItem();

  String _getLocaleString(BuildContext context, Locale? locale) {
    if (locale == null) return AppLocalizations.of(context).defaultText;
    return Intl.message(locale.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocale = AppLocalizations.of(context);
    final locale =
        ref.watch(appSettingProvider.select((state) => state.locale));
    final currentLocale = utils.getLocaleForString(locale);
    return ListItem<Locale?>.options(
      leading: const HugeIcon(icon: HugeIcons.strokeRoundedGlobe02, size: 24),
      title: Text(appLocale.language),
      delegate: OptionsDelegate(
        title: appLocale.language,
        titleBuilder: (context) => AppLocalizations.of(context).language,
        options: [null, ...AppLocalizations.delegate.supportedLocales],
        onChanged: (locale) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(locale: locale?.toString()),
              );
        },
        textBuilder: (locale) => _getLocaleString(context, locale),
        value: currentLocale,
      ),
    );
  }
}

class _ThemeItem extends StatelessWidget {
  const _ThemeItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const HugeIcon(icon: HugeIcons.strokeRoundedEdgeStyle, size: 24),
      title: Text(appLocale.theme),
      delegate: OpenDelegate(
        title: appLocale.theme,
        titleBuilder: (context) => AppLocalizations.of(context).theme,
        widget: const ThemeView(),
      ),
    );
  }
}

class _LoopbackItem extends StatelessWidget {
  const _LoopbackItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem(
      leading:
          const HugeIcon(icon: HugeIcons.strokeRoundedLockPassword, size: 24),
      title: Text(appLocale.loopback),
      onTap: () {
        windows?.runas(
          '"${join(dirname(Platform.resolvedExecutable), "EnableLoopback.exe")}"',
          "",
        );
      },
    );
  }
}

class _AccessItem extends StatelessWidget {
  const _AccessItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const HugeIcon(icon: HugeIcons.strokeRoundedListView, size: 24),
      title: Text(appLocale.accessControl),
      delegate: OpenDelegate(
        title: appLocale.accessControl,
        titleBuilder: (context) => AppLocalizations.of(context).accessControl,
        widget: const AccessView(),
      ),
    );
  }
}

class _ConfigItem extends StatelessWidget {
  const _ConfigItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const HugeIcon(icon: HugeIcons.strokeRoundedEdit01, size: 24),
      title: Text(appLocale.basicConfig),
      delegate: OpenDelegate(
        title: appLocale.override,
        titleBuilder: (context) => AppLocalizations.of(context).override,
        widget: const ConfigView(),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  const _SettingItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const HugeIcon(icon: HugeIcons.strokeRoundedSettings02, size: 24),
      title: Text(appLocale.application),
      delegate: OpenDelegate(
        title: appLocale.application,
        titleBuilder: (context) => AppLocalizations.of(context).application,
        widget: const ApplicationSettingView(),
      ),
    );
  }
}

class _DisclaimerItem extends StatelessWidget {
  const _DisclaimerItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem(
      leading:
          const HugeIcon(icon: HugeIcons.strokeRoundedLegalHammer, size: 24),
      title: Text(appLocale.disclaimer),
      onTap: () async {
        final isDisclaimerAccepted =
            await globalState.appController.showDisclaimer();
        if (!isDisclaimerAccepted) {
          unawaited(globalState.appController.handleExit());
        }
      },
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading:
          const HugeIcon(
              icon: HugeIcons.strokeRoundedInformationCircle, size: 24),
      title: Text(appLocale.about),
      delegate: OpenDelegate(
        title: appLocale.about,
        titleBuilder: (context) => AppLocalizations.of(context).about,
        widget: const AboutView(),
      ),
    );
  }
}

class _DeveloperItem extends StatelessWidget {
  const _DeveloperItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const HugeIcon(icon: HugeIcons.strokeRoundedCpu, size: 24),
      title: Text(appLocale.developerMode),
      delegate: OpenDelegate(
        title: appLocale.developerMode,
        titleBuilder: (context) => AppLocalizations.of(context).developerMode,
        widget: const DeveloperView(),
      ),
    );
  }
}


