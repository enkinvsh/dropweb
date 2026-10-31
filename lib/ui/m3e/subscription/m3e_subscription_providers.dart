// Провайдеры листа «Подписка»: модель из состояния приложения, действия (обновить, выбрать,
// удалить, открыть ссылку) и состояние обновления «идёт / не удалось».
// Аккаунта и личного кабинета здесь нет сознательно: владелец 2026-10-29 убрал их из
// Android-редизайна, он же магазинный.
// Тесты подменяют `m3eSubModelProvider` и `m3eSubActionsProvider`, не трогая globalState.

import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/error_mapper.dart';
import 'package:dropweb/models/profile.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/services/hwid_recovery.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_model.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_toast_kind.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// «Сейчас» для подписи «Обновлено N назад». Тест подменяет, чтобы кадр не плыл.
final m3eSubClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

/// Магазинная сборка (Google Play или iOS): в листе нет продления и пополнения. Тест
/// подменяет, чтобы проверить режим на хосте.
final m3eSubStoreBuildProvider = Provider<bool>((ref) => system.isStoreBuild);

/// Данные листа: подписки, текущая, пункты провайдера. Только чтение состояния.
final m3eSubModelProvider = Provider<M3eSubModel>((ref) {
  final profiles = ref.watch(profilesProvider);
  final currentId = ref.watch(currentProfileIdProvider);
  return m3eSubModelOf(
    profiles: profiles,
    currentId: currentId,
    storeBuild: ref.watch(m3eSubStoreBuildProvider),
  );
});

/// Всё, что лист делает в приложении. Тест подставляет свои функции.
@immutable
class M3eSubActions {
  const M3eSubActions({
    required this.refresh,
    required this.select,
    required this.delete,
    required this.openLink,
    required this.notify,
  });

  /// Настоящие действия приложения: те же вызовы, что у старого меню и экрана подписки.
  factory M3eSubActions.app(Ref ref) => M3eSubActions(
        refresh: (id) => _refresh(ref, id),
        select: (id) => ref.read(currentProfileIdProvider.notifier).value = id,
        delete: (id) async {
          await globalState.appController.deleteProfile(id);
        },
        openLink: (url) => unawaited(globalState.openUrl(url)),
        notify: (text, kind) => globalState.showNotifier(text, kind: kind),
      );

  /// Перезагрузить подписку. Бросает исключение, если не вышло. Возвращает вердикт по
  /// лимиту устройств; `null` читается как [HwidVerdict.clean] (подмена в тестах).
  final Future<HwidVerdict?> Function(String profileId) refresh;

  /// Сделать подписку текущей.
  final void Function(String profileId) select;

  /// Удалить подписку; текущей при этом становится первая из оставшихся.
  final Future<void> Function(String profileId) delete;

  /// Открыть ссылку (справочная, продление, пополнение).
  final void Function(String url) openLink;

  /// Показать плашку сверху.
  final void Function(String text, M3eToastKind kind) notify;
}

final m3eSubActionsProvider = Provider<M3eSubActions>(M3eSubActions.app);

/// Обновление без модального окна ошибки: о результате сообщает плашка, а не диалог
/// `showErrorMessage` старого `refreshProfiles`. Нажатие пользователя, поэтому лимит
/// устройств контроллер показывает заново, даже если эпизод уже идёт.
Future<HwidVerdict> _refresh(Ref ref, String id) async {
  Profile? profile;
  for (final p in ref.read(profilesProvider)) {
    if (p.id == id) profile = p;
  }
  // Подписку удалили, пока шло нажатие: это не успех, плашка «Обновлено» была бы ложью.
  if (profile == null) throw StateError('profile $id not found');
  final controller = globalState.appController;
  unawaited(App().playUiSound(DropwebSoundCue.subscriptionRefresh));
  // Флаг ставится через updateProfileById: он правит текущее значение в хранилище и
  // не воскрешает подписку, удалённую во время загрузки.
  controller.updateProfileById(id, (p) => p.copyWith(isUpdating: true));
  try {
    return await controller.updateProfileByUser(profile);
  } catch (e) {
    commonPrint.log('$e');
    controller.updateProfileById(id, (p) => p.copyWith(isUpdating: false));
    rethrow;
  }
}

/// Состояние обновления листа. Не живёт в `Profile`: «Не обновилась» — локальное
/// состояние M3E-слоя, пока лист открыт и пока подписка не обновилась успешно.
@immutable
class M3eSubRefreshState {
  const M3eSubRefreshState({this.updatingId, this.failed = const {}});

  /// Подписка, которую этот лист сейчас обновляет.
  final String? updatingId;

  /// Подписки, чьё последнее обновление не удалось.
  final Set<String> failed;

  @override
  bool operator ==(Object other) =>
      other is M3eSubRefreshState &&
      other.updatingId == updatingId &&
      other.failed.length == failed.length &&
      other.failed.containsAll(failed);

  @override
  int get hashCode => Object.hash(updatingId, Object.hashAllUnordered(failed));
}

class M3eSubRefresh extends Notifier<M3eSubRefreshState> {
  @override
  M3eSubRefreshState build() => const M3eSubRefreshState();

  /// Обновляет подписку [id]. Успех: плашка [okText] (check), состояние «не удалось»
  /// снимается. Сбой: плашка [failText] (alert), подписка помечается как не обновившаяся.
  /// Пока идёт обновление, повторное нажатие игнорируется. Возвращает `true` при успехе.
  ///
  /// Лимит устройств панель сообщает заголовком, а не ошибкой: загрузка проходит, но в файле
  /// заглушка без серверов. Это не обновление: подписка помечается как не обновившаяся
  /// (так же, как при сбое сети, и `false` возвращается тем же способом), а [okText] не
  /// показывается. Причину (окно лимита или плашка) уже показал контроллер, вторая плашка
  /// поверх неё была бы шумом. Снятый лимит контроллер празднует своей плашкой «Устройство
  /// зарегистрировано», поэтому [okText] поверх неё тоже не нужен.
  Future<bool> refresh(
    String id, {
    required String okText,
    required String failText,
  }) async {
    if (state.updatingId != null) return false;
    final actions = ref.read(m3eSubActionsProvider);
    state = M3eSubRefreshState(
      updatingId: id,
      failed: {...state.failed}..remove(id),
    );
    HwidVerdict? verdict;
    try {
      verdict = await actions.refresh(id);
    } catch (e) {
      state = M3eSubRefreshState(failed: {...state.failed, id});
      // Причина важна пользователю (лимит устройств, HWID, токен): тот же маппер, что у
      // старого диалога; без совпадения остаётся общий текст.
      actions.notify(
          ErrorMapper.mapError('$e') ?? failText, M3eToastKind.alert);
      return false;
    }
    if (verdict == HwidVerdict.limited) {
      state = M3eSubRefreshState(failed: {...state.failed, id});
      return false;
    }
    state = M3eSubRefreshState(failed: state.failed);
    if (verdict != HwidVerdict.recovered) {
      actions.notify(okText, M3eToastKind.check);
    }
    return true;
  }
}

final m3eSubRefreshProvider =
    NotifierProvider<M3eSubRefresh, M3eSubRefreshState>(M3eSubRefresh.new);
