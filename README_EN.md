<div align="right">
  <a href="README.md">Русский</a>
</div>

<img src="assets/images/header.png" alt="dropweb, VPN client for Android Windows macOS with anti-detection" width="720" />

# dropweb

<a href="https://github.com/enkinvsh/dropweb/releases">
  <img src="https://img.shields.io/github/v/release/enkinvsh/dropweb?include_prereleases&style=for-the-badge&color=15803D&labelColor=0D1117&label=release" alt="Latest Release">
</a>
<a href="https://github.com/enkinvsh/dropweb/stargazers">
  <img src="https://img.shields.io/github/stars/enkinvsh/dropweb?style=for-the-badge&color=15803D&labelColor=0D1117" alt="GitHub Stars">
</a>

<br>

<a href="https://github.com/enkinvsh/dropweb/releases">
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android">
</a>
<a href="https://github.com/enkinvsh/dropweb/releases">
  <img src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows">
</a>
<a href="https://github.com/enkinvsh/dropweb/releases">
  <img src="https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS">
</a>

---

dropweb is a consumer VPN client for Android, Windows and macOS. It helps people connect to international services through connection profiles, keeps the everyday interface simple and reduces the risk of local VPN detection on the device.

## Features

- **VPN profiles and subscriptions:** import by URL and QR code
- **TUN routing:** split tunneling for direct and proxied traffic
- **Detection protection:** randomized local ports, SOCKS authentication, no system proxy
- **Everyday UI:** minimal interface without extra settings

---

## Detection Protection

Most popular apps (Happ, v2rayNG, Hiddify, Neko Box) are vulnerable to local scanning. Any app on the device can find the standard SOCKS port (7890) without root — this is actively used for VPN user detection.

**How dropweb solves this:**

- **Dynamic ports** — randomization instead of default 7890/7891
- **SOCKS authentication** — enforced, scanners can't verify traffic type
- **TUN only** — removed system proxy (readable from OS settings), all routing via virtual interface

## Support the project

- [Tribute](https://web.tribute.tg/d/Huc)

---

## License

GPL-3.0 — see [LICENSE](LICENSE).

**Community:** [Telegram discussion forum](https://t.me/+gnnahAxAtisxZmVi)

---

<sub>This tool is designed for personal traffic security and information access.<br>User assumes responsibility for compliance with local laws.</sub>
