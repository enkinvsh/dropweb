<div align="right">
  <a href="README.md">Русский</a>
</div>

<img src="assets/images/header.png" alt="dropweb — VPN client for Android Windows macOS powered by mihomo Clash Meta with anti-detection" width="720" />

# dropweb

<a href="https://github.com/enkinvsh/dropweb/releases">
  <img src="https://img.shields.io/github/v/release/enkinvsh/dropweb?include_prereleases&style=for-the-badge&color=15803D&labelColor=0D1117&label=release" alt="Latest Release">
</a>
<a href="https://github.com/enkinvsh/dropweb/stargazers">
  <img src="https://img.shields.io/github/stars/enkinvsh/dropweb?style=for-the-badge&color=15803D&labelColor=0D1117" alt="GitHub Stars">
</a>

<br>

<a href="https://github.com/enkinvsh/dropweb/releases">
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Download for Android">
</a>
<a href="https://github.com/enkinvsh/dropweb/releases">
  <img src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Download for Windows">
</a>
<a href="https://github.com/enkinvsh/dropweb/releases">
  <img src="https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Download for macOS">
</a>

---

Dropweb is a consumer VPN client for Android, Windows, and macOS. It helps people import VPN subscriptions, connect and disconnect without extra setup, and reduce the risk of local VPN detection on the device.

The project remains an open-source GPL-3.0 fork of [FlClashX](https://github.com/pluralplay/FlClashX), powered by [mihomo](https://github.com/MetaCubeX/mihomo) (Clash Meta), with lineage to the original [FlClash](https://github.com/chen08209/FlClash). Attribution and source access stay visible in the build and license sections below.

## Download

- [Android](https://github.com/enkinvsh/dropweb/releases) — APK, 6.0+
- [Windows](https://github.com/enkinvsh/dropweb/releases) — Portable/Setup, 10+
- [macOS](https://github.com/enkinvsh/dropweb/releases) — DMG, 11+ (Intel and Apple Silicon)

## Features

- **Protocols:** VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC, WireGuard (Xray-core compatible)
- **Subscriptions:** Import via URL/QR, auto-update in background
- **Routing:** Split tunneling — local traffic direct, blocked through proxy (GeoIP/Geosite)
- **UI:** Stripped down to essentials, only necessary controls

---

## Why Fork and Detection Protection

FlClashX is an excellent client, but most popular apps (Happ, v2rayNG, Hiddify, Neko Box) are vulnerable to local scanning. Any app on the device can find the standard SOCKS port (7890) without root — this is actively used for VPN user detection.

**How dropweb solves this:**

- **Dynamic ports** — randomization instead of default 7890/7891
- **SOCKS authentication** — enforced, scanners can't verify traffic type
- **TUN only** — removed system proxy (readable from OS settings), all routing via virtual interface

---

## Build from Source

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

Requires Flutter SDK 3.24+. Mihomo binaries are downloaded automatically.

---

## Known Issues

- **Android:** Aggressive battery optimization (MIUI, ColorOS) may kill VPN in background. Disable battery optimization for dropweb
- **macOS:** First launch requires admin rights for TUN interface
- **Old devices:** Android with <3GB RAM may crash with heavy GeoIP databases

---

## License

GPL-3.0 — see [LICENSE](LICENSE).

**Community:** [Telegram discussion forum](https://t.me/+gnnahAxAtisxZmVi)

**Links:** [FlClashX — parent fork](https://github.com/pluralplay/FlClashX) · [FlClash — original](https://github.com/chen08209/FlClash)

---

<sub>This tool is designed for personal traffic security and information access.<br>User assumes responsibility for compliance with local laws.</sub>
