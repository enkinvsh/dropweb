// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../app_update.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$AppUpdateInfo {
  /// Marketing version WITHOUT a leading `v`, e.g. `0.8.2`.
  String get version => throw _privateConstructorUsedError;

  /// Release tag, e.g. `v0.8.2` — used to build the GitHub fallback URL.
  String get tag => throw _privateConstructorUsedError;

  /// Release notes (bullets), already split per line.
  List<String> get notes => throw _privateConstructorUsedError;

  /// Primary download URL: Yandex Cloud (RU-reliable).
  String get primaryUrl => throw _privateConstructorUsedError;

  /// Fallback download URL: the GitHub release asset (computed from
  /// `repository` + [tag]). Null when no asset name is known for the platform.
  String? get fallbackUrl => throw _privateConstructorUsedError;

  /// Lowercase hex sha256 of the APK. CORRUPTION check ONLY — it shares the
  /// manifest's trust root, so it is NOT a security control. The real gate is
  /// the native fail-closed signing-cert pin (verifyApkSignature, Task 4.4).
  String? get sha256 => throw _privateConstructorUsedError;

  /// Manifest `mandatory` flag. Soft-forced only: the UI nags persistently
  /// but never blocks app use.
  bool get mandatory => throw _privateConstructorUsedError;

  /// Manifest `minSupported` version, if present.
  String? get minSupported => throw _privateConstructorUsedError;

  /// Create a copy of AppUpdateInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppUpdateInfoCopyWith<AppUpdateInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppUpdateInfoCopyWith<$Res> {
  factory $AppUpdateInfoCopyWith(
          AppUpdateInfo value, $Res Function(AppUpdateInfo) then) =
      _$AppUpdateInfoCopyWithImpl<$Res, AppUpdateInfo>;
  @useResult
  $Res call(
      {String version,
      String tag,
      List<String> notes,
      String primaryUrl,
      String? fallbackUrl,
      String? sha256,
      bool mandatory,
      String? minSupported});
}

