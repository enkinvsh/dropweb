// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../meowzic.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$meowzicSearchHash() => r'c235bc586e44945b466e3960921a49dd1157d67d';

/// The search and the queue behind it, held above the route.
///
/// The shape follows Spotube's `AudioPlayerNotifier`
/// (lib/provider/audio_player/audio_player.dart): the queue lives in a
/// notifier and the screen only renders it. That is what buys the fix — the
/// meowzic page is pushed as a route, so anything kept in its `State` is built
/// fresh on every open and a search someone waited thirty seconds for is gone
/// the moment they tap a track and come back.
///
/// keepAlive for the same reason `AppUpdate` has it: an auto-disposing
/// provider would be torn down the instant the last route watching it pops,
/// which is exactly the moment this exists to survive.
///
/// In memory only. Surviving an app restart would need a table and is a
/// separate decision; surviving navigation is this one.
///
/// Copied from [MeowzicSearch].
@ProviderFor(MeowzicSearch)
final meowzicSearchProvider =
    NotifierProvider<MeowzicSearch, MeowzicSearchState>.internal(
  MeowzicSearch.new,
  name: r'meowzicSearchProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$meowzicSearchHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MeowzicSearch = Notifier<MeowzicSearchState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
