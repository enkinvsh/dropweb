#!/bin/bash
# DEV ONLY: fake-sign an unsigned Runner.app and install it on a jailbroken
# device with AppSync Unified. Usage: ios/scripts/fakesign.sh [path/to/Runner.app]
set -euo pipefail
APP=${1:-build/ios/iphoneos/Runner.app}
ENT="$(cd "$(dirname "$0")" && pwd)/fakesign"
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
command -v ldid >/dev/null || { echo "ldid missing: brew install ldid" >&2; exit 1; }
mkdir -p "$OUT/Payload" && cp -R "$APP" "$OUT/Payload/"
APP="$OUT/Payload/$(basename "$APP")"
for fw in "$APP"/Frameworks/*.framework; do
  ldid -S "$fw/$(basename "$fw" .framework)"
done
for dylib in "$APP"/Frameworks/*.dylib; do
  [ -e "$dylib" ] && ldid -S "$dylib"
done
if [ -d "$APP/PlugIns/PacketTunnel.appex" ]; then
  ldid -Iapp.dropweb.PacketTunnel -S"$ENT/PacketTunnel.xml" \
    "$APP/PlugIns/PacketTunnel.appex/PacketTunnel"
fi
# -I: nehelper identifies the VPN app by its signing identifier, which
# ldid would otherwise set to the binary name ("Runner").
ldid -Iapp.dropweb -S"$ENT/Runner.xml" "$APP/Runner"
(cd "$OUT" && zip -qr dropweb-dev.ipa Payload)
ideviceinstaller install "$OUT/dropweb-dev.ipa"
