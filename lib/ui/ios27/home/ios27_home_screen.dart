// Экран главной iOS: чистая сборка из готовых виджетов по раскладке доски. Без провайдеров.
//
// Доска: app.js:563-567 (`home()`), app.css `.home--b`, `.home__nav`, `.joy`, `.dock-btn`.
// Все размеры в CSS px доски 411×914 перенесены относительно безопасной области:
//   * шестерёнка: верх = верх безопасной области (на доске top 48 = высота статус-бара);
//   * карточка: на 60 ниже безопасной области (на доске 108 = 48 + 60);
//   * ряд кнопок: низ = max(низ безопасной области, 52) (на доске 52 = поле `.home--b`).

import 'dart:math' as math;

import 'package:dropweb/ui/ios27/glass/ios27_glass.dart' show Ios27Glass;
import 'package:dropweb/ui/ios27/glass/ios27_glass_away.dart'
    show Ios27GlassAwayTiming;
import 'package:dropweb/ui/ios27/home/ios27_home_view.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_backdrop.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_card.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_circle_button.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_dock_button.dart';
import 'package:dropweb/ui/ios27/home/widgets/ios27_power_button.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/layers/ios27_zoom.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter/widgets.dart';

/// Стиль строки состояния под тему приложения.
///
/// Экран рисует свой фон под строкой состояния и AppBar не имеет, поэтому без явного стиля iOS
/// берёт яркость из системы, а тема приложения может быть другой (светлая тема при тёмной
/// системе: белые часы на светлом фоне). На iOS `statusBarBrightness` — яркость ФОНА под
/// строкой, не значков.
class Ios27StatusBarRegion extends StatelessWidget {
  const Ios27StatusBarRegion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Ios27Colors.of(context).dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
      child: child,
    );
  }
}

/// Ключи элементов для сверки рамок с `layout.json` доски: имена те же.
abstract final class Ios27HomeKeys {
  static const settings = ValueKey<String>('settings');
  static const dock = ValueKey<String>('dock');
  static const dockSub = ValueKey<String>('dock-sub');
  static const power = ValueKey<String>('power');
  static const dockRoute = ValueKey<String>('dock-route');
}

/// Отступ карточки от верха безопасной области: 108 − 48 на доске.
const double kIos27HomeCardTop = 60;

/// Боковое поле экрана главной (`.home--b`, app.css).
const double kIos27HomeSidePad = 16;

/// Нижнее поле главной: 52 на доске (`.home--b { padding-bottom: 52px }`).
const double kIos27HomeBottomPad = 52;

/// Наименьшее нижнее поле, до которого ряд опускается, если карточка выросла (Dynamic Type).
///
/// Замер: iPhone SE 375×667, масштаб 2.0, сцена error — карточка 343 pt заходила под кнопку
/// питания на 25.5 pt; запас хода 52 → 16 даёт 36 pt и закрывает этот случай.
const double kIos27HomeBottomPadMin = 16;

/// Желаемый зазор между карточкой и кнопкой питания, когда ряд приходится опускать.
const double kIos27HomeCardGap = 8;

/// Высота ряда `joy`: по высоте кнопки питания.
const double kIos27HomeJoyHeight = kIos27PowerButtonSize;

/// Поле ряда `joy` слева и справа (`.joy__row { padding: 0 4px }`).
const double kIos27HomeJoyInset = 4;

/// Главная: фон, шестерёнка, карточка подключения, кнопка питания и нижний ряд.
///
/// Карточка не прокручивается (решение владельца D8 и урок Android): при крупном шрифте она
/// растёт вниз. Прокручиваемой её доска делает только из-за пагинации, которой в приложении нет.
class Ios27HomeScreen extends StatelessWidget {
  const Ios27HomeScreen({
    super.key,
    required this.data,
    this.onToggle,
    this.onSettings,
    this.onSubscriptions,
    this.onRoute,
    this.onRefresh,
    this.onLink,
    this.glassAway = false,
    this.now = DateTime.now,
  });

  final Ios27HomeData data;

  /// Нажатие по кнопке питания; `null` — не нажимается (идёт подключение).
  final VoidCallback? onToggle;
  final VoidCallback? onSettings;
  final VoidCallback? onSubscriptions;
  final VoidCallback? onRoute;

