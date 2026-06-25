// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_descriptor.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

GameDescriptor _$GameDescriptorFromJson(Map<String, dynamic> json) {
  return _GameDescriptor.fromJson(json);
}

/// @nodoc
mixin _$GameDescriptor {
  int get version => throw _privateConstructorUsedError;
  GameMode get mode => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'hysteria',
      fromJson: _hysteriaTemplateFromJson,
      toJson: _hysteriaTemplateToJson)
  GameHysteriaTemplate get hysteriaTemplate =>
      throw _privateConstructorUsedError;
  GameGroup get group => throw _privateConstructorUsedError;
  @JsonKey(name: 'rule-providers')
  Map<String, dynamic> get ruleProviders => throw _privateConstructorUsedError;
  List<String> get rules => throw _privateConstructorUsedError;

  /// Serializes this GameDescriptor to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GameDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GameDescriptorCopyWith<GameDescriptor> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameDescriptorCopyWith<$Res> {
  factory $GameDescriptorCopyWith(
          GameDescriptor value, $Res Function(GameDescriptor) then) =
      _$GameDescriptorCopyWithImpl<$Res, GameDescriptor>;
  @useResult
  $Res call(
      {int version,
      GameMode mode,
      @JsonKey(
          name: 'hysteria',
          fromJson: _hysteriaTemplateFromJson,
          toJson: _hysteriaTemplateToJson)
      GameHysteriaTemplate hysteriaTemplate,
      GameGroup group,
      @JsonKey(name: 'rule-providers') Map<String, dynamic> ruleProviders,
      List<String> rules});

  $GameModeCopyWith<$Res> get mode;
  $GameHysteriaTemplateCopyWith<$Res> get hysteriaTemplate;
  $GameGroupCopyWith<$Res> get group;
}

