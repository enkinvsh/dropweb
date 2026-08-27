// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../spotify.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$spotifyAuthHash() => r'59f6f577eed475b773d13b6156e0826593f52bc8';

/// Spotify sign-in, held above the route.
///
/// keepAlive for the reason `AppUpdate` has it and the meowzic search does:
/// an auto-disposing provider is torn down the moment the last route watching
/// it pops, and this exists to survive exactly that — the library tab is
/// inside a pushed route, and a sign-in that had to be repeated on every
/// visit would not be a sign-in.
///
/// Copied from [SpotifyAuth].
@ProviderFor(SpotifyAuth)
final spotifyAuthProvider =
    NotifierProvider<SpotifyAuth, SpotifyAuthState>.internal(
  SpotifyAuth.new,
  name: r'spotifyAuthProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$spotifyAuthHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SpotifyAuth = Notifier<SpotifyAuthState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
