// Удаление профиля убирает и его секреты (адреса, зеркала, sub-id) из
// защищённого хранилища: иначе ссылки с токеном переживают сам профиль.
import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/secure_profile_store.dart';
import 'package:dropweb/controller.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_path_provider.dart';
import '../support/fake_secure_profile_store.dart';

void main() {
  useFakePathProvider();
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSecureProfileStore store;

  setUp(() {
    store = FakeSecureProfileStore();
    preferences.secureStore = store;
  });

  tearDown(() => preferences.secureStore = secureProfileUrlStore);

  testWidgets('deleteProfile стирает секреты только удалённого профиля',
      (tester) async {
    const gone = Profile(id: 'gone', autoUpdateDuration: Duration(hours: 1));
    const kept = Profile(id: 'kept', autoUpdateDuration: Duration(hours: 1));
    globalState.config = const Config(
      themeProps: defaultThemeProps,
      profiles: [gone, kept],
      currentProfileId: 'kept',
    );
    store.urls['gone'] = 'https://sub.example/s/gone';
    store.mirrors['gone'] = ['https://m.example/s/gone'];
    store.subIds['gone'] = 'sid';
    store.urls['kept'] = 'https://sub.example/s/kept';

    late AppController controller;
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            controller = AppController(context, ref);
            return const SizedBox();
          },
        ),
      ),
    );
    // deleteProfile ходит в clearEffect через globalState, а лог — в logs из
    // appState.
    globalState.appController = controller;
    globalState.appState = AppState(
      version: 0,
      viewSize: const Size(400, 800),
      requests: FixedList(10),
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
    );

    await tester.runAsync(() => controller.deleteProfile('gone'));

    expect(widgetRef.read(profilesProvider).map((p) => p.id), ['kept']);
    expect(store.urls.keys, ['kept']);
    expect(store.mirrors, isEmpty);
    expect(store.subIds, isEmpty);
  });
}
