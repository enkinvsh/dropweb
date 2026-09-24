// Regression (A4-3): AppController.updateProfile merges the fetch result onto
// the store copy re-read AFTER the network fetch via applyFetchedProfileFields.
// Only fields owned by Profile.update / saveFile come from the fetched copy;
// user edits made during the fetch survive.
import 'package:dropweb/controller.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fetchedAt = DateTime(2026, 9, 24, 12);

  // Pre-fetch snapshot the fetch was built from.
  const snapshot = Profile(
    id: 'p1',
    label: 'sub',
    autoUpdateDuration: Duration(hours: 12),
    workMode: WorkMode.standard,
    isUpdating: true,
  );

  // What Profile.update returned (built from the snapshot).
  final fetched = snapshot.copyWith(
    subscriptionInfo: const SubscriptionInfo(upload: 1, download: 2, total: 3),
    providerHeaders: {
      'profile-update-interval': '6',
      'fallback-url': 'https://fallback.example',
      'dropweb-theme': 'x',
    },
    autoUpdateDuration: const Duration(hours: 6),
    fallbackUrl: 'https://fallback.example',
    lastUpdateDate: fetchedAt,
  );

  test('user edits made during the fetch survive; fetch fields are applied',
      () {
    // Store copy after the fetch: user switched to country mode + renamed.
    final fresh = snapshot.copyWith(
      label: 'renamed',
      workMode: WorkMode.country,
      staticCountry: 'DE',
      selectedMap: {'GLOBAL': 'DE-1'},
      autoUpdate: false,
    );

    final merged = applyFetchedProfileFields(fresh: fresh, fetched: fetched);

    // User-owned fields: from the fresh store copy.
    expect(merged.label, 'renamed');
    expect(merged.workMode, WorkMode.country);
    expect(merged.staticCountry, 'DE');
    expect(merged.selectedMap, {'GLOBAL': 'DE-1'});
    expect(merged.autoUpdate, isFalse);
    // Fetch-owned fields: from the fetched copy.
    expect(merged.subscriptionInfo, fetched.subscriptionInfo);
    expect(merged.providerHeaders, fetched.providerHeaders);
    expect(merged.lastUpdateDate, fetchedAt);
    expect(merged.autoUpdateDuration, const Duration(hours: 6));
    expect(merged.fallbackUrl, 'https://fallback.example');
    expect(merged.isUpdating, isFalse);
  });

  test('absent headers keep the fresh autoUpdateDuration / fallbackUrl', () {
    final fresh = snapshot.copyWith(
      autoUpdateDuration: const Duration(hours: 48),
      fallbackUrl: 'https://mine.example',
    );
    final noHeaders = fetched.copyWith(
      providerHeaders: const {},
      autoUpdateDuration: snapshot.autoUpdateDuration,
      fallbackUrl: null,
    );

    final merged = applyFetchedProfileFields(fresh: fresh, fetched: noHeaders);

    expect(merged.autoUpdateDuration, const Duration(hours: 48));
    expect(merged.fallbackUrl, 'https://mine.example');
    expect(merged.providerHeaders, isEmpty);
  });

  test('a profile without a label takes the fetched (disposition) label', () {
    final fresh = snapshot.copyWith(label: null);
    final merged = applyFetchedProfileFields(
      fresh: fresh,
      fetched: fetched.copyWith(label: 'from-disposition'),
    );
    expect(merged.label, 'from-disposition');
  });
}
