#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INTEGRATION="$SCRIPT_DIR/waywallen.sh"
BRIDGE="$SCRIPT_DIR/waywallen-bridge.py"
WATCHER="$SCRIPT_DIR/waywallen-palette-watch.py"
UNIT="ukishima-waywallen-palette.service"

for file in "$INTEGRATION" "$BRIDGE" "$WATCHER"; do
    if [[ ! -f "$file" ]]; then
        echo "ERRORE: file necessario non trovato: $file" >&2
        exit 1
    fi
done

command -v python3 >/dev/null || {
    echo "ERRORE: python3 non trovato." >&2
    exit 1
}
command -v systemctl >/dev/null || {
    echo "ERRORE: systemctl non trovato." >&2
    exit 1
}

# Verifica prima la sintassi dei file.
python3 -m py_compile "$BRIDGE" "$WATCHER"
bash -n "$INTEGRATION"

if ! grep -q 'PALETTE_UNIT="ukishima-waywallen-palette.service"' "$INTEGRATION"; then
    echo "ERRORE: waywallen.sh non configura l'unità della palette." >&2
    exit 1
fi

echo "Configuro e avvio l'integrazione Waywallen..."
echo "Potrebbero essere avviati anche il daemon e il layer-shell di Waywallen."

# Lo script esistente genera le unità e abilita la palette all'avvio.
bash "$INTEGRATION" start

if ! systemctl --user is-enabled --quiet "$UNIT"; then
    echo "ERRORE: il servizio non risulta abilitato." >&2
    exit 1
fi

if ! systemctl --user is-active --quiet "$UNIT"; then
    echo "ERRORE: il servizio non risulta attivo." >&2
    systemctl --user status "$UNIT" --no-pager || true
    journalctl --user -u "$UNIT" -n 30 --no-pager || true
    exit 1
fi

echo
echo "Servizio abilitato e attivo."
systemctl --user status "$UNIT" --no-pager
echo
echo "Per seguire i log:"
echo "journalctl --user -u $UNIT -f"
echo
echo "Per disabilitarlo:"
echo "systemctl --user disable --now $UNIT"
