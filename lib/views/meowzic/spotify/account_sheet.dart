import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

/// Shows the linked Spotify account and the way out of it.
///
/// A sheet behind the header's gear rather than a card on the Library tab,
/// which is where it used to live and where the owner rejected it: the tab is
/// for the library, and "kinvsh — отвязать" is a setting. It occupied the top of
/// a screen full of covers to say something that is true once and read once.
///
/// The same `showSheet` + [AdaptiveSheetScaffold] pairing as
/// `showMeowzicAgreement` next door, so the one other sheet this feature has
/// and this one behave identically on a phone and on a desktop window.
Future<void> showSpotifyAccount(BuildContext context) => showSheet<void>(
      context: context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.meowzicSpotifyAccount,
        body: const _SpotifyAccountBody(),
      ),
    );

class _SpotifyAccountBody extends ConsumerWidget {
  const _SpotifyAccountBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(spotifyAuthProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CommonCard(
            radius: Lumina.radiusLg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedUserCircle,
                    size: 32,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          auth.displayName ??
                              appLocalizations.meowzicSpotifyAccount,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          appLocalizations.meowzicSpotifyConnected,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurface.opacity38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Unlinking closes the sheet itself, because the sheet's whole
          // subject is the account it just discarded — leaving it open would
          // show an empty card over a screen that has already changed behind
          // it.
          TextButton(
            onPressed: () async {
              await ref.read(spotifyAuthProvider.notifier).signOut();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(appLocalizations.meowzicSpotifySignOut),
          ),
        ],
      ),
    );
  }
}
