// Кабинет провайдера: магазинная сборка никогда не ведёт в него, даже если
// заголовок оказался в профиле (при импорте он вырезается, это второй рубеж).
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';

const _withCabinet = Profile(
  id: 'p1',
  autoUpdateDuration: Duration(hours: 12),
  providerHeaders: {'dropweb-cabinet': 'https://cab.example.com'},
);

const _legacyMarker = Profile(
  id: 'p2',
  autoUpdateDuration: Duration(hours: 12),
  providerHeaders: {'dropweb-cabinet': 'cabinet'},
);

void main() {
  group('profileCabinetUri', () {
    test('store build: заголовок кабинета игнорируется', () {
      expect(profileCabinetUri(_withCabinet, isStoreBuild: true), isNull);
    });

    test('store build: запасной адрес по legacy-маркеру тоже не отдаётся', () {
      expect(profileCabinetUri(_legacyMarker, isStoreBuild: true), isNull);
    });

    test('sideload build: кабинет из заголовка', () {
      expect(
        profileCabinetUri(_withCabinet, isStoreBuild: false),
        Uri.parse('https://cab.example.com'),
      );
    });

    test('sideload build: legacy-маркер ведёт на адрес по умолчанию', () {
      expect(
        profileCabinetUri(_legacyMarker, isStoreBuild: false),
        Uri.parse(defaultCabinetUrl),
      );
    });
  });
}
