import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../symbols.g.dart';
import '../theme/m3e_text.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import 'm3e_list.dart';
import 'm3e_symbol.dart';

/// Ключи элементов страницы: совпадают с именами в `test/m3e/ref/layout.json`.
const Key kM3ePageBarKey = ValueKey<String>('m3e.bar');
const Key kM3ePageBackKey = ValueKey<String>('m3e.bar.back');
const Key kM3ePageTitleKey = ValueKey<String>('m3e.page.title');

/// Полноэкранная страница настроек (`pageHtml()` и `.dr-page` доски, learn/08):
/// строка 64 dp с кнопкой «Назад», крупный заголовок headline-medium в теле и прокрутка.
///
/// После прокрутки панель заливается surface-container (заливка продолжается под строку
/// состояния, edge-to-edge), а в ней проявляется малый заголовок title-large.
///
/// [body] кладётся под заголовок внутри прокрутки с полями 16 по бокам и 24 снизу; обычно
/// это колонка из [M3eList]. Списки внутри получают пункты на ступень выше фона
/// ([M3eListSurface.page]). [M3eThemeScope] должен стоять выше (его ставит [pushM3ePage]).
class M3ePage extends StatefulWidget {
  const M3ePage({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
  });

  final String title;
  final Widget body;

  /// По умолчанию `Navigator.maybePop`.
  final VoidCallback? onBack;

  @override
  State<M3ePage> createState() => _M3ePageState();
}

class _M3ePageState extends State<M3ePage> {
  bool _scrolled = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final scrolled = n.metrics.pixels > 0;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = M3eColors.of(context);
    final scheme = colors.scheme;
    final media = MediaQuery.of(context);
    final dark = colors.brightness == Brightness.dark;
    final instant = MediaQuery.disableAnimationsOf(context);
    final fade = instant ? Duration.zero : const Duration(milliseconds: 150);

    // Страница сама заливает фон под строкой состояния: значки подбираем под него, иначе
    // на светлой теме они остались бы светлыми от прошлого экрана.
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
      child: Material(
        color: scheme.surface,
        child: M3eListSurfaceScope(
          surface: M3eListSurface.page,
          child: Padding(
            padding: EdgeInsets.only(bottom: media.padding.bottom),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: fade,
                  color: _scrolled
                      ? scheme.surfaceContainer
                      : scheme.surfaceContainer.withValues(alpha: 0),
                  padding: EdgeInsets.only(top: media.padding.top),
                  child: SizedBox(
                    key: kM3ePageBarKey,
                    height: 64,
                    child: Row(
                      children: [
                        // Отступ панели 4 плюс поля кнопки 4: кнопка в 8 dp от края.
                        const SizedBox(width: 8),
                        _BackButton(
                          onPressed: widget.onBack ??
                              () => Navigator.maybePop(context),
                          label: l10n.m3eA11yBack,
                        ),
                        Expanded(
                          child: ExcludeSemantics(
                            // Малого заголовка в покое нет совсем (на доске opacity 0): так
                            // он не дублирует крупный ни для диктора, ни для поиска текста.
                            child: AnimatedSwitcher(
                              duration: fade,
                              child: _scrolled
                                  ? Align(
                                      key: const ValueKey<String>(
                                          'm3e.bar.title'),
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: Padding(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                                start: 4),
                                        child: Text(
                                          widget.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: m3eTextStyle(
                                            M3eType.titleLarge,
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Заголовок страницы: поля 8/0/24 вокруг headline-medium.
                          Padding(
                            key: kM3ePageTitleKey,
                            padding: const EdgeInsets.only(top: 8, bottom: 24),
                            child: Semantics(
                              header: true,
                              child: Text(
                                widget.title,
                                style: m3eTextStyle(
                                  M3eType.headlineMedium,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          widget.body,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Стандартная кнопка-значок 40 dp без контейнера (`.md-icon-button` по умолчанию):
/// значок onSurfaceVariant, при нажатии круг сжимается в скруглённый квадрат с углом 8.
class _BackButton extends StatefulWidget {
  const _BackButton({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  static const double _size = 40;
  static const double _pressedRadius = 8;

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = M3eColors.of(context).scheme;
    final content = scheme.onSurfaceVariant;
    final instant = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      button: true,
      label: widget.label,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _pressed ? _pressedRadius : _size / 2),
        duration: instant ? Duration.zero : const Duration(milliseconds: 150),
        curve: M3eEasing.standard,
        builder: (context, radius, child) {
          final shape = RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          );
          return SizedBox.square(
            key: kM3ePageBackKey,
            dimension: _size,
            child: Material(
              type: MaterialType.transparency,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: shape,
                onTap: widget.onPressed,
                onHighlightChanged: (value) => setState(() => _pressed = value),
                splashFactory: InkRipple.splashFactory,
                splashColor: content.withValues(alpha: M3eState.pressed),
                highlightColor: Colors.transparent,
                overlayColor: m3eStateLayer(content),
                child: child,
              ),
            ),
          );
        },
        child: Center(
          child: M3eSymbolIcon(M3eSymbol.arrowBack, color: content),
        ),
      ),
    );
  }
}

/// Открывает страницу полноэкранным маршрутом в корневом навигаторе.
///
/// Переход по learn/06 (общая ось X): вход 400 мс emphasized-decelerate, прозрачность
/// 0→1 и сдвиг 30 dp справа; выход 200 мс emphasized-accelerate. При «меньше движения»
/// сдвига нет, остаётся затухание 150 мс. Страницу оборачивает [M3eThemeScope]: маршрут
/// корневого навигатора лежит выше дерева, из которого его открыли, и тему не наследует.
Future<T?> pushM3ePage<T>(BuildContext context, WidgetBuilder builder) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  const shift = 30.0;
  return Navigator.of(context, rootNavigator: true).push<T>(
    PageRouteBuilder<T>(
      transitionDuration: Duration(milliseconds: reduced ? 150 : 400),
      reverseTransitionDuration: Duration(milliseconds: reduced ? 150 : 200),
      pageBuilder: (routeContext, _, __) =>
          M3eThemeScope(child: Builder(builder: builder)),
      transitionsBuilder: (routeContext, animation, _, child) {
        final curved = reduced
            ? animation
            : CurvedAnimation(
                parent: animation,
                curve: M3eEasing.emphasizedDecelerate,
                reverseCurve: M3eEasing.emphasizedAccelerate,
              );
        final faded = FadeTransition(opacity: curved, child: child);
        if (reduced) return faded;
        return AnimatedBuilder(
          animation: curved,
          builder: (context, faded) => Transform.translate(
            offset: Offset(shift * (1 - curved.value), 0),
            child: faded,
          ),
          child: faded,
        );
      },
    ),
  );
}
