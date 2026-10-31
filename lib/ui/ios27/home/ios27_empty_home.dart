// Пустая главная iOS (подписок нет): `emptyScreen()` доски, app.js:448-452, app.css:124-130.

import 'dart:async';

import 'package:dropweb/common/clipboard_subscription.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_nav.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_screen.dart';
import 'package:dropweb/ui/ios27/home/ios27_portrait_lock.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_backdrop.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_circle_button.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart' show Ios27Text;
import 'package:dropweb/ui/ios27/widgets/ios27_button.dart';
import 'package:dropweb/views/profiles/add_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключи элементов пустого экрана: имена совпадают с `empty*` в `test/ios27/ref/layout.json`.
abstract final class Ios27EmptyKeys {
  static const empty = ValueKey<String>('empty');
  static const icon = ValueKey<String>('empty.icon');
  static const title = ValueKey<String>('empty.title');
  static const actions = ValueKey<String>('empty.actions');
  static const paste = ValueKey<String>('empty.btn#0');
  static const scan = ValueKey<String>('empty.btn#1');
}

/// Низ блока иконки и заголовка: `.empty { padding: 0 16px 24px }` сдвигает центр блока вверх.
const double _kEmptyBottomPad = 24;

/// Чистый вид пустой главной: без провайдеров и платформы.
///
/// Рамка пустого экрана на доске начинается на 52 dp от верха, то есть на 4 dp ниже кнопки
/// настроек; верх берём от безопасной зоны, чтобы на iPhone с вырезом блок не уехал под него.
class Ios27EmptyView extends StatelessWidget {
  const Ios27EmptyView({
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
    final l = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final palette = Ios27Colors.of(context).palette;
    final bottom = media.padding.bottom > kIos27HomeBottomPad
        ? media.padding.bottom
        : kIos27HomeBottomPad;

    return Ios27StatusBarRegion(
      child: Ios27Backdrop(
        state: Ios27BackdropState.off,
        child: Stack(
          children: [
            // Боковые safe area: на iPhone Duo торцевую колонку Dynamic Island и строки
            // состояния система отдаёт как боковой отступ, шестерёнка и блок стоят внутри него.
            Positioned(
              top: media.padding.top,
              right: kIos27HomeSidePad + media.padding.right,
              child: Ios27CircleButton.icon(
                key: Ios27HomeKeys.settings,
                icon: Ios27IconName.settings,
                semanticLabel: l.settings,
                onPressed: onSettings,
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  kIos27HomeSidePad + media.padding.left,
                  media.padding.top + 4,
                  kIos27HomeSidePad + media.padding.right,
                  bottom,
                ),
                child: Column(
                  children: [
                    Expanded(
                      key: Ios27EmptyKeys.empty,
                      child: Padding(
                        padding:
                            const EdgeInsets.only(bottom: _kEmptyBottomPad),
                        // Прокрутка включается только при крупном шрифте на низком экране:
                        // обычный блок короче области и стоит по центру.
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox.square(
                                  key: Ios27EmptyKeys.icon,
                                  dimension: Ios27IconSpecs.empty.size,
                                  child: Ios27Icon.spec(
                                    Ios27IconName.link,
                                    Ios27IconSpecs.empty,
                                    color: palette.label2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l.m3eEmptyTitle,
                                  key: Ios27EmptyKeys.title,
                                  textAlign: TextAlign.center,
                                  // Regular, а не Bold роли title1: как заголовок пустой
                                  // главной на доске (app.css:129).
                                  style: ios27Text(context, Ios27Text.title1)
                                      .copyWith(fontWeight: FontWeight.w400),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      key: Ios27EmptyKeys.actions,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Ios27Button(
                          key: Ios27EmptyKeys.paste,
                          label: l.m3eEmptyPaste,
                          icon: Ios27IconName.clipboard,
                          style: Ios27ButtonStyle.prominent,
                          block: true,
                          nested: false,
                          onPressed: onPaste,
                        ),
                        const SizedBox(height: 12),
                        Ios27Button(
                          key: Ios27EmptyKeys.scan,
                          label: l.m3eEmptyScanQr,
                          icon: Ios27IconName.qr,
                          block: true,
                          nested: false,
                          onPressed: onScan,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Пустая главная, подключённая к приложению: те же пути добавления подписки, что у листа
/// добавления (`lib/views/profiles/add_profile.dart`).
class Ios27EmptyHome extends ConsumerWidget {
  const Ios27EmptyHome({super.key});

  /// «Вставить ссылку»: ссылка подписки из буфера импортируется сразу, иначе открывается лист
  /// добавления с текстом из буфера (порядок строки «Буфер обмена» листа `AddProfileView`,
  /// у которого эта функция приватная).
  Future<void> _paste(BuildContext context) async {
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {
      // Доступ к буферу может быть закрыт системой: считаем буфер пустым и открываем
      // пустой лист, а не показываем ошибку.
    }
    final url = extractSubscriptionUrl(text);
    if (url != null) {
      await addProfileFromUrl(url);
    } else if (context.mounted) {
      openIos27HomeAdd(context, initialUrl: text);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Ios27PortraitLock(
        child: Ios27EmptyView(
          onSettings: () => openIos27HomeSettings(context),
          onPaste: () => unawaited(_paste(context)),
          // Камера открывается сразу; на рабочем столе функция идёт другим путём.
          onScan: () => unawaited(scanProfileQrCode(context)),
        ),
      );
}
