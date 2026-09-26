# adb-пульт (debug remote)

Управление и инспекция приложения по adb без тапов по координатам: агент/разработчик шлёт broadcast, приложение выполняет команду **тем же кодом, что и UI**, и отвечает строкой в logcat.

## Гейты (все три обязательны)

1. **`android.permission.DUMP`** на ресивере (`DebugReceiver`, `AndroidManifest.xml`). DUMP есть только у shell (adb) и системы — сторонние приложения его получить не могут. Сама аппа DUMP не запрашивает.
2. **Не Play-сборка.** В сборке с `--dart-define=PLAY_BUILD=true` диспетчер отвечает `err disabled-in-play-build` и ничего не выполняет. Секция «adb-пульт» и «Тест краша» на экране разработчика в Play-сборке скрыты.
3. **Режим разработчика включён** (5 тапов по заголовку «Настройки» или по вкладке настроек). Иначе — `err developer-mode-off`.

UI-движок должен быть запущен (команды идут в Flutter main engine). Если не запущен, ресивер ставит команду в очередь (до 20) и пишет в logcat, как его запустить:

```sh
adb shell am start -n app.dropweb/app.dropweb.MainActivity
```

## Пакет и action

| Сборка | Пакет (`-p`) | Action (`-a`) |
|---|---|---|
| release / sideload | `app.dropweb` | `app.dropweb.DEBUG` |
| debug | `app.dropweb.debug` | `app.dropweb.debug.DEBUG` |

Ниже примеры для `app.dropweb`; для debug-сборки подставьте `app.dropweb.debug`.

## Ответы

```sh
adb logcat -s dropweb-dbg
```

Формат: `DBG[<id>] <cmd> ok <details>` / `DBG[<id>] <cmd> err <reason>`. `id` — необязательный extra, эхо в ответе (удобно сопоставлять запрос↔ответ). Весь текст проходит `redactUrls`; длинные ответы режутся на куски по 3500 символов с префиксом `[i/n] `. Также логируется `recv {...}` — полученные extras (значения длиннее 200 символов опускаются).

## Кавычки

`am broadcast` исполняется shell'ом **на устройстве**, поэтому имена с пробелами/эмодзи оборачивайте в одинарные кавычки ВНУТРИ двойных:

```sh
adb shell "am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd select --es group 'VPN' --es node 'Германия'"
```

Имена групп/нод резолвятся так: точное совпадение, иначе **уникальная** подстрока без учёта регистра. Неоднозначно → `err ambiguous ...` со списком до 10 кандидатов; не найдено → `err not-found ...`.

## Команды

```sh
# список команд
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd help

# состояние одной строкой JSON: running, workMode, staticCountry, fullTunnel,
# profile (без URL), lastUpdateDate, router (основная группа), developerMode,
# openLogs, logLevel/coreLogLevel, version, isPlayBuild, isDebug, groups{name: now}
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd status --es id 1

# подключить / отключить / переключить (как кнопка на дашборде; согласие на VPN
# должно быть уже принято в UI, иначе err vpn-consent-not-accepted; сразу после
# запуска start ждёт до 30 с, пока приложение загрузит конфиг в ядро, иначе
# err app-not-ready)
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd start
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd stop
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd toggle

# режим работы (как вкладка «Режимы»): standard | smart | country
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd mode --es value standard
# «Страна»: country = член основной группы (см. `groups group=<router из status>`)
adb shell "am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd mode --es value country --es country 'Германия'"
# стандарт с пином агрегатора внутри роутера (как тап по «Авто» в пикере страны)
adb shell "am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd mode --es value standard --es router 'Авто'"

# «Трафик»: весь (full) / по списку (list)
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd tunnel --es value full
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd tunnel --es value list

# выбрать ноду в группе (Selector; для url-test/fallback — пин, повторный выбор снимает пин)
adb shell "am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd select --es group 'VPN' --es node 'Германия'"

# группы: все (name [type] now members) или состав одной с последними задержками
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd groups
adb shell "am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd groups --es group 'VPN'"

# замер задержки членов группы (по умолчанию — основная группа), до 30 строк
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd ping
adb shell "am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd ping --es group 'VPN'"

# обновить подписку текущего профиля (как «Обновить подписку» в меню)
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd update

# дампы в файлы (ответ — путь); inline=1 — ещё и содержимое в logcat
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd diag
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd config --es inline 1
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd headers --es inline 1

# последние N записей in-app лога (по умолчанию 100, максимум 1000)
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd logs --es n 50

# журналирование: debug|info|error включают «Журналирование» + уровень ядра и
# зеркалируют строки ядра в dropweb-dbg (зеркало не сохраняется, живёт до off
# или перезапуска); off — выключает
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd loglevel --es value debug
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd loglevel --es value off

# навигация: имя PageLabel (dashboard, cabinet, tools, ...) или developer
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd nav --es page tools
adb shell am broadcast -p app.dropweb -a app.dropweb.DEBUG --es cmd nav --es page developer
```

## Файлы диагностики

Пишутся в app-specific external dir (adb-доступен без root):

```
/sdcard/Android/data/<пакет>/files/diag/
  diag-<yyyyMMdd-HHmmss>.txt   # хранятся последние 5
  diag-latest.txt
  config-latest.json           # итоговый конфиг ядра, redacted
  headers-latest.txt           # заголовки подписки, redacted
```

```sh
adb pull /sdcard/Android/data/app.dropweb/files/diag/ ./diag
```

Если external dir недоступен, файлы уходят в приватный app support dir — ответ это явно помечает.

Редакция: `uuid`, `password`, `private-key`, `public-key`, `short-id`, `pre-shared-key`, `auth*`, `obfs-password`, `psk`, `token`, `username`, `secret`, `authentication`, `certificate`, `private-key-passphrase` → `[REDACTED]` на любой глубине; `server` в `proxies` → стабильный хэш `srv-xxxxxx`; все URL → `redactUrls`. Имена, типы, порты, правила, группы, dns, sni/servername остаются.

## uiautomator

Ключевые контролы имеют стабильные `Semantics(identifier:)` → `resource-id` в `adb shell uiautomator dump`: `dw_connect`, `dw_nav_<pageLabel>`, `dw_mode_standard`, `dw_mode_country`, `dw_tunnel_list`, `dw_tunnel_full`, `dw_settings_title`, `dw_dev_diag`, `dw_dev_config`, `dw_dev_headers`, `dw_dev_adb`, `dw_dev_crash`, `dw_dev_clear`.