/// @nodoc
class _$GameDescriptorCopyWithImpl<$Res, $Val extends GameDescriptor>
    implements $GameDescriptorCopyWith<$Res> {
  _$GameDescriptorCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GameDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? mode = null,
    Object? hysteriaTemplate = null,
    Object? group = null,
    Object? ruleProviders = null,
    Object? rules = null,
  }) {
    return _then(_value.copyWith(
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as GameMode,
      hysteriaTemplate: null == hysteriaTemplate
          ? _value.hysteriaTemplate
          : hysteriaTemplate // ignore: cast_nullable_to_non_nullable
              as GameHysteriaTemplate,
      group: null == group
          ? _value.group
          : group // ignore: cast_nullable_to_non_nullable
              as GameGroup,
      ruleProviders: null == ruleProviders
          ? _value.ruleProviders
          : ruleProviders // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      rules: null == rules
          ? _value.rules
          : rules // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }

  /// Create a copy of GameDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GameModeCopyWith<$Res> get mode {
    return $GameModeCopyWith<$Res>(_value.mode, (value) {
      return _then(_value.copyWith(mode: value) as $Val);
    });
  }

  /// Create a copy of GameDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GameHysteriaTemplateCopyWith<$Res> get hysteriaTemplate {
    return $GameHysteriaTemplateCopyWith<$Res>(_value.hysteriaTemplate,
        (value) {
      return _then(_value.copyWith(hysteriaTemplate: value) as $Val);
    });
  }

  /// Create a copy of GameDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GameGroupCopyWith<$Res> get group {
    return $GameGroupCopyWith<$Res>(_value.group, (value) {
      return _then(_value.copyWith(group: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$GameDescriptorImplCopyWith<$Res>
    implements $GameDescriptorCopyWith<$Res> {
  factory _$$GameDescriptorImplCopyWith(_$GameDescriptorImpl value,
          $Res Function(_$GameDescriptorImpl) then) =
      __$$GameDescriptorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int version,
      GameMode mode,
      @JsonKey(
          name: 'hysteria',
          fromJson: _hysteriaTemplateFromJson,
          toJson: _hysteriaTemplateToJson)
      GameHysteriaTemplate hysteriaTemplate,
      GameGroup group,
      @JsonKey(name: 'rule-providers') Map<String, dynamic> ruleProviders,
      List<String> rules});

  @override
  $GameModeCopyWith<$Res> get mode;
  @override
  $GameHysteriaTemplateCopyWith<$Res> get hysteriaTemplate;
  @override
  $GameGroupCopyWith<$Res> get group;
}

/// @nodoc
class __$$GameDescriptorImplCopyWithImpl<$Res>
    extends _$GameDescriptorCopyWithImpl<$Res, _$GameDescriptorImpl>
    implements _$$GameDescriptorImplCopyWith<$Res> {
  __$$GameDescriptorImplCopyWithImpl(
      _$GameDescriptorImpl _value, $Res Function(_$GameDescriptorImpl) _then)
      : super(_value, _then);

  /// Create a copy of GameDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? mode = null,
    Object? hysteriaTemplate = null,
    Object? group = null,
    Object? ruleProviders = null,
    Object? rules = null,
  }) {
    return _then(_$GameDescriptorImpl(
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as GameMode,
      hysteriaTemplate: null == hysteriaTemplate
          ? _value.hysteriaTemplate
          : hysteriaTemplate // ignore: cast_nullable_to_non_nullable
              as GameHysteriaTemplate,
      group: null == group
          ? _value.group
          : group // ignore: cast_nullable_to_non_nullable
              as GameGroup,
      ruleProviders: null == ruleProviders
          ? _value._ruleProviders
          : ruleProviders // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      rules: null == rules
          ? _value._rules
          : rules // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GameDescriptorImpl implements _GameDescriptor {
  const _$GameDescriptorImpl(
      {required this.version,
      required this.mode,
      @JsonKey(
          name: 'hysteria',
          fromJson: _hysteriaTemplateFromJson,
          toJson: _hysteriaTemplateToJson)
      required this.hysteriaTemplate,
      required this.group,
      @JsonKey(name: 'rule-providers')
      final Map<String, dynamic> ruleProviders = const <String, dynamic>{},
      required final List<String> rules})
      : _ruleProviders = ruleProviders,
        _rules = rules;

  factory _$GameDescriptorImpl.fromJson(Map<String, dynamic> json) =>
      _$$GameDescriptorImplFromJson(json);

  @override
  final int version;
  @override
  final GameMode mode;
  @override
  @JsonKey(
      name: 'hysteria',
      fromJson: _hysteriaTemplateFromJson,
      toJson: _hysteriaTemplateToJson)
  final GameHysteriaTemplate hysteriaTemplate;
  @override
  final GameGroup group;
  final Map<String, dynamic> _ruleProviders;
  @override
  @JsonKey(name: 'rule-providers')
  Map<String, dynamic> get ruleProviders {
    if (_ruleProviders is EqualUnmodifiableMapView) return _ruleProviders;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_ruleProviders);
  }

  final List<String> _rules;
  @override
  List<String> get rules {
    if (_rules is EqualUnmodifiableListView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rules);
  }

  @override
  String toString() {
    return 'GameDescriptor(version: $version, mode: $mode, hysteriaTemplate: $hysteriaTemplate, group: $group, ruleProviders: $ruleProviders, rules: $rules)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameDescriptorImpl &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.hysteriaTemplate, hysteriaTemplate) ||
                other.hysteriaTemplate == hysteriaTemplate) &&
            (identical(other.group, group) || other.group == group) &&
            const DeepCollectionEquality()
                .equals(other._ruleProviders, _ruleProviders) &&
            const DeepCollectionEquality().equals(other._rules, _rules));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      version,
      mode,
      hysteriaTemplate,
      group,
      const DeepCollectionEquality().hash(_ruleProviders),
      const DeepCollectionEquality().hash(_rules));

  /// Create a copy of GameDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GameDescriptorImplCopyWith<_$GameDescriptorImpl> get copyWith =>
      __$$GameDescriptorImplCopyWithImpl<_$GameDescriptorImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GameDescriptorImplToJson(
      this,
    );
  }
}

abstract class _GameDescriptor implements GameDescriptor {
  const factory _GameDescriptor(
      {required final int version,
      required final GameMode mode,
      @JsonKey(
          name: 'hysteria',
          fromJson: _hysteriaTemplateFromJson,
          toJson: _hysteriaTemplateToJson)
      required final GameHysteriaTemplate hysteriaTemplate,
      required final GameGroup group,
      @JsonKey(name: 'rule-providers') final Map<String, dynamic> ruleProviders,
      required final List<String> rules}) = _$GameDescriptorImpl;

  factory _GameDescriptor.fromJson(Map<String, dynamic> json) =
      _$GameDescriptorImpl.fromJson;

