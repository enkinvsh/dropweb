// Круглые кнопки нижнего ряда главной: подписки слева и маршрут справа.
//
// Доска: app.js:556 (подписка), app.js:559 (маршрут), app.css:566-567 (`.dock-btn`: 48×48,
// значок 22). Подписи на доске у кнопок нет, только `aria-label`, поэтому текст здесь — лишь
// подпись для VoiceOver, и приходит она от вызывающего (l10n в виджет не входит).

import 'package:dropweb/ui/ios27/glass/ios27_glass.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_circle_button.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:flutter/widgets.dart';

/// Сторона кнопки дока, `.dock-btn` (app.css:566).
const double kIos27DockButtonSize = 48;

/// Идентификатор кнопки маршрута для автотестов и интеграции со старым UI (`dw_exit`).
const String kIos27RouteSemanticsId = 'dw_exit';

/// Кнопка дока: стеклянный круг 48 с одним значком 22.
///
/// Две роли:
///  * [Ios27DockButton.subscriptions] — слева, значок «стопка» (`stack`) всегда: логотип
///    провайдера на кнопку не ставится (решение владельца D5; доска: `subIcon()`).
///  * [Ios27DockButton.route] — справа, значок «глобус»; при [inactive] стекло гаснет
///    (`glass--inactive`, значок `--label-3`), а нажатие остаётся: на доске погасшая
///    кнопка маршрута всё равно открывает список (app.js:550, 559).
///
/// Позиционирование — дело родителя: виджет занимает ровно 48×48.
class Ios27DockButton extends StatelessWidget {
  /// Подписки: значок `stack`, без идентификатора.
  const Ios27DockButton.subscriptions({
    super.key,
    required this.semanticLabel,
    this.onPressed,
    this.away = false,
  })  : icon = Ios27IconName.stack,
        inactive = false,
        semanticIdentifier = null;

  /// Маршрут: значок `globe`, идентификатор [kIos27RouteSemanticsId].
  const Ios27DockButton.route({
    super.key,
    required this.semanticLabel,
    this.onPressed,
    this.inactive = false,
    this.away = false,
  })  : icon = Ios27IconName.globe,
        semanticIdentifier = kIos27RouteSemanticsId;

  /// Значок кнопки (`stack` или `globe`).
  final Ios27IconName icon;

  /// Подпись для VoiceOver («Подписка», «Маршрут: Авто. Открыть список»).
  final String semanticLabel;

  /// `null` — кнопка не нажимается.
  final VoidCallback? onPressed;

  /// Погасшее стекло для заблокированной подписки (`blocked()` на доске).
  final bool inactive;

  /// Идентификатор семантики; у кнопки подписок его нет.
  final String? semanticIdentifier;

  /// Кнопка ушла под лист (`.joy .glass { --g-o: 0 }`, app.css:330): стекло дематериализуется
  /// нативно, значок гаснет своей прозрачностью.
  final bool away;

  @override
  Widget build(BuildContext context) => Ios27CircleButton.icon(
        icon: icon,
        diameter: kIos27DockButtonSize,
        variant:
            inactive ? Ios27GlassVariant.inactive : Ios27GlassVariant.small,
        iconTone: inactive ? Ios27GlassTone.muted : Ios27GlassTone.normal,
        interactive: !inactive,
        onPressed: onPressed,
        semanticLabel: semanticLabel,
        semanticIdentifier: semanticIdentifier,
        away: away,
      );
}
