# Стабилизация первого старта (desktop/Windows): «Что-то пошло не так» + мёртвое ядро до рестарта

**Дата:** 2026-07-19 · **Ветка:** dev · **Статус:** исполнен (W0-W3, код в рабочем дереве, БЕЗ коммита; W4 отложен до полевых логов; VM-QA и Android-smoke — за владельцем)
**Авторы анализа:** Sisyphus + oracle gpt-5.6-sol (21 мин, Q1-Q4) + 2×explore + librarian (upstream pluralplay/FlClashX)

---

## §0. Симптом и рамки

Владелец: на **первом запуске** (Windows desktop) приложение иногда «ломается» — диалог
«Подсказка / Что-то пошло не так. Попробуйте ещё раз.» (скриншот: SubscriptionPage, карточки
режимов видны ⇒ профиль СУЩЕСТВУЕТ; статус «Остановлено»). **Перезапуск приложения лечит.**
Второй запрос владельца: на error-диалогах вместо «Отмена» — кнопка **«Скопировать логи»**,
чтобы юзер мог переслать логи в личку.

Рамки (sponge-app, без хардкодов):
- НИКАКОЙ провайдер-специфики: все фиксы применимы к любому Remnawave-провайдеру.
- Android (FFI-путь) НЕ трогаем поведенчески — там всё работает; readiness-гейт на Android = no-op.
- Дизайн-система: только существующие атомы/токены (CommonDialog, Lumina), новых визуальных систем нет.

## §1. Root-cause модель (доказано по коду, file:line)

Три независимых класса отказов, вместе дающие «сломано до рестарта»:

### R1. Скриншотный диалог = синхронный exception в пост-импортных шагах, НЕ таймаут ядра
- Диалог УНИКАЛЬНО производится `controller.dart:1519` (catch в `addProfileFormURL`):
  default title=`tip`(«Подсказка») + default `cancelable:true`(«Отмена»+«Подтвердить»).
  Все остальные error-диалоги: title=«Ошибка» и/или `cancelable:false`.
- Ошибки скачивания/валидации подписки ловит `CommonScaffoldState.loadingRun`
  (`controller.dart:1477-1493` → `widgets/scaffold.dart:167-203`) со СВОИМ диалогом — до 1519 не доходят.
- До 1519 доходят только синхронные шаги ПОСЛЕ скачивания:
  `_applyAllHeaderSettings` → `_applyCustomViewSettings` (без try/catch, `profile_service.dart:113-116`, `:529-633`),
  `_handleHwidHeaders` (`controller.dart:356-383`), `ProfileService.addProfile` (`:40-51`).
- **Ведущий кандидат (oracle, medium confidence): реентерабельность Riverpod-листенеров при
  частично закоммиченном addProfile.** `addProfile` пишет `profilesProvider`, затем
  `currentProfileIdProvider` → `needSetupProvider` → листенер `_ClashContainerState`
  (`manager/clash_manager.dart:30`) СИНХРОННО зовёт `handleChangeProfile()` (`controller.dart:899`)
  посреди импорта: `_resetSubscriptionTheme()`, ПОВТОРНЫЙ `_applyAllHeaderSettings`,
  `initForegroundCache()`, записи в logs/requests-провайдеры — всё без guard. Sync-исключение
  оттуда пробрасывается через присваивание `currentProfileIdProvider.notifier.value` в outer catch —
  профиль при этом УЖЕ виден (точное совпадение со скриншотом).
- Импорт-путь реентерабелен и трижды применяет одно и то же: header-apply ДО addProfile,
  header-apply в handleChangeProfile, плюс неотслеживаемый `applyProfileDebounce`.
- **Решающая улика ещё не собрана:** строка `[dropweb] Add Profile Failed: <exception>` в файл-логе
  (сейчас логируется только `$err`, без stack trace). ⇒ Wave 0 обязателен ДО архитектурных правок.

