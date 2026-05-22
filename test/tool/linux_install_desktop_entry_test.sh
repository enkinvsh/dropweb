#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

run_repo_mode_case() {
  CASE_DIR="$TMP_DIR/repo-mode"
  mkdir -p "$CASE_DIR/home" "$CASE_DIR/xdg-data" "$CASE_DIR/bin"
  export HOME="$CASE_DIR/home"
  export XDG_DATA_HOME="$CASE_DIR/xdg-data"

  FAKE_EXEC="$CASE_DIR/bin/dropweb"
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
}

run_relocated_artifact_case() {
  CASE_DIR="$TMP_DIR/relocated-artifact"
  mkdir -p "$CASE_DIR/home" "$CASE_DIR/xdg-data" "$CASE_DIR/bin" "$CASE_DIR/artifact-tools"
  export HOME="$CASE_DIR/home"
  export XDG_DATA_HOME="$CASE_DIR/xdg-data"

  FAKE_EXEC="$CASE_DIR/bin/dropweb"
  printf '#!/usr/bin/env sh\nexit 0\n' > "$FAKE_EXEC"
  chmod +x "$FAKE_EXEC"

  cp "$ROOT_DIR/tool/linux/install_desktop_entry.sh" "$CASE_DIR/artifact-tools/install_desktop_entry.sh"
  cp "$ROOT_DIR/linux/packaging/dropweb.desktop.template" "$CASE_DIR/artifact-tools/dropweb.desktop.template"
  cp "$ROOT_DIR/assets/images/icon.png" "$CASE_DIR/artifact-tools/dropweb.png"
  chmod +x "$CASE_DIR/artifact-tools/install_desktop_entry.sh"

  RELOCATED="$CASE_DIR/artifact-tools/install_desktop_entry.sh"
  "$RELOCATED" --exec "$FAKE_EXEC"

  DESKTOP_FILE="$XDG_DATA_HOME/applications/dropweb.desktop"
  ICON_FILE="$XDG_DATA_HOME/icons/hicolor/256x256/apps/dropweb.png"

  test -f "$DESKTOP_FILE"
  test -f "$ICON_FILE"
  grep -F "Exec=$FAKE_EXEC" "$DESKTOP_FILE"
  grep -F "Icon=dropweb" "$DESKTOP_FILE"

  "$RELOCATED" --uninstall
  test ! -e "$DESKTOP_FILE"
  test ! -e "$ICON_FILE"
}

run_parent_appimage_autodetect_case() {
  CASE_DIR="$TMP_DIR/parent-appimage"
  mkdir -p "$CASE_DIR/home" "$CASE_DIR/xdg-data" "$CASE_DIR/artifact-tools"
  export HOME="$CASE_DIR/home"
  export XDG_DATA_HOME="$CASE_DIR/xdg-data"

  APPIMAGE="$CASE_DIR/dropweb-amd64.AppImage"
  printf '#!/usr/bin/env sh\nexit 0\n' > "$APPIMAGE"
  chmod +x "$APPIMAGE"

  cp "$ROOT_DIR/tool/linux/install_desktop_entry.sh" "$CASE_DIR/artifact-tools/install_desktop_entry.sh"
  cp "$ROOT_DIR/linux/packaging/dropweb.desktop.template" "$CASE_DIR/artifact-tools/dropweb.desktop.template"
  cp "$ROOT_DIR/assets/images/icon.png" "$CASE_DIR/artifact-tools/dropweb.png"
  chmod +x "$CASE_DIR/artifact-tools/install_desktop_entry.sh"

  RELOCATED="$CASE_DIR/artifact-tools/install_desktop_entry.sh"
  "$RELOCATED"

  DESKTOP_FILE="$XDG_DATA_HOME/applications/dropweb.desktop"
  ICON_FILE="$XDG_DATA_HOME/icons/hicolor/256x256/apps/dropweb.png"

  test -f "$DESKTOP_FILE"
  test -f "$ICON_FILE"
  grep -F "Exec=$APPIMAGE" "$DESKTOP_FILE"

  "$RELOCATED" --uninstall
  test ! -e "$DESKTOP_FILE"
  test ! -e "$ICON_FILE"
}

run_repo_mode_case
run_relocated_artifact_case
run_parent_appimage_autodetect_case
