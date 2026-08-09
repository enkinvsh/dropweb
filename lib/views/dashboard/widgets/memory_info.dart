import 'dart:async';
import 'dart:io';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/common.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _memoryInfoStateNotifier = ValueNotifier<TrafficValue>(
  const TrafficValue(value: 0),
);

class MemoryInfo extends ConsumerStatefulWidget {
  const MemoryInfo({super.key});

  @override
  ConsumerState<MemoryInfo> createState() => _MemoryInfoState();
}

class _MemoryInfoState extends ConsumerState<MemoryInfo> {
  Timer? timer;
  bool _isCurrentPage = true;
  bool _polling = false;

  /// Bumped on every stop and every start, so a post-frame callback left over
  /// from a previous cycle can't arm a second, parallel timer chain.
  int _pollGeneration = 0;

  @override
  void initState() {
    super.initState();
    globalState.isForeground.addListener(_syncPolling);
    ref.listenManual(
      isCurrentPageProvider(PageLabel.dashboard),
      (_, next) {
        _isCurrentPage = next;
        _syncPolling();
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    globalState.isForeground.removeListener(_syncPolling);
    _polling = false;
    _pollGeneration++;
    timer?.cancel();
    timer = null;
    super.dispose();
  }

  /// The 2s probe is an FFI round-trip into the Go core. Off the dashboard, or
  /// with the window blurred/hidden, it renders nothing a user can see and only
  /// keeps macOS App Nap from ever engaging.
  bool get _shouldPoll => _isCurrentPage && globalState.isForeground.value;

  void _syncPolling() {
    if (!mounted) return;
    if (_shouldPoll) {
      if (_polling) return;
      _polling = true;
      unawaited(_updateMemory(++_pollGeneration));
    } else {
      _polling = false;
      _pollGeneration++;
      timer?.cancel();
      timer = null;
    }
  }

  Future<void> _updateMemory(int generation) async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || generation != _pollGeneration) return;
      final rss = ProcessInfo.currentRss;
      final value = clashLib != null ? rss : await clashCore.getMemory() + rss;
      // Re-check after the await: the app can go background mid-probe, and
      // arming the next timer then would resurrect the poll behind our back.
      if (!mounted || generation != _pollGeneration) return;
      _memoryInfoStateNotifier.value = TrafficValue(value: value);
      timer = Timer(
        const Duration(seconds: 2),
        () => unawaited(_updateMemory(generation)),
      );
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: getWidgetHeight(1),
        child: CommonCard(
          info: Info(
            label: appLocalizations.memoryInfo,
          ),
          onPressed: clashCore.requestGc,
          child: Container(
            padding: baseInfoEdgeInsets.copyWith(
              top: 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: globalState.measure.bodyMediumHeight + 2,
                  child: ValueListenableBuilder(
                    valueListenable: _memoryInfoStateNotifier,
                    builder: (_, trafficValue, __) => Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          trafficValue.showValue,
                          style: context.textTheme.bodyMedium?.toLight
                              .adjustSize(1),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Text(
                          trafficValue.showUnit,
                          style: context.textTheme.bodyMedium?.toLight
                              .adjustSize(1),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      );
}
