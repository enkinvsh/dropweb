import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/app.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/foundation.dart';

/// Подмена типа сборки для тестов: `true` — магазинная, `false` — обычная,
/// `null` — как есть. Только для проверки гейтов на macOS/Linux, где реальные
/// Play/iOS недоступны.
@visibleForTesting
bool? debugAccountStoreBlocked;

/// Решение владельца 2026-10-29: в магазинных сборках (Google Play, iOS)
/// аккаунта и личного кабинета нет вообще — ни входа, ни кабинета в браузере,
/// ни запросов к шлюзу аккаунта, ни чтения хранилища сессии. Политика
/// магазинов: вход по почте создаёт аккаунт (удаление в приложении, декларация
/// данных), а кабинет провайдера ведёт на оплату.
///
/// `kIsPlayBuild` — const из `--dart-define=PLAY_BUILD`: в Play-сборке
/// компилятор сворачивает `true || …`, и код за гейтом уходит из AAB. На iOS
/// отдельного const нет (потребовался бы `--dart-define=STORE_BUILD=true` в
/// командах сборки iOS), поэтому там гейт срабатывает в рантайме по
/// [System.isStoreBuild].
bool get accountStoreBlocked =>
    kIsPlayBuild || (debugAccountStoreBlocked ?? system.isStoreBuild);

/// Подмена «телефона» для тестов: `true` — Android в мобильной раскладке,
/// `false` — нет, `null` — как есть. На macOS/Linux реальный Android недоступен,
/// а `globalState.appState` без `initApp` не инициализирован.
@visibleForTesting
bool? debugAccountPhoneBlocked;

/// Решение владельца 2026-10-29: на Android в мобильной раскладке (M3E-экраны,
/// см. `useM3eHome` в pages/home.dart) входов в аккаунт в интерфейсе нет, поэтому
/// фоновая работа аккаунта там тоже не нужна: ни восстановления сессии при
/// старте, ни починки подписки при сбое обновления, ни чтения хранилища
/// сессии, ни запросов к шлюзу. Сохранённая сессия не удаляется — её просто
/// не читают.
///
/// Режим берётся на момент вызова из `appState.viewMode`. Сейчас
/// `utils.getViewMode` от ширины не зависит (всегда mobile), поэтому на старте,
/// когда размер окна ещё `Size.zero`, ответ уже верный и откладывать нечего.
/// Если раскладка снова станет зависеть от ширины, `restore()` придётся
/// повторять при смене режима: иначе планшет, увидевший mobile на нулевом
/// размере, так и не поднимет сессию. `Platform.isAndroid` проверяется первым:
/// на iOS и десктопе гейт всегда false и `globalState` не читается.
bool get accountPhoneBlocked =>
    debugAccountPhoneBlocked ??
    (Platform.isAndroid && globalState.appState.viewMode == ViewMode.mobile);

/// Фоновая работа аккаунта отключена: магазинная сборка или Android-телефон.
/// Гейт для restore / repair / onProfileUpdateFailed и создания контроллера.
/// Пункты интерфейса по-прежнему смотрят только на [accountStoreBlocked].
bool get accountBackgroundBlocked => accountStoreBlocked || accountPhoneBlocked;
