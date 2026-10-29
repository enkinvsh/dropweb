import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/dev_unlock_counter.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/about.dart' show shouldShowCheckForUpdate;
import 'package:dropweb/views/access.dart';
import 'package:dropweb/views/application_setting.dart';
import 'package:dropweb/views/config/config.dart';
import 'package:dropweb/views/developer.dart';
import 'package:dropweb/widgets/scaffold.dart' show CommonScaffold;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../symbols.g.dart';
import '../theme/m3e_own_color.dart';
import '../widgets/m3e_list.dart';
import '../widgets/m3e_page.dart';
import '../widgets/m3e_toast_kind.dart';
import 'm3e_language.dart';

/// Ключи экрана: имена из `test/m3e/ref/layout.json` (сцены `settings-<тема>-p<N>`).
const Key kM3eSettingsListKey = ValueKey<String>('m3e.list');

/// Ключ пункта основной группы (язык, оформление, о программе).
Key m3eSettingsItemKey(int index) => ValueKey<String>('m3e.list.item.$index');

/// Ключи дополнительных пунктов: на доске их нет, поэтому имена не из `layout.json`.
const Key kM3eSettingsMoreListKey = ValueKey<String>('m3e.settings.more');
const Key kM3eSettingsCheckUpdateKey =
    ValueKey<String>('m3e.settings.check_update');
const Key kM3eSettingsSupportKey = ValueKey<String>('m3e.settings.support');
const Key kM3eSettingsAlwaysOnKey = ValueKey<String>('m3e.settings.always_on');
const Key kM3eSettingsAccessKey = ValueKey<String>('m3e.settings.access');
const Key kM3eSettingsConfigKey = ValueKey<String>('m3e.settings.config');
const Key kM3eSettingsApplicationKey =
    ValueKey<String>('m3e.settings.application');
const Key kM3eSettingsDeveloperKey = ValueKey<String>('m3e.settings.developer');

/// Идентификатор заголовка для UI-автотестов: тот же, что стоял на заголовке старого
/// листа настроек.
const String kM3eSettingsTitleIdentifier = 'dw_settings_title';

/// Страница «Настройки»: `PAGES.settings` доски (android.js 479–483).
///
/// Первая группа — ровно пункты доски. Ниже вторая группа с тем, что было в старом листе
/// настроек и не должно пропасть: «Проверить обновления», «Поддержать проект» и (после
/// режима разработчика) входы в старые экраны. Пять быстрых нажатий на заголовок
/// включают режим разработчика, как раньше.
///
/// [version], [showCheckUpdate], [showSupport] нужны тестам; по умолчанию берутся из
/// приложения (версия сборки, магазинная ли сборка).
class M3eSettingsPage extends ConsumerStatefulWidget {
  const M3eSettingsPage({
    super.key,
    required this.onAppearance,
    required this.onAbout,
    required this.onCheckUpdate,
    this.version,
    this.showCheckUpdate,
    this.showSupport,
  });

  final VoidCallback onAppearance;
  final VoidCallback onAbout;
  final VoidCallback onCheckUpdate;
  final String? version;
  final bool? showCheckUpdate;
  final bool? showSupport;

  @override
  ConsumerState<M3eSettingsPage> createState() => _M3eSettingsPageState();
}

class _M3eSettingsPageState extends ConsumerState<M3eSettingsPage> {
  final DevUnlockCounter _devUnlock = DevUnlockCounter();

  Offset? _down;

