// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../app_update.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appUpdateHash() => r'cdce679dab65829210d6c554f5dcf08fbde20442';

/// In-app updater state machine (sideloaded Android only). Inert on the Play
/// build (kIsPlayBuild). keepAlive so an in-flight download survives navigation
/// between the dashboard banner and the update sheet.
///
/// Copied from [AppUpdate].
@ProviderFor(AppUpdate)
final appUpdateProvider = NotifierProvider<AppUpdate, AppUpdateState>.internal(
  AppUpdate.new,
  name: r'appUpdateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appUpdateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppUpdate = Notifier<AppUpdateState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
