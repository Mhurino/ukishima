#!/usr/bin/env python3
"""
Generate the rice colour set from a wallpaper and fan it out to the consumers.
One histogram pass yields both the area-dominant chromatic hue (binned by hue
family so a small vivid accent never hijacks the theme) and the mean lightness.
The mean lightness drives the pill's whole tone: a bright wallpaper makes a light
pill with dark text, a dark or OLED-black one makes a near-black pill with cream
text, so the surfaces and the text flip together for contrast across the full
range. The dominant hue tints every tier in HSL. An achromatic wallpaper drops to
a neutral grey ramp. matugen still builds the dark base16 the always-dark terminal
reads; the pill JSON carries surfaces, accent and the contrast-matched text.
"""
import colorsys
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

CACHE = Path.home() / ".cache" / "ukishima"

SURF_NAMES = ["surface", "surface_container_low", "surface_container",
              "surface_container_high", "surface_container_highest", "outline_variant"]
DARK_STEPS = [0.0, 0.022, 0.038, 0.065, 0.100, 0.225]
LIGHT_STEPS = [0.0, -0.045, -0.075, -0.115, -0.160, -0.340]
TEXT_KEYS = ["cream", "bright", "subtle", "dim", "faint", "icon_dim", "tick_rest"]
DARK_TEXT = [(0.90, 0.05), (0.97, 0.03), (0.73, 0.07), (0.54, 0.06),
             (0.44, 0.05), (0.81, 0.07), (0.75, 0.08)]
LIGHT_TEXT = [(0.20, 0.18), (0.10, 0.20), (0.36, 0.14), (0.48, 0.10),
              (0.56, 0.08), (0.28, 0.12), (0.34, 0.12)]


def analyze(wallpaper):
    """Analyze a wallpaper with Pillow, without requiring ImageMagick."""
    from PIL import Image

    with Image.open(wallpaper) as source:
        image = source.convert("RGB")
        image.thumbnail((200, 200), Image.Resampling.LANCZOS)
        quantized = image.quantize(colors=48)
        histogram = quantized.histogram()
        palette = quantized.getpalette()

    buckets, total, lum, chroma = {}, 0, 0.0, 0
    for index, count in enumerate(histogram):
        if not count:
            continue

        r, g, b = (palette[index * 3 + i] / 255 for i in range(3))
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        total += count
        lum += count * l

        if s < 0.15 or l < 0.05 or l > 0.92:
            continue

        chroma += count
        bucket = buckets.setdefault(
            (int(h * 360) // 30) % 12,
            {"wsat": 0.0, "best": None},
        )
        bucket["wsat"] += count * s
        score = count * s * (1 if 0.12 < l < 0.55 else 0.4)
        if not bucket["best"] or score > bucket["best"][0]:
            bucket["best"] = (score, h, s)

    mean_l = lum / total if total else 0.0
    if not buckets or chroma < 0.08 * total:
        return None, 0.0, mean_l

    win = max(buckets.values(), key=lambda v: v["wsat"])
    return win["best"][1], win["best"][2], mean_l


def matugen(source_hex):
    out = subprocess.run(
        ["matugen", "color", "hex", source_hex, "-m", "dark", "-j", "hex"],
        capture_output=True, text=True, check=True,
    )
    return json.loads(out.stdout)


def tint(hue, sat, light):
    r, g, b = colorsys.hls_to_rgb(hue % 1.0, max(0.0, min(1.0, light)), max(0.0, min(1.0, sat)))
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def lerp(x, x0, x1, y0, y1):
    t = max(0.0, min(1.0, (x - x0) / (x1 - x0)))
    return y0 + t * (y1 - y0)




def build_pill_palette(hue, sat, chromatic, mean_l):
    """Build the fork's existing pill palette for a chosen wallpaper tone."""
    light = mean_l >= 0.40
    surf_sat = min(sat, 0.26) if light else min(max(sat, 0.30 if chromatic else 0.0), 0.45)
    acc_sat = (min(sat + 0.18, 0.85) if light else min(max(sat, 0.30) + 0.12, 0.82)) if chromatic else 0.05
    if light:
        base = lerp(mean_l, 0.40, 0.66, 0.80, 0.93)
        steps, text, acc_l, deep_l, glow_l = LIGHT_STEPS, LIGHT_TEXT, 0.42, 0.30, 0.55
    else:
        base = lerp(mean_l, 0.0, 0.40, 0.045, 0.20)
        steps, text, acc_l, deep_l, glow_l = DARK_STEPS, DARK_TEXT, 0.70, 0.34, 0.86
    pill = {name: tint(hue, surf_sat, base + step) for name, step in zip(SURF_NAMES, steps)}
    pill["primary"] = tint(hue, acc_sat, acc_l)
    pill["primary_container"] = tint(hue, min(acc_sat + 0.08, 0.9), deep_l)
    pill["on_primary_container"] = tint(hue, min(acc_sat, 0.45), glow_l)
    pill["outline"] = tint(hue, surf_sat, base + (-0.35 if light else 0.35))
    for key, (lit, st) in zip(TEXT_KEYS, text):
        pill[key] = tint(hue, st, lit)
    return pill


def rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))


