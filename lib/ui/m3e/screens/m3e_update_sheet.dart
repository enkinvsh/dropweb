import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/app_update.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/m3e_text.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import '../widgets/m3e_button.dart';
import '../widgets/m3e_meter.dart';
import '../widgets/m3e_sheet.dart';
import '../widgets/m3e_toast_kind.dart';

/// Сколько листов обновления M3E открыто. Автопредложение (`offerUpdateSheet`)
/// не должно ложиться вторым поверх уже открытого ручного листа.
int _openSheets = 0;

/// Открыт ли сейчас лист обновления M3E.
bool get isM3eUpdateSheetOpen => _openSheets > 0;

/// Пауза между закрытием листа и тостом «Открываем установщик» (`update-install` доски).
const Duration kM3eUpdateToastDelay = Duration(milliseconds: 300);

/// Лист «Обновление» (`updateView` доски, android.js:583-599).
///
/// Состояние берётся из [appUpdateProvider]: лист сам переходит
/// available → downloading → verifying → readyToInstall → error. Если после закрытия
/// обновление так и ждёт действия, версия откладывается (`snoozeIfPending`), как у
/// прежнего листа.
///
/// Строка размера скрыта: манифест обновления размера не отдаёт.
///
/// Обязательное обновление ([AppUpdateInfo.mandatory]) остаётся без «Позже» и не
/// закрывается системной «Назад»; касание затемнения и свайп вниз тоже не закрывают
/// (`dismissible: false`).
Future<void> showM3eUpdateSheet(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  _openSheets++;
  try {
    await showM3eSheet<void>(
      context,
      dismissible: container.read(appUpdateProvider).info?.mandatory != true,
      builder: (_) => const _UpdateSheetBody(),
    );
  } finally {
    _openSheets--;
  }
  container.read(appUpdateProvider.notifier).snoozeIfPending();
}

/// Ручная «Проверить обновления»: нет обновления — тост, нет сети — тост об ошибке,
/// есть — лист. Окна загрузки нет: у M3E-экранов нет `CommonScaffold`; пока проверка
/// идёт (статус `checking`), пункт настроек неактивен, а повторный вызов игнорируется.
Future<void> m3eCheckForUpdate(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  // Вторая проверка поверх идущей возвращается сразу и без результата: статус
  // `checking` не означает «обновлений нет».
  if (container.read(appUpdateProvider).status == AppUpdateStatus.checking) {
    return;
  }
  await container.read(appUpdateProvider.notifier).check(manual: true);
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context);
  switch (container.read(appUpdateProvider).status) {
    case AppUpdateStatus.checkFailed:
      globalState.showNotifier(l10n.checkUpdateFailed,
          kind: M3eToastKind.alert);
    case AppUpdateStatus.available ||
          AppUpdateStatus.downloading ||
          AppUpdateStatus.verifying ||
          AppUpdateStatus.readyToInstall ||
          AppUpdateStatus.error:
      await showM3eUpdateSheet(context);
    case AppUpdateStatus.checking:
      // Проверка ещё идёт (check вернулся без результата): сообщать нечего.
      break;
    case AppUpdateStatus.idle || AppUpdateStatus.upToDate:
      globalState.showNotifier(l10n.checkUpdateError, kind: M3eToastKind.check);
  }
}

