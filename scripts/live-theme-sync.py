#!/usr/bin/env python3
"""Synchronize Ukishima wallpaper colors with Qt6ct and KDE/KColorScheme.

Default mode validates without writing. --apply updates the private Qt6ct
palette and a separate KDE color scheme, then notifies running KDE apps.
Existing Nordic.colors, widget styles, fonts, icons and GTK theme names are
not edited. No configuration backups are created.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

HOME = Path.home()
COLORS_FILE = HOME / ".cache/ukishima/colors.json"
QT_CONFIG = HOME / ".config/qt6ct/qt6ct.conf"
QT_SCHEME = HOME / ".config/qt6ct/colors/ukishima-live.conf"
KDE_GLOBALS = HOME / ".config/kdeglobals"
DOLPHIN_CONFIG = HOME / ".config/dolphinrc"
KDE_SCHEME = HOME / ".local/share/color-schemes/UkishimaLive.colors"
KDE_GROUPS = (
    "Colors:Button",
    "Colors:Header",
    "Colors:Selection",
    "Colors:Tooltip",
    "Colors:View",
    "Colors:Window",
)
SCHEME_ID = "UkishimaLive"


def rgb(value):
    if not isinstance(value, str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
        raise ValueError(f"Colore non valido: {value!r}")
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def mix(a, b, amount):
    ca, cb = rgb(a), rgb(b)
    out = [round(x * (1 - amount) + y * amount) for x, y in zip(ca, cb)]
    return "#" + "".join(f"{v:02x}" for v in out)


def rgb_csv(value):
    return ",".join(str(v) for v in rgb(value))


def qt_color(value):
    rgb(value)
    return "#ff" + value[1:].lower()


def validate_colors(colors):
    required = [
        "surface", "surface_container", "surface_container_low",
        "surface_container_high", "surface_container_highest",
        "outline_variant", "primary", "primary_container",
        "on_primary_container", "outline", "cream", "bright",
        "subtle", "dim", "faint",
    ]
    for key in required:
        if key not in colors:
            raise ValueError(f"Chiave mancante in colors.json: {key}")
        rgb(colors[key])


def make_qt_palette(colors):
    validate_colors(colors)
    surface = colors["surface"]
    active = [
        colors["cream"],
        colors["surface_container"],
        mix(colors["surface_container_highest"], colors["bright"], 0.35),
        mix(colors["surface_container_high"], colors["bright"], 0.12),
        mix(surface, "#000000", 0.30),
        colors["outline_variant"],
        colors["cream"],
        colors["bright"],
        colors["cream"],
        surface,
        colors["surface_container_low"],
        mix(surface, "#000000", 0.55),
        colors["primary"],
        surface,
        colors["primary"],
        colors["primary"],
        colors["surface_container"],
        surface,
        colors["surface_container_highest"],
        colors["cream"],
        colors["subtle"],
    ]
    inactive = list(active)
    disabled = [
        colors["dim"],
        colors["surface_container_low"],
        colors["surface_container_high"],
        colors["surface_container"],
        surface,
        colors["outline_variant"],
        colors["dim"],
        colors["bright"],
        colors["dim"],
        surface,
        colors["surface_container_low"],
        mix(surface, "#000000", 0.55),
        colors["primary"],
        surface,
        colors["primary"],
        colors["primary"],
        colors["surface_container_low"],
        surface,
        colors["surface_container_high"],
        colors["dim"],
        colors["faint"],
    ]
    if any(len(group) != 21 for group in (active, inactive, disabled)):
        raise ValueError("Ogni gruppo QPalette deve contenere 21 colori")
    rows = ["[ColorScheme]"]
    for name, group in (
        ("active_colors", active),
        ("inactive_colors", inactive),
        ("disabled_colors", disabled),
    ):
        rows.append(name + "=" + ", ".join(qt_color(c) for c in group))
    return "\n".join(rows) + "\n"


def kde_color_group(name, background, alternate, foreground, muted, colors):
    values = {
        "BackgroundAlternate": alternate,
        "BackgroundNormal": background,
        "DecorationFocus": colors["primary"],
        "DecorationHover": colors["primary"],
        "ForegroundActive": colors["primary"],
        "ForegroundInactive": muted,
        "ForegroundLink": colors["primary"],
        "ForegroundNegative": "#bf616a",
        "ForegroundNeutral": colors["outline"],
        "ForegroundNormal": foreground,
        "ForegroundPositive": "#a3be8c",
        "ForegroundVisited": colors["primary_container"],
    }
    return "[" + name + "]\n" + "".join(
        f"{key}={rgb_csv(value)}\n" for key, value in values.items()
    )


def make_kde_scheme(colors):
    validate_colors(colors)
    sections = {
        "Colors:Button": kde_color_group(
            "Colors:Button", colors["surface_container_high"],
            colors["surface_container"], colors["cream"], colors["dim"], colors,
        ),
        "Colors:Header": kde_color_group(
            "Colors:Header", colors["surface_container"],
            colors["surface_container_low"], colors["cream"], colors["dim"], colors,
        ),
        "Colors:Header][Inactive": kde_color_group(
            "Colors:Header][Inactive", colors["surface_container"],
            colors["surface_container_low"], colors["cream"], colors["dim"], colors,
        ),
        "Colors:Selection": kde_color_group(
            "Colors:Selection", colors["primary_container"],
            colors["primary_container"], colors["on_primary_container"],
            colors["cream"], colors,
        ),
        "Colors:Tooltip": kde_color_group(
            "Colors:Tooltip", colors["surface_container_highest"],
            colors["surface_container_high"], colors["bright"],
            colors["subtle"], colors,
        ),
        "Colors:View": kde_color_group(
            "Colors:View", colors["surface"], colors["surface_container_low"],
            colors["cream"], colors["dim"], colors,
        ),
        "Colors:Window": kde_color_group(
            "Colors:Window", colors["surface_container"],
            colors["surface_container_low"], colors["cream"],
            colors["dim"], colors,
        ),
    }
    preamble = (
        "[General]\n"
        f"ColorScheme={SCHEME_ID}\n"
        "Name=Ukishima Live\n\n"
        "[ColorEffects:Disabled]\n"
        "Color=56,56,56\nColorAmount=0\nColorEffect=0\n"
        "ContrastAmount=0.65\nContrastEffect=1\n"
        "IntensityAmount=0.1\nIntensityEffect=2\n\n"
        "[ColorEffects:Inactive]\n"
        "ChangeSelectionColor=true\nColor=112,111,110\n"
        "ColorAmount=0.025\nColorEffect=2\n"
        "ContrastAmount=0.1\nContrastEffect=2\nEnable=false\n"
        "IntensityAmount=0\nIntensityEffect=0\n\n"
    )
    return preamble + "\n".join(sections.values()), sections


def patch_appearance(text):
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = text.splitlines(keepends=True)
    header_re = re.compile(r"^\s*\[([^]]+)\]")
    start = None
    end = len(lines)
    for i, line in enumerate(lines):
        match = header_re.match(line)
        if not match:
            continue
        if start is None and match.group(1).strip().lower() == "appearance":
            start = i + 1
        elif start is not None:
            end = i
            break
    if start is None:
        if text and not text.endswith(("\n", "\r")):
            lines.append(newline)
        if lines and lines[-1].strip():
            lines.append(newline)
        lines.append("[Appearance]" + newline)
        start = len(lines)
        end = len(lines)
    updates = {
        "color_scheme_path": str(QT_SCHEME),
        "custom_palette": "true",
    }
    additions = []
    for key, value in updates.items():
        found = [i for i in range(start, end) if re.match(
            r"^\s*" + re.escape(key) + r"\s*=", lines[i], re.I
        )]
        if len(found) > 1:
            raise ValueError(f"Chiave duplicata nella sezione [Appearance]: {key}")
        if found:
            i = found[0]
            ending = "\r\n" if lines[i].endswith("\r\n") else ("\n" if lines[i].endswith("\n") else "")
            prefix = re.match(r"^(\s*[^=]+?=\s*)", lines[i]).group(1)
            lines[i] = prefix + value + ending
        else:
            additions.append(f"{key}={value}{newline}")
    for offset, line in enumerate(additions):
        lines.insert(start + offset, line)
    return "".join(lines)


def section_bounds(text, section):
    lines = text.splitlines(keepends=True)
    target_header = "[" + section + "]"
    header_re = re.compile(r"^\s*((?:\[[^]]+\])+)\s*(?:[;#].*)?$")
    target = None
    end = len(lines)

    for i, line in enumerate(lines):
        match = header_re.match(line.rstrip("\r\n"))
        if not match:
            continue
        if target is None and match.group(1) == target_header:
            target = i
        elif target is not None:
            end = i
            break

    return lines, target, end


def get_ini_value(text, section, key):
    lines, start, end = section_bounds(text, section)
    if start is None:
        return None
    pattern = re.compile(r"^\s*" + re.escape(key) + r"\s*=(.*)$", re.I)
    for line in lines[start + 1:end]:
        match = pattern.match(line.rstrip("\r\n"))
        if match:
            return match.group(1).strip()
    return None


def set_ini_key(text, section, key, value):
    lines, start, end = section_bounds(text, section)
    pattern = re.compile(r"^\s*" + re.escape(key) + r"\s*=", re.I)
    if start is None:
        if value is None:
            return text
        if text and not text.endswith("\n"):
            text += "\n"
        if text and not text.endswith("\n\n"):
            text += "\n"
        return text + f"[{section}]\n{key}={value}\n"

    matches = [i for i in range(start + 1, end) if pattern.match(lines[i])]
    if value is None:
        for i in reversed(matches):
            del lines[i]
    elif matches:
        i = matches[0]
        ending = "\r\n" if lines[i].endswith("\r\n") else ("\n" if lines[i].endswith("\n") else "")
        lines[i] = f"{key}={value}{ending}"
        for duplicate in reversed(matches[1:]):
            del lines[duplicate]
    else:
        lines.insert(start + 1, f"{key}={value}\n")
    return "".join(lines)


def get_ini_section(text, section):
    lines, start, end = section_bounds(text, section)
    if start is None:
        return None
    return "".join(lines[start:end])


def replace_ini_section(text, section, block):
    lines, start, end = section_bounds(text, section)
    if start is not None:
        replacement = [] if block is None else block.rstrip("\r\n").splitlines(keepends=True)
        if block is not None and replacement and not replacement[-1].endswith(("\n", "\r")):
            replacement[-1] += "\n"
        lines[start:end] = replacement
        return "".join(lines)
    if block is None:
        return text
    if text and not text.endswith("\n"):
        text += "\n"
    if text and not text.endswith("\n\n"):
        text += "\n"
    return text + block.rstrip("\r\n") + "\n"


def atomic_write(path, content, default_mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else default_mode
    fd, tmp_name = tempfile.mkstemp(prefix="." + path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(tmp_name, mode)
        os.replace(tmp_name, path)
    except Exception:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass
        raise


def apply_kde(colors, kde_scheme_text, kde_sections):
    kde_text = KDE_GLOBALS.read_text(encoding="utf-8") if KDE_GLOBALS.exists() else ""
    kde_text = set_ini_key(kde_text, "General", "ColorScheme", SCHEME_ID)
    for group, block in kde_sections.items():
        kde_text = replace_ini_section(kde_text, group, block)

    dolphin_text = DOLPHIN_CONFIG.read_text(encoding="utf-8") if DOLPHIN_CONFIG.exists() else ""
    # Remove the per-application Nordic pin: Dolphin now follows KDE's live system palette.
    dolphin_text = set_ini_key(dolphin_text, "UiSettings", "ColorScheme", None)

    atomic_write(KDE_SCHEME, kde_scheme_text, 0o644)
    atomic_write(KDE_GLOBALS, kde_text)
    if DOLPHIN_CONFIG.exists() or dolphin_text:
        atomic_write(DOLPHIN_CONFIG, dolphin_text)


def notify_kde_palette_changed():
    # KGlobalSettings::PaletteChanged = 0. This is a D-Bus signal, not a method.
    gdbus = shutil.which("gdbus")
    if gdbus:
        result = subprocess.run(
            [gdbus, "emit", "--session", "--object-path", "/KGlobalSettings",
             "--signal", "org.kde.KGlobalSettings.notifyChange", "0", "0"],
            check=False, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
        )
        if result.returncode == 0:
            return True
        print(f"Notifica KDE non inviata: {result.stderr.strip()}", file=sys.stderr)
    dbus_send = shutil.which("dbus-send")
    if dbus_send:
        result = subprocess.run(
            [dbus_send, "--session", "--type=signal", "/KGlobalSettings",
             "org.kde.KGlobalSettings.notifyChange", "int32:0", "int32:0"],
            check=False, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
        )
        if result.returncode == 0:
            return True
        print(f"Notifica KDE non inviata: {result.stderr.strip()}", file=sys.stderr)
    print("Avviso: gdbus/dbus-send non disponibile; riaprire Dolphin per vedere la palette.", file=sys.stderr)
    return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="applica le palette Qt6ct e KDE")
    parser.add_argument("--dry-run", action="store_true", help="verifica senza modificare file (predefinito)")
    args = parser.parse_args()

    if not COLORS_FILE.is_file():
        raise FileNotFoundError(f"File colori Ukishima non trovato: {COLORS_FILE}")
    if not QT_CONFIG.is_file():
        raise FileNotFoundError(f"Configurazione Qt6ct non trovata: {QT_CONFIG}")

    colors = json.loads(COLORS_FILE.read_text(encoding="utf-8"))
    qt_scheme = make_qt_palette(colors)
    kde_scheme, kde_sections = make_kde_scheme(colors)
    qt_config = QT_CONFIG.read_text(encoding="utf-8")
    updated_qt_config = patch_appearance(qt_config)

    if not args.apply:
        print("TEST OK: colori Ukishima validi.")
        print("Qt6ct: 21 colori per ciascuno dei 3 gruppi.")
        print("KDE: 6 gruppi colore (Button, Header, Selection, Tooltip, View, Window).")
        print(f"Palette Qt6ct: {QT_SCHEME}")
        print(f"Palette KDE: {KDE_SCHEME}")
        print("Dolphin seguirà la palette KDE di sistema; Nordic.colors resta intatto.")
        print("Nessun file è stato modificato. Per applicare: aggiungi --apply.")
        return

    atomic_write(QT_SCHEME, qt_scheme, 0o644)
    atomic_write(QT_CONFIG, updated_qt_config)
    apply_kde(colors, kde_scheme, kde_sections)
    notified = notify_kde_palette_changed()
    print("Palette Ukishima applicata a Qt6ct e KDE.")
    print(f"Palette KDE: {KDE_SCHEME}")
    print("Notifica cambio palette KDE inviata." if notified else "Palette scritta; notifica live non disponibile.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Errore live-theme-sync: {exc}", file=sys.stderr)
        sys.exit(1)
