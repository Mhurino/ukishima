#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${HOME:-$(getent passwd "$(id -un)" | cut -d: -f6)}"
INSTALL_ROOT="${UKISHIMA_INSTALL_ROOT:-$USER_HOME/.local/share/quickshell/ukishima}"

mkdir -p "$INSTALL_ROOT"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$SCRIPT_DIR/" "$INSTALL_ROOT/"
else
  cp -a "$SCRIPT_DIR/." "$INSTALL_ROOT/"
fi

warn() { printf '  \033[1;33m%s\033[0m\n' "$*"; }

cat <<EOF
Ukishima was installed to:
  $INSTALL_ROOT
  The copy is self-contained: config, scripts and the generated Hyprland
  files all resolve inside this folder, so no environment setup is needed.

Dependencies:
EOF

missing=0
check() {
  if ! command -v "$1" >/dev/null 2>&1; then
    missing=1
    warn "missing: $2 ($1)"
  fi
}

check quickshell   "shell runtime"
check hyprctl      "Hyprland IPC"
check jq           "JSON parsing in helper scripts"
check notify-send  "desktop notifications (libnotify)"
check curl         "weather + wallpaper search/downloads"
check python3      "palette generation (wallcolors.py)"
check magick       "wallpaper thumbs + palette (ImageMagick)"
check awww         "wallpaper daemon"
check awww-daemon  "wallpaper daemon"
check ffmpeg       "video wallpaper stills"
check nmcli        "wifi surface (NetworkManager)"
check bluetoothctl "bluetooth surface (bluez)"
check brightnessctl "backlight control (or light)"
check cava         "music visualiser"
check cliphist     "clipboard history"
check wl-paste     "clipboard history (wl-clipboard)"
check slurp        "window/region picker for screen recording"
check hyprsunset   "night light"
check xdg-open     "open record folder/files (xdg-utils)"

cat <<EOF

Optional, for the full feature set:
EOF

for b in gpu-screen-recorder mpvpaper matugen ddcutil kdialog zenity; do
  command -v "$b" >/dev/null 2>&1 || warn "optional: $b"
done

cat <<EOF

State:  \$XDG_STATE_HOME/ukishima   (default ~/.local/state/ukishima)
Cache:  \$XDG_CACHE_HOME/ukishima   (default ~/.cache/ukishima)

Launch:
  quickshell --config "$INSTALL_ROOT"

If you installed from your live config folder, add the modules to Hyprland:
  source = $INSTALL_ROOT/modules/*.lua
EOF

[ "$missing" -eq 0 ] || printf '\n  \033[1;31mSome core dependencies are missing — install them for full functionality.\033[0m\n' >&2
