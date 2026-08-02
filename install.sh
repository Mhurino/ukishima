#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${HOME:-$(getent passwd "$(id -un)" | cut -d: -f6)}"
INSTALL_ROOT="${PILL_INSTALL_ROOT:-$USER_HOME/.local/share/quickshell/pill}"

mkdir -p "$INSTALL_ROOT"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$SCRIPT_DIR/" "$INSTALL_ROOT/"
else
  cp -a "$SCRIPT_DIR/." "$INSTALL_ROOT/"
fi

cat <<EOF
Pill was prepared for independent install.

Installed app root: $INSTALL_ROOT
  Config, scripts and Hyprland-compat outputs all resolve inside this
  folder, so the copy is self-contained and needs no environment setup.

State:  \$XDG_STATE_HOME/pill   (default ~/.local/state/pill)
Cache:  \$XDG_CACHE_HOME/pill   (default ~/.cache/pill)

Launch:
  quickshell --config "$INSTALL_ROOT"
EOF
