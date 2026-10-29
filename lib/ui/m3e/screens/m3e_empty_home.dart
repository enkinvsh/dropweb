import 'dart:async';

import 'package:dropweb/common/clipboard_subscription.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/views/profiles/add_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import '../symbols.g.dart';
import '../theme/m3e_text.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import '../widgets/m3e_button.dart';
import '../widgets/m3e_round_button.dart';
import '../widgets/m3e_shape.dart';
import '../widgets/m3e_symbol.dart';
import 'm3e_add_subscription.dart';

/// Ключи элементов пустого экрана: совпадают с именами в `test/m3e/ref/layout.json`.
const Key kM3eEmptyKey = ValueKey<String>('m3e.empty');
const Key kM3eEmptyShapeKey = ValueKey<String>('m3e.empty.shape');
const Key kM3eEmptyTitleKey = ValueKey<String>('m3e.empty.title');
const Key kM3eEmptyActionsKey = ValueKey<String>('m3e.empty.actions');
const Key kM3eEmptyPasteKey = ValueKey<String>('m3e.empty.btn.0');
const Key kM3eEmptyScanKey = ValueKey<String>('m3e.empty.btn.1');
const Key kM3eNavButtonKey = ValueKey<String>('m3e.navBtn');

/// Отрисовка пустого экрана (подписок нет): `emptyHtml()` и `.dr-empty*` доски.
///
/// Чистый виджет без провайдеров и без обращения к платформе. [M3eThemeScope] ожидается
/// выше по дереву: на устройстве он стоит над всем M3E-деревом, второй слой не нужен.
class M3eEmptyView extends StatelessWidget {
  const M3eEmptyView({
    super.key,
    required this.onSettings,
    required this.onPaste,
    required this.onScan,
  });

  final VoidCallback onSettings;
  final VoidCallback onPaste;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = M3eColors.of(context);
    final scheme = colors.scheme;
    final media = MediaQuery.of(context);
    final dark = colors.brightness == Brightness.dark;

    // Иконки статус-бара задаём сами: экран рисует свой фон под строкой состояния,
    // и без этого на светлой теме иконки остались бы светлыми от прошлого экрана.
    final overlay =
        (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      // Фон пустого экрана на доске — `surface` схемы (замер эталонов: #EBFFE7, #0D0E11),
      // а не `--dr-bg` главной. Material даёт текстам DefaultTextStyle и поверхность
      // для кругов нажатия.
      child: Material(
        color: scheme.role('surface'),
        child: Stack(
          children: [
            // Блок «фигура + заголовок» центруется в высоте между строкой состояния и
            // кнопками; кнопки стоят у нижнего края над жестовой полосой.
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  top: media.padding.top,
                  bottom: media.padding.bottom,
                ),
                child: Column(
                  children: [
                    Expanded(
                      key: kM3eEmptyKey,
                      child: Center(
                        child: SingleChildScrollView(
                          // Прокрутка нужна только при крупном шрифте на низком окне;
                          // в обычном случае блок короче области и стоит по центру.
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox.square(
                                  key: kM3eEmptyShapeKey,
                                  dimension: 136,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      M3eShapeView(
                                        MaterialShapes.softBurst,
                                        color: scheme.role('primaryContainer'),
                                        size: 136,
                                      ),
                                      M3eSymbolIcon(
                                        M3eSymbol.link,
                                        size: 48,
                                        color:
                                            scheme.role('onPrimaryContainer'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  l10n.m3eEmptyTitle,
                                  key: kM3eEmptyTitleKey,
                                  textAlign: TextAlign.center,
                                  style: m3eTextStyle(
                                    M3eType.headlineSmall,
                                    color: scheme.role('onSurface'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      key: kM3eEmptyActionsKey,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          M3eButton(
                            key: kM3eEmptyPasteKey,
                            label: l10n.m3eEmptyPaste,
                            variant: M3eButtonVariant.filled,
                            size: M3eButtonSize.m,
                            icon: M3eSymbol.contentPaste,
                            onPressed: onPaste,
                          ),
                          const SizedBox(height: 8),
                          M3eButton(
                            key: kM3eEmptyScanKey,
                            label: l10n.m3eEmptyScanQr,
                            variant: M3eButtonVariant.tonal,
                            size: M3eButtonSize.m,
                            icon: M3eSymbol.qrCodeScanner,
                            onPressed: onScan,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Настройки: круглая кнопка справа сверху, на 4 dp ниже строки состояния.
            Positioned(
              top: media.padding.top + kM3eNavButtonTop,
              right: 16,
              child: M3eTonalIconButton(
                key: kM3eNavButtonKey,
                size: kM3eNavButtonSize,
                icon: const M3eSymbolIcon(M3eSymbol.settings),
                semanticLabel: l10n.m3eA11ySettings,
                onPressed: onSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Пустой экран, подключённый к приложению: те же пути добавления подписки, что у
/// листа `AddProfileView` (`lib/views/profiles/add_profile.dart`).
class M3eEmptyHome extends ConsumerWidget {
  const M3eEmptyHome({super.key, required this.onSettings});

  final VoidCallback onSettings;

  /// «Вставить ссылку»: порядок строки «Буфер обмена» листа `AddProfileView`
  /// (`_handlePasteFromClipboard`, приватный): ссылка подписки из буфера импортируется
  /// сразу, иначе лист «Добавить подписку» с текстом из буфера. Приватный метод листа
  /// не вызвать, поэтому склейка из тех же публичных функций.
  Future<void> _paste(BuildContext context) async {
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {
      // Доступ к буферу может быть закрыт системой: считаем буфер пустым и
      // отдаём пользователю пустой диалог, а не ошибку.
    }
    final url = extractSubscriptionUrl(text);
    if (url != null) {
      await addProfileFromUrl(url);
    } else if (context.mounted) {
      await showM3eAddSubscription(context, initialValue: text);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => M3eEmptyView(
        onSettings: onSettings,
        onPaste: () => unawaited(_paste(context)),
        // Камера открывается сразу; на рабочем столе функция сама идёт другим путём.
        onScan: () => unawaited(scanProfileQrCode(context)),
      );
}
