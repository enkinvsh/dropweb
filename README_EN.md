<div align="right">
  <a href="README.md">Русский</a>
</div>

<img src="assets/images/header.png" alt="dropweb, VPN client for Android Windows macOS powered by mihomo Clash Meta" width="720" />

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

Dropweb is a consumer VPN client for Android, Windows and macOS. It helps users connect through mihomo profiles, keeps the everyday interface simple, and gives users clear control over the VPN connection.

Dropweb remains an open GPL-3.0 fork of [FlClashX](https://github.com/pluralplay/FlClashX), uses [mihomo](https://github.com/MetaCubeX/mihomo) (Clash Meta), and preserves attribution to the original [FlClash](https://github.com/chen08209/FlClash). Attribution is available in [NOTICE.md](NOTICE.md) and [ATTRIBUTIONS.md](ATTRIBUTIONS.md).

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

## Why this fork exists

Dropweb keeps the mobile VPN experience focused on everyday use:

1. The main flow centers on connection and subscription management.
2. The Android build uses TUN/VPN as the primary connection mode.
3. Releases are published with matching source code for the shipped version.

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