  /// Прямоугольник элемента с ключом [key] в глобальных координатах. [M3ePage] не умеет
  /// сообщать о нажатии на заголовок, а менять его нельзя, поэтому ищем заголовок по
  /// ключу в момент отпускания пальца.
  Rect? _rectOf(Key key) {
    Rect? found;
    void visit(Element element) {
      if (found != null) return;
      if (element.widget.key == key) {
        final box = element.renderObject;
        if (box is RenderBox && box.hasSize && box.attached) {
          found = box.localToGlobal(Offset.zero) & box.size;
        }
        return;
      }
      element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  void _onPointerUp(PointerUpEvent event) {
    final down = _down;
    _down = null;
    // Прокрутка и долгое перетаскивание нажатием не считаются.
    if (down == null || (event.position - down).distance > 18) return;
    final spot = event.position;
    final big = _rectOf(kM3ePageTitleKey);
    final small = _rectOf(const ValueKey<String>('m3e.bar.title'));
    final hit =
        (big?.contains(spot) ?? false) || (small?.contains(spot) ?? false);
    if (hit) _onTitleTap();
  }

  void _onTitleTap() {
    if (!_devUnlock.registerTap()) return;
    if (ref.read(appSettingProvider).developerMode) return;
    ref
        .read(appSettingProvider.notifier)
        .updateState((s) => s.copyWith(developerMode: true));
    globalState.showNotifier(
      AppLocalizations.of(context).developerModeEnableTip,
      kind: M3eToastKind.check,
    );
  }

  /// Старый экран на странице своего `CommonScaffold`, как открывал `OpenDelegate`: он
  /// рисует Lumina-фон и свой заголовок, поэтому идёт отдельным маршрутом поверх.
  void _openLegacy(String title, Widget screen) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => CommonScaffold.open(
          key: Key(title),
          onBack: () => Navigator.of(routeContext).pop(),
          title: title,
          body: SafeArea(child: screen),
          disableBackground: true,
          actions: const [],
        ),
      ),
    );
  }

  Future<void> _openAlwaysOn() async {
    final ok = await app?.openVpnSettings() ?? false;
    if (!ok && mounted) {
      globalState.showNotifier(
        AppLocalizations.of(context).alwaysOnVpnOpenFailed,
        kind: M3eToastKind.alert,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(appSettingProvider.select((s) => s.locale));
    final developer =
        ref.watch(appSettingProvider.select((s) => s.developerMode));
    final ownColor = ref.watch(m3eOwnColorEnabledProvider);
    final version = widget.version ?? globalState.packageInfo.version;
    final showCheck = widget.showCheckUpdate ?? shouldShowCheckForUpdate();
    final showSupport = widget.showSupport ?? !system.isStoreBuild;

    final localeValue = m3eLocaleFromSetting(locale);
    final languageSub = localeValue == null
        ? l10n.m3eLangSystem
        : m3eLanguageNativeName(localeValue);

    final more = <Widget>[
      if (showCheck) _CheckUpdateItem(onTap: widget.onCheckUpdate),
      if (showSupport)
        M3eListItem(
          key: kM3eSettingsSupportKey,
          lead: M3eListLead.icon(M3eSymbol.link),
          label: l10n.supportProject,
          trail: M3eListTrail.icon(M3eSymbol.openInNew),
          onTap: () => globalState.openUrl('https://dropweb.org/donate'),
        ),
      if (developer) ...[
        M3eListItem(
          key: kM3eSettingsAlwaysOnKey,
          lead: M3eListLead.icon(M3eSymbol.shield),
          label: l10n.alwaysOnVpn,
          trail: M3eListTrail.icon(M3eSymbol.openInNew),
          onTap: _openAlwaysOn,
        ),
        M3eListItem(
          key: kM3eSettingsAccessKey,
          lead: M3eListLead.icon(M3eSymbol.lan),
          label: l10n.accessControl,
          onTap: () => _openLegacy(l10n.accessControl, const AccessView()),
        ),
        M3eListItem(
          key: kM3eSettingsConfigKey,
          lead: M3eListLead.icon(M3eSymbol.dns),
          label: l10n.basicConfig,
          onTap: () => _openLegacy(l10n.override, const ConfigView()),
        ),
        M3eListItem(
          key: kM3eSettingsApplicationKey,
          lead: M3eListLead.icon(M3eSymbol.settings),
          label: l10n.application,
          onTap: () =>
              _openLegacy(l10n.application, const ApplicationSettingView()),
        ),
        M3eListItem(
          key: kM3eSettingsDeveloperKey,
          lead: M3eListLead.icon(M3eSymbol.bolt),
          label: l10n.developerMode,
          onTap: () => _openLegacy(l10n.developerMode, const DeveloperView()),
        ),
      ],
    ];

    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => _down = e.position,
          onPointerUp: _onPointerUp,
          onPointerCancel: (_) => _down = null,
          child: M3ePage(
            title: l10n.settings,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KeyedSubtree(
                  key: kM3eSettingsListKey,
                  child: M3eList(
                    children: [
                      M3eListItem(
                        key: m3eSettingsItemKey(0),
                        lead: M3eListLead.icon(M3eSymbol.translate),
                        label: l10n.language,
                        sup: languageSub,
                        onTap: () => pushM3ePage<void>(
                          context,
                          (_) => const M3eLanguagePage(),
                        ),
                      ),
                      M3eListItem(
                        key: m3eSettingsItemKey(1),
                        lead: M3eListLead.icon(M3eSymbol.palette),
                        label: l10n.m3eAppearanceTitle,
                        sup: ownColor
                            ? l10n.m3eAppearanceOwn
                            : l10n.m3eAppearanceProvider,
                        onTap: widget.onAppearance,
                      ),
                      M3eListItem(
                        key: m3eSettingsItemKey(2),
                        lead: M3eListLead.icon(M3eSymbol.info),
                        label: l10n.m3eAboutTitle,
                        sup: l10n.m3eSettingsAboutVersion(version),
                        onTap: widget.onAbout,
                      ),
                    ],
                  ),
                ),
                if (more.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  KeyedSubtree(
                    key: kM3eSettingsMoreListKey,
                    child: M3eList(children: more),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Невидимая метка поверх заголовка: UI-автотесты находят его по
        // идентификатору. Нажатия пропускает насквозь, их ловит Listener выше.
        Positioned(
          top: top + 64,
          left: 16,
          right: 16,
          height: 68,
          child: IgnorePointer(
            child: Semantics(
              identifier: kM3eSettingsTitleIdentifier,
              container: true,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}

/// «Проверить обновления»: при найденной версии под названием появляется строка
/// «Найдена новая версия · X» и бейдж, как в старом листе. Пока идёт проверка, пункт
/// статичный с подписью «Проверка...» (строка `checking`): повторное нажатие дало бы
/// ложное «уже последняя версия».
class _CheckUpdateItem extends ConsumerWidget {
  const _CheckUpdateItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final version = ref.watch(
      appUpdateProvider.select(
        (s) => s.status == AppUpdateStatus.available ||
                s.status == AppUpdateStatus.readyToInstall
            ? s.info?.version
            : null,
      ),
    );
    final checking = ref.watch(
      appUpdateProvider.select((s) => s.status == AppUpdateStatus.checking),
    );
    return M3eListItem(
      key: kM3eSettingsCheckUpdateKey,
      lead: M3eListLead.icon(M3eSymbol.update),
      label: l10n.checkUpdate,
      sup: checking
          ? l10n.checking
          : version == null
              ? null
              : '${l10n.discoverNewVersion} · $version',
      trail: version == null || checking ? null : M3eListTrail.badge(),
      onTap: checking ? null : onTap,
    );
  }
}
