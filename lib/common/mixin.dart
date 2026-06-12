import 'package:dropweb/models/models.dart';
import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
import 'context.dart';

mixin AutoDisposeNotifierMixin<T> on AutoDisposeNotifier<T> {
  set value(T value) {
    state = value;
  }

  // Mirror-forward hook: when a config slice provider's state changes, this
  // fires its `onUpdate` (lib/providers/config.dart), which routes the new
  // slice into the flat `globalState.config` mirror via
  // `ConfigRepository.syncSlice` (lib/common/config_repository.dart). The
  // reverse direction (mirror → providers) is each provider's `build()`; the
  // aggregation (providers → mirror) is `configState`
  // (lib/providers/state.dart). Field coverage across both halves is locked by
  // test/common/config_roundtrip_test.dart.
  @override
  bool updateShouldNotify(previous, next) {
    final res = super.updateShouldNotify(previous, next);
    if (res) {
      onUpdate(next);
    }
    return res;
  }

  void onUpdate(T value) {}
}

mixin PageMixin<T extends StatefulWidget> on State<T> {
  void onPageShow() {
    initPageState();
  }

  void initPageState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final commonScaffoldState = context.commonScaffoldState;
      commonScaffoldState?.actions = actions;
      commonScaffoldState?.floatingActionButton = floatingActionButton;
      commonScaffoldState?.onKeywordsUpdate = onKeywordsUpdate;
      commonScaffoldState?.updateSearchState(
        (_) => onSearch != null
            ? AppBarSearchState(
                onSearch: onSearch!,
              )
            : null,
      );
    });
  }

  void onPageHidden() {}

  List<Widget> get actions => [];

  Widget? get floatingActionButton => null;

  Function(String)? get onSearch => null;

  Function(List<String>)? get onKeywordsUpdate => null;
}
