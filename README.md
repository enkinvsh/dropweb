<div align="right">
  <a href="README_EN.md">English</a>
</div>

<img src="assets/images/header.png" alt="dropweb — приватный VPN-клиент для Android, Windows, macOS и Linux" width="720" />

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/images/wordmark-dark.png">
  <img src="assets/images/wordmark-light.png" alt="dropweb" height="46">
</picture>

<a href="https://github.com/enkinvsh/dropweb/releases">
  <img src="https://img.shields.io/github/v/release/enkinvsh/dropweb?include_prereleases&style=for-the-badge&color=15803D&labelColor=0D1117&label=release" alt="Последний релиз">
</a>
<a href="https://github.com/enkinvsh/dropweb/stargazers">
  <img src="https://img.shields.io/github/stars/enkinvsh/dropweb?style=for-the-badge&color=15803D&labelColor=0D1117" alt="GitHub Stars">
</a>
<a href="LICENSE">
  <img src="https://img.shields.io/badge/license-GPL--3.0-15803D?style=for-the-badge&labelColor=0D1117" alt="Лицензия GPL-3.0">
</a>

<br>

<a href="https://github.com/enkinvsh/dropweb/releases">
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Скачать для Android">
</a>
<a href="https://github.com/enkinvsh/dropweb/releases">
  <img src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Скачать для Windows">
</a>
<a href="https://github.com/enkinvsh/dropweb/releases">
  <img src="https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Скачать для macOS">
</a>
<a href="https://github.com/enkinvsh/dropweb/releases">
  <img src="https://img.shields.io/badge/Linux-1793D1?style=for-the-badge&logo=linux&logoColor=white" alt="Скачать для Linux">
</a>

---

**dropweb** — приватный VPN- и прокси-клиент для Android, Windows, macOS и Linux на ядре mihomo (Clash.Meta). Вы подключаете собственную конфигурацию; dropweb устанавливает соединение по ней и управляет маршрутизацией.

Команда dropweb придерживается принципов открытого кода, приватности по умолчанию и предсказуемого поведения на всех платформах. Журналы активности не ведутся; dropweb не предоставляет серверы и не вмешивается в трафик — конфигурации и ключи остаются на устройстве.

<table>
  <tr>
    <td><img src="docs/screenshots/connected.png" alt="Главный экран dropweb с активным подключением" width="240" /></td>
    <td><img src="docs/screenshots/modes.png" alt="Режимы работы и выбор страны" width="240" /></td>
    <td><img src="docs/screenshots/menu.png" alt="Меню аккаунта на дашборде" width="240" /></td>
  </tr>
</table>

---

## <img src="docs/icons/diff.svg" width="24" alt="" /> Ключевые отличия

### <img src="docs/icons/shield.svg" width="20" alt="" /> Защита от утечки на устройстве

Большинство клиентов держат открытый локальный прокси-порт, к которому может обратиться любое приложение на том же устройстве — это потенциальный канал утечки вашего IP. На мобильных платформах dropweb закрывает его по умолчанию: случайный порт при каждом запуске, обязательная аутентификация прокси и маршрутизация только через TUN-интерфейс без отдельных слушателей. Локальный прокси недоступен другим приложениям на устройстве.

### <img src="docs/icons/ai.svg" width="20" alt="" /> Интеллектуальный выбор маршрута

Режим **«Умный»** опирается на ML-модель ядра (LightGBM): она прогнозирует оптимальный узел по реальным метрикам соединения вместо постоянных контрольных пингов. Это снижает число фоновых опросов; выбор узла не требует ручной настройки.

### <img src="docs/icons/fingerprint.svg" width="20" alt="" /> Современные TLS-профили

dropweb формирует TLS-рукопожатие исходящих соединений по профилю актуального браузера, включая кастомные профили **Firefox 148** и **Safari 26** с пост-квантовым обменом ключами **X25519MLKEM768**. Таких профилей нет в апстрим-uTLS.

### <img src="docs/icons/puzzle.svg" width="20" alt="" /> Устойчивость соединения