### R2. «Мёртвое ядро до рестарта» = гонка инсталлятора + отсутствие watchdog никогда-не-подключившегося ядра (60-75% полевых кейсов)
Цепочка одна, не два независимых фактора:
- Инсталлятор: создаёт+стартует DropwebHelperService, ждёт RUNNING ≤15s НЕ-фатально, сразу
  запускает app (`inno_setup.iss:192-217`). App даёт «существующему, но не готовому» сервису
  всего 5s grace (`clash/service.dart:204-213`) → молча падает в direct-spawn.
- Helper `POST /start` (timeout 2s) «успех» = только `spawn()` — НЕ коннект ядра к бриджу
  (`request.dart:351-376`, `service.dart:147-156`). Ядро при неудачном dial делает exit(1)
  (`core/server.go:41-50`). Для helper-spawned ядра: нет Process handle, нет сокета ⇒
  `_onCoreDeath` НИКОГДА не сработает ⇒ `socketCompleter` вечно pending ⇒ `sendMessage` ждёт
  вечно, каждый invoke умирает по своему таймауту (validateConfig 30s fail-closed, setup 2min).
- Direct-spawn `Process.start` throw (AV-карантин/нет exe) = unhandled async error из
  конструктора (`service.dart:18-21`, `:167-173` — reStart вне runZonedGuarded), невидим, без retry.
- Self-heal (`connect_service.dart:159-188`): 1 рестарт / 5 мин, ТОЛЬКО по наблюдённой смерти
  (process-exit / socket-close) — для «никогда не подключился» не срабатывает.
- Почему рестарт лечит: второй запуск «тёплый» — Defender уже просканировал exe, сервис
  зарегистрирован и отвечает, файловая система устаканилась.
- Upstream-сверка (librarian): FlClashX имеет ту же дыру helper /start, но crash-recovery =
  5 ретраев с backoff 1/2/4/8/16s (у нас 1/5мин); их фикс гонки первого коннекта 4c6f33a к нам
  не применим (мы не флашим completers). Направление фикса — явный coreReady + watchdog.

### R3. Тихие no-op пути: «импортировано, но не применено» без единого диалога (20-30%)
- `addProfileFormURL` молча return при unmounted scaffold (`controller.dart:1473-1475`).
- `_applyProfile` зовёт публичный `setupClashConfig()` со scaffold-гейтом — молчаливый return
  (`controller.dart:587-605`, `:874-895`); `updateClashConfig` аналогично (`:558-566`).
- `addProfile` планирует `applyProfileDebounce` НЕ awaited (`profile_service.dart:50`) ⇒ профиль
  сохранён/выбран, а конфиг в ядро не применён (или упал в чужом error-surface) — app «сломан
  до рестарта» БЕЗ диалога (рестарт чинит: `_initCore → applyProfile`).

### R-минус (исключено)
- Firewall/loopback — не причина (бридж строго 127.0.0.1, ядро = исходящий connect).
- Тема/звук/хаптика — обёрнуты catch/unawaited, до 1519 не доходят.
- `_handleHwidHeaders` — очень низкая вероятность (нужны редкие заголовки, всё null-safe/unawaited).
- ErrorMapper: наши же fail-closed строки («core did not answer», «core call timed out») НЕ
  матчатся ни одним паттерном (`error_mapper.dart`) ⇒ юзер видит generic вместо actionable.

## §2. Wave 0 — диагностика + error-UX с «Скопировать логи» (SHIP FIRST, low-risk)

Цель: полевые улики ДО архитектурных правок + немедленный саппорт-канал. Только Dart, кроссплатформенно.

W0.1 Phase-tagged boot journal через существующий `commonPrint.log` (файл-лог уже есть:
`<appSupport>/logs/dropweb_YYYY-MM-DD[_N].log`, редактируется `redactUrls`, ротация 7 дней):
- Маркеры: `[boot] bridge-bind`, `helper-check`, `helper-start-accepted`, `direct-spawn`,
  `connect-back`, `core-init`, `[import] validate`, `profile-commit`, `profile-apply` —
  в `clash/service.dart` (_initServer/_reStart/_helperReadyWithGrace), `controller.dart`
  (_initCore, addProfileFormURL), `profile_service.dart` (addProfile).
