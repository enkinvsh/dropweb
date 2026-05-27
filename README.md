<div align="right">
  <a href="README_EN.md">English</a>
</div>

<img src="assets/images/header.png" alt="dropweb, VPN-клиент для Android Windows macOS с защитой от детекции" width="720" />

# dropweb

<a href="https://github.com/enkinvsh/dropweb/releases">
  <img src="https://img.shields.io/github/v/release/enkinvsh/dropweb?include_prereleases&style=for-the-badge&color=15803D&labelColor=0D1117&label=release" alt="Latest Release">
</a>
<a href="https://github.com/enkinvsh/dropweb/stargazers">
  <img src="https://img.shields.io/github/stars/enkinvsh/dropweb?style=for-the-badge&color=15803D&labelColor=0D1117" alt="GitHub Stars">
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

---

dropweb — потребительский VPN-клиент для Android, Windows и macOS. Он помогает подключаться к зарубежным сервисам через профили подключения, держит повседневный интерфейс простым и снижает риск локальной детекции VPN на устройстве.

## Фичи

- **VPN-профили и подписки:** импорт по URL и QR-коду
- **TUN-маршрутизация:** split tunneling для прямого и проксируемого трафика
- **Защита от детекции:** рандомные локальные порты, SOCKS-аутентификация, без системного прокси
- **Повседневный UI:** минимальный интерфейс без лишних настроек

---

## Защита от детекции

Большинство популярных приложений (Happ, v2rayNG, Hiddify, Neko Box) уязвимы к локальному сканированию. Любое приложение на устройстве может найти стандартный SOCKS-порт (7890) без root-прав — это активно используется для [выявления VPN-пользователей](https://habr.com/ru/news/1020902/).

**Как dropweb решает проблему:**

- **Динамические порты** — рандомизация вместо дефолтных 7890/7891
- **SOCKS-аутентификация** — принудительно включена, сканеры не могут проверить тип трафика
- **Только TUN** — выпилен системный прокси (который читается из настроек ОС), весь роутинг через виртуальный интерфейс

## Поддержать проект

- [Tribute](https://web.tribute.tg/d/Huc)

---

## Лицензия

GPL-3.0 — см. [LICENSE](LICENSE).

**Сообщество:** [Telegram-форум для обсуждений](https://t.me/+gnnahAxAtisxZmVi)

---

<sub>Инструмент создан для обеспечения безопасности личного трафика и доступа к информации.<br>Ответственность за использование несёт пользователь.</sub>
