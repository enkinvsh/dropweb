// Страница «О программе» iOS-редизайна (доска `page('about')`, app.js:630-636) без группы «Обновление»:
// store-сборки обновляются через магазин (R10).

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/ui/ios27/pages/ios27_page.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart' show Ios27Text;
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:dropweb/ui/m3e/screens/m3e_about.dart'
    show kM3eProjectSiteUrl, m3ePrivacyUrl;
import 'package:flutter/widgets.dart';

/// Грань «Default» иконки (светлая, как `appIcon(96)` доски в светлой теме, app.js:15-27).
/// Страница её НЕ показывает: ассет остался в сборке, ссылка на него нужна только тесту,
/// который следит, что светлая грань нигде не всплывает.
const String kIos27AboutIconDefault =
    'assets/images/ios27/about_icon_default.png';

/// Грань «Dark» иконки: единственная, которую показывает страница, в обеих темах.
const String kIos27AboutIconDark = 'assets/images/ios27/about_icon_dark.png';

/// Сторона иконки (`appIcon(96,'about__icon')`).
const double kIos27AboutIconSize = 96;

/// Растр иконки лежит в 288 px (= 96 pt @3x): `Image.asset` по размеру в pt сам берёт
/// нужный масштаб, а при @2x и @1x сжимает фильтром `medium` без муара на скруглении.
const FilterQuality _kIconFilter = FilterQuality.medium;

/// Иконка приложения «О программе»: всегда тёмная грань, в светлой теме тоже.
///
/// Решение владельца (30.10): тёмная иконка основная везде. На рабочем столе (iOS 14 и стиль
/// значков «по умолчанию» на Mac) стоит именно она, и страница показывает ту же картинку, что
/// пользователь только что нажал. Это сознательное отличие от доски: там `appIcon()` берёт
/// грань по теме. Провайдер иконку не красит (правило платформы).
///
/// Растры собраны генератором с тех же слоёв, что рисует `appIcon()` доски: маска squircle,
/// фон, чёрная и белая каёмки, тень и блик глифа. Плоские `dropweb-1024*.png` доски так не
/// выглядят: маски и эффектов в них нет.
class Ios27AboutIcon extends StatelessWidget {
  const Ios27AboutIcon({super.key});

  // Иконка декоративна: на доске она `aria-hidden`, имя приложения читается из текста ниже.
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Image.asset(
          kIos27AboutIconDark,
          width: kIos27AboutIconSize,
          height: kIos27AboutIconSize,
          filterQuality: _kIconFilter,
        ),
      );
}

/// Тело страницы «О программе»: шапка и группа из двух внешних ссылок.
///
/// Чистая отрисовка без обращения к платформе: версия и ядро приходят снаружи, ссылки
/// открывает вызывающий. Ключи `about.*` совпадают с именами в `test/ios27/ref/layout.json`.
class Ios27AboutBody extends StatelessWidget {
  const Ios27AboutBody({
    required this.version,
    required this.core,
    required this.nameKey,
    required this.onSite,
    required this.onPrivacy,
    super.key,
  });

  /// Версия приложения (`0.10.3`).
  final String version;

  /// Версия ядра; для отладочной сборки без ядра вызывающий уже подставил «—».
  final String core;

  /// Ключ текста «dropweb»: по нему маленький заголовок панели решает, когда проявиться.
  final GlobalKey nameKey;

  /// Нажатие на «Сайт проекта».
  final VoidCallback onSite;

  /// Нажатие на «Политика конфиденциальности».
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Ios27Colors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `.about{padding:12px 24px 8px;text-align:center}`
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Column(
            children: [
              // `.about__icon{margin:0 auto 14px}`
              const SizedBox.square(
                key: ValueKey<String>('about.icon'),
                dimension: kIos27AboutIconSize,
                child: Ios27AboutIcon(),
              ),
              const SizedBox(height: 14),
              // `.about__name{font:700 28px/34px}` (роль title1)
              SizedBox(
                key: const ValueKey<String>('about.name'),
                width: double.infinity,
                child: Text(
                  'dropweb',
                  key: nameKey,
                  textAlign: TextAlign.center,
                  style: ios27Text(context, Ios27Text.title1),
                ),
              ),
              // `.about__ver{margin-top:4px;font:400 15px/20px;color:var(--label-2)}` + `num`
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    l10n.m3eAboutVersion(version, core),
                    key: const ValueKey<String>('about.ver'),
                    textAlign: TextAlign.center,
                    style: ios27Text(
                      context,
                      Ios27Text.subhead,
                      color: colors.palette.label2,
                    ).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Ios27Gap(),
        Ios27List(
          children: [
            Ios27ListRow(
              title: l10n.m3eAboutSite,
              detail: Uri.parse(kM3eProjectSiteUrl).host,
              accessory: Ios27RowAccessory.external,
              onTap: onSite,
            ),
            Ios27ListRow(
              title: l10n.m3eAboutPrivacy,
              accessory: Ios27RowAccessory.external,
              onTap: onPrivacy,
            ),
          ],
        ),
      ],
    );
  }
}

/// Открывает страницу «О программе».
///
/// Версию и ядро берём оттуда же, что и Android-вариант (`M3eAbout`): ядро собирается через
/// `--dart-define CORE_VERSION`, в отладочной сборке его нет, тогда пишем «—».
Future<void> openIos27About(BuildContext context) {
  final version = globalState.packageInfo.version;
  final coreVersion = globalState.coreVersion;
  final core = coreVersion == null || coreVersion.isEmpty ? '—' : coreVersion;
  // Ключ создаём один раз: builder страницы вызывается на каждую перестройку, а якорю
  // сворачивания нужен тот же элемент.
  final nameKey = GlobalKey();
  return pushIos27Page<void>(
    context,
    titleBuilder: (c) => AppLocalizations.of(c).m3eAboutTitle,
    largeTitle: false,
    collapseAnchor: nameKey,
    builder: (_) => Ios27AboutBody(
      version: version,
      core: core,
      nameKey: nameKey,
      onSite: () => globalState.openUrl(kM3eProjectSiteUrl),
      onPrivacy: () => globalState.openUrl(m3ePrivacyUrl()),
    ),
  );
}