- Outer catch `addProfileFormURL` (`controller.dart:1514`): логировать `err` + `stackTrace`
  (второй аргумент catch) — сейчас теряем стек, из-за этого R1 не закрыт точно.

W0.2 `GlobalState.showErrorMessage` — НОВЫЙ метод рядом с `showMessage` (`state.dart:396`),
`CommonDialog` НЕ трогаем, ~40 confirm-вызовов не мигрируем:
```dart
Future<void> showErrorMessage({String? title, required InlineSpan message, String? diagnosticPhase});
```
- Ровно 2 действия: **«Скопировать логи»** (собирает bundle → clipboard, диалог НЕ закрывает,
  notifier «Логи скопированы») и **«Ок»** (закрыть). Title default = `errorTitle` («Ошибка»).
- Мигрируемые call-sites (только настоящие error-surfaces):
  `scaffold.dart:194` (loadingRun), `state.dart:469` (safeRun silence:false),
  `controller.dart:1519` (outer import catch — уходит и default-«Подсказка»),
  `profiles_content.dart:49,83`, `resources.dart:259,272`.
- l10n: ключи `copyLogs` («Скопировать логи»/"Copy logs"), `logsCopied` («Логи скопированы»/
  "Logs copied") в 4 arb (ru/en/ja/zh_CN) + `flutter gen-l10n`/build_runner по конвенции.

W0.3 `FileLogger.buildSupportBundle()` (сбор — в file_logger/диагностик-сервис, НЕ в state.dart):
- Формат: заголовок `dropweb diagnostics / timestamp / app version / OS / phase:` + `---- file
  tail ----` + `---- in-app tail ----`.
- Хвост по ВСЕМ сегментам сегодняшнего дня `dropweb_YYYY-MM-DD[_N].log` (не только базовому);
  перед чтением flush, СЕРИАЛИЗОВАТЬ снапшот против `_processQueue` (текущий `flushPendingLogs`
  fire-and-forget — недостаточен); повторно прогнать `redactUrls` по итоговому тексту (defense in depth).
- Размер: **32 KiB total** (≈24 KiB файл-хвост + ≈8 KiB in-app буфер `logsProvider`), резать по
  целым UTF-8 строкам. (Clipboard Windows тянет мегабайты — лимит диктует Telegram ~4096 симв/
  сообщение; 32K = несколько фаз старта, ок для DM. Полные логи остаются в Export Logs.)

W0.4 ErrorMapper: добавить паттерны для наших fail-closed строк (`core did not answer`,
`core call timed out`) → RU/EN actionable: «VPN-ядро не отвечает. Перезапустите приложение.» /
"VPN core is not responding. Restart the app." — юзер получает понятный шаг вместо generic.

## §3. Wave 1A — helper ownership (пререквизит watchdog, short)

До ЛЮБЫХ деструктивных `/stop`/restart: валидировать, что SCM-сервис наш —
`sc qc DropwebHelperService` binPath указывает в наш `{app}` (сейчас `checkService`
(`windows.dart:369-384`) принимает любой ответ как presence; ownership-проверка есть только в
conflict-resolution `:276-298` — переиспользовать её). Чужой владелец порта 47896 ⇒ специфичная
ошибка «конфликт helper-сервиса», НЕ убивать неизвестный сервис. Без этого Wave 1B-watchdog
станет чаще стрелять деструктивными вызовами по чужим процессам.

## §4. Wave 1B — generation-scoped readiness + watchdog никогда-не-подключившегося ядра (medium)

Desktop-only (`lib/clash/service.dart` + узкая обвязка в controller/connect_service). Android FFI не входит.

