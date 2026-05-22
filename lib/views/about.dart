import 'dart:io';
import 'dart:math' as math;

import 'package:dropweb/common/common.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Whether the About page should show the manual "Check for updates" entry.
///
/// Android is the Google Play target: Play policy requires app updates to
/// ship through the store, so the in-app GitHub-driven update check must
/// stay hidden there. Desktop and other non-Play targets continue to ship
/// signed binaries from GitHub releases, so the manual check stays
/// available on those platforms.
///
/// [isAndroid] is injected so this helper stays testable without mocking
/// `Platform`; production callers pass `Platform.isAndroid`.
@visibleForTesting
bool shouldShowCheckForUpdate({required bool isAndroid}) => !isAndroid;

@immutable
class Contributor {
  const Contributor({
    required this.name,
    required this.avatar,
    required this.role,
    this.link,
  });
  final String name;
  final String avatar;
  final String role;
  final String? link;
}

// Order = order shown in the credits sheet.
const _credits = <Contributor>[
  Contributor(
    name: 'chen08209',
    avatar: 'assets/images/avatars/chen08209.jpg',
    role: 'Original FlClash author',
    link: 'https://github.com/chen08209',
  ),
  Contributor(
    name: 'pluralplay',
    avatar: 'assets/images/avatars/pluralplay.jpg',
    role: 'FlClashX maintainer',
    link: 'https://github.com/pluralplay',
  ),
  Contributor(
    name: 'kastov',
    avatar: 'assets/images/avatars/kastov.jpg',
    role: 'contributor',
    link: 'https://github.com/kastov',
  ),
  Contributor(
    name: 'x_kit_',
    avatar: 'assets/images/avatars/x_kit_.jpg',
    role: 'contributor',
    link: 'https://github.com/this-xkit',
  ),
  Contributor(
    name: 'katsukibtw',
    avatar: 'assets/images/avatars/katsukibtw.jpg',
    role: 'contributor',
    link: 'https://github.com/katsukibtw',
  ),
  Contributor(
    name: 'cool_coala',
    avatar: 'assets/images/avatars/cool_coala.jpg',
    role: 'contributor',
  ),
  Contributor(
    name: 'arpic',
    avatar: 'assets/images/avatars/arpic.jpg',
    role: 'contributor',
  ),
  Contributor(
    name: 'legiz',
    avatar: 'assets/images/avatars/legiz.jpg',
    role: 'contributor',
  ),
];

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  Future<void> _checkUpdate(BuildContext context) async {
    final commonScaffoldState = context.commonScaffoldState;
    if (commonScaffoldState?.mounted != true) return;
    final data = await commonScaffoldState?.loadingRun<Map<String, dynamic>?>(
      request.checkForUpdate,
      title: appLocalizations.checkUpdate,
    );
    globalState.appController.checkUpdateResultHandle(
      data: data,
      handleError: true,
    );
  }

  List<Widget> _buildMoreSection(BuildContext context) {
    final items = <Widget>[
      // "Thanks" is now a single tappable entry that opens a full credits
      // sheet — no parade of avatars on the main About page.
      ListItem(
        leading: HugeIcon(icon: HugeIcons.strokeRoundedFavourite, size: 24),
        title: Text(appLocalizations.gratitude),
        onTap: () => _showCreditsSheet(context),
        trailing: HugeIcon(icon: HugeIcons.strokeRoundedLink01, size: 24),
      ),
      // Hidden on Android (Play target) — updates ship through Google Play
      // there. Other platforms continue to fetch from GitHub releases. See
      // [shouldShowCheckForUpdate] for the policy.
      if (shouldShowCheckForUpdate(isAndroid: Platform.isAndroid))
        ListItem(
          title: Text(appLocalizations.checkUpdate),
          onTap: () => _checkUpdate(context),
          trailing: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 24),
        ),
      ListItem(
        title: Text(appLocalizations.project),
        onTap: () => globalState.openUrl("https://github.com/$repository"),
        trailing: HugeIcon(icon: HugeIcons.strokeRoundedLink01, size: 24),
      ),
      ListItem(
        title: Text(appLocalizations.originalRepository),
        onTap: () => globalState.openUrl(
          "https://github.com/pluralplay/FlClashX",
        ),
        trailing: HugeIcon(icon: HugeIcons.strokeRoundedLink01, size: 24),
      ),
      ListItem(
        title: Text(appLocalizations.core),
        onTap: () => globalState.openUrl(
          "https://github.com/MetaCubeX/mihomo",
        ),
        trailing: HugeIcon(icon: HugeIcons.strokeRoundedLink01, size: 24),
      ),
    ];
    return generateSection(
      separated: false,
      title: appLocalizations.more,
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

// -----------------------------------------------------------------------
// App header: tap anywhere on the logo + name block to flip 3D and swap
// between dropweb icon / name and the author's avatar / handle "kinvsh".
// -----------------------------------------------------------------------

class _AppHeader extends StatefulWidget {
  const _AppHeader();

  @override
  State<_AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<_AppHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _flip;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flip = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.isAnimating) return;
    if (_controller.value >= 0.5) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  // Open the front-face primary link: project repo.
  void _openFrontPrimary() => globalState.openUrl(
        'https://github.com/$repository',
      );

  // Open the back-face primary link: author's github.
  void _openBackPrimary() => globalState.openUrl(
        'https://github.com/enkinvsh',
      );

  // Open the back-face secondary link: project landing page.
  void _openBackSecondary() => globalState.openUrl('https://dropweb.org');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: _flip,
      builder: (_, __) {
        final t = _flip.value;
        final angle = t * math.pi;
        final showFront = t < 0.5;

        // Avatar / logo column — tap toggles flip.
        final avatar = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: showFront
                ? Image.asset(
                    'assets/images/icon.png',
                    width: 64,
                    height: 64,
                  )
                : ClipOval(
                    child: Image.asset(
                      'assets/images/avatars/enkinvsh.jpg',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
        );

        // Text column — each line is its own tap target opening a link.
        final textColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: showFront ? _openFrontPrimary : _openBackPrimary,
              child: Text(
                showFront ? appName : 'kinvsh',
                style: textTheme.headlineSmall,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: showFront ? _openFrontPrimary : _openBackSecondary,
              child: Text(
                showFront ? globalState.packageInfo.version : 'dropweb',
                style: textTheme.labelLarge?.copyWith(
                  decoration: showFront ? null : TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (showFront) const _CoreVersionWidget(),
          ],
        );

        Widget face = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            avatar,
            const SizedBox(width: 4),
            textColumn,
          ],
        );

        // Back face is counter-rotated so its content isn't mirrored.
        if (!showFront) {
          face = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: face,
          );
        }

        return Align(
          alignment: Alignment.centerLeft,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: face,
          ),
        );
      },
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

// -----------------------------------------------------------------------
// Credits sheet — full list with avatars + roles + links, opened only
// when the user explicitly taps "Благодарность" in the About menu.
// -----------------------------------------------------------------------

void _showCreditsSheet(BuildContext context) {
  showSheet(
    context: context,
    builder: (_, type) => AdaptiveSheetScaffold(
      type: type,
      title: appLocalizations.gratitude,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              // kinvsh is shown as the flip-side of the dropweb logo header,
              // not in the credits grid.
              for (final c in _credits)
                SizedBox(
                  width: 80,
                  child: _CreditAvatar(person: c),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CreditAvatar extends StatelessWidget {
  const _CreditAvatar({required this.person});
  final Contributor person;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        if (person.link != null) globalState.openUrl(person.link!);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            foregroundImage: AssetImage(person.avatar),
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              person.name[0].toUpperCase(),
              style: TextStyle(
                fontFamily: 'Onest',
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            person.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Onest',
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            person.role,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Onest',
              fontSize: 9,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