  /// «Обновить» на карточке.
  final VoidCallback? onRefresh;

  /// Ссылка в объявлении; игнорируется, если ссылки не нажимаются ([Ios27HomeData.linksTappable]).
  final ValueChanged<String>? onLink;

  /// Над главной открыт лист или страница: нижний ряд уходит, стекло не должно лежать на стекле
  /// (app.css:330-333, WWDC25 284). Возвращается, как только лист начинает закрываться. Уходят
  /// кнопки дока и питания (`.joy .glass`); шестерёнка остаётся. Стекло убирает нативный вид
  /// ([Ios27Glass.away], тайминги в [Ios27GlassAwayTiming]), значки гаснут своей прозрачностью.
  final bool glassAway;

  /// «Сейчас» для таймера карточки: тесты подставляют часы fake-async.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeTop = media.padding.top;
    final bottom = media.padding.bottom > kIos27HomeBottomPad
        ? media.padding.bottom
        : kIos27HomeBottomPad;

    return Ios27StatusBarRegion(
      child: Ios27Backdrop(
        state: data.backdrop,
        // Не `Stack`: нижний ряд зависит от высоты карточки, а она известна только после её
        // раскладки (см. [_HomeLayout]).
        child: CustomMultiChildLayout(
          delegate: _HomeLayout(
            safeTop: safeTop,
            safeLeft: media.padding.left,
            safeRight: media.padding.right,
            bottom: bottom,
          ),
          children: [
            LayoutId(
              id: _Slot.gear,
              child: Ios27CircleButton.icon(
                key: Ios27HomeKeys.settings,
                icon: Ios27IconName.settings,
                semanticLabel: data.settingsLabel,
                onPressed: onSettings,
              ),
            ),
            LayoutId(
              id: _Slot.card,
              // Карточка и подвал с объявлением — одна группа: раскладка меряет их вместе, чтобы
              // зазор до кнопки питания считался от низа подвала, а не карточки.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Ios27Card(
                    data: data.card,
                    now: now,
                    onRefresh: onRefresh,
                  ),
                  Ios27CardFooter(
                    text: data.card.announce,
                    onLink: data.linksTappable ? onLink : null,
                  ),
                ],
              ),
            ),
            LayoutId(
              id: _Slot.joy,
              // Нажатия под листом блокируем, а скрываем стекло не прозрачностью этой обёртки, а
              // параметром `away` у самих кнопок: прозрачный предок нативного стекла рисуется
              // неправильно (см. [Ios27Glass.away]). Из семантики ряд уходит сразу: кнопки под
              // листом VoiceOver не нужны.
              child: IgnorePointer(
                ignoring: glassAway,
                child: ExcludeSemantics(
                  excluding: glassAway,
                  child: Semantics(
                    container: true,
                    label: data.joyLabel,
                    child: Padding(
                      key: Ios27HomeKeys.dock,
                      padding: const EdgeInsets.symmetric(
                        horizontal: kIos27HomeJoyInset,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            key: Ios27HomeKeys.dockSub,
                            width: kIos27DockButtonSize,
                            height: kIos27DockButtonSize,
                            child: Ios27ZoomSource(
                              id: Ios27ZoomId.subscriptions,
                              icon: (c) => _zoomIcon(
                                c,
                                Ios27IconName.stack,
                                Ios27IconSpecs.standard,
                              ),
                              child: Ios27DockButton.subscriptions(
                                semanticLabel: data.subscriptionsLabel,
                                onPressed: onSubscriptions,
                                away: glassAway,
                              ),
                            ),
                          ),
                          SizedBox(
                            key: Ios27HomeKeys.power,
                            width: kIos27PowerButtonSize,
                            height: kIos27PowerButtonSize,
                            child: Ios27ZoomSource(
                              id: Ios27ZoomId.power,
                              icon: (c) => _zoomIcon(
                                c,
                                Ios27IconName.power,
                                Ios27IconSpecs.power,
                              ),
                              child: Ios27PowerButton(
                                state: data.power,
                                semanticLabel: data.powerLabel,
                                onPressed:
                                    data.powerPressable ? onToggle : null,
                                away: glassAway,
                              ),
                            ),
                          ),
                          SizedBox(
                            key: Ios27HomeKeys.dockRoute,
                            width: kIos27DockButtonSize,
                            height: kIos27DockButtonSize,
                            child: Ios27ZoomSource(
                              id: Ios27ZoomId.route,
                              icon: (c) => _zoomIcon(
                                c,
                                Ios27IconName.globe,
                                Ios27IconSpecs.standard,
                              ),
                              child: Ios27DockButton.route(
                                semanticLabel: data.routeLabel,
                                inactive: data.blocked,
                                onPressed: onRoute,
                                away: glassAway,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Значок кнопки для растущего стекла: рисуется отдельно от кнопки, потому что сама кнопка на
  // время зума скрыта (app.css:303 `.glass.is-src`), а исчезает значок отдельным шагом
  // (motion.js:121-128).
  static Widget _zoomIcon(
          BuildContext context, Ios27IconName name, Ios27IconSpec spec) =>
      Ios27Icon.spec(
        name,
        spec,
        color: ios27ColorsFor(context).palette.glassLabel,
      );
}

enum _Slot { gear, card, joy }

/// Раскладка главной: шестерёнка, карточка и нижний ряд.
///
/// По умолчанию геометрия доски: шестерёнка на `safeTop`, карточка на `safeTop + 60`, низ ряда
/// на [bottom] (`max(safe.bottom, 52)`). Если карточка выросла от Dynamic Type и до кнопки
/// питания остаётся меньше [kIos27HomeCardGap], ряд опускается к [kIos27HomeBottomPadMin].
/// Карточку не прокручиваем (D8), текст не сжимаем.
///
/// Боковые отступы [safeLeft] и [safeRight] нужны для iPhone Duo: система уводит Dynamic Island и
/// строку состояния в вертикальную колонку вдоль торцевого края (HIG «Designing for iPhone Duo»),
/// и эта колонка приходит как боковая safe area. Поле [kIos27HomeSidePad] отсчитывается от её
/// внутренней границы, иначе колонка закроет шестерёнку и конец текста карточки. Без боковых
/// отступов (все нынешние iPhone в портрете) раскладка совпадает с доской.
class _HomeLayout extends MultiChildLayoutDelegate {
  _HomeLayout({
    required this.safeTop,
    required this.safeLeft,
    required this.safeRight,
    required this.bottom,
  });

  final double safeTop;
  final double safeLeft;
  final double safeRight;
  final double bottom;

  @override
  void performLayout(Size size) {
    final left = safeLeft + kIos27HomeSidePad;
    final right = size.width - safeRight - kIos27HomeSidePad;
    final width = math.max(0.0, right - left);

    final gear = layoutChild(_Slot.gear, BoxConstraints.loose(size));
    positionChild(_Slot.gear, Offset(right - gear.width, safeTop));

    final cardTop = safeTop + kIos27HomeCardTop;
    final card = layoutChild(
      _Slot.card,
      BoxConstraints(minWidth: width, maxWidth: width),
    );
    positionChild(_Slot.card, Offset(left, cardTop));

    final inset = ios27HomeBottomInset(
      screenHeight: size.height,
      cardBottom: cardTop + card.height,
      preferred: bottom,
    );
    layoutChild(
      _Slot.joy,
      BoxConstraints.tight(Size(width, kIos27HomeJoyHeight)),
    );
    positionChild(
      _Slot.joy,
      Offset(left, size.height - inset - kIos27HomeJoyHeight),
    );
  }

  @override
  bool shouldRelayout(_HomeLayout old) =>
      old.safeTop != safeTop ||
      old.safeLeft != safeLeft ||
      old.safeRight != safeRight ||
      old.bottom != bottom;
}

/// Нижнее поле ряда: [preferred], а при высокой карточке меньше, но не ниже
/// [kIos27HomeBottomPadMin]. Нехватку сверх этого предела не скрываем: остаётся перекрытие.
double ios27HomeBottomInset({
  required double screenHeight,
  required double cardBottom,
  required double preferred,
}) {
  final fits =
      screenHeight - kIos27HomeJoyHeight - kIos27HomeCardGap - cardBottom;
  if (fits >= preferred) {
    return preferred;
  }
  final lowest =
      kIos27HomeBottomPadMin < preferred ? kIos27HomeBottomPadMin : preferred;
  return fits > lowest ? fits : lowest;
}