- НЕ одноразовый глобальный Future (протухнет после crash/restart) — **generation-scoped**
  state machine: `idle → binding → spawning → waitingForConnect → initializing → ready | failed`.
  Каждый reStart = новое поколение/completer; таймеры, exit- и socket-close-колбэки несут
  generation ID (stale колбэк не валит текущую попытку).
- `ready` = bind ✓ + spawn принят ✓ + connect-back ✓ + **строгий** init/health roundtrip ✓.
  Существующий fail-open `init/isInit` НЕ переиспользовать как readiness — strict-обёртка,
  таймаут которой кидает типизированный `CoreBootException(phase)`.
- Watchdog: после spawn — дедлайн connect-back **15-20s**; по истечении: лог фазы → stop
  verified-helper-child / kill direct-process → сброс socket-generation → retry с backoff
  **1/2/4s (2-3 попытки)** → после исчерпания `failed` с phase-tagged ошибкой (через
  showErrorMessage из W0). Покрывает оба края R2: helper-spawned-never-connected И
  `Process.start` throw (типизированный catch: path, OS error code, phase).
- Риск «двух ядер»: перед respawn — await stop/kill + сброс socket state (protocol nonce НЕ
  вводим, пока логи не докажут stale cross-attempt коннекты).
- Direct-fallback после появления verified-helper: предпочитать восстановление helper, а не
  молчаливый непривилегированный direct-spawn (TUN потом сломан).

## §5. Wave 2 — транзакционный импорт + отслеживаемое применение (medium)

- Перед `Profile.update`: await readiness (Wave 1B) с bounded UI-состоянием («Запускаем
  VPN-ядро…», существующий loading-механизм); на Android — немедленный no-op. Исчерпан
  watchdog ⇒ специфичная ошибка, НИКОГДА не вечное ожидание.
- Один явный транзакционный порядок вместо реентерабельного:
  1) download+validate; 2) commit профиля+selection БЕЗ запуска листенер-apply посреди операции
  (узкий `profileCommitInProgress`-флаг вокруг двух provider-записей, `try/finally`, без
  глобального event-bus); 3) header-settings изолированными фазами; 4) ОДИН явный awaited
  `applyProfile`; 5) success-репорт только после известного исхода apply.
- Точечные фиксы:
  - `_applyProfile` → звать `_setupClashConfig` напрямую, минуя scaffold-гейтнутый публичный
    `setupClashConfig` (R3);
  - `applyProfileDebounce` НЕ использовать для завершения импорта (debounce — для UI-чёрна);
  - `_applyCustomViewSettings` и `_handleHwidHeaders` — независимые try/catch с phase-логами:
    их падение НЕ валит и НЕ откатывает валидный импорт (best-effort косметика), но commit/apply
    остаются авторитетными и видимыми при падении;
  - unmounted-scaffold return'ы → bounded ожидание UI-готовности или прямой не-overlay путь;
    по таймауту — явная ошибка `ui-not-ready`, не молчание;
  - provider-листенеры (`_ClashContainerState`) — guarded async, чтобы исключение не
    пробрасывалось назад в присваивание провайдера (R1).

## §6. Wave 3 — инсталлятор (short-medium)

`inno_setup.iss`: перед запуском app ждать verified helper `/ping` (хэш-токен), не только SCM
RUNNING; ожидание bounded — по истечении app всё равно запускается (финальный авторитет —
app-side watchdog Wave 1B). Инсталлятор не может доказать connect-back будущего ядра ⇒ W3
повышает вероятность удачного первого старта, но НЕ заменяет Wave 1B.

## §7. Wave 4 — снятие лесов (quick, после полевого подтверждения)

Когда логи (W0-журнал) подтвердят стабильный readiness и one-apply импорт — убрать устаревшие
grace/fallback-ветки, чтобы не поддерживать две конкурирующие стартовые стратегии.

## §8. QA per wave: инструмент → шаги → ожидаемый результат

