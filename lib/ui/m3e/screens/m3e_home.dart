// Главная Android: сборка экрана из готовых компонентов по раскладке доски
// (canon/dropweb/android.css: `.dr-main`, `.dr-top`, `.dr-joy`, `.dr-dock`).
// Платформу не читаем: golden на macOS и устройство строят один и тот же кадр.

import 'dart:async';

import 'package:dropweb/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../home/m3e_actions.dart';
import '../home/m3e_elapsed_clock.dart';
import '../home/m3e_home_model.dart';
import '../home/m3e_home_providers.dart';
import '../home/m3e_ip_session.dart';
import '../symbols.g.dart';
import '../theme/m3e_theme_scope.dart';
import '../widgets/m3e_hero_button.dart';
import '../widgets/m3e_home_backdrop.dart';
import '../widgets/m3e_round_button.dart';
import '../widgets/m3e_sub_card.dart';
import '../widgets/m3e_symbol.dart';

/// Ключи для проверки раскладки: имена совпадают с `test/m3e/ref/layout.json`.
const Key kM3eNavBtnKey = ValueKey<String>('m3e.navBtn');
const Key kM3eSubsBtnKey = ValueKey<String>('m3e.subsBtn');
const Key kM3eRouteBtnKey = ValueKey<String>('m3e.routeBtn');
const Key kM3eJoyKey = ValueKey<String>('m3e.joy');

/// Часы экрана: срок подписки считается от них. Тесты подменяют, чтобы кадр не
/// зависел от даты запуска.
final m3eHomeClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

/// Отступ карточки от верха: `.dr-main` 52 = строка состояния 44 + 8, плюс
/// `.dr-top` margin-top 56 − 44 из раскладки доски = строка состояния + 64.
const double _kCardTop = 64;

/// Низ ряда `joy`: поле 52 доски = жестовая полоса 24 + 28.
const double _kJoyBottom = 28;
const double _kJoyHeight = 80;
const double _kSidePad = 16;
const double _kHeroSize = 88;

/// Главная: вход приложения → вид → экран. Тема (`M3eThemeScope`) стоит выше по
/// дереву: на устройстве её ставит `HomePage`, в тестах — стенд.
class M3eHome extends ConsumerStatefulWidget {
  const M3eHome({super.key});

  @override
  ConsumerState<M3eHome> createState() => _M3eHomeState();
}

class _M3eHomeState extends ConsumerState<M3eHome> with WidgetsBindingObserver {
  /// Состояние индикатора на месте адреса: `settling` — идёт сессия проверки после смены
  /// туннеля (промежуточные адреса не показываем), `waiting` — адреса нет и мы ждём его
  /// не дольше потолка. Уведомитель, а не `setState`: значение меняется из слушателей
  /// провайдеров, в том числе в `initState`, где `setState` нельзя.
  final ValueNotifier<({bool settling, bool waiting})> _ip =
      ValueNotifier((settling: false, waiting: false));

  /// Потолок ожидания адреса, пока его нет (см. [m3eIpWaitProvider]).
  Timer? _ipWaitTimer;

  /// Единая последовательность проверки адреса (см. [M3eIpSession]).
  late final M3eIpSession _ipSession;

  /// Секунды таймера сеанса: считаются здесь, а не берутся из `runTimeProvider`, который
  /// приходит раз в 2 с (общий период `startUpdateTasks`).
  late final M3eElapsedClock _elapsed;

  bool _foreground = true;
  bool _tickers = true;

