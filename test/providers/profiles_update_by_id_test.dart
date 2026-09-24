// Regression (A4-3 / A5-1): Profiles.updateProfile(id, builder) — the by-id
// transform behind AppController.updateProfileById — must update in place
// from the CURRENT value and never append a missing id (setProfile does
// append, which is how stale writes used to resurrect deleted profiles).
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const p1 = Profile(
    id: 'p1',
    label: 'one',
    autoUpdateDuration: Duration(hours: 12),
  );

  setUp(() {
    globalState.config = const Config(
      themeProps: defaultThemeProps,
      profiles: [p1],
    );
  });

  test('transforms the current store value in place', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(profilesProvider.notifier);

    // A concurrent edit lands first…
    notifier.setProfile(p1.copyWith(workMode: WorkMode.country));
    // …then the isUpdating toggle must build on it, not on a snapshot.
    notifier.updateProfile('p1', (p) => p.copyWith(isUpdating: true));

    final after = container.read(profilesProvider).single;
    expect(after.workMode, WorkMode.country);
    expect(after.isUpdating, isTrue);
  });

  test('is a no-op for a missing id (never resurrects a deleted profile)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(profilesProvider.notifier);

    notifier.deleteProfileById('p1');
    final before = container.read(profilesProvider);
    notifier.updateProfile('p1', (p) => p.copyWith(isUpdating: false));

    expect(container.read(profilesProvider), isEmpty);
    expect(identical(container.read(profilesProvider), before), isTrue,
        reason: 'no state emission for an absent id');
  });
}