/// @nodoc
class _$AppUpdateInfoCopyWithImpl<$Res, $Val extends AppUpdateInfo>
    implements $AppUpdateInfoCopyWith<$Res> {
  _$AppUpdateInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppUpdateInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? tag = null,
    Object? notes = null,
    Object? primaryUrl = null,
    Object? fallbackUrl = freezed,
    Object? sha256 = freezed,
    Object? mandatory = null,
    Object? minSupported = freezed,
  }) {
    return _then(_value.copyWith(
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      tag: null == tag
          ? _value.tag
          : tag // ignore: cast_nullable_to_non_nullable
              as String,
      notes: null == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      primaryUrl: null == primaryUrl
          ? _value.primaryUrl
          : primaryUrl // ignore: cast_nullable_to_non_nullable
              as String,
      fallbackUrl: freezed == fallbackUrl
          ? _value.fallbackUrl
          : fallbackUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      sha256: freezed == sha256
          ? _value.sha256
          : sha256 // ignore: cast_nullable_to_non_nullable
              as String?,
      mandatory: null == mandatory
          ? _value.mandatory
          : mandatory // ignore: cast_nullable_to_non_nullable
              as bool,
      minSupported: freezed == minSupported
          ? _value.minSupported
          : minSupported // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AppUpdateInfoImplCopyWith<$Res>
    implements $AppUpdateInfoCopyWith<$Res> {
  factory _$$AppUpdateInfoImplCopyWith(
          _$AppUpdateInfoImpl value, $Res Function(_$AppUpdateInfoImpl) then) =
      __$$AppUpdateInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String version,
      String tag,
      List<String> notes,
      String primaryUrl,
      String? fallbackUrl,
      String? sha256,
      bool mandatory,
      String? minSupported});
}

/// @nodoc
class __$$AppUpdateInfoImplCopyWithImpl<$Res>
    extends _$AppUpdateInfoCopyWithImpl<$Res, _$AppUpdateInfoImpl>
    implements _$$AppUpdateInfoImplCopyWith<$Res> {
  __$$AppUpdateInfoImplCopyWithImpl(
      _$AppUpdateInfoImpl _value, $Res Function(_$AppUpdateInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppUpdateInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? tag = null,
    Object? notes = null,
    Object? primaryUrl = null,
    Object? fallbackUrl = freezed,
    Object? sha256 = freezed,
    Object? mandatory = null,
    Object? minSupported = freezed,
  }) {
    return _then(_$AppUpdateInfoImpl(
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      tag: null == tag
          ? _value.tag
          : tag // ignore: cast_nullable_to_non_nullable
              as String,
      notes: null == notes
          ? _value._notes
          : notes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      primaryUrl: null == primaryUrl
          ? _value.primaryUrl
          : primaryUrl // ignore: cast_nullable_to_non_nullable
              as String,
      fallbackUrl: freezed == fallbackUrl
          ? _value.fallbackUrl
          : fallbackUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      sha256: freezed == sha256
          ? _value.sha256
          : sha256 // ignore: cast_nullable_to_non_nullable
              as String?,
      mandatory: null == mandatory
          ? _value.mandatory
          : mandatory // ignore: cast_nullable_to_non_nullable
              as bool,
      minSupported: freezed == minSupported
          ? _value.minSupported
          : minSupported // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$AppUpdateInfoImpl implements _AppUpdateInfo {
  const _$AppUpdateInfoImpl(
      {required this.version,
      required this.tag,
      final List<String> notes = const <String>[],
      required this.primaryUrl,
      this.fallbackUrl,
      this.sha256,
      this.mandatory = false,
      this.minSupported})
      : _notes = notes;

  /// Marketing version WITHOUT a leading `v`, e.g. `0.8.2`.
  @override
  final String version;

  /// Release tag, e.g. `v0.8.2` — used to build the GitHub fallback URL.
  @override
  final String tag;

  /// Release notes (bullets), already split per line.
  final List<String> _notes;

  /// Release notes (bullets), already split per line.
  @override
  @JsonKey()
  List<String> get notes {
    if (_notes is EqualUnmodifiableListView) return _notes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_notes);
  }

  /// Primary download URL: Yandex Cloud (RU-reliable).
  @override
  final String primaryUrl;

  /// Fallback download URL: the GitHub release asset (computed from
  /// `repository` + [tag]). Null when no asset name is known for the platform.
  @override
  final String? fallbackUrl;

  /// Lowercase hex sha256 of the APK. CORRUPTION check ONLY — it shares the
  /// manifest's trust root, so it is NOT a security control. The real gate is
  /// the native fail-closed signing-cert pin (verifyApkSignature, Task 4.4).
  @override
  final String? sha256;

  /// Manifest `mandatory` flag. Soft-forced only: the UI nags persistently
  /// but never blocks app use.
  @override
  @JsonKey()
  final bool mandatory;

  /// Manifest `minSupported` version, if present.
  @override
  final String? minSupported;

  @override
  String toString() {
    return 'AppUpdateInfo(version: $version, tag: $tag, notes: $notes, primaryUrl: $primaryUrl, fallbackUrl: $fallbackUrl, sha256: $sha256, mandatory: $mandatory, minSupported: $minSupported)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppUpdateInfoImpl &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.tag, tag) || other.tag == tag) &&
            const DeepCollectionEquality().equals(other._notes, _notes) &&
            (identical(other.primaryUrl, primaryUrl) ||
                other.primaryUrl == primaryUrl) &&
            (identical(other.fallbackUrl, fallbackUrl) ||
                other.fallbackUrl == fallbackUrl) &&
            (identical(other.sha256, sha256) || other.sha256 == sha256) &&
            (identical(other.mandatory, mandatory) ||
                other.mandatory == mandatory) &&
            (identical(other.minSupported, minSupported) ||
                other.minSupported == minSupported));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      version,
      tag,
      const DeepCollectionEquality().hash(_notes),
      primaryUrl,
      fallbackUrl,
      sha256,
      mandatory,
      minSupported);

  /// Create a copy of AppUpdateInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppUpdateInfoImplCopyWith<_$AppUpdateInfoImpl> get copyWith =>
      __$$AppUpdateInfoImplCopyWithImpl<_$AppUpdateInfoImpl>(this, _$identity);
}

abstract class _AppUpdateInfo implements AppUpdateInfo {
  const factory _AppUpdateInfo(
      {required final String version,
      required final String tag,
      final List<String> notes,
      required final String primaryUrl,
      final String? fallbackUrl,
      final String? sha256,
      final bool mandatory,
      final String? minSupported}) = _$AppUpdateInfoImpl;

  /// Marketing version WITHOUT a leading `v`, e.g. `0.8.2`.
  @override
  String get version;

  /// Release tag, e.g. `v0.8.2` — used to build the GitHub fallback URL.
  @override
  String get tag;

  /// Release notes (bullets), already split per line.
  @override
  List<String> get notes;

  /// Primary download URL: Yandex Cloud (RU-reliable).
  @override
  String get primaryUrl;

  /// Fallback download URL: the GitHub release asset (computed from
  /// `repository` + [tag]). Null when no asset name is known for the platform.
  @override
  String? get fallbackUrl;

  /// Lowercase hex sha256 of the APK. CORRUPTION check ONLY — it shares the
  /// manifest's trust root, so it is NOT a security control. The real gate is
  /// the native fail-closed signing-cert pin (verifyApkSignature, Task 4.4).
  @override
  String? get sha256;

  /// Manifest `mandatory` flag. Soft-forced only: the UI nags persistently
  /// but never blocks app use.
  @override
  bool get mandatory;

  /// Manifest `minSupported` version, if present.
  @override
  String? get minSupported;

  /// Create a copy of AppUpdateInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppUpdateInfoImplCopyWith<_$AppUpdateInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AppUpdateState {
  AppUpdateStatus get status => throw _privateConstructorUsedError;
  AppUpdateInfo? get info => throw _privateConstructorUsedError;

  /// Download progress 0.0..1.0 (only meaningful while [status] is downloading).
  double get progress => throw _privateConstructorUsedError;

  /// Human-facing error key/message for the error state.
  String? get error => throw _privateConstructorUsedError;

  /// User dismissed the soft banner this run (mandatory updates ignore this).
  bool get dismissed => throw _privateConstructorUsedError;

  /// Create a copy of AppUpdateState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppUpdateStateCopyWith<AppUpdateState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppUpdateStateCopyWith<$Res> {
  factory $AppUpdateStateCopyWith(
          AppUpdateState value, $Res Function(AppUpdateState) then) =
      _$AppUpdateStateCopyWithImpl<$Res, AppUpdateState>;
  @useResult
  $Res call(
      {AppUpdateStatus status,
      AppUpdateInfo? info,
      double progress,
      String? error,
      bool dismissed});

  $AppUpdateInfoCopyWith<$Res>? get info;
}

/// @nodoc
class _$AppUpdateStateCopyWithImpl<$Res, $Val extends AppUpdateState>
    implements $AppUpdateStateCopyWith<$Res> {
  _$AppUpdateStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppUpdateState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? info = freezed,
    Object? progress = null,
    Object? error = freezed,
    Object? dismissed = null,
  }) {
    return _then(_value.copyWith(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AppUpdateStatus,
      info: freezed == info
          ? _value.info
          : info // ignore: cast_nullable_to_non_nullable
              as AppUpdateInfo?,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as double,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      dismissed: null == dismissed
          ? _value.dismissed
          : dismissed // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  /// Create a copy of AppUpdateState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AppUpdateInfoCopyWith<$Res>? get info {
    if (_value.info == null) {
      return null;
    }

    return $AppUpdateInfoCopyWith<$Res>(_value.info!, (value) {
      return _then(_value.copyWith(info: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AppUpdateStateImplCopyWith<$Res>
    implements $AppUpdateStateCopyWith<$Res> {
  factory _$$AppUpdateStateImplCopyWith(_$AppUpdateStateImpl value,
          $Res Function(_$AppUpdateStateImpl) then) =
      __$$AppUpdateStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {AppUpdateStatus status,
      AppUpdateInfo? info,
      double progress,
      String? error,
      bool dismissed});

  @override
  $AppUpdateInfoCopyWith<$Res>? get info;
}

/// @nodoc
class __$$AppUpdateStateImplCopyWithImpl<$Res>
    extends _$AppUpdateStateCopyWithImpl<$Res, _$AppUpdateStateImpl>
    implements _$$AppUpdateStateImplCopyWith<$Res> {
  __$$AppUpdateStateImplCopyWithImpl(
      _$AppUpdateStateImpl _value, $Res Function(_$AppUpdateStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppUpdateState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? info = freezed,
    Object? progress = null,
    Object? error = freezed,
    Object? dismissed = null,
  }) {
    return _then(_$AppUpdateStateImpl(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AppUpdateStatus,
      info: freezed == info
          ? _value.info
          : info // ignore: cast_nullable_to_non_nullable
              as AppUpdateInfo?,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as double,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      dismissed: null == dismissed
          ? _value.dismissed
          : dismissed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$AppUpdateStateImpl implements _AppUpdateState {
  const _$AppUpdateStateImpl(
      {this.status = AppUpdateStatus.idle,
      this.info,
      this.progress = 0.0,
      this.error,
      this.dismissed = false});

  @override
  @JsonKey()
  final AppUpdateStatus status;
  @override
  final AppUpdateInfo? info;

  /// Download progress 0.0..1.0 (only meaningful while [status] is downloading).
  @override
  @JsonKey()
  final double progress;

  /// Human-facing error key/message for the error state.
  @override
  final String? error;

  /// User dismissed the soft banner this run (mandatory updates ignore this).
  @override
  @JsonKey()
  final bool dismissed;

  @override
  String toString() {
    return 'AppUpdateState(status: $status, info: $info, progress: $progress, error: $error, dismissed: $dismissed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppUpdateStateImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.info, info) || other.info == info) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.dismissed, dismissed) ||
                other.dismissed == dismissed));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, status, info, progress, error, dismissed);

  /// Create a copy of AppUpdateState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppUpdateStateImplCopyWith<_$AppUpdateStateImpl> get copyWith =>
      __$$AppUpdateStateImplCopyWithImpl<_$AppUpdateStateImpl>(
          this, _$identity);
}

abstract class _AppUpdateState implements AppUpdateState {
  const factory _AppUpdateState(
      {final AppUpdateStatus status,
      final AppUpdateInfo? info,
      final double progress,
      final String? error,
      final bool dismissed}) = _$AppUpdateStateImpl;

  @override
  AppUpdateStatus get status;
  @override
  AppUpdateInfo? get info;

  /// Download progress 0.0..1.0 (only meaningful while [status] is downloading).
  @override
  double get progress;

  /// Human-facing error key/message for the error state.
  @override
  String? get error;

  /// User dismissed the soft banner this run (mandatory updates ignore this).
  @override
  bool get dismissed;

  /// Create a copy of AppUpdateState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppUpdateStateImplCopyWith<_$AppUpdateStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
