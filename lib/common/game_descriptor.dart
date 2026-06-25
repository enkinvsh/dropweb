// ignore_for_file: invalid_annotation_target
//
// Pure, typed core for the «Игровой» (gaming) work mode descriptor.
//
// The descriptor (`game.yml`) is REMOTE-CONTROLLED ROUTING, so parsing and the
// origin pin are security-critical. This module stays Flutter-free and
// dart:io-free (only `package:yaml` + `freezed_annotation`) so it is trivially
// unit-testable and easy to audit. The fetch/cache I/O wiring lives elsewhere
// (it consumes [parseGameDescriptor] + [isPinnedGamingHost]); this file is the
// pure decision core only.
//
// NOTE: the origin-pin constants live HERE, beside the [isPinnedGamingHost]
// guard that enforces them, rather than in `lib/common/constant.dart`:
// `constant.dart` is Flutter/dart:io-heavy and (via `common.dart`) re-exports
// this file, so importing it would defeat this module's purity and create an
// import cycle. They remain reachable repo-wide through `common.dart`.

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:yaml/yaml.dart';

part 'game_descriptor.freezed.dart';
part 'game_descriptor.g.dart';

/// Origin pin (host) for the gaming descriptor. The fetch layer must accept the
/// descriptor ONLY from this exact host (see [isPinnedGamingHost]).
const kGamingDescriptorHost = 'raw.githubusercontent.com';

/// Origin pin (path prefix) for the gaming descriptor — the canonical repo on
/// [kGamingDescriptorHost]. The descriptor URL's path must start with this.
const kGamingDescriptorPathPrefix = '/enkinvsh/dropweb-game/';

/// The only `version:` value [parseGameDescriptor] accepts. A descriptor with
/// any other version is rejected (returns `null`) so an incompatible remote
/// schema can never be partially applied.
const kGamingDescriptorSchemaVersion = 1;

/// Parses [headerValue] into the gaming descriptor URL.
///
/// Returns the parsed [Uri] when [headerValue] is a non-empty, absolute URL
/// with a host. Returns `null` when the value is null, empty/whitespace, not an
/// absolute URL (e.g. a relative path), missing a host (e.g. `http://`), or
/// unparseable junk.
Uri? gamingDescriptorUrl(String? headerValue) {
  final trimmed = headerValue?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (!uri.isAbsolute || uri.host.isEmpty) return null;

  return uri;
}

/// The typed `game.yml` descriptor: the remote routing payload for the gaming
/// work mode. Built only via [parseGameDescriptor], which validates before
/// constructing.
@freezed
class GameDescriptor with _$GameDescriptor {
  const factory GameDescriptor({
    required int version,
    required GameMode mode,
    @JsonKey(
      name: 'hysteria',
      fromJson: _hysteriaTemplateFromJson,
      toJson: _hysteriaTemplateToJson,
    )
    required GameHysteriaTemplate hysteriaTemplate,
    required GameGroup group,
    @JsonKey(name: 'rule-providers')
    @Default(<String, dynamic>{})
    Map<String, dynamic> ruleProviders,
    required List<String> rules,
  }) = _GameDescriptor;

  factory GameDescriptor.fromJson(Map<String, Object?> json) =>
      _$GameDescriptorFromJson(json);
}

/// The gaming mode's identity + presentation. [id] must be `gaming`; [name] is
/// the user-facing label. [minAppVersion] is stored but NOT enforced here.
@freezed
class GameMode with _$GameMode {
  const factory GameMode({
    required String id,
    required String name,
    String? icon,
    String? minAppVersion,
  }) = _GameMode;

  factory GameMode.fromJson(Map<String, Object?> json) =>
      _$GameModeFromJson(json);
}

/// Generic Hysteria2 node template (port/alpn/skip-cert-verify) shared by the
/// gaming nodes. Intentionally carries NO node domains — those arrive
/// separately via the `dropweb-game-nodes` header.
@freezed
class GameHysteriaTemplate with _$GameHysteriaTemplate {
  const factory GameHysteriaTemplate({
    required int port,
    @Default(<String>[]) List<String> alpn,
    @JsonKey(name: 'skip-cert-verify') @Default(false) bool skipCertVerify,
  }) = _GameHysteriaTemplate;

