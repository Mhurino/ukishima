#!/usr/bin/env python3
# UKISHIMA_COLOR_FILTER_V1
"""Build a cached colour index from Ukishima wallpaper previews."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tif", ".tiff"}
VIDEO_EXTS = {".mp4", ".webm", ".mkv", ".mov"}
CACHE_ROOT = Path(os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache")) / "ukishima"
INDEX_FILE = CACHE_ROOT / "wallpaper-colors-v1.json"
ROOT = Path(__file__).resolve().parent.parent


def stat_signature(*paths: Path) -> str:
    parts = []
    for path in paths:
        try:
            st = path.stat()
            parts.append(f"{path}:{st.st_mtime_ns}:{st.st_size}")
        except OSError:
            parts.append(f"{path}:missing")
    return "|".join(parts)


def extract_palette(path: Path) -> list[str]:
    from PIL import Image, ImageOps

    with Image.open(path) as source:
        image = ImageOps.exif_transpose(source).convert("RGB")
        image.thumbnail((160, 160), Image.Resampling.LANCZOS)
        quantized = image.quantize(colors=28)
        histogram = quantized.histogram()
        palette = quantized.getpalette()

    if not palette:
        return []

    ranked = sorted(
        ((count, index) for index, count in enumerate(histogram) if count > 0),
        reverse=True,
    )
    total = sum(count for count, _ in ranked)
    picked: list[tuple[int, int, int]] = []
    result: list[str] = []

    for count, index in ranked:
        if count < max(2, total * 0.012) and len(result) >= 4:
            break
        base = index * 3
        rgb = (palette[base], palette[base + 1], palette[base + 2])

        # Merge nearly identical quantized colours so the UI shows useful variety.
        if any(
            sum((rgb[i] - old[i]) ** 2 for i in range(3)) ** 0.5 < 38
            for old in picked
        ):
            continue

        picked.append(rgb)
        result.append("#%02x%02x%02x" % rgb)
        if len(result) >= 7:
            break

    return result


def local_sources(wallpaper_dir: str):
    root = Path(wallpaper_dir).expanduser()
    if not root.is_dir():
        return

    # Match the exact folder-key convention used by wallpaper-thumbs.sh.
    folder_key = hashlib.md5(wallpaper_dir.encode("utf-8")).hexdigest()
    thumb_dir = CACHE_ROOT / "wp-thumbs" / folder_key

    for source in root.rglob("*"):
        if not source.is_file() or source.suffix.lower() not in IMAGE_EXTS | VIDEO_EXTS:
            continue

        thumb = thumb_dir / (source.name + ".png")
        if thumb.is_file():
            try:
                if thumb.stat().st_mtime_ns >= source.stat().st_mtime_ns:
                    candidate = thumb
                else:
                    candidate = None if source.suffix.lower() in VIDEO_EXTS else source
            except OSError:
                candidate = None
        else:
            candidate = None if source.suffix.lower() in VIDEO_EXTS else source

        if candidate and candidate.is_file():
            yield str(source), candidate, (source, candidate)


def local_path(value: str):
    text = str(value or "")
    if not text:
        return None
    if text.startswith("file://"):
        return Path(unquote(urlparse(text).path)).expanduser()
    if "://" in text:
        return None
    return Path(text).expanduser()


def load_waywallen_sources():
    """Reuse locally available Waywallen resources/previews; never download media."""
    bridge_path = ROOT / "scripts" / "waywallen-bridge.py"
    if not bridge_path.is_file():
        return

    connection = None
    try:
        spec = importlib.util.spec_from_file_location("ukishima_color_waywallen_bridge", bridge_path)
        if spec is None or spec.loader is None:
            return
        bridge = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = bridge
        spec.loader.exec_module(bridge)

        connection = bridge.connect_ws()
        items = bridge.list_wallpapers(connection, 7601)
        for item in items:
            resource_text = str(item.get("resource") or "")
            preview_text = str(item.get("preview") or "")
            kind = str(item.get("type") or "").lower()
            resource = local_path(resource_text)
            preview = local_path(preview_text)
            candidate = None

            if kind == "image":
                candidate = resource if resource and resource.is_file() else preview
            elif kind == "scene":
                candidate = preview if preview and preview.is_file() else resource
            elif kind == "video":
                if resource:
                    canonical = os.path.realpath(str(resource))
                    key = hashlib.sha256(canonical.encode("utf-8")).hexdigest()[:32]
                    cached = CACHE_ROOT / "waywallen-thumbs" / (key + ".jpg")
                    if cached.is_file():
                        candidate = cached
                if candidate is None and preview and preview.is_file():
                    candidate = preview
            else:
                candidate = preview if preview and preview.is_file() else resource

            if candidate and candidate.is_file() and resource_text:
                yield resource_text, candidate, tuple(
                    p for p in (resource, candidate) if p is not None
                )
    except Exception as exc:
        print(f"Waywallen index skipped: {exc}", file=sys.stderr)
    finally:
        if connection is not None:
            try:
                connection.close()
            except Exception:
                pass


def main() -> int:
    if len(sys.argv) < 3 or sys.argv[1] != "index":
        print(json.dumps({"byPath": {}, "error": "usage: wallpaper-colors.py index WALLPAPER_DIR [WAYWALLEN]"}))
        return 0

    wallpaper_dir = sys.argv[2]
    include_waywallen = len(sys.argv) > 3 and sys.argv[3] == "1"

    try:
        from PIL import Image  # noqa: F401
    except Exception as exc:
        print(json.dumps({"byPath": {}, "error": f"Pillow unavailable: {exc}"}))
        return 0

    CACHE_ROOT.mkdir(parents=True, exist_ok=True)
    try:
        cache = json.loads(INDEX_FILE.read_text(encoding="utf-8"))
        if cache.get("version") != 1 or not isinstance(cache.get("items"), dict):
            cache = {"version": 1, "items": {}}
    except (OSError, ValueError, AttributeError):
        cache = {"version": 1, "items": {}}

    by_path: dict[str, list[str]] = {}
    updated = False
    sources = list(local_sources(wallpaper_dir) or [])
    if include_waywallen:
        sources.extend(load_waywallen_sources() or [])

    for display_path, image_path, signature_paths in sources:
        signature = stat_signature(*signature_paths)
        cached = cache["items"].get(display_path)
        if isinstance(cached, dict) and cached.get("signature") == signature and isinstance(cached.get("colors"), list):
            colors = cached["colors"]
        else:
            try:
                colors = extract_palette(image_path)
            except Exception as exc:
                print(f"Palette skipped for {display_path}: {exc}", file=sys.stderr)
                colors = []
            cache["items"][display_path] = {
                "signature": signature,
                "colors": colors,
            }
            updated = True

        if colors:
            by_path[display_path] = colors
            canonical = os.path.realpath(display_path)
            by_path.setdefault(canonical, colors)

    if updated or not INDEX_FILE.exists():
        temporary = INDEX_FILE.with_suffix(".tmp")
        temporary.write_text(json.dumps(cache, separators=(",", ":")), encoding="utf-8")
        temporary.replace(INDEX_FILE)

    print(json.dumps({"byPath": by_path, "error": ""}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