  @override
  int get version;
  @override
  GameMode get mode;
  @override
  @JsonKey(
      name: 'hysteria',
      fromJson: _hysteriaTemplateFromJson,
      toJson: _hysteriaTemplateToJson)
  GameHysteriaTemplate get hysteriaTemplate;
  @override
  GameGroup get group;
  @override
  @JsonKey(name: 'rule-providers')
  Map<String, dynamic> get ruleProviders;
  @override
  List<String> get rules;

  /// Create a copy of GameDescriptor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameDescriptorImplCopyWith<_$GameDescriptorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

GameMode _$GameModeFromJson(Map<String, dynamic> json) {
  return _GameMode.fromJson(json);
}

/// @nodoc
mixin _$GameMode {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get icon => throw _privateConstructorUsedError;
  String? get minAppVersion => throw _privateConstructorUsedError;

  /// Serializes this GameMode to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GameMode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GameModeCopyWith<GameMode> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameModeCopyWith<$Res> {
  factory $GameModeCopyWith(GameMode value, $Res Function(GameMode) then) =
      _$GameModeCopyWithImpl<$Res, GameMode>;
  @useResult
  $Res call({String id, String name, String? icon, String? minAppVersion});
}

/// @nodoc
class _$GameModeCopyWithImpl<$Res, $Val extends GameMode>
    implements $GameModeCopyWith<$Res> {
  _$GameModeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GameMode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? icon = freezed,
    Object? minAppVersion = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      icon: freezed == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String?,
      minAppVersion: freezed == minAppVersion
          ? _value.minAppVersion
          : minAppVersion // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GameModeImplCopyWith<$Res>
    implements $GameModeCopyWith<$Res> {
  factory _$$GameModeImplCopyWith(
          _$GameModeImpl value, $Res Function(_$GameModeImpl) then) =
      __$$GameModeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String name, String? icon, String? minAppVersion});
}

/// @nodoc
class __$$GameModeImplCopyWithImpl<$Res>
    extends _$GameModeCopyWithImpl<$Res, _$GameModeImpl>
    implements _$$GameModeImplCopyWith<$Res> {
  __$$GameModeImplCopyWithImpl(
      _$GameModeImpl _value, $Res Function(_$GameModeImpl) _then)
      : super(_value, _then);

  /// Create a copy of GameMode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? icon = freezed,
    Object? minAppVersion = freezed,
  }) {
    return _then(_$GameModeImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      icon: freezed == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String?,
      minAppVersion: freezed == minAppVersion
          ? _value.minAppVersion
          : minAppVersion // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GameModeImpl implements _GameMode {
  const _$GameModeImpl(
      {required this.id, required this.name, this.icon, this.minAppVersion});

  factory _$GameModeImpl.fromJson(Map<String, dynamic> json) =>
      _$$GameModeImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? icon;
  @override
  final String? minAppVersion;

  @override
  String toString() {
    return 'GameMode(id: $id, name: $name, icon: $icon, minAppVersion: $minAppVersion)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameModeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.minAppVersion, minAppVersion) ||
                other.minAppVersion == minAppVersion));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, icon, minAppVersion);

  /// Create a copy of GameMode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GameModeImplCopyWith<_$GameModeImpl> get copyWith =>
      __$$GameModeImplCopyWithImpl<_$GameModeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GameModeImplToJson(
      this,
    );
  }
}

abstract class _GameMode implements GameMode {
  const factory _GameMode(
      {required final String id,
      required final String name,
      final String? icon,
      final String? minAppVersion}) = _$GameModeImpl;

  factory _GameMode.fromJson(Map<String, dynamic> json) =
      _$GameModeImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get icon;
  @override
  String? get minAppVersion;

