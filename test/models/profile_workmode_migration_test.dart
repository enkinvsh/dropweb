import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Migration lock: profiles persisted with the removed «Игровой» work mode
  // must degrade to standard on load. Guaranteed by the
  // `@JsonKey(unknownEnumValue: WorkMode.standard)` annotation on
  // Profile.workMode once `gaming` is dropped from the enum.
  test('persisted gaming workMode deserializes to standard', () {
    final profile = Profile.fromJson({
      'id': 'profile-a',
      'autoUpdateDuration': const Duration(hours: 12).inMicroseconds,
      'workMode': 'gaming',
    });

    expect(profile.workMode, WorkMode.standard);
  });
}
