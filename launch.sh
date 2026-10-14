#!/usr/bin/env sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Usa questi valori solo se MALLOC_CONF non è già stato configurato.
: "${MALLOC_CONF:=background_thread:true,dirty_decay_ms:100,muzzy_decay_ms:100}"
export MALLOC_CONF

if command -v qs >/dev/null 2>&1; then
    exec qs -p "$DIR" "$@"
elif command -v quickshell >/dev/null 2>&1; then
    exec quickshell --config "$DIR" "$@"
fi

echo "Ukishima: quickshell non trovato nel PATH." >&2
exit 127