  /// Create a copy of GameMode
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameModeImplCopyWith<_$GameModeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

GameHysteriaTemplate _$GameHysteriaTemplateFromJson(Map<String, dynamic> json) {
  return _GameHysteriaTemplate.fromJson(json);
}

/// @nodoc
mixin _$GameHysteriaTemplate {
  int get port => throw _privateConstructorUsedError;
  List<String> get alpn => throw _privateConstructorUsedError;
  @JsonKey(name: 'skip-cert-verify')
  bool get skipCertVerify => throw _privateConstructorUsedError;

  /// Serializes this GameHysteriaTemplate to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GameHysteriaTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GameHysteriaTemplateCopyWith<GameHysteriaTemplate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameHysteriaTemplateCopyWith<$Res> {
  factory $GameHysteriaTemplateCopyWith(GameHysteriaTemplate value,
          $Res Function(GameHysteriaTemplate) then) =
      _$GameHysteriaTemplateCopyWithImpl<$Res, GameHysteriaTemplate>;
  @useResult
  $Res call(
      {int port,
      List<String> alpn,
      @JsonKey(name: 'skip-cert-verify') bool skipCertVerify});
}

/// @nodoc
class _$GameHysteriaTemplateCopyWithImpl<$Res,
        $Val extends GameHysteriaTemplate>
    implements $GameHysteriaTemplateCopyWith<$Res> {
  _$GameHysteriaTemplateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GameHysteriaTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? port = null,
    Object? alpn = null,
    Object? skipCertVerify = null,
  }) {
    return _then(_value.copyWith(
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
      alpn: null == alpn
          ? _value.alpn
          : alpn // ignore: cast_nullable_to_non_nullable
              as List<String>,
      skipCertVerify: null == skipCertVerify
          ? _value.skipCertVerify
          : skipCertVerify // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GameHysteriaTemplateImplCopyWith<$Res>
    implements $GameHysteriaTemplateCopyWith<$Res> {
  factory _$$GameHysteriaTemplateImplCopyWith(_$GameHysteriaTemplateImpl value,
          $Res Function(_$GameHysteriaTemplateImpl) then) =
      __$$GameHysteriaTemplateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int port,
      List<String> alpn,
      @JsonKey(name: 'skip-cert-verify') bool skipCertVerify});
}

/// @nodoc
class __$$GameHysteriaTemplateImplCopyWithImpl<$Res>
    extends _$GameHysteriaTemplateCopyWithImpl<$Res, _$GameHysteriaTemplateImpl>
    implements _$$GameHysteriaTemplateImplCopyWith<$Res> {
  __$$GameHysteriaTemplateImplCopyWithImpl(_$GameHysteriaTemplateImpl _value,
      $Res Function(_$GameHysteriaTemplateImpl) _then)
      : super(_value, _then);

  /// Create a copy of GameHysteriaTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? port = null,
    Object? alpn = null,
    Object? skipCertVerify = null,
  }) {
    return _then(_$GameHysteriaTemplateImpl(
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
      alpn: null == alpn
          ? _value._alpn
          : alpn // ignore: cast_nullable_to_non_nullable
              as List<String>,
      skipCertVerify: null == skipCertVerify
          ? _value.skipCertVerify
          : skipCertVerify // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GameHysteriaTemplateImpl implements _GameHysteriaTemplate {
  const _$GameHysteriaTemplateImpl(
      {required this.port,
      final List<String> alpn = const <String>[],
      @JsonKey(name: 'skip-cert-verify') this.skipCertVerify = false})
      : _alpn = alpn;

  factory _$GameHysteriaTemplateImpl.fromJson(Map<String, dynamic> json) =>
      _$$GameHysteriaTemplateImplFromJson(json);

  @override
  final int port;
  final List<String> _alpn;
  @override
  @JsonKey()
  List<String> get alpn {
    if (_alpn is EqualUnmodifiableListView) return _alpn;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_alpn);
  }

  @override
  @JsonKey(name: 'skip-cert-verify')
  final bool skipCertVerify;

  @override
  String toString() {
    return 'GameHysteriaTemplate(port: $port, alpn: $alpn, skipCertVerify: $skipCertVerify)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameHysteriaTemplateImpl &&
            (identical(other.port, port) || other.port == port) &&
            const DeepCollectionEquality().equals(other._alpn, _alpn) &&
            (identical(other.skipCertVerify, skipCertVerify) ||
                other.skipCertVerify == skipCertVerify));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, port,
      const DeepCollectionEquality().hash(_alpn), skipCertVerify);

  /// Create a copy of GameHysteriaTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GameHysteriaTemplateImplCopyWith<_$GameHysteriaTemplateImpl>
      get copyWith =>
          __$$GameHysteriaTemplateImplCopyWithImpl<_$GameHysteriaTemplateImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GameHysteriaTemplateImplToJson(
      this,
    );
  }
}

abstract class _GameHysteriaTemplate implements GameHysteriaTemplate {
  const factory _GameHysteriaTemplate(
          {required final int port,
          final List<String> alpn,
          @JsonKey(name: 'skip-cert-verify') final bool skipCertVerify}) =
      _$GameHysteriaTemplateImpl;

  factory _GameHysteriaTemplate.fromJson(Map<String, dynamic> json) =
      _$GameHysteriaTemplateImpl.fromJson;

