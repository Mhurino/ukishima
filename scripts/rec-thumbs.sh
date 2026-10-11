#!/bin/sh
# Generate cached filmstrip covers for every supported video in the recording folder.
recdir="$1"
[ -n "$recdir" ] && [ -d "$recdir" ] || exit 0

cache="${XDG_CACHE_HOME:-$HOME/.cache}/ukishima/rec-thumbs"
mkdir -p "$cache" || exit 0

# Prune covers whose source video no longer exists. Cache names retain the
# original extension, so `clip.mp4.jpg` maps unambiguously to `clip.mp4`.
for thumb in "$cache"/*.jpg; do
    [ -e "$thumb" ] || continue
    src="$recdir/$(basename "$thumb" .jpg)"
    [ -f "$src" ] || rm -f -- "$thumb"
done

find "$recdir" -maxdepth 1 -type f \
    \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.webm' -o -iname '*.avi' -o -iname '*.m4v' -o -iname '*.mpg' -o -iname '*.mpeg' -o -iname '*.ts' -o -iname '*.mts' -o -iname '*.m2ts' -o -iname '*.flv' -o -iname '*.wmv' -o -iname '*.ogv' -o -iname '*.3gp' -o -iname '*.3g2' -o -iname '*.vob' -o -iname '*.mxf' -o -iname '*.divx' \) -exec sh -c '
        cache="$1"
        shift
        for src do
            thumb="$cache/$(basename "$src").jpg"
            if [ ! -s "$thumb" ] || [ "$src" -nt "$thumb" ]; then
                tmp="$thumb.tmp.jpg"
                ffmpeg -y -ss 1 -i "$src" -frames:v 1 -vf scale=200:-1 -q:v 4 "$tmp" >/dev/null 2>&1
                [ -s "$tmp" ] || ffmpeg -y -ss 0 -i "$src" -frames:v 1 -vf scale=200:-1 -q:v 4 "$tmp" >/dev/null 2>&1
                if [ -s "$tmp" ]; then
                    mv -f -- "$tmp" "$thumb"
                else
                    rm -f -- "$tmp"
                fi
            fi
        done
    ' sh "$cache" {} +
