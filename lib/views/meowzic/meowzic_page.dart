import 'package:dropweb/common/common.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// The meowzic screen: search and library behind bottom tabs.
///
/// Built on [CommonScaffold] rather than a bare [Scaffold] so it inherits the
/// house app bar and the Lumina mesh background — a plain Scaffold renders
/// flat black and reads as a different app the moment you arrive from the
/// dashboard.
///
/// Both tabs are empty until something fills them: the Spotify adapter
/// supplies the library and the bridge answers search. The empty states are
/// the product's real ones, not scaffolding, so they survive that arrival.
class MeowzicPage extends StatefulWidget {
  const MeowzicPage({super.key});

  @override
  State<MeowzicPage> createState() => _MeowzicPageState();
}

class _MeowzicPageState extends State<MeowzicPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => CommonScaffold(
        title: 'meowzic',
        body: IndexedStack(
          index: _index,
          children: [
            NullStatus(label: appLocalizations.meowzicSearchEmpty),
            NullStatus(label: appLocalizations.meowzicLibraryEmpty),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          backgroundColor: Colors.transparent,
          destinations: [
            NavigationDestination(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                size: 24,
              ),
              label: appLocalizations.meowzicSearchTab,
            ),
            NavigationDestination(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedLibrary,
                size: 24,
              ),
              label: appLocalizations.meowzicLibraryTab,
            ),
          ],
        ),
      );
}