  @override
  int get port;
  @override
  List<String> get alpn;
  @override
  @JsonKey(name: 'skip-cert-verify')
  bool get skipCertVerify;

  /// Create a copy of GameHysteriaTemplate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameHysteriaTemplateImplCopyWith<_$GameHysteriaTemplateImpl>
      get copyWith => throw _privateConstructorUsedError;
}

GameGroup _$GameGroupFromJson(Map<String, dynamic> json) {
  return _GameGroup.fromJson(json);
}

/// @nodoc
mixin _$GameGroup {
  String get name => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  String? get url => throw _privateConstructorUsedError;
  int? get interval => throw _privateConstructorUsedError;
  int? get tolerance => throw _privateConstructorUsedError;

  /// Serializes this GameGroup to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GameGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GameGroupCopyWith<GameGroup> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameGroupCopyWith<$Res> {
  factory $GameGroupCopyWith(GameGroup value, $Res Function(GameGroup) then) =
      _$GameGroupCopyWithImpl<$Res, GameGroup>;
  @useResult
  $Res call(
      {String name, String type, String? url, int? interval, int? tolerance});
}

/// @nodoc
class _$GameGroupCopyWithImpl<$Res, $Val extends GameGroup>
    implements $GameGroupCopyWith<$Res> {
  _$GameGroupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GameGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? type = null,
    Object? url = freezed,
    Object? interval = freezed,
    Object? tolerance = freezed,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      url: freezed == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
      interval: freezed == interval
          ? _value.interval
          : interval // ignore: cast_nullable_to_non_nullable
              as int?,
      tolerance: freezed == tolerance
          ? _value.tolerance
          : tolerance // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GameGroupImplCopyWith<$Res>
    implements $GameGroupCopyWith<$Res> {
  factory _$$GameGroupImplCopyWith(
          _$GameGroupImpl value, $Res Function(_$GameGroupImpl) then) =
      __$$GameGroupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name, String type, String? url, int? interval, int? tolerance});
}

/// @nodoc
class __$$GameGroupImplCopyWithImpl<$Res>
    extends _$GameGroupCopyWithImpl<$Res, _$GameGroupImpl>
    implements _$$GameGroupImplCopyWith<$Res> {
  __$$GameGroupImplCopyWithImpl(
      _$GameGroupImpl _value, $Res Function(_$GameGroupImpl) _then)
      : super(_value, _then);

  /// Create a copy of GameGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? type = null,
    Object? url = freezed,
    Object? interval = freezed,
    Object? tolerance = freezed,
  }) {
    return _then(_$GameGroupImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      url: freezed == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
      interval: freezed == interval
          ? _value.interval
          : interval // ignore: cast_nullable_to_non_nullable
              as int?,
      tolerance: freezed == tolerance
          ? _value.tolerance
          : tolerance // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GameGroupImpl implements _GameGroup {
  const _$GameGroupImpl(
      {required this.name,
      required this.type,
      this.url,
      this.interval,
      this.tolerance});

  factory _$GameGroupImpl.fromJson(Map<String, dynamic> json) =>
      _$$GameGroupImplFromJson(json);

  @override
  final String name;
  @override
  final String type;
  @override
  final String? url;
  @override
  final int? interval;
  @override
  final int? tolerance;

  @override
  String toString() {
    return 'GameGroup(name: $name, type: $type, url: $url, interval: $interval, tolerance: $tolerance)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameGroupImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.interval, interval) ||
                other.interval == interval) &&
            (identical(other.tolerance, tolerance) ||
                other.tolerance == tolerance));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, name, type, url, interval, tolerance);

  /// Create a copy of GameGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GameGroupImplCopyWith<_$GameGroupImpl> get copyWith =>
      __$$GameGroupImplCopyWithImpl<_$GameGroupImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GameGroupImplToJson(
      this,
    );
  }
}

abstract class _GameGroup implements GameGroup {
  const factory _GameGroup(
      {required final String name,
      required final String type,
      final String? url,
      final int? interval,
      final int? tolerance}) = _$GameGroupImpl;

  factory _GameGroup.fromJson(Map<String, dynamic> json) =
      _$GameGroupImpl.fromJson;

  @override
  String get name;
  @override
  String get type;
  @override
  String? get url;
  @override
  int? get interval;
  @override
  int? get tolerance;

  /// Create a copy of GameGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameGroupImplCopyWith<_$GameGroupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
