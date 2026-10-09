#!/usr/bin/env bash
set -euo pipefail

APP_ID="org.waywallen.waywallen"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LAYER_BIN="$HOME/.local/bin/waywallen-layer-shell"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
DAEMON_UNIT="ukishima-waywallen.service"
LAYER_UNIT="ukishima-waywallen-layer-shell.service"
PALETTE_UNIT="ukishima-waywallen-palette.service"
TMP_WORKDIR=""
cleanup() { if [ -n "$TMP_WORKDIR" ] && [ -d "$TMP_WORKDIR" ]; then rm -rf -- "$TMP_WORKDIR"; fi; }
trap cleanup EXIT

notify() {
    command -v notify-send >/dev/null 2>&1 && notify-send --app-name=Ukishima "Waywallen" "$1" >/dev/null 2>&1 || true
}
require_flatpak() {
    command -v flatpak >/dev/null 2>&1 || { echo "flatpak non trovato" >&2; notify "Flatpak non disponibile nel PATH."; return 1; }
    flatpak info "$APP_ID" >/dev/null 2>&1 || { echo "Flatpak $APP_ID non installato" >&2; notify "Installa prima Waywallen da Flatpak."; return 1; }
}
expand_path() {
    local value="$1"
    if [ "$value" = "~" ]; then printf '%s\n' "$HOME"
    elif [[ "$value" == "~/"* ]]; then printf '%s/%s\n' "$HOME" "${value#~/}"
    elif [[ "$value" = /* ]]; then printf '%s\n' "$value"
    else printf '%s/%s\n' "$PWD" "$value"
    fi
}
grant_folder() {
    require_flatpak
    local folder
    folder="$(expand_path "${1:-}")"
    [ -n "$folder" ] && [ -d "$folder" ] || { notify "La cartella deve esistere: ${1:-}"; echo "Cartella non valida: ${1:-}" >&2; return 1; }
    flatpak override --user "--filesystem=$folder:ro" "$APP_ID"
    notify "Accesso concesso. Aggiungi la cartella in Waywallen → Libraries."
}
install_layer_shell() {
    [ -x "$LAYER_BIN" ] && return 0
    command -v curl >/dev/null 2>&1 || { echo "curl non trovato" >&2; return 1; }
    command -v jq >/dev/null 2>&1 || { echo "jq non trovato" >&2; return 1; }
    command -v tar >/dev/null 2>&1 || { echo "tar non trovato" >&2; return 1; }
    command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum non trovato" >&2; return 1; }
    local arch asset url digest archive bin share_dir
    case "$(uname -m)" in
        x86_64|amd64) arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) notify "Architettura non supportata: $(uname -m)"; echo "Architettura non supportata" >&2; return 1 ;;
    esac
    TMP_WORKDIR="$(mktemp -d)"
    curl -fsSL "https://api.github.com/repos/waywallen/waywallen-display/releases/latest" -o "$TMP_WORKDIR/release.json"
    asset="$(jq -r --arg arch "$arch" '.assets[] | select(.name | startswith("waywallen-layer-shell-") and endswith("-" + $arch + ".tar.gz")) | [.browser_download_url, .digest] | @tsv' "$TMP_WORKDIR/release.json" | head -n 1)"
    [ -n "$asset" ] || { echo "Asset layer-shell non trovato per $arch" >&2; return 1; }
    IFS=$'\t' read -r url digest <<< "$asset"
    [[ "$digest" == sha256:* ]] || { echo "La release non espone un digest SHA-256; installazione interrotta." >&2; return 1; }
    archive="$TMP_WORKDIR/layer-shell.tar.gz"
    curl -fL "$url" -o "$archive"
    printf '%s  %s\n' "${digest#sha256:}" "$archive" | sha256sum -c -
    mkdir -p "$TMP_WORKDIR/unpacked" "$HOME/.local/bin" "$HOME/.local/share"
    tar -xzf "$archive" -C "$TMP_WORKDIR/unpacked"
    bin="$(find "$TMP_WORKDIR/unpacked" -type f -name waywallen-layer-shell -print -quit)"
    [ -n "$bin" ] || { echo "Il pacchetto non contiene waywallen-layer-shell" >&2; return 1; }
    install -Dm755 "$bin" "$LAYER_BIN"
    share_dir="$(dirname "$bin")/share"
    if [ -d "$share_dir" ]; then cp -a "$share_dir/." "$HOME/.local/share/"; fi
    rm -rf -- "$TMP_WORKDIR"
    TMP_WORKDIR=""
}
write_units() {
    local flatpak_bin bash_bin script_path python_bin
    flatpak_bin="$(command -v flatpak)"
    bash_bin="$(command -v bash)"
    python_bin="$(command -v python3)"
    script_path="$SCRIPT_DIR/waywallen.sh"
    mkdir -p "$UNIT_DIR"
    cat > "$UNIT_DIR/$DAEMON_UNIT" <<EOF
[Unit]
Description=Waywallen wallpaper daemon (Flatpak)
After=basic.target

[Service]
Type=simple
ExecStart=$flatpak_bin run --command=waywallen $APP_ID --no-ui
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF
    cat > "$UNIT_DIR/$LAYER_UNIT" <<EOF
[Unit]
Description=Waywallen wallpaper layer-shell client for Hyprland
Requires=$DAEMON_UNIT
After=$DAEMON_UNIT

[Service]
Type=simple
ExecStart=$bash_bin "$script_path" layer-shell
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF

    cat > "$UNIT_DIR/$PALETTE_UNIT" <<EOF
[Unit]
Description=Synchronize Ukishima palette with Waywallen wallpapers
Requires=$DAEMON_UNIT
After=$DAEMON_UNIT
PartOf=$DAEMON_UNIT

[Service]
Type=simple
ExecStart=$python_bin "$SCRIPT_DIR/waywallen-palette-watch.py"
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF
}
prepare_services() {
    require_flatpak
    install_layer_shell
    local flags_file folder
    flags_file="${XDG_STATE_HOME:-$HOME/.local/state}/ukishima/flags.json"
    folder="$(jq -r '.waywallenWallpaperDir // ""' "$flags_file" 2>/dev/null || true)"
    if [ -n "$folder" ]; then
        folder="$(expand_path "$folder")"
        if [ -d "$folder" ]; then flatpak override --user "--filesystem=$folder:ro" "$APP_ID"; fi
    fi
    write_units
    systemctl --user daemon-reload
    systemctl --user import-environment XDG_RUNTIME_DIR WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE >/dev/null 2>&1 || true
}
enable_integration() {
    prepare_services
    awww kill >/dev/null 2>&1 || true
    pkill -x mpvpaper >/dev/null 2>&1 || true
    systemctl --user enable --now "$DAEMON_UNIT" "$LAYER_UNIT" "$PALETTE_UNIT"
    notify "Waywallen attivato e configurato per l'avvio automatico."
}
start_integration() {
    prepare_services
    systemctl --user enable --now "$DAEMON_UNIT" "$LAYER_UNIT" "$PALETTE_UNIT"
}
disable_integration() {
    systemctl --user disable --now "$PALETTE_UNIT" "$LAYER_UNIT" "$DAEMON_UNIT" >/dev/null 2>&1 || true
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    flatpak kill "$APP_ID" >/dev/null 2>&1 || true
    bash "$SCRIPT_DIR/wallpaper.sh" force-init >/dev/null 2>&1 || true
    notify "Supporto Waywallen disattivato; ripristinato il backend sfondi di Ukishima."
}
run_layer_shell() {
    local runtime candidate i
    runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    export XDG_RUNTIME_DIR="$runtime"
    for i in $(seq 1 120); do
        if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "$runtime/$WAYLAND_DISPLAY" ]; then break; fi
        candidate="$(find "$runtime" -maxdepth 1 -type s -name 'wayland-*' -printf '%T@ %f\n' 2>/dev/null | sort -nr | awk 'NR == 1 { print $2 }')"
        if [ -n "$candidate" ]; then export WAYLAND_DISPLAY="$candidate"; break; fi
        sleep 1
    done
    [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "$runtime/$WAYLAND_DISPLAY" ] || { echo "Socket Wayland non trovato in $runtime" >&2; return 1; }
    for i in $(seq 1 120); do [ -S "$runtime/waywallen/display.sock" ] && break; sleep 1; done
    [ -S "$runtime/waywallen/display.sock" ] || { echo "Socket del daemon Waywallen non trovato" >&2; return 1; }
    [ -x "$LAYER_BIN" ] || install_layer_shell
    exec "$LAYER_BIN" --socket "$runtime/waywallen/display.sock"
}
case "${1:-}" in
    enable) enable_integration ;;
    start) start_integration ;;
    disable) disable_integration ;;
    open) require_flatpak; nohup flatpak run "$APP_ID" >/dev/null 2>&1 </dev/null & ;;
    grant-folder) grant_folder "${2:-}" ;;
    layer-shell) run_layer_shell ;;
    *) echo "Uso: $0 {enable|start|disable|open|grant-folder PATH|layer-shell}" >&2; exit 2 ;;
esac
