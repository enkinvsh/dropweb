// Лист «Подписка» (сцены `sub` и `refresh-fail` доски): golden поверх главной под scrim,
// паритет раскладки с `layout.json` (±4 dp), действия листа и худшие данные.
// Прогон: `fvm flutter test test/m3e/subscription_sheet_test.dart`; эталоны golden
// обновляются флагом `--update-goldens`.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dropweb/common/error_mapper.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/config.dart' show AppSettingProps;
import 'package:dropweb/models/profile.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/ui/m3e/home/m3e_actions.dart' show m3eRefreshProfile;
import 'package:dropweb/ui/m3e/screens/m3e_home.dart';
import 'package:dropweb/ui/m3e/screens/m3e_subscription_sheet.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_logo.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_model.dart';
import 'package:dropweb/ui/m3e/subscription/m3e_subscription_providers.dart';
import 'package:dropweb/ui/m3e/theme/m3e_theme_scope.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_list.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_sheet.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gate_support.dart';
import 'home_scenes.dart';
import 'support/board_fixtures.dart';
import 'support/golden.dart';

const double _tolerance = 4;

const _sheetKey = ValueKey<String>('m3e.sheet');
const _titleKey = ValueKey<String>('m3e.sheet.title');
const _backKey = ValueKey<String>('m3e.sheet.back');
const _scrimKey = ValueKey<String>('m3e.scrim');
const _addStepKey = ValueKey<String>('test.add.step');

/// Хранилища подписок и настроек без записи в конфиг: `build`/`onUpdate` настоящих
/// лезут в `globalState`, которого в тесте нет.
class _FakeProfiles extends Profiles {
  _FakeProfiles([this._initial = const []]);

  final List<Profile> _initial;

  @override
  List<Profile> build() => _initial;

  @override
  void onUpdate(List<Profile> value) {}
}

class _FakeCurrentId extends CurrentProfileId {
  _FakeCurrentId([this._id]);

  final String? _id;

  @override
  String? build() => _id;

  @override
  void onUpdate(String? value) {}
}

class _FakeAppSetting extends AppSetting {
  _FakeAppSetting(this._props);

  final AppSettingProps _props;

  @override
  AppSettingProps build() => _props;

  @override
  void onUpdate(AppSettingProps value) {}
}

List<Override> get _fakeStores => [
      profilesProvider.overrideWith(_FakeProfiles.new),
      currentProfileIdProvider.overrideWith(_FakeCurrentId.new),
    ];

/// Журнал вызовов подменённых действий листа.
class _Calls {
  final List<String> log = [];
  bool refreshFails = false;

  /// Что бросает обновление при `refreshFails`; по умолчанию ошибка без известной причины.
  Exception refreshError = Exception('нет связи');
  final List<(String, M3eToastKind)> toasts = [];

  M3eSubActions get actions => M3eSubActions(
        refresh: (id) async {
          log.add('refresh:$id');
          if (refreshFails) throw refreshError;
        },
        select: (id) => log.add('select:$id'),
        delete: (id) async => log.add('delete:$id'),
        openLink: (url) => log.add('link:$url'),
        notify: (text, kind) {
          log.add('toast:${kind.name}:$text');
          toasts.add((text, kind));
        },
      );
}

/// Подписки доски: имена, страницы и логотипы NORMAL или WORST. Логотип без `.svg` в
/// тесте не грузится (сети нет), поэтому у него остаются инициалы.
M3eSubModel _model({
  bool worst = false,
  int? count,
  String? currentId = 'p0',
  bool support = true,
  bool refreshing = false,
  String? renew,
  String? topUp,
  DateTime? updatedAt,
  Map<int, String> logos = const {},
}) {
  final d = worst ? kBoardWorst : kBoardNormal;
  final n = count ?? d.profiles.length;
  return M3eSubModel(
    profiles: [
      for (var i = 0; i < n; i++)
        M3eSubProfile(
          id: 'p$i',
          name: i < d.profiles.length ? d.profiles[i] : 'Подписка ${i + 1}',
          host: i < d.pages.length ? d.pages[i] : 'host$i.example',
          logoUrl: logos[i] ??
              ((i < d.logos.length &&
                      (d.logos[i]?.toLowerCase().endsWith('.svg') ?? false))
                  ? d.logos[i]
                  : null),
        ),
    ],
    currentId: currentId,
    updatedAt: updatedAt ?? kHomeNow.subtract(const Duration(minutes: 4)),
    refreshing: refreshing,
    supportUrl: support ? 'https://${d.pages[0]}' : null,
    renewUrl: renew,
    topUpUrl: topUp,
  );
}

