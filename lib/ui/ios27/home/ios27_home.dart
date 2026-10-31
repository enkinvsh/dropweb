// Главная iOS, подключённая к приложению: провайдеры → вид → чистый экран.
//
// Тонкая обёртка по образцу Android-главной (`M3eHome`): вся логика сцен лежит в адаптере
// `buildIos27HomeData`, рисует `Ios27HomeScreen`. Здесь только то, что без провайдеров не
// сделать: подписки на вход, якорь таймера, сессия проверки внешнего адреса.
//
// Секунды таймера идут внутри карточки (`Ios27ElapsedBuilder`, останавливается под TickerMode(false)
// и в фоне), поэтому наблюдателя за жизненным циклом приложения здесь нет.

import 'dart:async';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_actions.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_screen.dart';
import 'package:dropweb/ui/ios27/home/ios27_home_view.dart';
import 'package:dropweb/ui/ios27/home/ios27_portrait_lock.dart';
import 'package:dropweb/ui/m3e/home/m3e_elapsed_clock.dart'
    show m3eTickClockProvider;
import 'package:dropweb/ui/m3e/home/m3e_home_providers.dart';
import 'package:dropweb/ui/m3e/home/m3e_ip_session.dart';
import 'package:dropweb/ui/m3e/m3e_emoji.dart' show stripLeadEmoji;
import 'package:dropweb/ui/m3e/screens/m3e_home.dart' show m3eHomeClockProvider;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Главная iOS. Тема (`Ios27ThemeScope`) стоит выше по дереву: её ставит `HomePage`.
class Ios27Home extends ConsumerStatefulWidget {
  const Ios27Home({super.key});

  @override
  ConsumerState<Ios27Home> createState() => _Ios27HomeState();
}

class _Ios27HomeState extends ConsumerState<Ios27Home> {
  /// Состояние индикатора на месте адреса: `settling` — идёт сессия проверки после смены
  /// туннеля (промежуточные адреса не показываем), `waiting` — адреса нет и мы ждём его не
  /// дольше потолка. Уведомитель, а не `setState`: значение меняется из слушателей
  /// провайдеров, в том числе в `initState`, где `setState` нельзя.
  final ValueNotifier<({bool settling, bool waiting})> _ip =
      ValueNotifier((settling: false, waiting: false));

  /// Потолок ожидания адреса, пока его нет (см. [m3eIpWaitProvider]).
  Timer? _ipWaitTimer;

  /// Единая последовательность проверки адреса: все поводы (туннель, смена узла, сигнал
  /// контроллера) сводятся в неё, иначе один connect показал бы один и тот же адрес дважды.
  late final M3eIpSession _ipSession;

  /// Начало сеанса для таймера карточки.
  final Ios27SinceAnchor _anchor = Ios27SinceAnchor();
  DateTime? _since;

  @override
  void initState() {
    super.initState();
    // Проверку внешнего адреса приложение запускает только при виджете «сетевая проверка»
    // старой панели. На новой главной его нет, и без этого адрес оставался бы прочерком.
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
          // Появление узла из null — это включение VPN, его ведёт сигнал туннеля выше.
          if (prev != null && next != null && prev != next) {
            _ipSession.routeChanged();
          }
        },
      )
      // Якорь таймера переставляется только на новое значение источника: по возвращении
      // из фона или при перестройке экрана в провайдере лежит устаревшее число, и пересчёт
      // от него откатил бы секунды назад.
      ..listenManual<Duration?>(
        m3eHomeInputProvider.select((i) => i.runTime),
        (prev, next) =>
            _since = _anchor.update(next, ref.read(m3eTickClockProvider)()),
        fireImmediately: true,
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
    _ipSession.dispose();
    _ipWaitTimer?.cancel();
    _ip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final input = ref.watch(m3eHomeInputProvider);
    final now = ref.watch(m3eHomeClockProvider)();
    final tick = ref.watch(m3eTickClockProvider);
    final route = ref.watch(m3eRouteNodeProvider);
    final actions = ref.watch(ios27HomeActionsProvider);
    final l = AppLocalizations.of(context);
    // Разделитель и дата — по локали экрана, а не по глобальной локали intl.
    final locale =
        Intl.canonicalizedLocale(Localizations.localeOf(context).toString());
    // Над главной лежит лист, страница или окно: нижний ряд уходит, пока они не закроются.
    final covered = ModalRoute.isCurrentOf(context) == false;

    return Ios27PortraitLock(
      child: ValueListenableBuilder<({bool settling, bool waiting})>(
        valueListenable: _ip,
        builder: (context, ip, _) {
          final data = buildIos27HomeData(
            l,
            input,
            now: now,
            locale: locale,
            ipPending: ip.waiting,
            ipSettling: ip.settling,
            since: _since,
            // Узел вида «🇳🇱 Amsterdam» читается диктором как «флаг Нидерландов»: эмодзи убираем.
            routeName: route == null ? null : stripLeadEmoji(route),
          );
          return Ios27HomeScreen(
            data: data,
            now: tick,
            glassAway: covered,
            onToggle: () => unawaited(actions.toggleVpn(context, ref)),
            onSettings: () => actions.openSettings(context),
            onSubscriptions: () => actions.openSubscriptions(context),
            onRoute: () => actions.openRoute(context),
            onRefresh: () => unawaited(actions.refresh(context, ref)),
            onLink: (url) {
              final uri = Uri.tryParse(url);
              if (uri != null) actions.openLink(uri);
            },
          );
        },
      ),
    );
  }
}
