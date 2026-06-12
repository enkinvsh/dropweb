import 'package:dropweb/common/common.dart';
import 'package:dropweb/plugins/tile.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/config.g.dart';

// CONFIG MIRROR — slice enumeration site (1 of 3).
// These 12 `@riverpod` slices are the UI-isolate source of truth for `Config`.
// Each one seeds FORWARD from the flat mirror in its `build()`
// (`globalState.config.<slice>`) and mirrors BACK in its `onUpdate` via the
// single write path `globalState.configRepository.syncSlice(...)`
// (lib/common/config_repository.dart).
// The other two enumeration sites that MUST stay in lockstep with the field
// list here:
//   * lib/providers/state.dart — `configState` re-aggregates these 12 slices.
//   * lib/models/config.dart   — the `Config` freezed model (the field list).
// Adding a Config field means: add the field there, add a slice here (build +
// onUpdate), and aggregate it in `configState`. The drift-lock that fails if
// any of those is forgotten: test/common/config_roundtrip_test.dart.
@riverpod
class AppSetting extends _$AppSetting with AutoDisposeNotifierMixin {
  @override
  AppSettingProps build() => globalState.config.appSetting;

  @override
  void onUpdate(AppSettingProps value) {
    globalState.configRepository.syncSlice(
      (c) => c.copyWith(appSetting: value),
    );
  }

  void updateState(AppSettingProps Function(AppSettingProps state) builder) {
    state = builder(state);
  }
}

@riverpod
class WindowSetting extends _$WindowSetting with AutoDisposeNotifierMixin {
  @override
  WindowProps build() => globalState.config.windowProps;

  @override
  void onUpdate(WindowProps value) {
    globalState.configRepository.syncSlice(
      (c) => c.copyWith(windowProps: value),
    );
  }

  void updateState(WindowProps Function(WindowProps state) builder) {
    state = builder(state);
  }
}

@riverpod
class VpnSetting extends _$VpnSetting with AutoDisposeNotifierMixin {
  @override
  VpnProps build() => globalState.config.vpnProps;

  @override
  void onUpdate(VpnProps value) {
    globalState.configRepository.syncSlice(
      (c) => c.copyWith(vpnProps: value),
    );
  }

  void updateState(VpnProps Function(VpnProps state) builder) {
    state = builder(state);
  }
}

@riverpod
class NetworkSetting extends _$NetworkSetting with AutoDisposeNotifierMixin {
  @override
  NetworkProps build() => globalState.config.networkProps;

  @override
  void onUpdate(NetworkProps value) {
    globalState.configRepository.syncSlice(
      (c) => c.copyWith(networkProps: value),
    );
  }

  void updateState(NetworkProps Function(NetworkProps state) builder) {
    state = builder(state);
  }
}

@riverpod
class ThemeSetting extends _$ThemeSetting with AutoDisposeNotifierMixin {
  @override
  ThemeProps build() => globalState.config.themeProps;

  @override
  void onUpdate(ThemeProps value) {
    globalState.configRepository.syncSlice(
      (c) => c.copyWith(themeProps: value),
    );
  }

  void updateState(ThemeProps Function(ThemeProps state) builder) {
    state = builder(state);
  }
}

@riverpod
class Profiles extends _$Profiles with AutoDisposeNotifierMixin {
  @override
  List<Profile> build() => globalState.config.profiles;

  @override
  void onUpdate(List<Profile> value) {
    globalState.configRepository.syncSlice(
      (c) => c.copyWith(profiles: value),
    );
  }

  String? _getLabel(String? label, String id) {
    final realLabel = label ?? id;
    final hasDup = state.indexWhere(
            (element) => element.label == realLabel && element.id != id) !=
        -1;
    if (hasDup) {
      return _getLabel(utils.getOverwriteLabel(realLabel), id);
    } else {
      return label;
    }
  }

