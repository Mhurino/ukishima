#!/usr/bin/env bash
set -euo pipefail

id="${1:-}"
src="${2:-}"

[[ "$id" =~ ^[A-Za-z0-9_-]+$ ]] || exit 2
[[ -f "$src" && -r "$src" ]] || exit 3
command -v ffmpeg >/dev/null 2>&1 || exit 4

cache="${XDG_CACHE_HOME:-$HOME/.cache}/ukishima/waywallen-thumbs"
mkdir -p "$cache"

out="$cache/$id.jpg"
tmp="$cache/$id.tmp.jpg"

if [[ -s "$out" && "$out" -nt "$src" ]]; then
    printf '%s\n' "$out"
    exit 0
fi

rm -f "$tmp"

if command -v timeout >/dev/null 2>&1; then
    if ! timeout 20s ffmpeg -hide_banner -loglevel error -y \
        -ss 1 -i "$src" -frames:v 1 \
        -vf 'scale=512:288:force_original_aspect_ratio=decrease,pad=512:288:(ow-iw)/2:(oh-ih)/2:color=black' \
        -q:v 4 "$tmp" </dev/null; then
        rm -f "$tmp"
        exit 0
    fi
else
    if ! ffmpeg -hide_banner -loglevel error -y \
        -ss 1 -i "$src" -frames:v 1 \
        -vf 'scale=512:288:force_original_aspect_ratio=decrease,pad=512:288:(ow-iw)/2:(oh-ih)/2:color=black' \
        -q:v 4 "$tmp" </dev/null; then
        rm -f "$tmp"
        exit 0
    fi
fi

if [[ -s "$tmp" ]]; then
    mv "$tmp" "$out"
    printf '%s\n' "$out"
else
    rm -f "$tmp"
fi
