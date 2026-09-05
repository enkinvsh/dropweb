import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/app.g.dart';

@riverpod
class RealTunEnable extends _$RealTunEnable with AutoDisposeNotifierMixin {
  @override
  bool build() => globalState.appState.realTunEnable;

  @override
  void onUpdate(bool value) {
    globalState.appState = globalState.appState.copyWith(
      realTunEnable: value,
    );
  }
}

@riverpod
class Logs extends _$Logs with AutoDisposeNotifierMixin {
  @override
  FixedList<Log> build() => globalState.appState.logs;

  void addLog(Log value) {
    state = state.copyWith()..add(value);
  }

  @override
  void onUpdate(FixedList<Log> value) {
    globalState.appState = globalState.appState.copyWith(
      logs: value,
    );
  }
}

@riverpod
class Requests extends _$Requests with AutoDisposeNotifierMixin {
  @override
  FixedList<Connection> build() => globalState.appState.requests;

  @override
  void onUpdate(FixedList<Connection> value) {
    globalState.appState = globalState.appState.copyWith(
      requests: value,
    );
  }

  void addRequest(Connection value) {
    state = state.copyWith()..add(value);
  }
}

@riverpod
class Providers extends _$Providers with AutoDisposeNotifierMixin {
  @override
  List<ExternalProvider> build() => globalState.appState.providers;

  @override
  void onUpdate(List<ExternalProvider> value) {
    globalState.appState = globalState.appState.copyWith(
      providers: value,
    );
  }

  void setProvider(ExternalProvider? provider) {
    if (provider == null) return;
    final index = state.indexWhere((item) => item.name == provider.name);
    if (index == -1) return;
    state = List.from(state)..[index] = provider;
  }
}

@riverpod
class Packages extends _$Packages with AutoDisposeNotifierMixin {
  @override
  List<Package> build() => globalState.appState.packages;

  @override
  void onUpdate(List<Package> value) {
    globalState.appState = globalState.appState.copyWith(
      packages: value,
    );
  }
}

@riverpod
class AppBrightness extends _$AppBrightness with AutoDisposeNotifierMixin {
  @override
  Brightness? build() => globalState.appState.brightness;

  @override
  void onUpdate(Brightness? value) {
    globalState.appState = globalState.appState.copyWith(
      brightness: value,
    );
  }

  void setState(Brightness? value) {
    state = value;
  }
}

@riverpod
class Traffics extends _$Traffics with AutoDisposeNotifierMixin {
  @override
  FixedList<Traffic> build() => globalState.appState.traffics;

  @override
  void onUpdate(FixedList<Traffic> value) {
    globalState.appState = globalState.appState.copyWith(
      traffics: value,
    );
  }

  void addTraffic(Traffic value) {
    state = state.copyWith()..add(value);
  }

  void clear() {
    state = state.copyWith()..clear();
  }
}

@riverpod
class TotalTraffic extends _$TotalTraffic with AutoDisposeNotifierMixin {
  @override
  Traffic build() => globalState.appState.totalTraffic;

  @override
  void onUpdate(Traffic value) {
    globalState.appState = globalState.appState.copyWith(
      totalTraffic: value,
    );
  }
}

@riverpod
class LocalIp extends _$LocalIp with AutoDisposeNotifierMixin {
  @override
  String? build() => globalState.appState.localIp;

  @override
  void onUpdate(String? value) {
    globalState.appState = globalState.appState.copyWith(
      localIp: value,
    );
  }

  @override
  set state(String? value) {
    super.state = value;
    globalState.appState = globalState.appState.copyWith(
      localIp: state,
    );
  }
}

@riverpod
class RunTime extends _$RunTime with AutoDisposeNotifierMixin {
  @override
  int? build() => globalState.appState.runTime;

  @override
  void onUpdate(int? value) {
    globalState.appState = globalState.appState.copyWith(
      runTime: value,
    );
  }

  bool get isStart => state != null;
}

@riverpod
class ViewSize extends _$ViewSize with AutoDisposeNotifierMixin {
  @override
  Size build() => globalState.appState.viewSize;

  @override
  void onUpdate(Size value) {
    globalState.appState = globalState.appState.copyWith(
      viewSize: value,
    );
  }

  ViewMode get viewMode => utils.getViewMode(state.width);

  bool get isMobileView => viewMode == ViewMode.mobile;
}

@riverpod
double viewWidth(Ref ref) => ref.watch(viewSizeProvider).width;

@riverpod
ViewMode viewMode(Ref ref) => utils.getViewMode(ref.watch(viewWidthProvider));

@riverpod
bool isMobileView(Ref ref) => ref.watch(viewModeProvider) == ViewMode.mobile;

@riverpod
double viewHeight(Ref ref) => ref.watch(viewSizeProvider).height;

@riverpod
class Init extends _$Init with AutoDisposeNotifierMixin {
  @override
  bool build() => globalState.appState.isInit;

  @override
  void onUpdate(bool value) {
    globalState.appState = globalState.appState.copyWith(
      isInit: value,
    );
  }
}

@riverpod
class CurrentPageLabel extends _$CurrentPageLabel
    with AutoDisposeNotifierMixin {
  @override
  PageLabel build() => globalState.appState.pageLabel;

  @override
  void onUpdate(PageLabel value) {
    globalState.appState = globalState.appState.copyWith(
      pageLabel: value,
    );
  }
}

@riverpod
class SortNum extends _$SortNum with AutoDisposeNotifierMixin {
  @override
  int build() => globalState.appState.sortNum;

  @override
  void onUpdate(int value) {
    globalState.appState = globalState.appState.copyWith(
      sortNum: value,
    );
  }

