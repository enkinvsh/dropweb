import 'dart:async';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import 'item.dart';

class ConnectionsView extends ConsumerStatefulWidget {
  const ConnectionsView({super.key});

  @override
  ConsumerState<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends ConsumerState<ConnectionsView>
    with PageMixin {
  final _connectionsStateNotifier = ValueNotifier<ConnectionsState>(
    const ConnectionsState(),
  );
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );

  Timer? timer;
  bool _isCurrentPage = true;
  bool _polling = false;

  /// Bumped on every stop and every start, so a post-frame callback left over
  /// from a previous cycle can't arm a second, parallel timer chain.
  int _pollGeneration = 0;

  @override
  List<Widget> get actions => [
        IconButton(
          onPressed: () async {
            clashCore.closeConnections();
            _connectionsStateNotifier.value =
                _connectionsStateNotifier.value.copyWith(
              connections: await clashCore.getConnections(),
            );
          },
          icon: HugeIcon(icon: HugeIcons.strokeRoundedDelete01, size: 24),
        ),
      ];

  @override
  Null Function(String value) get onSearch => (value) {
        _connectionsStateNotifier.value =
            _connectionsStateNotifier.value.copyWith(
          query: value,
        );
      };

  @override
  Null Function(List<String> keywords) get onKeywordsUpdate => (keywords) {
        _connectionsStateNotifier.value =
            _connectionsStateNotifier.value.copyWith(keywords: keywords);
      };

  /// The 1s refresh pulls the whole connection table over FFI. Off this page,
  /// or with the window blurred/hidden, nobody sees the result and the timer
  /// alone is enough to keep macOS App Nap from ever engaging.
  bool get _shouldPoll => _isCurrentPage && globalState.isForeground.value;

  void _syncPolling() {
    if (!mounted) return;
    if (_shouldPoll) {
      if (_polling) return;
      _polling = true;
      unawaited(_updateConnections(++_pollGeneration));
    } else {
      _polling = false;
      _pollGeneration++;
      timer?.cancel();
      timer = null;
    }
  }

  Future<void> _updateConnections(int generation) async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || generation != _pollGeneration) return;
      final connections = await clashCore.getConnections();
      // Re-check after the await: the page can be left or the window hidden
      // mid-fetch, and arming the next timer then would resurrect the poll.
      if (!mounted || generation != _pollGeneration) return;
      _connectionsStateNotifier.value =
          _connectionsStateNotifier.value.copyWith(
        connections: connections,
      );
      timer = Timer(
        const Duration(seconds: 1),
        () => unawaited(_updateConnections(generation)),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    globalState.isForeground.addListener(_syncPolling);
    ref.listenManual(
      isCurrentPageProvider(
        PageLabel.connections,
        handler: (pageLabel, viewMode) =>
            pageLabel == PageLabel.tools && viewMode == ViewMode.mobile,
      ),
      (prev, next) {
        if (prev != next && next == true) {
          initPageState();
        }
        _isCurrentPage = next;
        _syncPolling();
      },
      fireImmediately: true,
    );
  }

  Future<void> _handleBlockConnection(String id) async {
    clashCore.closeConnection(id);
    _connectionsStateNotifier.value = _connectionsStateNotifier.value.copyWith(
      connections: await clashCore.getConnections(),
    );
  }

  @override
  void dispose() {
    globalState.isForeground.removeListener(_syncPolling);
    _polling = false;
    _pollGeneration++;
    timer?.cancel();
    _connectionsStateNotifier.dispose();
    _scrollController.dispose();
    timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<ConnectionsState>(
        valueListenable: _connectionsStateNotifier,
        builder: (_, state, __) {
          final connections = state.list;
          if (connections.isEmpty) {
            return NullStatus(
              label: appLocalizations.nullTip(appLocalizations.connections),
            );
          }
          return CommonScrollBar(
            controller: _scrollController,
            child: ListView.separated(
              controller: _scrollController,
              itemBuilder: (_, index) {
                final connection = connections[index];
                return ConnectionItem(
                  key: Key(connection.id),
                  connection: connection,
                  onClickKeyword: (value) {
                    context.commonScaffoldState?.addKeyword(value);
                  },
                  trailing: IconButton(
                    icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedBlocked, size: 24),
                    onPressed: () {
                      _handleBlockConnection(connection.id);
                    },
                  ),
                );
              },
              separatorBuilder: (context, index) => const Divider(
                height: 0,
              ),
              itemCount: connections.length,
            ),
          );
        },
      );
}
