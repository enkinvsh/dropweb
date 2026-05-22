<div align="right">
  <a href="README_EN.md">English</a>
</div>

<img src="assets/images/header.png" alt="dropweb, VPN-клиент для Android Windows macOS на базе mihomo Clash Meta" width="720" />

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

Dropweb: потребительский VPN-клиент для Android, Windows и macOS. Он помогает подключаться через профили mihomo, держит повседневный интерфейс простым и даёт пользователю понятный контроль над VPN-подключением.

Проект остаётся открытым GPL-3.0 форком [FlClashX](https://github.com/pluralplay/FlClashX), использует ядро [mihomo](https://github.com/MetaCubeX/mihomo) (Clash Meta) и сохраняет связь с оригинальным [FlClash](https://github.com/chen08209/FlClash). Атрибуция доступна в [NOTICE.md](NOTICE.md) и [ATTRIBUTIONS.md](ATTRIBUTIONS.md).

## Загрузка

- [Android](https://github.com/enkinvsh/dropweb/releases) — APK, 6.0+
- [Windows](https://github.com/enkinvsh/dropweb/releases) — Portable/Setup, 10+
- [macOS](https://github.com/enkinvsh/dropweb/releases) — DMG, 11+ (Intel и Apple Silicon)

### Source availability gate for direct APK releases

Direct APK download links must not be published until exact-version source links are live for the shipped APK. Release metadata should include `sourceUrl`, `sourceArchiveUrl`, `license`, and, when the APK depends on the served cabinet flow, `cabinetSourceUrl`.

## Фичи

- **Протоколы:** VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC, WireGuard (Xray-core совместимые)
- **Подписки:** Импорт по URL/QR, автообновление в фоне
- **Маршрутизация:** Split tunneling — локальный трафик напрямую, заблокированный через прокси (GeoIP/Geosite)
- **UI:** Максимально урезан, только базовые переключатели

---

## Почему форк

Dropweb делает мобильный VPN-клиент проще для повседневного использования:

1. Основной сценарий сосредоточен вокруг подключения и подписки.
2. Android-сборка использует TUN/VPN-подключение как основной режим работы.
3. Релизы публикуются вместе с исходным кодом соответствующей версии.

---

## Сборка из исходников

```bash
git clone https://github.com/enkinvsh/dropweb.git
cd dropweb
flutter pub get

# Android
dart run setup.dart android --arch arm64

# Windows  
dart run setup.dart windows

# macOS
dart run setup.dart macos
```

Требуется Flutter SDK 3.24+. Бинарники mihomo скачиваются автоматически.

---

## Known Issues

- **Android:** Агрессивное энергосбережение (MIUI, ColorOS) может убивать VPN в фоне. Отключите оптимизацию батареи для dropweb
- **macOS:** При первом запуске нужны права администратора для TUN-интерфейса
- **Старые устройства:** На Android с <3 ГБ ОЗУ возможны вылеты при тяжёлых GeoIP-базах

---

## Лицензия

GPL-3.0 — см. [LICENSE](LICENSE).

**Сообщество:** [Telegram-форум для обсуждений](https://t.me/+gnnahAxAtisxZmVi)

**Ссылки:** [FlClashX — родительский форк](https://github.com/pluralplay/FlClashX) · [FlClash — оригинал](https://github.com/chen08209/FlClash)

---

<sub>Инструмент создан для обеспечения безопасности личного трафика и доступа к информации.<br>Ответственность за использование несёт пользователь.</sub>