Опциональная функция повышает надёжность TLS-соединений на нестабильных и перегруженных сетях, разбивая начало рукопожатия на сегменты. Включается одним тумблером и не требует настройки.

### <img src="docs/icons/flash.svg" width="20" alt="" /> Точный статус подключения

Индикатор становится активным только когда туннель установлен: ядро подтверждает готовность интерфейсу. Ложноположительное состояние «подключено» исключено — при сбое приложение возвращается в состояние «отключено».

---

## <img src="docs/icons/compare.svg" width="24" alt="" /> Сравнение

| Возможность | dropweb | GUI на mihomo/Clash | GUI на Xray/sing-box |
|---|:---:|:---:|:---:|
| Защита приватности на устройстве (изоляция локального прокси) | <img src="docs/icons/yes.svg" width="15" alt="да" /> по умолчанию | <img src="docs/icons/partial.svg" width="15" alt="частично" /> редко / опционально | <img src="docs/icons/partial.svg" width="15" alt="частично" /> редко |
| Устойчивость TLS-соединения (фрагментация ClientHello) | <img src="docs/icons/yes.svg" width="15" alt="да" /> | <img src="docs/icons/no.svg" width="15" alt="нет" /> | <img src="docs/icons/partial.svg" width="15" alt="частично" /> в ядре, обычно только через ручной JSON |
| Современные TLS-профили (Firefox 148 / Safari 26, пост-квант) | <img src="docs/icons/yes.svg" width="15" alt="да" /> | <img src="docs/icons/no.svg" width="15" alt="нет" /> только пресеты uTLS | <img src="docs/icons/partial.svg" width="15" alt="частично" /> часто несовместимо |
| Интеллектуальный выбор маршрута (ML, LightGBM) | <img src="docs/icons/yes.svg" width="15" alt="да" /> режим «Умный» | <img src="docs/icons/partial.svg" width="15" alt="частично" /> только через YAML | <img src="docs/icons/no.svg" width="15" alt="нет" /> |
| Режимы одним касанием (Стандарт / Умный / Страна) | <img src="docs/icons/yes.svg" width="15" alt="да" /> | <img src="docs/icons/no.svg" width="15" alt="нет" /> | <img src="docs/icons/no.svg" width="15" alt="нет" /> |
| Точный статус подключения (UI ждёт реального туннеля) | <img src="docs/icons/yes.svg" width="15" alt="да" /> | <img src="docs/icons/no.svg" width="15" alt="нет" /> | <img src="docs/icons/no.svg" width="15" alt="нет" /> |
| Android + Windows + macOS + Linux из одной кодовой базы | <img src="docs/icons/yes.svg" width="15" alt="да" /> | частично | редко |

<sub><img src="docs/icons/yes.svg" width="13" alt="" /> — есть из коробки · <img src="docs/icons/partial.svg" width="13" alt="" /> — частично / только вручную · <img src="docs/icons/no.svg" width="13" alt="" /> — нет. Сравнение по состоянию экосистемы на 2026 год; многие функции существуют в ядрах, но не вынесены в интерфейс клиента.</sub>

---

## <img src="docs/icons/features.svg" width="24" alt="" /> Возможности

**Подключение**
- Импорт подписок по URL и QR-коду, фоновое авто-обновление
- Режимы работы одним касанием: **Стандарт**, **Умный** (ML), **Страна** (весь трафик через выбранную страну)
- Каскадные маршруты и резервный пул узлов
- Протоколы ядра: VLESS (Reality / Vision / XHTTP), VMess, Trojan, Hysteria2, TUIC, ShadowTLS, AnyTLS, WireGuard
- Импорт конфигураций sing-box

**Приватность и безопасность**
- Изоляция локального прокси: случайный порт + аутентификация, маршрутизация только через TUN
- Современные TLS-профили с пост-квантовым обменом ключами
- Опциональная фрагментация TLS для устойчивости соединения
- Маршрутизация по правилам, geosite/geoip, split tunneling по приложениям
- Ядро mihomo (Clash.Meta) с актуальными исправлениями безопасности (DoS/OOB) из mihomo v1.19.27