Widget _app(
  M3eSubModel model, {
  required _Calls calls,
  String scene = 'home-off',
  int provider = 0,
  Brightness brightness = Brightness.light,
  bool worst = false,
  List<Override> extra = const [],
}) =>
    gateHomeApp(
      scene,
      provider: provider,
      brightness: brightness,
      worst: worst,
      extra: [
        ...extra,
        m3eSubModelProvider.overrideWithValue(model),
        m3eSubClockProvider.overrideWithValue(() => kHomeNow),
        m3eSubActionsProvider.overrideWithValue(calls.actions),
      ],
    );

Future<void> _pump(WidgetTester tester, Widget app,
    {bool shadows = false}) async {
  debugDisableShadows = !shadows;
  await pumpM3eBoard(tester, app);
  await tester.pump(const Duration(seconds: 1));
}

BuildContext _homeContext(WidgetTester tester) =>
    tester.element(find.byType(M3eHome));

/// Шаг «Добавить подписку» подменён заглушкой с собственным заголовком.
Widget _addStep(BuildContext context) => const M3eSheetScaffold(
      title: 'Добавить подписку',
      body: SizedBox(key: _addStepKey, height: 40),
    );

final List<(String, String)> _deleteAsks = [];

Future<void> _open(
  WidgetTester tester, {
  bool confirm = true,
}) async {
  unawaited(
    showM3eSubscriptionSheet(
      _homeContext(tester),
      addBuilder: _addStep,
      confirmDelete: (context, name) async {
        _deleteAsks.add(('ask', name));
        return confirm;
      },
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Плашка «Нет связи с сервером» поверх листа: так её рисует MessageManager выше
/// навигатора. Цвета M3E переносятся в запись оверлея явно.
void _showToast(WidgetTester tester, M3eToastKind kind, String text) {
  final ctx = _homeContext(tester);
  final colors = M3eColors.of(ctx);
  Navigator.of(ctx, rootNavigator: true).overlay!.insert(
        OverlayEntry(
          builder: (_) => M3eColors(
            scheme: colors.scheme,
            home: colors.home,
            brightness: colors.brightness,
            child: MediaQuery(
              data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
              child: Material(
                type: MaterialType.transparency,
                child: M3eToastPresenter(
                  hold: null,
                  message: M3eToastMessage(kind: kind, text: text),
                ),
              ),
            ),
          ),
        ),
      );
}

Future<void> _golden(WidgetTester tester, String name) async {
  try {
    await expectM3eGolden(tester, name);
  } finally {
    debugDisableShadows = true;
  }
}

final Map<String, dynamic> _layout =
    jsonDecode(File('test/m3e/ref/layout.json').readAsStringSync())
        as Map<String, dynamic>;

Rect _rectOf(Object? raw, [int index = 0]) {
  final m = (raw is List ? raw[index] : raw) as Map<String, dynamic>;
  return Rect.fromLTWH(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['w'] as num).toDouble(),
    (m['h'] as num).toDouble(),
  );
}

void _expectRect(Rect board, Rect ours, String what) {
  expect((board.left - ours.left).abs(), lessThanOrEqualTo(_tolerance),
      reason: '$what x: board=$board ours=$ours');
  expect((board.top - ours.top).abs(), lessThanOrEqualTo(_tolerance),
      reason: '$what y: board=$board ours=$ours');
  expect((board.width - ours.width).abs(), lessThanOrEqualTo(_tolerance),
      reason: '$what w: board=$board ours=$ours');
  expect((board.height - ours.height).abs(), lessThanOrEqualTo(_tolerance),
      reason: '$what h: board=$board ours=$ours');
}

M3eListItem _item(WidgetTester tester, Key key) =>
    tester.widget<M3eListItem>(find.byKey(key));

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.load(const Locale('ru'));
  });

  setUp(_deleteAsks.clear);
  tearDown(() => debugDisableShadows = true);

  group('golden: sub и refresh-fail × тема × провайдеры', () {
    for (final brightness in Brightness.values) {
      for (final p in const [0, 5]) {
        final theme = '${brightness.name}_p$p';
        testWidgets('sub_$theme', (tester) async {
          await _pump(
            tester,
            _app(_model(),
                calls: _Calls(), provider: p, brightness: brightness),
            shadows: true,
          );
          await _open(tester);
          expect(tester.takeException(), isNull);
          await _golden(tester, 'sub_$theme');
        });

        testWidgets('refreshfail_$theme', (tester) async {
          // Сцена доски: сети нет (главная offline), лист открыт, плашка удержана.
          await _pump(
            tester,
            _app(
              _model(),
              calls: _Calls(),
              scene: 'offline',
              provider: p,
              brightness: brightness,
            ),
            shadows: true,
          );
          await _open(tester);
          _showToast(tester, M3eToastKind.alert, l.m3eToastRefreshFail);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 700));
          expect(tester.takeException(), isNull);
          await _golden(tester, 'refreshfail_$theme');
        });
      }
    }
  });

  group('паритет раскладки с доской', () {
    for (final brightness in Brightness.values) {
      for (final p in const [0, 5]) {
        for (final (scene, ref) in const [
          ('home-off', 'sub'),
          ('offline', 'refresh-fail'),
        ]) {
          testWidgets('$ref ${brightness.name} p$p', (tester) async {
            await _pump(
              tester,
              _app(_model(),
                  calls: _Calls(),
                  scene: scene,
                  provider: p,
                  brightness: brightness),
            );
            await _open(tester);
            final e = (_layout['$ref-${brightness.name}-p$p']
                as Map<String, dynamic>)['elements'] as Map<String, dynamic>;

            _expectRect(_rectOf(e['sheet']),
                tester.getRect(find.byKey(_sheetKey)), 'sheet');
            _expectRect(_rectOf(e['sheet.title']),
                tester.getRect(find.byKey(_titleKey)), 'sheet.title');
            _expectRect(_rectOf(e['scrim']),
                tester.getRect(find.byKey(_scrimKey)), 'scrim');
            for (var i = 0; i < 4; i++) {
              _expectRect(_rectOf(e['list'], i),
                  tester.getRect(find.byKey(kM3eSubListKey(i))), 'list.$i');
            }
            final items = <Key>[
              kM3eSubRefreshKey,
              kM3eSubSupportKey,
              kM3eSubProfileKey('p0'),
              kM3eSubProfileKey('p1'),
              kM3eSubAddKey,
              kM3eSubDeleteKey,
            ];
            for (var i = 0; i < items.length; i++) {
              _expectRect(_rectOf(e['list.item'], i),
                  tester.getRect(find.byKey(items[i])), 'list.item.$i');
            }
            _expectRect(_rectOf(e['list.head']),
                tester.getRect(find.byKey(kM3eSubHeadKey)), 'list.head');
            if (ref == 'refresh-fail') {
              // Плашка живёт над листом. Решение владельца 2026-10-29: центр плашки на
              // линии кнопки настроек, на доске она ниже на 6 dp (y 52 против 46).
              // Сдвиг вычитается явно, а не поглощается допуском.
              _showToast(tester, M3eToastKind.alert, l.m3eToastRefreshFail);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 700));
              const ownerShift = Offset(0, 52 - (44 + kM3eToastTopGap));
              _expectRect(
                  _rectOf(e['toast']).shift(-ownerShift),
                  tester.getRect(find.byKey(const ValueKey('m3e.toast'))),
                  'toast');
              _expectRect(
                  _rectOf(e['toast.text']).shift(-ownerShift),
                  tester.getRect(find.byKey(const ValueKey('m3e.toast.text'))),
                  'toast.text');
            }
          });
        }
      }
    }
  });

  group('содержимое', () {
    testWidgets('заголовок, подписи, текущая подписка отмечена',
        (tester) async {
      await _pump(tester, _app(_model(), calls: _Calls()));
      await _open(tester);
      expect(tester.widget<Text>(find.byKey(_titleKey)).data, l.m3eSubTitle);
      expect(_item(tester, kM3eSubRefreshKey).label, l.m3eRefresh);
      expect(_item(tester, kM3eSubRefreshKey).sup, l.m3eUpdatedMinutesAgo(4));
      expect(_item(tester, kM3eSubSupportKey).label, l.m3eSubSupport);
      expect(_item(tester, kM3eSubSupportKey).sup, 'cfgpull.com');
      expect(_item(tester, kM3eSubProfileKey('p0')).radioChecked, isTrue);
      expect(_item(tester, kM3eSubProfileKey('p1')).radioChecked, isFalse);
      expect(_item(tester, kM3eSubProfileKey('p1')).sup, 'panel.home-vpn.ru');
      expect(_item(tester, kM3eSubAddKey).label, l.addSubscription);
      expect(_item(tester, kM3eSubDeleteKey).label, l.m3eSubDelete);
      expect(find.text(l.m3eSubAll), findsOneWidget);
    });

    testWidgets('без support-url пункта «Справочная» нет', (tester) async {
      await _pump(tester, _app(_model(support: false), calls: _Calls()));
      await _open(tester);
      expect(find.byKey(kM3eSubSupportKey), findsNothing);
    });

    testWidgets('подписка ещё не обновлялась: подписи у «Обновить» нет',
        (tester) async {
      final model = M3eSubModel(
        profiles: _model().profiles,
        currentId: 'p0',
      );
      await _pump(tester, _app(model, calls: _Calls()));
      await _open(tester);
      expect(_item(tester, kM3eSubRefreshKey).sup, isNull);
    });

    testWidgets('продление и пополнение — только когда есть', (tester) async {
      await _pump(tester, _app(_model(), calls: _Calls()));
      await _open(tester);
      for (final k in [kM3eSubRenewKey, kM3eSubTopUpKey]) {
        expect(find.byKey(k), findsNothing);
      }
    });

    testWidgets('пункты провайдера и их действия', (tester) async {
      final calls = _Calls();
      await _pump(
        tester,
        _app(
          _model(
            renew: 'https://cfgpull.com/renew',
            topUp: 'https://cfgpull.com/topup',
          ),
          calls: calls,
        ),
      );
      await _open(tester);
      await tester.tap(find.byKey(kM3eSubRenewKey));
      await tester.tap(find.byKey(kM3eSubTopUpKey));
      expect(calls.log, [
        'link:https://cfgpull.com/renew',
        'link:https://cfgpull.com/topup',
      ]);
      expect(tester.takeException(), isNull);
    });
  });

  group('действия', () {
    testWidgets('обновить: успех — плашка check, ошибки нет', (tester) async {
      final calls = _Calls();
      await _pump(tester, _app(_model(), calls: calls));
      await _open(tester);
      await tester.tap(find.byKey(kM3eSubRefreshKey));
      await tester.pump();
      expect(calls.log, ['refresh:p0', 'toast:check:${l.m3eToastRefreshed}']);
      final container = ProviderScope.containerOf(_homeContext(tester));
      expect(container.read(m3eSubRefreshProvider).failed, isNot(contains('p0')));
      expect(container.read(m3eSubRefreshProvider).updatingId, isNull);
    });

    testWidgets('обновить: ошибка — плашка alert и состояние «не обновилась»',
        (tester) async {
      final calls = _Calls()..refreshFails = true;
      await _pump(tester, _app(_model(), calls: calls));
      await _open(tester);
      await tester.tap(find.byKey(kM3eSubRefreshKey));
      await tester.pump();
      expect(calls.log, ['refresh:p0', 'toast:alert:${l.m3eToastRefreshFail}']);
      final container = ProviderScope.containerOf(_homeContext(tester));
      expect(container.read(m3eSubRefreshProvider).failed, contains('p0'));

      // Повтор после восстановления связи снимает «не обновилась».
      calls
        ..refreshFails = false
        ..log.clear();
      await tester.tap(find.byKey(kM3eSubRefreshKey));
      await tester.pump();
      expect(calls.log, ['refresh:p0', 'toast:check:${l.m3eToastRefreshed}']);
      expect(container.read(m3eSubRefreshProvider).failed, isNot(contains('p0')));
    });

    testWidgets('обновить: известная причина ошибки доходит до плашки',
        (tester) async {
      final reason = ErrorMapper.mapError('status code of 403');
      expect(reason, isNotNull);
      final calls = _Calls()
        ..refreshFails = true
        ..refreshError = Exception('DioException: status code of 403');
      await _pump(tester, _app(_model(), calls: calls));
      await _open(tester);
      await tester.tap(find.byKey(kM3eSubRefreshKey));
      await tester.pump();
      expect(calls.log, ['refresh:p0', 'toast:alert:$reason']);
      expect(reason, isNot(l.m3eToastRefreshFail));
    });

    test(
        'настоящее обновление несуществующей подписки — ошибка, а не «Обновлено»',
        () async {
      final container = ProviderContainer(overrides: _fakeStores);
      addTearDown(container.dispose);
      await expectLater(
        container.read(m3eSubActionsProvider).refresh('нет-такой'),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('пока подписка обновляется, пункт не нажимается',
        (tester) async {
      final calls = _Calls();
      await _pump(tester, _app(_model(refreshing: true), calls: calls));
      await _open(tester);
      expect(_item(tester, kM3eSubRefreshKey).onTap, isNull);
      expect(_item(tester, kM3eSubRefreshKey).sup, l.loadingEllipsis);
      await tester.tap(find.byKey(kM3eSubRefreshKey), warnIfMissed: false);
      expect(calls.log, isEmpty);
    });

    testWidgets('«Справочная» открывает ссылку и показывает плашку',
        (tester) async {
      final calls = _Calls();
      await _pump(tester, _app(_model(), calls: calls));
      await _open(tester);
      await tester.tap(find.byKey(kM3eSubSupportKey));
      expect(calls.log, [
        'link:https://cfgpull.com',
        'toast:out:${l.m3eToastSupport}',
      ]);
    });

    testWidgets('выбор подписки отдаёт её id', (tester) async {
      final calls = _Calls();
      await _pump(tester, _app(_model(), calls: calls));
      await _open(tester);
      await tester.tap(find.byKey(kM3eSubProfileKey('p1')));
      expect(calls.log, ['select:p1']);
    });

    testWidgets('«Добавить подписку» кладёт шаг в стек, «Назад» возвращает',
        (tester) async {
      await _pump(tester, _app(_model(), calls: _Calls()));
      await _open(tester);
      expect(find.byKey(_backKey), findsNothing);
      await tester.tap(find.byKey(kM3eSubAddKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_addStepKey), findsOneWidget);
      expect(
          tester.widget<Text>(find.byKey(_titleKey)).data, 'Добавить подписку');
      expect(find.byKey(_backKey), findsOneWidget);

      await tester.tap(find.byKey(_backKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<Text>(find.byKey(_titleKey)).data, l.m3eSubTitle);
      expect(find.byKey(kM3eSubAddKey), findsOneWidget);
    });

    testWidgets('удаление: «Удалить» в диалоге удаляет текущую подписку',
        (tester) async {
      final calls = _Calls();
      await _pump(tester, _app(_model(), calls: calls));
      await _open(tester);
      await tester.tap(find.byKey(kM3eSubDeleteKey));
      await tester.pump();
      expect(_deleteAsks, [('ask', 'DROPWEB')]);
      expect(calls.log, ['delete:p0']);
    });

    testWidgets('удаление: отказ в диалоге ничего не удаляет', (tester) async {
      final calls = _Calls();
      await _pump(tester, _app(_model(), calls: calls));
      await _open(tester, confirm: false);
      await tester.tap(find.byKey(kM3eSubDeleteKey));
      await tester.pump();
      expect(_deleteAsks, [('ask', 'DROPWEB')]);
      expect(calls.log, isEmpty);
    });

    testWidgets('без текущей подписки «Обновить» и «Удалить» не нажимаются',
        (tester) async {
      await _pump(tester, _app(_model(currentId: null), calls: _Calls()));
      await _open(tester);
      expect(_item(tester, kM3eSubRefreshKey).onTap, isNull);
      expect(_item(tester, kM3eSubDeleteKey).onTap, isNull);
    });

    testWidgets('удалили последнюю подписку: лист закрывается', (tester) async {
      final calls = _Calls();
      final model = StateProvider<M3eSubModel>((ref) => _model());
      await _pump(
        tester,
        gateHomeApp(
          'home-off',
          extra: [
            m3eSubModelProvider.overrideWith((ref) => ref.watch(model)),
            m3eSubClockProvider.overrideWithValue(() => kHomeNow),
            m3eSubActionsProvider.overrideWithValue(calls.actions),
          ],
        ),
      );
      await _open(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
      ProviderScope.containerOf(_homeContext(tester))
          .read(model.notifier)
          .state = const M3eSubModel(profiles: [], currentId: null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(_sheetKey), findsNothing);
    });
  });

  group('магазинная сборка', () {
    final headers = {
      'support-url': 'https://t.me/support',
      'dropweb-cabinet': 'https://lk.cfgpull.com/',
      'dropweb-renew-url': 'https://cfgpull.com/renew',
      'dropweb-topup-url': 'https://cfgpull.com/topup',
    };
    final storeProfile = Profile(
      id: 'a',
      label: 'A',
      autoUpdateDuration: const Duration(hours: 1),
      providerHeaders: headers,
    );

    test('модель: продление и пополнение скрыты', () {
      final m = m3eSubModelOf(
        profiles: [storeProfile],
        currentId: 'a',
        storeBuild: true,
      );
      expect(m.renewUrl, isNull);
      expect(m.topUpUrl, isNull);
      expect(m.hasExtras, isFalse);
    });

    testWidgets('лист: нет «Продлить», «Пополнить»', (tester) async {
      final model = m3eSubModelOf(
        profiles: [storeProfile],
        currentId: 'a',
        storeBuild: true,
      );
      await _pump(tester, _app(model, calls: _Calls()));
      await _open(tester);
      for (final key in [kM3eSubRenewKey, kM3eSubTopUpKey]) {
        expect(find.byKey(key), findsNothing);
      }
      // Поддержка остаётся: её правило магазина не режет.
      expect(find.byKey(kM3eSubSupportKey), findsOneWidget);
    });
  });

  group('аккаунта и кабинета в листе нет никогда', () {
    // Владелец 2026-10-29: Android-редизайн = магазинный, без входа и кабинета ни в
    // какой сборке. Заголовок `dropweb-cabinet` и сессия аккаунта ничего не меняют.
    const profile = Profile(
      id: 'a',
      label: 'A',
      autoUpdateDuration: Duration(hours: 1),
      providerHeaders: {
        'support-url': 'https://t.me/support',
        'dropweb-cabinet': 'https://lk.cfgpull.com/',
        'dropweb-renew-url': 'https://cfgpull.com/renew',
        'dropweb-topup-url': 'https://cfgpull.com/topup',
      },
    );

    test('модель не-магазинной сборки не знает про кабинет и аккаунт', () {
      final m = m3eSubModelOf(
        profiles: [profile],
        currentId: 'a',
        storeBuild: false,
      );
      // Продление и пополнение остаются: их режет только магазин.
      expect(m.renewUrl, 'https://cfgpull.com/renew');
      expect(m.topUpUrl, 'https://cfgpull.com/topup');
    });

    testWidgets('лист из реального провайдера: ни «Аккаунт», ни «Кабинет»',
        (tester) async {
      await _pump(
        tester,
        gateHomeApp(
          'home-off',
          extra: [
            ..._fakeStores,
            profilesProvider.overrideWith(() => _FakeProfiles([profile])),
            currentProfileIdProvider.overrideWith(() => _FakeCurrentId('a')),
            m3eSubStoreBuildProvider.overrideWithValue(false),
            m3eSubClockProvider.overrideWithValue(() => kHomeNow),
            m3eSubActionsProvider.overrideWithValue(_Calls().actions),
          ],
        ),
      );
      await _open(tester);
      expect(find.byKey(kM3eSubRenewKey), findsOneWidget);
      expect(find.byKey(kM3eSubTopUpKey), findsOneWidget);
      expect(find.text(l.account), findsNothing);
      expect(find.text(l.personalCabinet), findsNothing);
      expect(find.byType(M3eListItem), findsWidgets);
    });
  });

  group('«Обновить» на главной', () {
    const buttonKey = ValueKey<String>('test.refresh');
    const p0 = Profile(
      id: 'p0',
      label: 'DROPWEB',
      autoUpdateDuration: Duration(hours: 1),
    );

    Future<_Calls> pumpButton(WidgetTester tester, {Profile? profile}) async {
      final calls = _Calls();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWithValue(profile),
            m3eSubActionsProvider.overrideWithValue(calls.actions),
          ],
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => TextButton(
                key: buttonKey,
                onPressed: () => unawaited(m3eRefreshProfile(context, ref)),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return calls;
    }

    testWidgets('успех: плашка check', (tester) async {
      final calls = await pumpButton(tester, profile: p0);
      await tester.tap(find.byKey(buttonKey));
      await tester.pump();
      expect(calls.log, ['refresh:p0', 'toast:check:${l.m3eToastRefreshed}']);
    });

    testWidgets('ошибка: плашка alert с причиной', (tester) async {
      final reason = ErrorMapper.mapError('status code of 403');
      final calls = await pumpButton(tester, profile: p0);
      calls
        ..refreshFails = true
        ..refreshError = Exception('status code of 403');
      await tester.tap(find.byKey(buttonKey));
      await tester.pump();
      expect(calls.log, ['refresh:p0', 'toast:alert:$reason']);
    });

    testWidgets('ошибка без известной причины: общий текст', (tester) async {
      final calls = await pumpButton(tester, profile: p0);
      calls.refreshFails = true;
      await tester.tap(find.byKey(buttonKey));
      await tester.pump();
      expect(calls.log, ['refresh:p0', 'toast:alert:${l.m3eToastRefreshFail}']);
    });

    testWidgets('нет текущей подписки: ничего не происходит', (tester) async {
      final calls = await pumpButton(tester);
      await tester.tap(find.byKey(buttonKey));
      await tester.pump();
      expect(calls.log, isEmpty);
    });
  });

  group('логотип провайдера в листе', () {
    // Решение владельца 2026-10-29: в листе логотип есть, на кнопке подписок главной нет.
    // Переключатель «Лого из подписки» (на телефоне владельца выключен) на лист не влияет.
    const svgUrl = 'https://x.example/logo.svg';
    const pngUrl = 'https://x.example/logo.png';
    const brokenUrl = 'https://x.example/broken.svg';
    // 1×1 прозрачный PNG.
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAHnOcQAAAAABJRU5ErkJggg==',
    );
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
        '<rect width="10" height="10" fill="#fff"/></svg>';

    Widget app(Map<int, String> logos, Map<String, M3eSubLogo?> resolved) =>
        _app(
          _model(logos: logos),
          calls: _Calls(),
          extra: [
            for (final e in resolved.entries)
              m3eSubLogoProvider(e.key).overrideWith((ref) => e.value),
          ],
        );

    testWidgets('SVG из заголовка рисуется в аватаре', (tester) async {
      await _pump(
        tester,
        app({0: svgUrl}, {svgUrl: const M3eSubLogo.svg(svg)}),
      );
      await _open(tester);
      final p0 = find.byKey(kM3eSubProfileKey('p0'));
      // Вместо инициалов в аватаре SVG (вторая картинка в строке — галочка текущей).
      expect(find.descendant(of: p0, matching: find.text('D')), findsNothing);
      expect(find.descendant(of: p0, matching: find.byType(SvgPicture)),
          findsNWidgets(2));
      expect(
          find.descendant(
              of: find.byKey(kM3eSubProfileKey('p1')),
              matching: find.byType(SvgPicture)),
          findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('растровый логотип рисуется в аватаре', (tester) async {
      await _pump(
        tester,
        app({0: pngUrl}, {pngUrl: M3eSubLogo.raster(MemoryImage(png))}),
      );
      await _open(tester);
      expect(
        find.descendant(
          of: find.byKey(kM3eSubProfileKey('p0')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('нет заголовка или логотип не загрузился: инициалы',
        (tester) async {
      await _pump(
        tester,
        // У p0 заголовок есть, но файл не загрузился; у p1 заголовка нет.
        app({0: brokenUrl}, {brokenUrl: null}),
      );
      await _open(tester);
      final p0 = find.byKey(kM3eSubProfileKey('p0'));
      final p1 = find.byKey(kM3eSubProfileKey('p1'));
      expect(find.descendant(of: p0, matching: find.text('D')), findsOneWidget);
      expect(find.descendant(of: p1, matching: find.text('Д')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'переключатель «Лого из подписки» выключен: логотип всё равно есть',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          ..._fakeStores,
          profilesProvider.overrideWith(
            () => _FakeProfiles([
              const Profile(
                id: 'a',
                label: 'A',
                autoUpdateDuration: Duration(hours: 1),
                providerHeaders: {'dropweb-logo': pngUrl},
              ),
            ]),
          ),
          currentProfileIdProvider.overrideWith(() => _FakeCurrentId('a')),
          appSettingProvider.overrideWith(
            () => _FakeAppSetting(
              const AppSettingProps(applySubscriptionLogo: false),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(m3eSubModelProvider).profiles.single.logoUrl,
        pngUrl,
      );
    });

    test('битый SVG и пустой ответ дают инициалы', () async {
      final container = ProviderContainer(
        overrides: [
          m3eLogoSvgProvider(brokenUrl).overrideWith((ref) => '<svg><g></svg>'),
          m3eLogoSvgProvider(svgUrl).overrideWith((ref) => ''),
        ],
      );
      addTearDown(container.dispose);
      expect(
          await container.read(m3eSubLogoProvider(brokenUrl).future), isNull);
      expect(await container.read(m3eSubLogoProvider(svgUrl).future), isNull);
    });

    test('рабочий SVG проходит проверку', () async {
      final container = ProviderContainer(
        overrides: [m3eLogoSvgProvider(svgUrl).overrideWith((ref) => svg)],
      );
      addTearDown(container.dispose);
      final logo = await container.read(m3eSubLogoProvider(svgUrl).future);
      expect(logo?.svg, svg);
    });
  });

  group('худшие данные', () {
    testWidgets('длинные имена: строки не ломают раскладку', (tester) async {
      await _pump(
        tester,
        _app(_model(worst: true), calls: _Calls(), worst: true),
      );
      await _open(tester);
      expect(tester.takeException(), isNull);
      for (var i = 0; i < kBoardWorst.profiles.length; i++) {
        final rect = tester.getRect(find.byKey(kM3eSubProfileKey('p$i')));
        expect(rect.width, 379, reason: 'профиль $i');
        expect(rect.left, 16);
      }
    });

    testWidgets('10 подписок: лист упирается в 72 dp от верха и прокручивается',
        (tester) async {
      await _pump(
        tester,
        _app(_model(worst: true, count: 10), calls: _Calls(), worst: true),
      );
      await _open(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(_sheetKey)).top, closeTo(72, 0.01));
      // Пункт «Удалить подписку» в конце списка уходит за край и достижим прокруткой.
      await tester.scrollUntilVisible(
        find.byKey(kM3eSubDeleteKey),
        200,
        scrollable: find.descendant(
          of: find.byKey(_sheetKey),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.byKey(kM3eSubDeleteKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('модель из приложения', () {
    Profile profile(String id,
            {String? label, Map<String, String> headers = const {}}) =>
        Profile(
          id: id,
          label: label,
          autoUpdateDuration: const Duration(hours: 1),
          providerHeaders: headers,
        );

    M3eSubModel build(
      List<Profile> profiles, {
      String? current,
      bool store = false,
    }) =>
        m3eSubModelOf(
          profiles: profiles,
          currentId: current,
          storeBuild: store,
        );

    test('хост страницы: profile-web-page-url, затем support-url, иначе нет',
        () {
      final m = build([
        profile('a', label: 'A', headers: {
          'profile-web-page-url': 'https://cfgpull.com/ru',
          'support-url': 'https://t.me/support',
        }),
        profile('b',
            label: 'B', headers: {'support-url': 'https://t.me/support'}),
        profile('c', label: 'C'),
      ]);
      expect(m.profiles.map((p) => p.host), ['cfgpull.com', 't.me', null]);
    });

    test('имя — serviceName: заголовок бренда главнее ярлыка', () {
      final m = build([
        profile('a',
            label: 'host.example', headers: {'dropweb-servicename': 'Мой VPN'}),
        profile('b'),
      ]);
      expect(m.profiles.map((p) => p.name), ['Мой VPN', 'b']);
    });

    test('логотип берётся из заголовка dropweb-logo', () {
      final m = build([
        profile('a', headers: {'dropweb-logo': 'https://x.example/logo.svg'}),
        profile('b', headers: {'dropweb-logo': 'https://x.example/logo.png'}),
        profile('c'),
      ]);
      expect(m.profiles.map((p) => p.logoUrl), [
        'https://x.example/logo.svg',
        'https://x.example/logo.png',
        null,
      ]);
    });

    test('продление и пополнение берутся по заголовкам', () {
      final headers = {
        'support-url': 'https://t.me/support',
        'dropweb-cabinet': 'https://lk.cfgpull.com/',
        'dropweb-renew-url': 'https://cfgpull.com/renew',
        'dropweb-topup-url': 'https://cfgpull.com/topup',
      };
      final m = build([profile('a', headers: headers)], current: 'a');
      expect(m.supportUrl, 'https://t.me/support');
      expect(m.renewUrl, 'https://cfgpull.com/renew');
      expect(m.topUpUrl, 'https://cfgpull.com/topup');
      expect(m.hasExtras, isTrue);
    });

    test('магазинная сборка режет продление и пополнение', () {
      final headers = {
        'support-url': 'https://t.me/support',
        'dropweb-cabinet': 'https://lk.cfgpull.com/',
        'dropweb-renew-url': 'https://cfgpull.com/renew',
        'dropweb-topup-url': 'https://cfgpull.com/topup',
      };
      final m =
          build([profile('a', headers: headers)], current: 'a', store: true);
      expect(m.renewUrl, isNull);
      expect(m.topUpUrl, isNull);
      // Поддержка остаётся: правило магазинов её не режет.
      expect(m.supportUrl, 'https://t.me/support');
      expect(m.hasExtras, isFalse);
    });

    test('ссылки не http(s) отбрасываются', () {
      final m = build(
        [
          profile('a', headers: {
            'dropweb-renew-url': 'javascript:alert(1)',
            'dropweb-topup-url': 'tg://resolve?domain=x',
          }),
        ],
        current: 'a',
      );
      expect(m.renewUrl, isNull);
      expect(m.topUpUrl, isNull);
    });

    test('текущая подписка: когда обновлялась и обновляется ли сейчас', () {
      final at = DateTime(2026, 10, 29, 11, 56);
      final m = build(
        [
          profile('a').copyWith(lastUpdateDate: at, isUpdating: true),
          profile('b'),
        ],
        current: 'a',
      );
      expect(m.updatedAt, at);
      expect(m.refreshing, isTrue);
      expect(m.current?.id, 'a');
    });

    test('инициалы: два первых слова, как у доски', () {
      expect(m3eSubInitials('Дом'), 'Д');
      expect(m3eSubInitials('Мамин телефон'), 'МТ');
      expect(m3eSubInitials('Северо-Западный Интернет'), 'СЗ');
      expect(m3eSubInitials('!!!'), '?');
    });

    test('«Обновлено N назад»: порог минута, час, сутки', () {
      final now = DateTime(2026, 10, 29, 12);
      String? at(Duration ago) => m3eUpdatedAgo(l, now.subtract(ago), now);
      expect(at(Duration.zero), l.m3eUpdatedJustNow);
      expect(at(const Duration(seconds: 59)), l.m3eUpdatedJustNow);
      expect(at(const Duration(minutes: 4)), l.m3eUpdatedMinutesAgo(4));
      expect(at(const Duration(minutes: 59)), l.m3eUpdatedMinutesAgo(59));
      expect(at(const Duration(hours: 3)), l.m3eUpdatedHoursAgo(3));
      expect(at(const Duration(days: 2)), l.m3eUpdatedDaysAgo(2));
      // Часы устройства ушли назад: «только что», а не отрицательное число.
      expect(m3eUpdatedAgo(l, now.add(const Duration(minutes: 5)), now),
          l.m3eUpdatedJustNow);
      expect(m3eUpdatedAgo(l, null, now), isNull);
    });
  });
}