  int add() => state++;
}

@riverpod
class CheckIpNum extends _$CheckIpNum with AutoDisposeNotifierMixin {
  @override
  int build() => globalState.appState.checkIpNum;

  @override
  void onUpdate(int value) {
    globalState.appState = globalState.appState.copyWith(
      checkIpNum: value,
    );
  }

  int add() => state++;
}

@riverpod
class BackBlock extends _$BackBlock with AutoDisposeNotifierMixin {
  @override
  bool build() => globalState.appState.backBlock;

  @override
  void onUpdate(bool value) {
    globalState.appState = globalState.appState.copyWith(
      backBlock: value,
    );
  }
}

@riverpod
class Version extends _$Version with AutoDisposeNotifierMixin {
  @override
  int build() => globalState.appState.version;

  @override
  void onUpdate(int value) {
    globalState.appState = globalState.appState.copyWith(
      version: value,
    );
  }
}

@riverpod
class Groups extends _$Groups with AutoDisposeNotifierMixin {
  @override
  List<Group> build() => globalState.appState.groups;

  @override
  void onUpdate(List<Group> value) {
    globalState.appState = globalState.appState.copyWith(
      groups: value,
    );
  }
}

/// DELAY_DIAG (handoff `docs/plans/2026-07-05-handoff-delay-badges.md` §4) —
/// the single renderer for a `delayDataSource` key.
///
/// The whole value of the DELAY_DIAG instrumentation is that a human running
/// `logcat | grep DELAY_DIAG` can put a `writeKey=` line next to a `readKey=`
/// line and see a mismatch by eye. That only works if every side spells a key
/// the same way, so the write side (`views/proxies/common.dart`), the apply
/// side (`DelayDataSource.setDelay`) and the read side (`providers/state.dart`
/// `getDelay`) all format through THIS function. Do not inline a variant.
///
/// An empty `url` or `name` is precisely the V7 symptom — the core omits them
/// on its nil-proxy and panic paths, so the reply lands under `("", "")` while
/// the badge reads a different key and stays blank forever. `(url=, name=)` is
/// far too easy to miss in a wall of log, hence the explicit `<EMPTY>`
/// placeholder plus a greppable `EMPTY_KEY!` marker.
///
/// The double quotes around the URL are LOAD-BEARING, not decoration.
/// `commonPrint.log` pipes everything through `redactUrls`, whose URL pattern
/// is `(?:https?|clash|dropweb)://[^\s<>"']+` — it runs to the next whitespace
/// or quote, so an unquoted `url=…/generate_204, name=…` hands the redactor
/// the segment `generate_204,` (13 chars, WITH the comma). That is over the
/// 12-char benign threshold in `log_redaction.dart`, so the path would come
/// out as `/[REDACTED]` and the key would stop being comparable. The closing
/// quote ends the match at the real end of the URL and `generate_204` (exactly
/// 12) survives. Any reformatting here must keep a quote or whitespace
/// immediately after the URL.
String formatDelayKey(String url, String name) {
  final rendered = '(url="${url.isEmpty ? '<EMPTY>' : url}", '
      'name="${name.isEmpty ? '<EMPTY>' : name}")';
  return url.isEmpty || name.isEmpty ? '$rendered EMPTY_KEY!' : rendered;
}

@riverpod
class DelayDataSource extends _$DelayDataSource with AutoDisposeNotifierMixin {
  @override
  DelayMap build() => globalState.appState.delayMap;

  @override
  void onUpdate(DelayMap value) {
    globalState.appState = globalState.appState.copyWith(
      delayMap: value,
    );
  }

  void setDelay(Delay delay) {
    // DELAY_DIAG (handoff §4, write-boundary `setDelay`): report the outcome of
    // the equality guard BEFORE it runs, so hypothesis B (a repeat measurement
    // with an identical value is silently swallowed and the freshness signal is
    // lost) is visible rather than inferred.
    //
    // Hoisted out of the `if` for logging only — this is the exact expression
    // the guard used to evaluate inline, evaluated exactly once either way.
    final previousValue = state[delay.url]?[delay.name];
    if (kDebugMode) {
      // kDebugMode-gated deliberately: besides the app-side delay tests, this
      // is also fed by the core's `onDelay` push (`manager/clash_manager.dart`),
      // a background stream that runs for the whole session. The in-app log
      // buffer is a `FixedList` of only `maxLength` (150) entries, so an
      // unconditional line here would keep it permanently full of DELAY_DIAG
      // and evict the very support-bundle evidence this wave exists to collect.
      // Handoff §4 scopes capture to the `app.dropweb.debug` build anyway.
      commonPrint.log(
        '[DELAY_DIAG] '
        '${previousValue != delay.value ? 'WRITE_APPLY' : 'WRITE_NOOP_EQUAL'} '
        'key=${formatDelayKey(delay.url, delay.name)} '
        'old=$previousValue new=${delay.value}',
      );
    }
    if (previousValue != delay.value) {
      final newDelayMap = Map<String, Map<String, int?>>.from(state);
      if (newDelayMap[delay.url] == null) {
        newDelayMap[delay.url] = <String, int?>{};
      }
      newDelayMap[delay.url]![delay.name] = delay.value;
      state = newDelayMap;
    }
  }
}

@riverpod
class ProxiesQuery extends _$ProxiesQuery with AutoDisposeNotifierMixin {
  @override
  String build() => globalState.appState.proxiesQuery;

  @override
  void onUpdate(String value) {
    globalState.appState = globalState.appState.copyWith(
      proxiesQuery: value,
    );
  }
}