  factory GameHysteriaTemplate.fromJson(Map<String, Object?> json) =>
      _$GameHysteriaTemplateFromJson(json);
}

/// The proxy-group definition the gaming rules route through.
@freezed
class GameGroup with _$GameGroup {
  const factory GameGroup({
    required String name,
    required String type,
    String? url,
    int? interval,
    int? tolerance,
  }) = _GameGroup;

  factory GameGroup.fromJson(Map<String, Object?> json) =>
      _$GameGroupFromJson(json);
}

/// Parses [yamlText] into a validated [GameDescriptor].
///
/// PURE: parse YAML → plain `Map<String, dynamic>` → validate → typed model.
/// Returns `null` on ANY failure — malformed YAML, a non-map document, an
/// unsupported [kGamingDescriptorSchemaVersion], a missing/empty/non-`gaming`
/// `mode.id`, empty `rules`, or any missing required field. Never throws to the
/// caller (a bad remote payload must fail closed, never crash routing).
GameDescriptor? parseGameDescriptor(String yamlText) {
  try {
    final root = _deepConvertYaml(loadYaml(yamlText));
    if (root is! Map<String, dynamic>) return null;

    // Version gate BEFORE construction: an incompatible schema is rejected
    // outright (covers both wrong value and wrong type).
    if (root['version'] != kGamingDescriptorSchemaVersion) return null;

    final descriptor = GameDescriptor.fromJson(root);

    // Post-construction validation for fields that are present-but-invalid
    // (missing required fields already threw above and are caught below).
    if (descriptor.mode.id != 'gaming') return null;
    if (descriptor.rules.isEmpty) return null;

    return descriptor;
  } catch (_) {
    return null;
  }
}

/// Whether [uri] is the pinned origin for the gaming descriptor: `https` +
/// host exactly [kGamingDescriptorHost] + a path starting with
/// [kGamingDescriptorPathPrefix]. Security gate for remote-controlled routing.
bool isPinnedGamingHost(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host == kGamingDescriptorHost &&
    uri.path.startsWith(kGamingDescriptorPathPrefix);

/// Last-good preference: returns [fresh] when available, otherwise the
/// previously [cached] descriptor, otherwise `null`. Lets a transient fetch
/// failure keep serving the last known-good descriptor.
GameDescriptor? resolveGameDescriptor({
  GameDescriptor? fresh,
  GameDescriptor? cached,
}) =>
    fresh ?? cached;

/// Unwraps the `hysteria: { template: {...} }` nesting into the flat
/// [GameHysteriaTemplate] field. Receives the already-deep-converted `hysteria`
/// map; throws (→ parse returns `null`) when `template` is absent/malformed.
GameHysteriaTemplate _hysteriaTemplateFromJson(Map<String, dynamic> json) =>
    GameHysteriaTemplate.fromJson(json['template'] as Map<String, dynamic>);

/// Re-nests [value] back under a `template` key, mirroring the source schema.
Map<String, dynamic> _hysteriaTemplateToJson(GameHysteriaTemplate value) =>
    <String, dynamic>{'template': value.toJson()};

/// Recursively converts parsed-YAML nodes ([YamlMap]/[YamlList] + scalars) into
/// plain `Map<String, dynamic>` / `List<dynamic>` / scalar values so the result
/// is free of YAML wrapper types and safe for `*.fromJson` (which casts to
/// `Map<String, dynamic>`). Returns the node unchanged when it is already plain.
dynamic _deepConvertYaml(dynamic node) {
  if (node is Map) {
    return <String, dynamic>{
      for (final entry in node.entries)
        entry.key.toString(): _deepConvertYaml(entry.value),
    };
  }
  if (node is List) {
    return <dynamic>[for (final item in node) _deepConvertYaml(item)];
  }
  return node;
}