  /// Бег по секундам нужен, только пока экран виден и приложение на переднем плане:
  /// иначе таймер каждую секунду будил бы закрытый экран и батарею.
  void _syncTick() => _elapsed.setTick(tick: _tickers && _foreground);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = switch (state) {
      AppLifecycleState.paused ||
      AppLifecycleState.hidden ||
      AppLifecycleState.detached =>
        false,
      _ => true,
    };
    _syncTick();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Поверх главной лежит непрозрачный маршрут: тикеры под ним выключены.
    _tickers = TickerMode.valuesOf(context).enabled;
    _syncTick();
  }

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null ||
        (lifecycle != AppLifecycleState.paused &&
            lifecycle != AppLifecycleState.hidden &&
            lifecycle != AppLifecycleState.detached);
    WidgetsBinding.instance.addObserver(this);
    _elapsed = M3eElapsedClock(ref.read(m3eTickClockProvider))
      ..update(ref.read(m3eHomeInputProvider).runTime);
    // Проверку внешнего адреса приложение запускает только при виджете «сетевая
    // проверка» на старой панели (`app_state_manager.dart`). На M3E-главной его нет,
    // и без этого адрес оставался бы прочерком. Все поводы (туннель, смена узла, сигнал
    // контроллера) сводит в одну последовательность [M3eIpSession]: иначе один connect
    // сбрасывал и показывал один и тот же адрес дважды.
    _ipSession = M3eIpSession(
      io: ref.read(m3eIpRefreshProvider),
      settle: ref.read(m3eIpSettleProvider),
      connectWait: ref.read(m3eIpConnectWaitProvider),
      afterBump: ref.read(m3eIpBumpDelayProvider),
      retryPause: ref.read(m3eIpRetryPauseProvider),
      grace: ref.read(m3eIpGraceProvider),
      onSettling: ({required settling}) =>
          _ip.value = (settling: settling, waiting: _ip.value.waiting),
      log: ref.read(m3eIpLogProvider),
    );
    ref
      ..listenManual(
        m3eIpCheckSignalProvider,
        (prev, next) {
          if (prev == null) {
            _ipSession.start();
          } else if (prev.$2 != next.$2) {
            _ipSession.tunnelChanged(on: next.$2);
          } else if (prev.$1 != next.$1) {
            _ipSession.bump();
          }
        },
        fireImmediately: true,
      )
      ..listenManual<String?>(
        m3eRouteNodeProvider,
        (prev, next) {
          // Появление узла из null — это включение VPN, его ведёт сигнал туннеля выше;
          // переприменение профиля сразу после подключения отсекает окно в сессии.
          if (prev != null && next != null && prev != next) {
            _ipSession.routeChanged();
          }
        },
      )
      // Только новое значение источника: по возвращении из фона в провайдере лежит
      // устаревшее число, и пересчёт якоря от него откатил бы таймер.
      ..listenManual<Duration?>(
        m3eHomeInputProvider.select((i) => i.runTime),
        (prev, next) => _elapsed.update(next),
      )
      // Нет адреса — ждём его не дольше потолка; пришёл адрес — ожидание кончено.
      ..listenManual<String?>(
        m3eHomeInputProvider.select((i) => i.ipAddress),
        (prev, next) => next == null ? _waitIp() : _stopWaitIp(),
        fireImmediately: true,
      );
  }

  void _waitIp() {
    _ip.value = (settling: _ip.value.settling, waiting: true);
    _ipWaitTimer?.cancel();
    _ipWaitTimer = Timer(ref.read(m3eIpWaitProvider), () {
      _ip.value = (settling: _ip.value.settling, waiting: false);
    });
  }

  void _stopWaitIp() {
    _ipWaitTimer?.cancel();
    _ip.value = (settling: _ip.value.settling, waiting: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _elapsed.dispose();
    _ipSession.dispose();
    _ipWaitTimer?.cancel();
    _ip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final input = ref.watch(m3eHomeInputProvider);
    final now = ref.watch(m3eHomeClockProvider)();
    final l = AppLocalizations.of(context);
    // Разделитель и дата — по локали экрана, а не по глобальной локали intl.
    final locale = Intl.canonicalizedLocale(
      Localizations.localeOf(context).toString(),
    );
    final actions = ref.watch(m3eHomeActionsProvider);
    return ValueListenableBuilder<({bool settling, bool waiting})>(
      valueListenable: _ip,
      builder: (context, ip, _) {
        final view = buildM3eHomeView(
          l,
          input,
          now: now,
          locale: locale,
          ipPending: ip.waiting,
          ipSettling: ip.settling,
        );
        return M3eHomeScreen(
          view: view,
          linksTappable: input.linksTappable,
          onToggle:
              view.heroPressable ? () => actions.toggleVpn(context, ref) : null,
          onSettings: () => actions.openSettings(context, ref),
          onSubscriptions: () => actions.openSubscriptions(context, ref),
          onRoute: () => actions.openRoute(context, ref),
          onRefresh: () => actions.refresh(context, ref),
          onLink: actions.openLink,
          liveTimer: _elapsed,
        );
      },
    );
  }
}

/// Чистая отрисовка главной по готовому виду [M3eHomeView].
class M3eHomeScreen extends StatelessWidget {
  const M3eHomeScreen({
    super.key,
    required this.view,
    this.linksTappable = true,
    this.onToggle,
    this.onSettings,
    this.onSubscriptions,
    this.onRoute,
    this.onRefresh,
    this.onLink,
    this.liveTimer,
  });