**Интерфейс**
- Тёмная тема **Lumina**; рендеринг оптимизирован для устройств среднего класса
- Родной системный трей на Windows/Linux и статус-бар на macOS
- Независимая доставка обновлений

---

## <img src="docs/icons/efficiency.svg" width="24" alt="" /> Эффективность и надёжность

Потребление батареи и памяти снижено относительно типового клиента на ядре mihomo за счёт ряда специфических оптимизаций.

**Батарея и фон**
- Фоновые опросы прокси-групп останавливаются, когда приложение свёрнуто — пробуждения каждые 20 секунд устранены
- Рендеринг интерфейса приостанавливается в фоне
- Сеть обновляется только при включении экрана — меньше пробуждений радио и процессора
- Режим «Умный» не гоняет постоянные контрольные пинги по серверам
- Исключение из энергосбережения запрашивается контекстно — только после первого успешного подключения

**Память и стабильность**
- Ограничение Go-кучи (мягкий лимит 192 МБ + ранний сборщик мусора) — предсказуемый расход ОЗУ на среднем железе
- Защита ядра от паник: сбой в отдельной горутине не роняет VPN-процесс
- Кэш конфигурации — мгновенные переключения без переинициализации ядра
- Атомарная запись профилей и ленивая загрузка geodata

**Сборка для современного Android**
- 16-КБ выравнивание страниц памяти — совместимость с новыми устройствами и требованиями Google Play
- minSdk 24 и строгая (fail-closed) подпись релиза

---

## <img src="docs/icons/customize.svg" width="24" alt="" /> Кастомизация под провайдера

Оператор подписки задаёт оформление и поведение клиента через HTTP-заголовки ответа подписки — без отдельной сборки и форка. Один бинарник поддерживает брендинг нескольких провайдеров.

Через заголовки `dropweb-*` оператор может настроить:

- **Тему одной строкой** — акцентный цвет, два цвета фоновых орбов, фильтр цветовой схемы и размытость (`dropweb-theme`)
- **Логотип и название сервиса** на карточке подписки (`dropweb-logo`, `dropweb-servicename`)
- **Личный кабинет и управление подпиской** — ссылка на кабинет и контекстные действия (`dropweb-cabinet`)
- **Аварийный резервный пул** узлов на случай недоступности основных (`dropweb-disconeko`)
- **Объявления и метаданные** сервиса (`announce`, `support-url`)

Пользователь сохраняет контроль над оформлением: тумблеры **«Тема из подписки»** и **«Лого из подписки»** (по умолчанию включены) в любой момент возвращают вид по умолчанию; при выключенных тумблерах значения оператора не применяются.

---

## <img src="docs/icons/privacy.svg" width="24" alt="" /> Приватность

dropweb — клиент: серверную инфраструктуру приложение не предоставляет. Вы подключаете собственную конфигурацию (подписку), по которой устанавливается соединение. Вмешательство в трафик и реклама отсутствуют, журналы сетевой активности не ведутся. Конфигурации и ключи хранятся в защищённом хранилище на устройстве и не передаются.

---

## <img src="docs/icons/opensource.svg" width="24" alt="" /> Открытый код

dropweb распространяется под лицензией **GPL-3.0** — исходный код полностью открыт и доступен для аудита. Проект основан на FlClashX (форк FlClash) и использует ядро mihomo (Clash.Meta); мы благодарны их авторам и сообществу.

- FlClashX (© pluralplay) — https://github.com/pluralplay/FlClashX
- FlClash (© chen08209) — https://github.com/chen08209/FlClash
- mihomo / Clash.Meta (© MetaCubeX) — https://github.com/MetaCubeX/mihomo

---

## <img src="docs/icons/community.svg" width="24" alt="" /> Сообщество

- [Telegram-форум для обсуждений](https://t.me/+gnnahAxAtisxZmVi)

## <img src="docs/icons/license.svg" width="24" alt="" /> Лицензия

GPL-3.0 — см. [LICENSE](LICENSE).

---

<sub>dropweb — инструмент для приватности и безопасности личного трафика. Порядок использования определяется законодательством вашей страны; ответственность за использование несёт пользователь.</sub>
