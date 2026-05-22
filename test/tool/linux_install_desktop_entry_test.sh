#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

export HOME="$TMP_DIR/home"
export XDG_DATA_HOME="$TMP_DIR/xdg-data"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$TMP_DIR/bin"

FAKE_EXEC="$TMP_DIR/bin/dropweb"
printf '#!/usr/bin/env sh\nexit 0\n' > "$FAKE_EXEC"
chmod +x "$FAKE_EXEC"

INSTALLER="$ROOT_DIR/tool/linux/install_desktop_entry.sh"
"$INSTALLER" --exec "$FAKE_EXEC"

DESKTOP_FILE="$XDG_DATA_HOME/applications/dropweb.desktop"
ICON_FILE="$XDG_DATA_HOME/icons/hicolor/256x256/apps/dropweb.png"

test -f "$DESKTOP_FILE"
test -f "$ICON_FILE"
grep -F "Exec=$FAKE_EXEC" "$DESKTOP_FILE"
grep -F "Icon=dropweb" "$DESKTOP_FILE"
grep -F "Type=Application" "$DESKTOP_FILE"
grep -F "Categories=Network;" "$DESKTOP_FILE"

"$INSTALLER" --uninstall
test ! -e "$DESKTOP_FILE"
test ! -e "$ICON_FILE"
