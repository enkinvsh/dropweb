import 'package:dropweb/common/common.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Asks for consent before meowzic is switched on.
///
/// Shown on the first tap of the strip rather than at first launch or as a
/// settings toggle: until somebody deliberately asks for music, the feature
/// stays absent. Declining changes nothing and the next tap asks again.
///
/// Returns true only when the user accepted.
Future<bool> showMeowzicAgreement(BuildContext context) async {
  final accepted = await showSheet<bool>(
    context: context,
    builder: (_, type) => AdaptiveSheetScaffold(
      type: type,
      title: appLocalizations.meowzicAgreementTitle,
      body: const _MeowzicAgreementBody(),
    ),
  );
  return accepted ?? false;
}

class _MeowzicAgreementBody extends StatelessWidget {
  const _MeowzicAgreementBody();

  // Only the text scrolls. Both buttons stay pinned so declining is never
  // pushed below the fold — with the copy inside the scroll view, a long
  // agreement leaves "accept" as the only visible option, which reads as a
  // dark pattern even when it is an accident of layout.
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                appLocalizations.meowzicAgreementBody,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(appLocalizations.meowzicAgreementAccept),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(appLocalizations.meowzicAgreementDecline),
                ),
              ],
            ),
          ),
        ],
      );
}