Общие команды (build-машина: fvm Flutter 3.41.6, см. `recall "dropweb_build_machine"`):
- Статика: `dart analyze` (или flutter_analyze MCP) → **0 errors** (baseline warnings/infos не считаем).
- Юнит-тесты: `fvm flutter test <путь>`; существующий suite: `fvm flutter test test/common test/clash` → все зелёные (baseline 242+).
- Файл-лог для проверок: `<appSupport>/logs/dropweb_YYYY-MM-DD.log` (macOS: `~/Library/Application Support/dropweb/logs/`; Windows: `%APPDATA%`-эквивалент от `getApplicationSupportDirectory()`).

### W0 QA
1. `dart analyze` → 0 errors.
2. НОВЫЕ тесты: `fvm flutter test test/common/support_bundle_test.dart test/common/error_mapper_test.dart` →
   зелёные. Покрытие: bundle ≤32 KiB; резка по целым UTF-8 строкам; `redactUrls` применён к итогу
   (вставить URL с токеном в лог → в bundle `[REDACTED]`); хвост собирается по сегментам `_N`;
   ErrorMapper мапит `"error: core did not answer (timeout) — config not validated"` и
   `"error: core call timed out (setupConfig)"` в RU/EN «перезапустите приложение»-тексты.
3. Manual desktop (можно macOS — UI кроссплатформенный): запустить app; вызвать error-диалог
   (импорт валидного URL при убитом ядре: переименовать бинарь ядра перед запуском) →
   диалог = title «Ошибка», кнопки «Скопировать логи» + «Ок» (НЕ «Отмена/Подтвердить»);
   тап «Скопировать логи» → диалог ОСТАЛСЯ открыт, notifier «Логи скопированы», в буфере обмена
   текст, начинающийся `dropweb diagnostics` с `phase:` и двумя секциями хвостов; «Ок» закрывает.
4. Boot-журнал: нормальный старт → `grep "\[boot\]" <лог-файл>` показывает последовательность
   `bridge-bind → (helper-check|direct-spawn) → connect-back → core-init`; импорт →
   `grep "\[import\]"` показывает `validate → profile-commit → profile-apply`.
5. Outer catch: спровоцировать ошибку импорта → лог содержит `Add Profile Failed:` + stack trace (≥3 фрейма).
6. Regression: `fvm flutter test test/common test/clash` → без новых падений; confirm-диалоги
   (напр. внешняя ссылка из настроек) по-прежнему «Отмена/Подтвердить».

### W1A QA
1. НОВЫЙ тест: `fvm flutter test test/clash/helper_ownership_test.dart` → зелёный. Покрытие:
   mock `sc qc` вывод с нашим binPath (`{app}\DropwebHelperService.exe`) → ownership OK;
   чужой binPath (`C:\Other\foo.exe`) → ownership-ошибка, НОЛЬ вызовов `/stop`.
2. Windows VM: `sc create DropwebHelperService binPath= "C:\Other\foo.exe"` (фейк) → запуск app →
   лог `[boot] helper-check` фиксирует конфликт со специфичной ошибкой; app продолжает через
   direct-spawn; фейковый сервис НЕ остановлен/не удалён (`sc query` до/после идентичен).

### W1B QA
1. НОВЫЕ тесты: `fvm flutter test test/clash/core_readiness_test.dart` → зелёные. Покрытие =
   unit-случаи 1-5: no-connect → 2-3 retry (backoff 1/2/4s, ускоренный fake-clock) →
   `CoreBootException(phase: connectBack)`; поколение N-1 колбэки не влияют на N; `Process.start`
   throw → типизированная spawn-ошибка без unhandled zone error; strict-init-fail → retry от
   `initializing`, `ready` не выставлен; после исчерпания — `failed` ровно один раз.
2. Windows VM, сценарий «никогда не подключился»: переименовать `DropwebCore.exe` → запуск app →
   ≤~40s появляется диалог с фазой (`spawn`/`connect-back`) и кнопкой «Скопировать логи»;
   в логе 2-3 строки `[boot] connect-back timeout gen=1 attempt=K` с нарастающим backoff.