def to_hex(v):
    return "#%02x%02x%02x" % tuple(round(c * 255) for c in v)


def lum(h):
    lin = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb(h)]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def contrast(a, b):
    l1, l2 = lum(a), lum(b)
    lo, hi = min(l1, l2), max(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def ensure_contrast(color, bg, ratio):
    """Shift a colour until it clears ratio:1 against bg, keeping its hue."""
    if contrast(color, bg) >= ratio:
        return color
    h, l, s = colorsys.rgb_to_hls(*rgb(color))
    dark_bg = lum(bg) < 0.5
    lo, hi = (l, 1.0) if dark_bg else (0.0, l)
    for _ in range(30):
        mid = (lo + hi) / 2
        if contrast(to_hex(colorsys.hls_to_rgb(h, mid, s)), bg) >= ratio:
            if dark_bg:
                hi = mid
            else:
                lo = mid
        else:
            if dark_bg:
                lo = mid
            else:
                hi = mid
    return to_hex(colorsys.hls_to_rgb(h, hi if dark_bg else lo, s))


def backup_gtk_file(path):
    """Preserve a pre-existing GTK config file before changing it."""
    if not path.exists() and not path.is_symlink():
        return
    backup = path.with_name(path.name + ".ukishima-backup")
    if backup.exists() or backup.is_symlink():
        return
    if path.is_symlink():
        backup.symlink_to(os.readlink(path))
    else:
        shutil.copy2(path, backup)


def ensure_gtk_import(directory, pairs):
    """Append the generated palette import while retaining the previous theme."""
    for name, imp in pairs.items():
        line = '@import "%s";' % imp
        main = directory / name
        try:
            if main.is_symlink():
                backup_gtk_file(main)
                target = Path(os.readlink(main))
                if not target.is_absolute():
                    target = directory / target
                target = target.resolve()
                main.unlink()
                main.write_text('@import url("file://%s");\n%s\n' % (target, line))
            elif main.is_file():
                current = main.read_text()
                if line not in current:
                    backup_gtk_file(main)
                    if not current.endswith("\n"):
                        current += "\n"
                    main.write_text(current + line + "\n")
            else:
                main.write_text(line + "\n")
        except OSError:
            pass


def gtk_body(pill):
    accent = pill["primary"]
    mapping = [
        ("accent_color", accent), ("accent_bg_color", accent),
        ("accent_fg_color", ensure_contrast(pill["bright"], accent, 4.5)),
        ("window_bg_color", pill["surface"]), ("window_fg_color", pill["cream"]),
        ("headerbar_bg_color", pill["surface_container"]), ("headerbar_fg_color", pill["cream"]),
        ("popover_bg_color", pill["surface_container_high"]), ("popover_fg_color", pill["cream"]),
        ("view_bg_color", pill["surface_container_low"]), ("view_fg_color", pill["cream"]),
        ("card_bg_color", pill["surface_container"]), ("card_fg_color", pill["cream"]),
        ("sidebar_bg_color", pill["surface_container_low"]), ("sidebar_fg_color", pill["cream"]),
        ("destructive_color", "#e05a4f"), ("destructive_bg_color", "#5a2320"),
        ("destructive_fg_color", "#f5d9d4"), ("success_color", "#8fb573"),
        ("warning_color", "#d9a03f"), ("borders", pill["outline"]),
    ]
    return ("/* Generated by ukishima wallcolors.py - do not hand-edit. */\n"
            + "\n".join("@define-color %s %s;" % kv for kv in mapping) + "\n")


def render_gtk(tone, dark):
    """Generate GTK3/GTK4 palette files and make them override theme colours last."""
    try:
        d3 = Path.home() / ".config" / "gtk-3.0"
        d3.mkdir(parents=True, exist_ok=True)
        palette3 = d3 / "ukishima.css"
        backup_gtk_file(palette3)
        palette3.write_text(gtk_body(dark))
        ensure_gtk_import(d3, {"gtk.css": "ukishima.css"})

        d4 = Path.home() / ".config" / "gtk-4.0"
        d4.mkdir(parents=True, exist_ok=True)
        palette4 = d4 / "ukishima.css"
        dark4 = d4 / "ukishima-dark.css"
        backup_gtk_file(palette4)
        backup_gtk_file(dark4)
        palette4.write_text(gtk_body(tone))
        dark4.write_text(gtk_body(dark))
        ensure_gtk_import(d4, {"gtk.css": "ukishima.css", "gtk-dark.css": "ukishima-dark.css"})
    except OSError:
        pass

def render_fastfetch(pill):
    """
    Recolour the fastfetch readout from the same pill palette. fastfetch has no
    daemon, so writing the rendered config is enough, the next run picks it up.
    The accent drives the keys and the torii, the surface ramp the lantern body,
    and a dim text tone the section rules, so it tracks the wallpaper like the
    pill and terminal do.
    """
    ff = Path.home() / ".config" / "fastfetch"
    tmpl = ff / "config.jsonc.in"
    if not tmpl.is_file():
        return
    seq = lambda h: "%d;%d;%d" % tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
    repl = {
        "__LANTERN__": str(ff / "lantern.txt"),
        "__KEYS__": seq(pill["primary"]),
        "__SEP__": seq(pill["dim"]),
        "__LOGO1__": seq(pill["primary"]),
        "__LOGO2__": seq(pill["on_primary_container"]),
        "__LOGO3__": seq(pill["surface_container"]),
        "__LOGO4__": seq(pill["surface_container_high"]),
        "__LOGO5__": seq(pill["subtle"]),
        "__LOGO6__": seq(pill["outline"]),
        "__LOGO7__": seq(pill["bright"]),
    }
    out = tmpl.read_text()
    for key, val in repl.items():
        out = out.replace(key, val)
    (ff / "config.jsonc").write_text(out)


def main():
    if len(sys.argv) < 2:
        return 1
    if sys.argv[1] == "--hue":
        hue = (float(sys.argv[2]) % 360) / 360.0
        mode = sys.argv[3] if len(sys.argv) > 3 else "dark"
        sat = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
        sat = max(0.0, min(1.0, sat))
        mean_l = 0.85 if mode == "light" else 0.12
        chromatic = sat > 0.02
    else:
        wallpaper = sys.argv[1]
        if not Path(wallpaper).is_file():
            return 0
        hue, sat, mean_l = analyze(wallpaper)
        chromatic = hue is not None
        if not chromatic:
            hue, sat = 0.09, 0.0
    CACHE.mkdir(parents=True, exist_ok=True)

    light = mean_l >= 0.40
    pill = build_pill_palette(hue, sat, chromatic, mean_l)
    dark_pill = pill if not light else build_pill_palette(hue, sat, chromatic, 0.12)
    (CACHE / "colors.json").write_text(json.dumps(pill, indent=2) + "\n")
    render_fastfetch(pill)
    render_gtk(pill, dark_pill)

    try:
        b = {k: v["dark"]["color"] for k, v in
             matugen(tint(hue, sat, 0.45) if chromatic else "#787878")["base16"].items()}
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        return 0

    (CACHE / "hypr-colors.lua").write_text(
        'return {\n    active = "%s",\n    inactive = "%s",\n}\n'
        % (pill["primary"], b["base01"]))

    lines = [
        f'background = {b["base00"]}',
        f'foreground = {b["base07"]}',
        f'cursor-color = {pill["primary"]}',
        f'selection-background = {b["base02"]}',
        f'selection-foreground = {b["base07"]}',
    ]
    for i in range(16):
        lines.append(f'palette = {i}={b["base%02x" % i]}')
    (CACHE / "ghostty-colors").write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