  final M3eHomeView view;

  /// Таймер сеанса раз в секунду; без него показывается строка из [view].
  final ValueListenable<String?>? liveTimer;

  /// В магазинных сборках ссылки в объявлении не нажимаются.
  final bool linksTappable;
  final VoidCallback? onToggle;
  final VoidCallback? onSettings;
  final VoidCallback? onSubscriptions;
  final VoidCallback? onRoute;
  final VoidCallback? onRefresh;
  final void Function(Uri uri)? onLink;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = M3eColors.of(context);
    final media = MediaQuery.of(context);
    final safe = media.padding;
    final dark = colors.brightness == Brightness.dark;

    // Фон рисует сам экран под строкой состояния: иконки задаём явно, чтобы на
    // светлой теме они не остались светлыми от прошлого экрана.
    final overlay =
        (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );

    final size = media.size;
    // Центр кнопки: волна фона расходится от неё (`--dr-wave-x/y`).
    final heroCenter = Offset(
      size.width / 2,
      size.height - safe.bottom - _kJoyBottom - _kJoyHeight / 2,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Stack(
        children: [
          Positioned.fill(
            child: M3eHomeBackdrop(
              state: view.heroState,
              blocked: view.blocked,
              waveOrigin: heroCenter,
            ),
          ),
          Positioned(
            left: _kSidePad,
            right: _kSidePad,
            top: safe.top + _kCardTop,
            // Карточка и подвал с объявлением — один блок: раскладка мерит их вместе, а
            // подвал всегда стоит вплотную под карточкой, как бы она ни выросла.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                M3eSubCard(
                  data: view.card,
                  onRefresh: onRefresh,
                  liveTimer: liveTimer,
                ),
                M3eCardFooter(
                  text: view.card.announce,
                  onLink: linksTappable ? onLink : null,
                ),
              ],
            ),
          ),
          Positioned(
            right: _kSidePad,
            top: safe.top + kM3eNavButtonTop,
            child: M3eTonalIconButton(
              key: kM3eNavBtnKey,
              size: kM3eNavButtonSize,
              icon: const M3eSymbolIcon(M3eSymbol.settings),
              semanticLabel: l.m3eA11ySettings,
              onPressed: onSettings,
            ),
          ),
          Positioned(
            left: _kSidePad,
            right: _kSidePad,
            bottom: safe.bottom + _kJoyBottom,
            height: _kJoyHeight,
            child: Semantics(
              container: true,
              label: l.m3eA11yJoy,
              child: Stack(
                key: kM3eJoyKey,
                clipBehavior: Clip.none,
                children: [
                  // Боковые кнопки по 48 стоят в `.dr-joy` с полем 4 по бокам и по
                  // центру высоты 80.
                  Positioned(
                    left: 4,
                    top: (_kJoyHeight - 48) / 2,
                    child: M3eTonalIconButton(
                      key: kM3eSubsBtnKey,
                      size: 48,
                      // Владелец 2026-10-29: на кнопке подписок всегда знак-стопка,
                      // логотип провайдера (`dropweb-logo`) сюда не ставится.
                      icon: const M3eSubMark(),
                      semanticLabel: l.m3eA11ySubs,
                      onPressed: onSubscriptions,
                    ),
                  ),
                  // Кнопка 88 при ряде 80: поле −4 сверху и снизу (`margin: -4px 0`),
                  // поэтому позиция явная, а не из ограничений ряда.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (_kJoyHeight - _kHeroSize) / 2,
                    height: _kHeroSize,
                    child: Center(
                      child: M3eHeroButton(
                        state: view.heroState,
                        disabled: view.heroDisabled,
                        onPressed: onToggle,
                        semanticLabel: view.heroLabel,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: (_kJoyHeight - 48) / 2,
                    // `dw_exit` на старом экране — строка выхода, открывающая выбор
                    // страны; автотесты через adb ищут вход в выбор маршрута по нему.
                    child: M3eTonalIconButton(
                      key: kM3eRouteBtnKey,
                      size: 48,
                      icon: const M3eSymbolIcon(M3eSymbol.public),
                      semanticLabel: l.m3eA11yRoute,
                      semanticIdentifier: 'dw_exit',
                      onPressed: onRoute,
                      muted: view.blocked,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