3. VM, сценарий «медленный первый старт»: обёртка-скрипт вместо ядра со sleep 25s перед exec
   настоящего → первая попытка истекает, вторая успешна → статус ready, Connect работает,
   в логе `gen=1 attempt=2 connect-back ok`.
4. VM, generation-recovery: при подключённом ядре `taskkill /F /IM DropwebCore.exe` → лог
   показывает новое поколение, реконнект; повторный Connect работает без рестарта app.

### W2 QA
1. НОВЫЕ тесты: `fvm flutter test test/services/profile_import_transaction_test.dart` → зелёные.
   Покрытие = unit-случаи 6-9: импорт ждёт readiness; commit один раз; apply один раз и awaited;
   success только после apply; падение `_applyCustomViewSettings`/HWID → фаза в логе, профиль
   цел, apply выполнен; падение commit/apply → нет success-cue, специфичный диалог;
   unmounted scaffold → `ui-not-ready` ошибка, не silent return.
2. Desktop manual, мёртвое ядро (бинарь переименован): импорт валидного URL → UI «Запускаем
   VPN-ядро…» → по исчерпании watchdog специфичная ошибка (НЕ generic «Что-то пошло не так»);
   состояние консистентно: либо профиля нет, либо профиль есть И ошибка apply показана.
3. Desktop manual, живое ядро: импорт → `grep -c "\[import\] profile-apply" <лог>` = **1** на
   один импорт (дубликаты header-apply/debounce устранены); success-notifier после apply.
4. Android regression (Pixel 10, flutter-dev MCP): fresh install (`flutter_app_restart
   clear_data=True`) → импорт подписки → скорость/поведение не изменились (readiness-гейт no-op),
   `flutter_screenshot` дашборда после импорта — профиль применён, Connect активен.

### W3 QA
1. Windows VM, чистый образ: собрать инсталлятор → установка → installer-лог содержит ожидание
   verified `/ping` (не только SCM RUNNING) → app запускается → НЕМЕДЛЕННЫЙ импорт подписки
   на первом старте успешен (основной полевой сценарий R2).
2. Негатив: остановить/заблокировать helper-сервис до конца установки → инсталлятор всё равно
   завершает установку за bounded время (без вечного ожидания) → app запускается → watchdog
   W1B отрабатывает деградацию с диалогом.

### W4 QA
1. Diff-review: каждая удаляемая grace/fallback-ветка перечислена в описании коммита;
   `rg "<удалённый идентификатор>" lib/` → 0 вхождений для каждого.
2. Повторить: W1B-VM сценарии 2-4 + W2 desktop 2-3 + Android smoke (W2.4) → все зелёные БЕЗ
   удалённых веток (доказательство, что старт/retry/recovery не опирались на снятые леса).

### Final Verification Wave (перед закрытием плана)
1. `dart analyze` → 0 errors.
2. `fvm flutter test test/common test/clash test/services` → все зелёные.
3. Полный VM-прогон: W1A.2, W1B.2-4, W2.2-3, W3.1-2 за одну сессию на чистом снапшоте.
4. Android on-device: W2.4.
5. Owner-визирование текстов ошибок (RU) и содержимого «Скопировать логи» по реальному bundle.

## §9. Порядок исполнения и оценка

W0 (short) → W1A (short) → W1B (medium) → W2 (medium) → W3 (short) → W4 (quick).
Суммарно ≈3-5 инж-дней + Windows VM. W0 шипается отдельно и немедленно даёт: (а) решающую улику
по R1 (`Add Profile Failed` + stack), (б) кнопку «Скопировать логи» владельцу, (в) actionable
тексты вместо generic. Решение о деталях R1-фикса в W2 уточняется по первым полевым логам W0 —
план это допускает без пересмотра архитектуры.

Конвенции: не коммитить без команды владельца; generated-код только через build_runner/gen-l10n;
`.omo/plans/` копия синхронизируется с канонической `docs/plans/` при правках.
