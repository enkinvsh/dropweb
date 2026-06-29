// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_descriptor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GameDescriptorImpl _$$GameDescriptorImplFromJson(Map<String, dynamic> json) =>
    _$GameDescriptorImpl(
      version: (json['version'] as num).toInt(),
      mode: GameMode.fromJson(json['mode'] as Map<String, dynamic>),
      group: GameGroup.fromJson(json['group'] as Map<String, dynamic>),
      ruleProviders: json['rule-providers'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
      rules: (json['rules'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$$GameDescriptorImplToJson(
        _$GameDescriptorImpl instance) =>
    <String, dynamic>{
      'version': instance.version,
      'mode': instance.mode,
      'group': instance.group,
      'rule-providers': instance.ruleProviders,
      'rules': instance.rules,
    };

_$GameModeImpl _$$GameModeImplFromJson(Map<String, dynamic> json) =>
    _$GameModeImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      minAppVersion: json['minAppVersion'] as String?,
    );

Map<String, dynamic> _$$GameModeImplToJson(_$GameModeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'icon': instance.icon,
      'minAppVersion': instance.minAppVersion,
    };

_$GameGroupImpl _$$GameGroupImplFromJson(Map<String, dynamic> json) =>
    _$GameGroupImpl(
      name: json['name'] as String,
      type: json['type'] as String,
      url: json['url'] as String?,
      interval: (json['interval'] as num?)?.toInt(),
      tolerance: (json['tolerance'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$GameGroupImplToJson(_$GameGroupImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'type': instance.type,
      'url': instance.url,
      'interval': instance.interval,
      'tolerance': instance.tolerance,
    };
