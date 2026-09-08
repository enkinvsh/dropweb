# Улики с устройства: чекпоинт W1 (dropweb-app)

**Стенд:** Pixel 10 `56131FDCR00APV`, Android 16, сборка `app.dropweb.debug` из `dev` @ `bba1267` (волны 0+1). Тестовая подписка, 19 узлов. 2026-09-08, 21:17-21:30.

| Пункт | Шаги | Наблюдение | Вердикт |
|---|---|---|---|
| V2 | Wi-Fi→LTE и обратно под живым туннелем | `[isolate] networkChanged isService=true` → `BEARER_CHANGE … resetting DNS pools` → `[isolate-violation] Null check operator used on a null value`. Стек: `ClashCore._internal (core.dart:23)` ← `clashCore (core.dart:340)` ← `vpn.dart:85`. Воспроизведено дважды (21:21:26, 21:21:44) | ПОДТВЕРЖДЁН, корень найден |
| R5 | переходы runTime при подключении | замер 1: `[ack] armed` 21:19:10.007 → `complete` .100 → `[runtime] null -> set` .101 = **94 мс**; замер 2: 21:27:37.689 → .38.709 → .710 = **1021 мс**. Допуск 0..2000 | В НОРМЕ |
| V6 | connect → stop → connect, те же параметры | 2-я сессия: `NotificationRecord pkg=app.dropweb.debug id=1 channel=dropweb FOREGROUND_SERVICE`, `isForeground=true foregroundId=1`. Уведомление на месте | НЕ ВОСПРОИЗВЁЛСЯ (через UI приложения; путь через плитку не проверен) |
| V7 | пикер «Страна» на живой подписке | 242 строки DELAY_DIAG, **0 `EMPTY_KEY!`**, 0 записей под пустым url/name. Все 7 видимых бейджей заполнены: 125 / n/a / 108 / 101 / 109 / 361 / 272 ms | НЕ ВОСПРОИЗВЁЛСЯ |
| V1 | тап QS-плитки при живом туннеле | не снят | БЛОКИРОВАН: плитки debug-сборки нет в шторке |
| A4 | cold boot → плитка первой | не снят | БЛОКИРОВАН: та же причина |
| A5 | режим полёта + плитка | не снят | БЛОКИРОВАН: та же причина |

## V2: корень

`lib/clash/lib.dart:399-403` объявляет два взаимоисключающих геттера:
```dart
ClashLib?        get clashLib        => Platform.isAndroid && !globalState.isService ? ClashLib() : null;
ClashLibHandler? get clashLibHandler => Platform.isAndroid &&  globalState.isService ? ClashLibHandler() : null;
```
В сервисном изоляте `clashLib` null всегда. `networkChanged` трогает `clashCore`, конструктор `ClashCore._internal()` делает `clashInterface = clashLib!` (`core.dart:23`) и падает. Сброс DNS обрывается сразу после лога «resetting DNS pools», то есть не выполняется. Research предсказал это верно. Чинится в волне 4.

## Поправки, добытые замером

1. Гипотеза research по V7 не подтвердилась: механизм «Go-ядро не отдаёт url/name → запись под `""`» не сработал ни разу (0 из 242). Вместо него: раскол ключа. Карта задержек ключуется парой `(testUrl, name)`, один узел пишется под двумя URL: под объявленным группой (`urlFrom=cardState`, `cp.cloudflare.com`) и под глобальным фолбэком (`declaredUrl=<null>`, `urlFrom=fallback`, `www.gstatic.com`). Пример: «🇳🇱 Нидерланды» пишется и читается под обоими. Сейчас безвредно: пишутся оба, читаются оба. Латентно даёт ровно пустой бейдж, если заполнена одна сторона. Увидено только потому, что задача 1.6 логирует `declaredUrl`/`fallbackUrl`/`urlFrom`/`resolvedFrom` сверх однострочного требования плана.
2. Поле `clashLibHandler` в `[isolate]`-логе бесполезно: тождественно равно `isService`, на пути отказа печатает `true` и выглядит здоровым. Исходное `clashLibReady=${!isService}` из плана было семантически верным. Правка отдельным коммитом.
3. Диагноз V2 дали не поля, а стек: try/catch со `$st` (задача 1.1) плюс задача 1.5, вернувшая настоящие обработчики ошибок. Без 1.5 стека бы не было.

## Что мешает закрыть чекпоинт

V1/A4/A5 требуют QS-плитку debug-сборки. Программные пути закрыты правильно и ослаблять их нельзя: `TempActivity` `exported=false` (в манифесте комментарий SECURITY), виджет под `BIND_APPWIDGET`, `TileService.onClick` зовёт `GlobalState.handleStart()` напрямую. `settings put secure sysui_qs_tiles` на Android 16 игнорируется: SystemUI переехал на собственное хранилище. Нужна ручная операция владельца: шторка → «Изменить» → перетащить вторую плитку dropweb.

## Операционные уроки

- `dumpsys notification_manager`: несуществующий сервис, молча даёт пустой вывод; на нём едва не был выписан ложный вердикт «V6 подтверждён». Правильный вызов: `dumpsys notification --noredact`.
- Слепой `adb shell input tap` опасен: `KEYCODE_BACK` свернул приложение, и тапы ушли в чужое приложение на переднем плане. Перед каждым вводом проверять `topResumedActivity`.
- Тестовый токен подписки (16 символов) редактор из задачи 1.4 съедает корректно: проверено на живом URL, 6 сценариев, без утечки.
