import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

extension PackageInfoExtension on PackageInfo {
  // The "clash-verge" token is LOAD-BEARING and must stay: Remnawave (and
  // similar gateways) pick the subscription FORMAT from the User-Agent via
  // regexes anchored at the start of the string. A recognized clash-client UA
  // gets Mihomo/Clash YAML; an unknown UA (e.g. plain "dropweb/...") gets
  // base64/VLESS which the core can't parse ("provider does not support this
  // app"). To show "dropweb" as the client in the panel instead, the gateway's
  // Mihomo response-rule regex must be taught to match "^dropweb/" first; only
  // then can this token be dropped.
  String get ua => [
        "clash-verge/v$version",
        "dropweb/v$version",
        "Platform/${Platform.operatingSystem}",
      ].join(" ");
}
