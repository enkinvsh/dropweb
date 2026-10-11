// Повторное добавление той же подписки (диплинк, «+», буфер, QR) не должно
// плодить дубль: существующий профиль перенаправляется на новый URL и
// сохраняет все пользовательские настройки.
import 'dart:io';

import 'package:dropweb/common/path.dart';
import 'package:dropweb/common/preferences.dart';
import 'package:dropweb/common/secure_profile_store.dart';
import 'package:dropweb/controller.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_path_provider.dart';
import '../support/fake_secure_profile_store.dart';

const _oldUrl = 'https://old.example/TOKEN-OLD';
const _newUrl = 'https://new.example/TOKEN-NEW';
const _mirror = 'https://mirror.example/TOKEN-M';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useFakePathProvider();
  SharedPreferences.setMockInitialValues({});

  late FakeSecureProfileStore fake;

  setUp(() {
    fake = FakeSecureProfileStore();
    preferences.secureStore = fake;
  });

  tearDown(() {
    preferences.secureStore = secureProfileUrlStore;
  });

  // Профиль после перезапуска: URL уже вынесен из JSON в защищённое хранилище.
  Profile existingProfile({String id = 'old', String? subId}) {
    fake.urls[id] = _oldUrl;
    fake.mirrors[id] = [_mirror];
    if (subId != null) fake.subIds[id] = subId;
    return Profile(
      id: id,
      label: 'Мой VPN',
      autoUpdate: false,
      autoUpdateDuration: const Duration(hours: 6),
      currentGroupName: 'Auto',
      selectedMap: const {'Auto': 'node-1'},
      unfoldSet: const {'Auto'},
      workMode: WorkMode.country,
      staticCountry: 'NL',
      fullTunnel: true,
    );
  }

  Profile downloaded({required String url, String? subId}) => Profile(
        id: 'tmp',
        url: url,
        label: 'new.example',
        autoUpdateDuration: const Duration(hours: 12),
        subId: subId,
        lastUpdateDate: DateTime(2026, 10, 11),
        providerHeaders: const {'dropweb-theme': 'fidelity'},
      );

  group('findReAddTarget', () {
    test('тот же URL (с точностью до нормализации) — совпадение', () async {
      final existing = existingProfile();
      final target = await findReAddTarget(
        profiles: [existing],
        newUrl: '  https://OLD.example/TOKEN-OLD ',
        newSubId: null,
      );
      expect(target?.id, 'old');
    });

    test('URL совпал с зеркалом существующего профиля — совпадение', () async {
      final existing = existingProfile();
      final target = await findReAddTarget(
        profiles: [existing],
        newUrl: _mirror,
        newSubId: null,
      );
      expect(target?.id, 'old');
    });

    test('другой URL, тот же subId — совпадение', () async {
      final existing = existingProfile(subId: 'SID-1');
      final target = await findReAddTarget(
        profiles: [existing],
        newUrl: _newUrl,
        newSubId: 'SID-1',
      );
      expect(target?.id, 'old');
    });

    test('другой URL и другой subId — нет совпадения', () async {
      final existing = existingProfile(subId: 'SID-1');
      final target = await findReAddTarget(
        profiles: [existing],
        newUrl: _newUrl,
        newSubId: 'SID-2',
      );
      expect(target, isNull);
    });

    test('пустые subId не считаются совпадением', () async {
      final existing = existingProfile();
      final target = await findReAddTarget(
        profiles: [existing],
        newUrl: _newUrl,
        newSubId: null,
      );
      expect(target, isNull);
    });

    test('при нескольких совпадениях предпочитается текущий профиль', () async {
      final a = existingProfile(id: 'a', subId: 'SID-1');
      final b = existingProfile(id: 'b', subId: 'SID-1');
      final target = await findReAddTarget(
        profiles: [a, b],
        newUrl: _newUrl,
        newSubId: 'SID-1',
        currentProfileId: 'b',
      );
      expect(target?.id, 'b');
      final first = await findReAddTarget(
        profiles: [a, b],
        newUrl: _newUrl,
        newSubId: 'SID-1',
      );
      expect(first?.id, 'a');
    });
  });

  group('resolveReAddedProfile', () {
    // Та же семантика, что у profilesProvider.setProfile: замена по id или
    // добавление в конец.
    List<Profile> commit(List<Profile> profiles, Profile profile) {
      final index = profiles.indexWhere((p) => p.id == profile.id);
      if (index == -1) return [...profiles, profile];
      return [...profiles]..[index] = profile;
    }

    Future<void> writeTmpFile() async {
      final tmpPath = await appPath.getProfilePath('tmp');
      await File(tmpPath).create(recursive: true);
      await File(tmpPath).writeAsString('proxies: []\n');
    }

    test('повтор того же URL — остаётся один профиль', () async {
      await writeTmpFile();
      final existing = existingProfile();
      final result = await resolveReAddedProfile(
        downloaded: downloaded(url: _oldUrl),
        newUrl: _oldUrl,
        profiles: [existing],
      );
      final profiles = commit([existing], result);
      expect(profiles, hasLength(1));
      expect(profiles.single.id, 'old');
    });

    test('другой URL с тем же subId — один профиль, перенаправлен', () async {
      await writeTmpFile();
      final existing = existingProfile(subId: 'SID-1');
      final result = await resolveReAddedProfile(
        downloaded: downloaded(url: _newUrl, subId: 'SID-1'),
        newUrl: _newUrl,
        profiles: [existing],
      );
      final profiles = commit([existing], result);
      expect(profiles, hasLength(1));
      expect(profiles.single.id, 'old');
      expect(profiles.single.workMode, WorkMode.country);
      expect(fake.urls['old'], _newUrl);
    });

    test('другой subId — новый профиль, старый не тронут', () async {
      await writeTmpFile();
      final existing = existingProfile(subId: 'SID-1');
      final result = await resolveReAddedProfile(
        downloaded: downloaded(url: _newUrl, subId: 'SID-2'),
        newUrl: _newUrl,
        profiles: [existing],
      );
      final profiles = commit([existing], result);
      expect(profiles, hasLength(2));
      expect(result.id, 'tmp');
      expect(fake.urls['old'], _oldUrl);
      final tmpPath = await appPath.getProfilePath('tmp');
      expect(File(tmpPath).existsSync(), isTrue);
    });
  });

  group('adoptDownloadedProfile', () {
    test('сохраняет id и настройки, URL — новый, файл переезжает на старый id',
        () async {
      final existing = existingProfile(subId: 'SID-1');
      fake.preferred['old'] = _mirror;
      final tmpPath = await appPath.getProfilePath('tmp');
      final oldPath = await appPath.getProfilePath('old');
      await File(tmpPath).create(recursive: true);
      await File(tmpPath).writeAsString('proxies: []\n');
      await File(oldPath).create(recursive: true);
      await File(oldPath).writeAsString('stale: true\n');

      final result = await adoptDownloadedProfile(
        existing: existing,
        downloaded: downloaded(url: _newUrl, subId: 'SID-1'),
        newUrl: _newUrl,
      );

      expect(result.id, 'old');
      expect(result.url, _newUrl);
      expect(result.label, 'Мой VPN');
      expect(result.autoUpdate, isFalse);
      expect(result.currentGroupName, 'Auto');
      expect(result.selectedMap, {'Auto': 'node-1'});
      expect(result.unfoldSet, {'Auto'});
      expect(result.workMode, WorkMode.country);
      expect(result.staticCountry, 'NL');
      expect(result.fullTunnel, isTrue);
      expect(result.providerHeaders['dropweb-theme'], 'fidelity');
      expect(result.lastUpdateDate, DateTime(2026, 10, 11));

      expect(await File(oldPath).readAsString(), 'proxies: []\n');
      expect(File(tmpPath).existsSync(), isFalse);

      expect(fake.urls['old'], _newUrl);
      expect(fake.preferred.containsKey('old'), isFalse);
      expect(fake.subIds['old'], 'SID-1');
      expect(await preferences.getProfileUrl(result), _newUrl);
    });

    test('пустой label существующего профиля заменяется скачанным', () async {
      final existing = existingProfile().copyWith(label: '');
      final tmpPath = await appPath.getProfilePath('tmp');
      await File(tmpPath).create(recursive: true);
      await File(tmpPath).writeAsString('proxies: []\n');

      final result = await adoptDownloadedProfile(
        existing: existing,
        downloaded: downloaded(url: _newUrl),
        newUrl: _newUrl,
      );
      expect(result.label, 'new.example');
    });

    test('секреты временного id подчищаются', () async {
      final existing = existingProfile();
      fake.preferred['tmp'] = _mirror;
      final tmpPath = await appPath.getProfilePath('tmp');
      await File(tmpPath).create(recursive: true);
      await File(tmpPath).writeAsString('proxies: []\n');

      await adoptDownloadedProfile(
        existing: existing,
        downloaded: downloaded(url: _newUrl),
        newUrl: _newUrl,
      );
      expect(fake.preferred.containsKey('tmp'), isFalse);
    });
  });
}