class _UpdateSheetBody extends ConsumerWidget {
  const _UpdateSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateProvider);
    final notifier = ref.read(appUpdateProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final scheme = M3eColors.of(context).scheme;
    final info = state.info;
    final mandatory = info?.mandatory == true;
    final percent = (state.progress.clamp(0.0, 1.0) * 100).round();
    final onVariant = m3eTextStyle(
      M3eType.bodyMedium,
      color: scheme.onSurfaceVariant,
    );

    final phase = switch (state.status) {
      AppUpdateStatus.downloading => <Widget>[
          _UpdateProgress(
            percent: state.progress.clamp(0.0, 1.0) * 100,
            label: l10n.m3eUpdateProgressLabel,
          ),
          Text(
            l10n.m3eUpdateDownloading(percent),
            style: onVariant.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      AppUpdateStatus.verifying => <Widget>[
          _UpdateProgress(
            percent: 100,
            full: true,
            label: l10n.m3eUpdateProgressLabel,
          ),
          Text(l10n.m3eUpdateVerifying, style: onVariant),
        ],
      AppUpdateStatus.readyToInstall => <Widget>[
          Text(l10n.m3eUpdateReady, style: onVariant),
        ],
      AppUpdateStatus.error => <Widget>[
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.m3eUpdateFailed,
              style: onVariant.copyWith(color: scheme.error),
            ),
          ),
        ],
      _ => const <Widget>[],
    };

    final later = M3eButton(
      label: l10n.updateLater,
      variant: M3eButtonVariant.text,
      size: M3eButtonSize.m,
      onPressed: () => Navigator.of(context).maybePop(),
    );
    Widget confirm(String label, VoidCallback onPressed) => M3eButton(
          label: label,
          variant: M3eButtonVariant.filled,
          size: M3eButtonSize.m,
          onPressed: onPressed,
        );

    // Подтверждение справа, отказ слева (learn/09); во время проверки подписи кнопок нет.
    final actions = switch (state.status) {
      AppUpdateStatus.downloading => <Widget>[
          M3eButton(
            label: l10n.updateCancel,
            variant: M3eButtonVariant.text,
            size: M3eButtonSize.m,
            onPressed: notifier.cancel,
          ),
        ],
      AppUpdateStatus.verifying => const <Widget>[],
      AppUpdateStatus.readyToInstall => <Widget>[
          if (!mandatory) later,
          confirm(l10n.updateInstall, () => _install(context, notifier)),
        ],
      AppUpdateStatus.error => <Widget>[
          if (!mandatory) later,
          confirm(l10n.updateRetry, notifier.download),
        ],
      _ => <Widget>[
          if (!mandatory) later,
          confirm(l10n.update, notifier.download),
        ],
    };

    return PopScope(
      canPop: !mandatory,
      child: M3eSheetScaffold(
        title:
            info != null ? l10n.m3eUpdateTitle(info.version) : l10n.checkUpdate,
        horizontalPadding: 24,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (info != null && info.notes.isNotEmpty) ...[
              // `.dr-list-head` с боковыми полями 0: поля листа уже 24.
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Text(
                  l10n.m3eUpdateNotes,
                  style: m3eTextStyle(
                    M3eType.titleSmall,
                    color: scheme.primary,
                  ),
                ),
              ),
              _Notes(notes: info.notes, style: onVariant, dot: scheme.primary),
            ],
            if (mandatory)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(l10n.updateMandatoryNote, style: onVariant),
              ),
            if (phase.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < phase.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      phase[i],
                    ],
                  ],
                ),
              ),
          ],
        ),
        footer: actions.isEmpty
            ? null
            : Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    actions[i],
                  ],
                ],
              ),
      ),
    );
  }

  /// `update-install` доски: запуск установщика, закрытие листа и через 300 мс тост.
  /// Без разрешения на установку из неизвестных источников `install()` ведёт в настройки
  /// и возвращает false: лист остаётся, чтобы нажать «Установить» ещё раз, а тост не
  /// врёт про установщик. Закрытие листа в этом случае откладывало бы версию на сутки.
  Future<void> _install(BuildContext context, AppUpdate notifier) async {
    final launched = await notifier.install();
    if (!launched || !context.mounted) return;
    final text = AppLocalizations.of(context).m3eToastInstaller;
    Navigator.of(context).pop();
    Future<void>.delayed(
      kM3eUpdateToastDelay,
      () => globalState.showNotifier(text, kind: M3eToastKind.check),
    );
  }
}

/// Список заметок `.dr-notes`: зазор 8, точка 6×6 цвета primary в 6 dp от края, текст
/// со сдвигом 20.
class _Notes extends StatelessWidget {
  const _Notes({required this.notes, required this.style, required this.dot});

  final List<String> notes;
  final TextStyle style;
  final Color dot;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < notes.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(notes[i], style: style),
                ),
                Positioned(
                  left: 6,
                  top: 7,
                  child: DecoratedBox(
                    decoration:
                        BoxDecoration(color: dot, shape: BoxShape.circle),
                    child: const SizedBox.square(dimension: 6),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
}

/// Линейный индикатор `.dr-progress`: ширина активной части едет на пружине default
/// spatial (`transition: width` доски). Тикер живёт только пока пружина движется;
/// без анимаций (reduced motion) значение выставляется сразу.
class _UpdateProgress extends StatefulWidget {
  const _UpdateProgress({
    required this.percent,
    required this.label,
    this.full = false,
  });

  final double percent;
  final bool full;
  final String label;

  @override
  State<_UpdateProgress> createState() => _UpdateProgressState();
}

class _UpdateProgressState extends State<_UpdateProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this, value: widget.percent);

  @override
  void didUpdateWidget(_UpdateProgress old) {
    super.didUpdateWidget(old);
    if (old.percent == widget.percent) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.percent;
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        M3eSpring.defaultSpatial.description,
        _controller.value,
        widget.percent,
        _controller.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = M3eColors.of(context).scheme;
    return Semantics(
      label: widget.label,
      value: '${widget.percent.round()}%',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => M3eMeter(
            // Пружина может перелететь за 100: полная полоса только в проверке подписи.
            percent: widget.full ? 100 : _controller.value.clamp(0.0, 99.9),
            activeColor: scheme.primary,
            trackColor: scheme.secondaryContainer,
          ),
        ),
      ),
    );
  }
}
