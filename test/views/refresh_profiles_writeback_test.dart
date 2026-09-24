// Regression (A5-1): the refresh UI paths must not write a STALE Profile
// snapshot back on failure, nor resurrect a profile deleted mid-fetch.
//
// lib/views/subscription/profiles_content.dart refreshProfiles() toggles
// `isUpdating` through AppController.updateProfileById, which transforms the
// CURRENT store value by id and never appends (Profiles.updateProfile). The
// fake below mirrors those semantics exactly; `setProfile` records a stale
// wholesale write so the test fails if a path regresses to it.
import 'package:dropweb/controller.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/subscription/profiles_content.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeController implements AppController {
  final Map<String, Profile> store = {};
  late Future<void> Function(Profile) onUpdate;
  int wholesaleWrites = 0;

  @override
  void setProfile(Profile profile) {
    wholesaleWrites++;
    store[profile.id] = profile;
  }

  @override
  void updateProfileById(String id, Profile Function(Profile profile) builder) {
    final current = store[id];
    if (current == null) return; // never appends
    store[id] = builder(current);
  }

  @override
  Future<void> updateProfile(Profile profile) => onUpdate(profile);

  @override
  void addLog(Log log) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<BuildContext> _unmountedContext(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(Builder(builder: (c) {
    ctx = c;
    return const SizedBox();
  }));
  // Unmounted: skips only the error-dialog branch.
  await tester.pumpWidget(const SizedBox());
  return ctx;
}

void main() {
  const original = Profile(
    id: 'p1',
    label: 'sub',
    autoUpdateDuration: Duration(hours: 12),
    workMode: WorkMode.standard,
  );

  testWidgets(
      'refresh failure keeps a concurrent work-mode change and clears isUpdating',
      (tester) async {
    final fake = _FakeController();
    globalState.appController = fake;
    fake.store[original.id] = original;

    fake.onUpdate = (p) async {
      expect(fake.store[p.id]!.isUpdating, isTrue);
      // User picks a country while the fetch is in flight, then it fails.
      fake.store[p.id] = fake.store[p.id]!.copyWith(
        workMode: WorkMode.country,
        staticCountry: 'DE',
        selectedMap: {'Router': 'DE-1'},
      );
      throw Exception('connection timeout');
    };

    await refreshProfiles(await _unmountedContext(tester), original);

    final after = fake.store['p1']!;
    expect(after.workMode, WorkMode.country);
    expect(after.staticCountry, 'DE');
    expect(after.selectedMap, {'Router': 'DE-1'});
    expect(after.isUpdating, isFalse);
    expect(fake.wholesaleWrites, 0,
        reason: 'isUpdating toggles must not write a snapshot wholesale');
  });

  testWidgets('refresh failure does not resurrect a profile deleted mid-fetch',
      (tester) async {
    final fake = _FakeController();
    globalState.appController = fake;
    fake.store[original.id] = original;

    fake.onUpdate = (p) async {
      fake.store.remove(p.id); // deleted during the fetch
      throw Exception('connection timeout');
    };

    await refreshProfiles(await _unmountedContext(tester), original);

    expect(fake.store.containsKey('p1'), isFalse);
  });
}
