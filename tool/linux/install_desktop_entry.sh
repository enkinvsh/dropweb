#!/usr/bin/env sh
set -eu

APP_ID="dropweb"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
XDG_BASE="${XDG_DATA_HOME:-$HOME/.local/share}"
APPLICATIONS_DIR="$XDG_BASE/applications"
ICONS_DIR="$XDG_BASE/icons/hicolor/256x256/apps"
DESKTOP_FILE="$APPLICATIONS_DIR/$APP_ID.desktop"
ICON_FILE="$ICONS_DIR/$APP_ID.png"
TEMPLATE_FILE="$ROOT_DIR/linux/packaging/dropweb.desktop.template"
SOURCE_ICON="$ROOT_DIR/assets/images/icon.png"

usage() {
  printf '%s\n' "Usage: $0 [--exec PATH] [--uninstall]"
}

refresh_caches() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPLICATIONS_DIR" >/dev/null 2>&1 || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache "$XDG_BASE/icons/hicolor" >/dev/null 2>&1 || true
  fi
}

uninstall_entry() {
  rm -f "$DESKTOP_FILE" "$ICON_FILE"
  refresh_caches
  printf '%s\n' "Removed Dropweb desktop entry from $DESKTOP_FILE"
}

find_neighbor_appimage() {
  for candidate in "$SCRIPT_DIR"/*.AppImage "$SCRIPT_DIR"/dropweb*AppImage; do
    if [ -f "$candidate" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

resolve_exec() {
  if [ "${1:-}" != "" ]; then
    printf '%s\n' "$1"
    return 0
  fi
  if find_neighbor_appimage; then
    return 0
  fi
  if command -v dropweb >/dev/null 2>&1; then
    command -v dropweb
    return 0
  fi
  return 1
}

EXEC_PATH=""
UNINSTALL=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --exec)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      EXEC_PATH="$2"
      shift 2
      ;;
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$UNINSTALL" -eq 1 ]; then
  uninstall_entry
  exit 0
fi

RESOLVED_EXEC="$(resolve_exec "$EXEC_PATH")" || {
  printf '%s\n' "Could not find Dropweb executable. Pass --exec /path/to/dropweb or run this installer next to the AppImage." >&2
  exit 1
}

if [ ! -x "$RESOLVED_EXEC" ]; then
  printf '%s\n' "Dropweb executable is not executable: $RESOLVED_EXEC" >&2
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  printf '%s\n' "Desktop template not found: $TEMPLATE_FILE" >&2
  exit 1
fi

if [ ! -f "$SOURCE_ICON" ]; then
  printf '%s\n' "Icon source not found: $SOURCE_ICON" >&2
  exit 1
fi

# Escape characters that are special inside the sed replacement (\ & |).
ESCAPED_EXEC=$(printf '%s' "$RESOLVED_EXEC" | sed -e 's/[\\&|]/\\&/g')

mkdir -p "$APPLICATIONS_DIR" "$ICONS_DIR"
sed "s|@EXEC@|$ESCAPED_EXEC|g" "$TEMPLATE_FILE" > "$DESKTOP_FILE"
cp "$SOURCE_ICON" "$ICON_FILE"
refresh_caches
printf '%s\n' "Installed Dropweb desktop entry to $DESKTOP_FILE"
