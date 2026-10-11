import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Сколько шитов обновления сейчас открыто — чтобы автопредложение не легло
/// вторым поверх уже открытого (ручного или автоматического).
int _openUpdateSheets = 0;

/// Открывает шит обновления (Android sideload). Реактивен к
/// [appUpdateProvider]: тело переходит available → downloading → verifying →
/// readyToInstall → error. При закрытии с ещё не применённым обновлением эта
/// версия откладывается (см. [AppUpdate.snoozeIfPending]).
Future<void> showUpdateSheet(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  _openUpdateSheets++;
  try {
    await showSheet<void>(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (context, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.discoverNewVersion,
        body: const _AppUpdateSheetBody(),
      ),
    );
  } finally {
    _openUpdateSheets--;
  }
  container.read(appUpdateProvider.notifier).snoozeIfPending();
}

/// Автопредложение по результату [AppUpdate.autoCheck]: открывает шит, только
/// если поверх главного экрана ничего не открыто. Иначе юзер, вернувшийся из
/// почты с кодом, получил бы шит поверх шторки входа; обновление при этом
/// остаётся в настройках, а следующая проверка предложит его снова.
/// [context] — корневой навигатор, чтобы шит не зависел от текущего экрана.
Future<void> offerUpdateSheet(BuildContext context) async {
  if (_openUpdateSheets > 0 || !context.mounted) return;
  final navigator = Navigator.maybeOf(context, rootNavigator: true);
  if (navigator == null || navigator.canPop()) return;
  await showUpdateSheet(context);
}

class _AppUpdateSheetBody extends ConsumerWidget {
  const _AppUpdateSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateProvider);
    final notifier = ref.read(appUpdateProvider.notifier);
    final info = state.info;
    final textTheme = context.textTheme;
    final colorScheme = context.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            info != null
                ? '$appName ${info.version}'
                : appLocalizations.checkUpdate,
            style: textTheme.headlineSmall,
          ),
          if (info != null && info.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final note in info.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('•  $note', style: textTheme.bodyMedium),
              ),
          ],
          if (info?.mandatory == true) ...[
            const SizedBox(height: 12),
            Text(
              appLocalizations.updateMandatoryNote,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (state.status == AppUpdateStatus.downloading) ...[
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(Lumina.radiusMd),
              child: LinearProgressIndicator(
                value: state.progress == 0 ? null : state.progress,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${appLocalizations.updateDownloading}  ${(state.progress * 100).round()}%',
              style: textTheme.bodySmall,
            ),
          ],
          if (state.status == AppUpdateStatus.verifying) ...[
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(Lumina.radiusMd),
              child: const LinearProgressIndicator(),
            ),
            const SizedBox(height: 8),
            Text(appLocalizations.updateVerifying, style: textTheme.bodySmall),
          ],
          if (state.status == AppUpdateStatus.error) ...[
            const SizedBox(height: 16),
            Text(
              appLocalizations.updateFailed,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          _Actions(state: state, notifier: notifier),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.state, required this.notifier});

  final AppUpdateState state;
  final AppUpdate notifier;

  @override
  Widget build(BuildContext context) {
    final mandatory = state.info?.mandatory == true;
    switch (state.status) {
      case AppUpdateStatus.downloading:
        return Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: notifier.cancel,
            child: Text(appLocalizations.updateCancel),
          ),
        );
      case AppUpdateStatus.verifying:
        return const SizedBox.shrink();
      case AppUpdateStatus.readyToInstall:
        return _row(
          context,
          primaryLabel: appLocalizations.updateInstall,
          onPrimary: notifier.install,
          showLater: !mandatory,
        );
      case AppUpdateStatus.error:
        return _row(
          context,
          primaryLabel: appLocalizations.updateRetry,
          onPrimary: notifier.download,
          showLater: !mandatory,
        );
      case AppUpdateStatus.available:
      case AppUpdateStatus.idle:
      case AppUpdateStatus.checking:
      case AppUpdateStatus.upToDate:
      case AppUpdateStatus.checkFailed:
        return _row(
          context,
          primaryLabel: appLocalizations.update,
          onPrimary: notifier.download,
          showLater: !mandatory,
        );
    }
  }

  Widget _row(
    BuildContext context, {
    required String primaryLabel,
    required VoidCallback onPrimary,
    required bool showLater,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (showLater)
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(appLocalizations.updateLater),
          ),
        const SizedBox(width: 8),
        FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
      ],
    );
  }
}
