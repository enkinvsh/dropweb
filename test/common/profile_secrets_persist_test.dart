// Зеркала, sub-id и fallback подписки несут токен: в plaintext Config (JSON в
// SharedPreferences) их быть не должно — только в защищённом хранилище.
import 'dart:convert';

import 'package:dropweb/common/constant.dart';
import 'package:dropweb/common/preferences.dart';
import 'package:dropweb/common/secure_profile_store.dart';
import 'package:dropweb/common/subscription_beacon.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_path_provider.dart';
import '../support/fake_secure_profile_store.dart';

const _mirror1 = 'https://mirror.example/TOKEN-M1';
const _mirror2 = 'https://mirror.example/TOKEN-M2';
const _fallback = 'https://mirror.example/TOKEN-FB';
const _subId = 'TOKEN-SUBID';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useFakePathProvider();
  SharedPreferences.setMockInitialValues({});

  late SharedPreferences sp;
  late FakeSecureProfileStore fake;

  setUp(() async {
    sp = (await preferences.sharedPreferencesCompleter.future)!;
    await sp.clear();
    fake = FakeSecureProfileStore();
    preferences.secureStore = fake;
    preferences.rawStringWriter =
        (prefs, key, value) => prefs.setString(key, value);
  });

  tearDown(() {
    preferences.secureStore = secureProfileUrlStore;
    preferences.rawStringWriter = Preferences.defaultRawStringWriter;
  });

  test('saveConfig уносит зеркала/subId/fallback в защищённое хранилище',
      () async {
    const profile = Profile(
      id: 'p1',
      url: 'https://primary.example/TOKEN-P',
      autoUpdateDuration: Duration(hours: 12),
      fallbackUrl: _fallback,
      mirrorUrls: [_mirror1, _mirror2],
      subId: _subId,
      providerHeaders: {
        'fallback-url': _fallback,
        'dropweb-sub-mirrors': '$_mirror1,$_mirror2',
        'dropweb-sub-id': _subId,
        'dropweb-theme': 'fidelity',
      },
    );

    final ok = await preferences.saveConfig(
      const Config(themeProps: defaultThemeProps, profiles: [profile]),
    );
    expect(ok, isTrue);

    final raw = sp.getString(configKey)!;
    expect(raw, isNot(contains('TOKEN')),
        reason: 'ни один токен не должен лечь в plaintext Config');
    final stored = Config.compatibleFromJson(json.decode(raw)).profiles.single;
    expect(stored.mirrorUrls, isEmpty);
    expect(stored.subId, isNull);
    expect(stored.fallbackUrl, isNull);
    expect(stored.providerHeaders, {'dropweb-theme': 'fidelity'});

    expect(fake.mirrors['p1'], [_mirror1, _mirror2]);
    expect(fake.subIds['p1'], _subId);
    expect(fake.fallbacks['p1'], _fallback);
  });

  test('getProfileMirrors / getProfileSubId: сначала хранилище, потом поле',
      () async {
    const inMemory = Profile(
      id: 'p1',
      autoUpdateDuration: Duration(hours: 12),
      mirrorUrls: [_mirror2],
      subId: 'mem',
    );
    expect(await preferences.getProfileMirrors(inMemory), [_mirror2]);
    expect(await preferences.getProfileSubId(inMemory), 'mem');

    fake.mirrors['p1'] = [_mirror1];
    fake.subIds['p1'] = _subId;
    expect(await preferences.getProfileMirrors(inMemory), [_mirror1]);
    expect(await preferences.getProfileSubId(inMemory), _subId);
  });

  test('preferredUrl пишется и стирается через хранилище', () async {
    const p = Profile(id: 'p1', autoUpdateDuration: Duration(hours: 12));
    expect(await preferences.getProfilePreferredUrl(p), isNull);
    expect(await preferences.setProfilePreferredUrl('p1', _mirror1), isTrue);
    expect(await preferences.getProfilePreferredUrl(p), _mirror1);
    expect(await preferences.setProfilePreferredUrl('p1', null), isTrue);
    expect(await preferences.getProfilePreferredUrl(p), isNull);
  });

  test('маяк: адреса, ключи и состояние пишутся и стираются вместе с профилем',
      () async {
    expect(await preferences.getProfileBeaconUrls('p1'), isEmpty);
    expect(await preferences.getProfileBeaconKeys('p1'), isEmpty);
    expect(await preferences.getProfileBeaconState('p1'), isNull);

    expect(
      await preferences
          .setProfileBeaconUrls('p1', ['https://beacon.example/d']),
      isTrue,
    );
    expect(await preferences.setProfileBeaconKeys('p1', ['KEY']), isTrue);
    const state = BeaconState(seq: 2, document: '{"payload":"a","sig":"b"}');
    expect(await preferences.setProfileBeaconState('p1', state), isTrue);

    expect(await preferences.getProfileBeaconUrls('p1'),
        ['https://beacon.example/d']);
    expect(await preferences.getProfileBeaconKeys('p1'), ['KEY']);
    expect(await preferences.getProfileBeaconState('p1'), state);

    await preferences.removeProfileSecrets('p1');
    expect(await preferences.getProfileBeaconUrls('p1'), isEmpty);
    expect(await preferences.getProfileBeaconKeys('p1'), isEmpty);
    expect(await preferences.getProfileBeaconState('p1'), isNull);
  });

  test('SecureProfileUrlStore: маяк с проверкой чтением и removeProfile',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureProfileUrlStore.instance;
    expect(
        await store.setBeaconUrls('p9', ['https://beacon.example/d']), isTrue);
    expect(await store.setBeaconKeys('p9', ['K1', 'K2']), isTrue);
    expect(await store.setBeaconState('p9', '{"seq":1,"doc":"x"}'), isTrue);
    expect(await store.getBeaconUrls('p9'), ['https://beacon.example/d']);
    expect(await store.getBeaconKeys('p9'), ['K1', 'K2']);
    expect(await store.getBeaconState('p9'), '{"seq":1,"doc":"x"}');

    await store.removeProfile('p9');
    expect(await store.getBeaconUrls('p9'), isNull);
    expect(await store.getBeaconKeys('p9'), isNull);
    expect(await store.getBeaconState('p9'), isNull);
  });

  test('setProfileUrl пишет основной адрес в хранилище', () async {
    const p = Profile(
      id: 'p1',
      url: 'https://old.example/s',
      autoUpdateDuration: Duration(hours: 12),
    );
    expect(
        await preferences.setProfileUrl('p1', 'https://new.example/s'), isTrue);
    expect(await preferences.getProfileUrl(p), 'https://new.example/s');
  });
}
