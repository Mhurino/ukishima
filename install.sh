#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${HOME:-$(getent passwd "$(id -un)" | cut -d: -f6)}"
INSTALL_ROOT="${PILL_INSTALL_ROOT:-$USER_HOME/.local/share/quickshell/pill}"
CONFIG_ROOT="${PILL_CONFIG_DIR:-$USER_HOME/.config/pill}"
HYPER_ROOT="${PILL_HYPR_CONFIG_DIR:-$USER_HOME/.config/pill/hypr}"
STATE_ROOT="${PILL_STATE_DIR:-$USER_HOME/.local/state/pill}"
CACHE_ROOT="${PILL_CACHE_DIR:-$USER_HOME/.cache/pill}"

mkdir -p "$INSTALL_ROOT" "$CONFIG_ROOT" "$HYPER_ROOT" "$STATE_ROOT" "$CACHE_ROOT"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$SCRIPT_DIR/" "$INSTALL_ROOT/"
else
  cp -a "$SCRIPT_DIR/." "$INSTALL_ROOT/"
fi

cat > "$CONFIG_ROOT/pill.env" <<EOF
PILL_CONFIG_DIR="$CONFIG_ROOT"
PILL_HYPR_CONFIG_DIR="$HYPER_ROOT"
PILL_STATE_DIR="$STATE_ROOT"
PILL_CACHE_DIR="$CACHE_ROOT"
EOF

cat <<EOF
Pill was prepared for independent install.

Installed app root: $INSTALL_ROOT
Config root:       $CONFIG_ROOT
Hypr compat root:  $HYPER_ROOT
State root:        $STATE_ROOT
Cache root:        $CACHE_ROOT

Export these values before running Quickshell:

export PILL_CONFIG_DIR="$CONFIG_ROOT"
export PILL_HYPR_CONFIG_DIR="$HYPER_ROOT"
export PILL_STATE_DIR="$STATE_ROOT"
export PILL_CACHE_DIR="$CACHE_ROOT"

Optional: add the export lines to your shell profile if you want them persistent.
EOF