  void setProfile(Profile profile) {
    final profilesTemp = List<Profile>.from(state);
    final index =
        profilesTemp.indexWhere((element) => element.id == profile.id);
    final updateProfile = profile.copyWith(
      label: _getLabel(profile.label, profile.id),
    );
    if (index == -1) {
      profilesTemp.add(updateProfile);
    } else {
      profilesTemp[index] = updateProfile;
    }
    state = profilesTemp;
  }

  void updateProfile(String profileId, Profile Function(Profile profile) builder) {
    final profilesTemp = List<Profile>.from(state);
    final index = profilesTemp.indexWhere((element) => element.id == profileId);
    if (index != -1) {
      profilesTemp[index] = builder(profilesTemp[index]);
    }
    state = profilesTemp;
  }

  void deleteProfileById(String id) {
    state = state.where((element) => element.id != id).toList();
  }
}

@riverpod
class CurrentProfileId extends _$CurrentProfileId
    with AutoDisposeNotifierMixin {
  @override
  String? build() => globalState.config.currentProfileId;

  @override
  void onUpdate(String? value) {
    globalState.configRepository.syncSlice(
      (c) => c.copyWith(currentProfileId: value),
    );
    // Notify tile service about profile change
    tile?.updateTile();
  }
}

@riverpod
class OverrideDns extends _$OverrideDns with AutoDisposeNotifierMixin {
  @override
  bool build() => globalState.config.overrideDns;

  @override
  void onUpdate(bool value) {
    globalState.configRepository.syncSlice(
      (c) => c.copyWith(overrideDns: value),
    );
  }
}

@riverpod
class HotKeyActions extends _$HotKeyActions with AutoDisposeNotifierMixin {
  @override
  List<HotKeyAction> build() => globalState.config.hotKeyActions;

  @override
  void onUpdate(List<HotKeyAction> value) {
    globalState.configRepository.syncSlice(
      (c) => c.copyWith(hotKeyActions: value),
    );
  }
}

@riverpod
class ProxiesStyleSetting extends _$ProxiesStyleSetting
    with AutoDisposeNotifierMixin {
  @override
  ProxiesStyle build() => globalState.config.proxiesStyle;

  @override
  void onUpdate(ProxiesStyle value) {
    globalState.configRepository.syncSlice(
      (c) => c.copyWith(proxiesStyle: value),
    );
  }

  void updateState(ProxiesStyle Function(ProxiesStyle state) builder) {
    state = builder(state);
  }
}

@riverpod
class ScriptState extends _$ScriptState with AutoDisposeNotifierMixin {
  @override
  ScriptProps build() => globalState.config.scriptProps;

  @override
  void onUpdate(ScriptProps value) {
    globalState.configRepository.syncSlice(
      (c) => c.copyWith(scriptProps: value),
    );
  }

  void setScript(Script script) {
    final list = List<Script>.from(state.scripts);
    final index = list.indexWhere((item) => item.id == script.id);
    if (index != -1) {
      list[index] = script;
    } else {
      list.add(script);
    }
    state = state.copyWith(
      scripts: list,
    );
  }

  void setId(String id) {
    state = state.copyWith(
      currentId: state.currentId != id ? id : null,
    );
  }

  void del(String id) {
    final list = List<Script>.from(state.scripts);
    final index = list.indexWhere((item) => item.label == id);
    if (index != -1) {
      list.removeAt(index);
    }
    final nextId = id == state.currentId ? null : state.currentId;
    state = state.copyWith(
      scripts: list,
      currentId: nextId,
    );
  }

  bool isExits(String label) => state.scripts.indexWhere((item) => item.label == label) != -1;
}

@riverpod
class PatchClashConfig extends _$PatchClashConfig
    with AutoDisposeNotifierMixin {
  @override
  ClashConfig build() => globalState.config.patchClashConfig;

  void updateState(ClashConfig? Function(ClashConfig state) builder) {
    final newState = builder(state);
    if (newState == null) {
      return;
    }
    state = newState;
  }

  @override
  void onUpdate(ClashConfig value) {
    globalState.configRepository.syncSlice(
      (c) => c.copyWith(patchClashConfig: value),
    );
  }
}
