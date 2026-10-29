import 'package:dropweb/common/common.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../color/color.dart';
import '../icon/m3e_app_icon.dart';
import '../symbols.g.dart';
import '../theme/m3e_text.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import '../widgets/m3e_list.dart';
import '../widgets/m3e_page.dart';
import 'm3e_update_sheet.dart';

/// Ключи элементов экрана: совпадают с именами в `test/m3e/ref/layout.json`
/// (сцены `about-<тема>-p<N>`).
const Key kM3eAboutKey = ValueKey<String>('m3e.about');
const Key kM3eAboutLogoKey = ValueKey<String>('m3e.about.logo');
const Key kM3eAboutTitleKey = ValueKey<String>('m3e.about.title');
const Key kM3eAboutVersionKey = ValueKey<String>('m3e.about.version');
const Key kM3eAboutListKey = ValueKey<String>('m3e.list');

/// Ключ пункта списка; номер считается внутри списка «О программе».
Key m3eAboutItemKey(int index) => ValueKey<String>('m3e.list.item.$index');

/// Сайт проекта: на доске пункт подписан `dropweb.org`. В старом «О программе» ссылка
/// «Проект» вела на GitHub, но в M3E-версии пункт называется «Сайт проекта».
const String kM3eProjectSiteUrl = 'https://dropweb.org';

/// Политика конфиденциальности: те же адреса, что у `privacyPolicyUrl()` в
/// `views/about.dart`. Та функция помечена `@visibleForTesting`, из другой библиотеки
/// её вызвать нельзя без предупреждения анализатора, поэтому адреса повторены здесь.
/// Адрес общий для «О программе» и раскрытия VPN перед подключением.
String m3ePrivacyUrl() => system.isStoreBuild
    ? 'https://dropweb.org/app/privacy/'
    : 'https://dropweb.org/privacy';

/// Экран «О программе»: `PAGES.about` на странице `pageHtml()` доски (android.js 502–512).
///
/// Чистая отрисовка без провайдеров и без обращения к платформе. [M3eThemeScope] должен
/// стоять выше по дереву. Пункт «Обновление» рисуется только при [updateVersion] != null:
/// решать, показывать ли его (магазинная сборка, статус обновления), должен вызывающий.
class M3eAboutView extends StatelessWidget {
  const M3eAboutView({
    super.key,
    required this.version,
    required this.core,
    this.updateVersion,
    required this.onBack,
    this.onUpdate,
    required this.onSite,
    required this.onPrivacy,
  });

  final String version;
  final String core;
  final String? updateVersion;
  final VoidCallback onBack;
  final VoidCallback? onUpdate;
  final VoidCallback onSite;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = M3eColors.of(context).scheme;
    final updateVersion = this.updateVersion;
    // Ключ пункта — номер среди показанных: без обновления «Сайт» получает нулевой.
    var n = 0;
    final items = <Widget>[
      if (updateVersion != null)
        M3eListItem(
          key: m3eAboutItemKey(n++),
          lead: M3eListLead.icon(M3eSymbol.systemUpdate),
          label: l10n.m3eAboutUpdate,
          sup: l10n.m3eAboutUpdateAvailable(updateVersion),
          trail: M3eListTrail.badge(),
          onTap: onUpdate,
        ),
      M3eListItem(
        key: m3eAboutItemKey(n++),
        lead: M3eListLead.icon(M3eSymbol.public),
        label: l10n.m3eAboutSite,
        sup: 'dropweb.org',
        trail: M3eListTrail.icon(M3eSymbol.openInNew),
        onTap: onSite,
      ),
      M3eListItem(
        key: m3eAboutItemKey(n++),
        lead: M3eListLead.icon(M3eSymbol.policy),
        label: l10n.m3eAboutPrivacy,
        trail: M3eListTrail.icon(M3eSymbol.openInNew),
        onTap: onPrivacy,
      ),
    ];
    return M3ePage(
      title: l10n.m3eAboutTitle,
      onBack: onBack,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Identity(version: version, core: core, scheme: scheme, l10n: l10n),
          KeyedSubtree(
            key: kM3eAboutListKey,
            child: M3eList(children: items),
          ),
        ],
      ),
    );
  }
}

/// Блок `.dr-about`: значок 96, «dropweb», строка версии. Отступы 8 сверху и 28 снизу,
/// зазор между строками 4, под значком ещё 12.
class _Identity extends StatelessWidget {
  const _Identity({
    required this.version,
    required this.core,
    required this.scheme,
    required this.l10n,
  });

  final String version;
  final String core;
  final M3eScheme scheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => SizedBox(
        key: kM3eAboutKey,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 28),
          child: Column(
            children: [
              SizedBox.square(
                key: kM3eAboutLogoKey,
                dimension: 96,
                child: M3eAppIcon(colors: scheme.icon, size: 96),
              ),
              const SizedBox(height: 16),
              Text(
                'dropweb',
                key: kM3eAboutTitleKey,
                textAlign: TextAlign.center,
                style: m3eTextStyle(
                  M3eType.headlineSmall,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.m3eAboutVersion(version, core),
                key: kM3eAboutVersionKey,
                textAlign: TextAlign.center,
                style: m3eTextStyle(
                  M3eType.bodyMedium,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Рабочий экран «О программе» на Android: данные приложения поверх [M3eAboutView].
///
/// Открывается отдельным полноэкранным маршрутом (не через `OpenDelegate`): тот кладёт
/// страницу в `CommonScaffold` со старым заголовком и фоном Lumina.
class M3eAbout extends ConsumerWidget {
  const M3eAbout({super.key});

  /// Статусы, при которых пользователю есть что показать: новая версия найдена,
  /// качается, проверяется или готова к установке.
  static bool _hasUpdate(AppUpdateStatus status) =>
      status == AppUpdateStatus.available ||
      status == AppUpdateStatus.downloading ||
      status == AppUpdateStatus.verifying ||
      status == AppUpdateStatus.readyToInstall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Магазинные сборки обновляются через магазин: пункта нет, провайдер не слушаем.
    final updateVersion = system.isStoreBuild
        ? null
        : ref.watch(
            appUpdateProvider.select(
              (s) => _hasUpdate(s.status) ? s.info?.version : null,
            ),
          );
    final coreVersion = globalState.coreVersion;

    return M3eThemeScope(
      child: M3eAboutView(
        version: globalState.packageInfo.version,
        // Ядро собирается через --dart-define CORE_VERSION; в отладочной сборке его нет.
        core: coreVersion == null || coreVersion.isEmpty ? '—' : coreVersion,
        updateVersion: updateVersion,
        onBack: () => Navigator.maybePop(context),
        onUpdate: updateVersion == null ? null : () => showM3eUpdateSheet(context),
        onSite: () => globalState.openUrl(kM3eProjectSiteUrl),
        onPrivacy: () => globalState.openUrl(m3ePrivacyUrl()),
      ),
    );
  }
}
