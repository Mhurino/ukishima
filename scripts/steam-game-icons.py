#!/usr/bin/env python3
import os
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

HOME = Path.home()
CACHE = Path(os.environ.get("XDG_CACHE_HOME", str(HOME / ".cache"))) / "ukishima/steam-icons"
MAP = CACHE / "active.json"

def read_env(pid):
    try:
        raw = Path("/proc/%s/environ" % pid).read_bytes()
        result = {}
        for item in raw.split(bytes([0])):
            if b"=" in item:
                k, v = item.split(b"=", 1)
                result[k.decode(errors="replace")] = v.decode(errors="replace")
        return result
    except OSError:
        return {}

def parent_pid(pid):
    try:
        stat = Path("/proc/%s/stat" % pid).read_text()
        return int(stat[stat.rfind(")") + 2:].split()[1])
    except (OSError, ValueError, IndexError):
        return 0

def find_steam_env(pid):
    current = int(pid)
    for _ in range(12):
        env = read_env(current)
        for key in ("SteamGameId", "SteamAppId",
                    "STEAM_COMPAT_APP_ID", "SteamOverlayGameId"):
            appid = env.get(key, "")
            if appid.isdigit() and appid != "0":
                return appid, env
        current = parent_pid(current)
        if current <= 1:
            break
    return "", {}

def get_libraries():
    roots = [
        HOME / ".local/share/Steam",
        HOME / ".steam/steam",
        HOME / ".steam/root"
    ]
    found = list(roots)

    for root in roots:
        vdf = root / "steamapps/libraryfolders.vdf"
        if not vdf.is_file():
            continue
        for line in vdf.read_text(errors="replace").splitlines():
            parts = line.strip().split(chr(34))
            if len(parts) >= 4 and parts[1] == "path":
                found.append(Path(parts[3]))

    result = []
    for item in found:
        try:
            resolved = item.expanduser().resolve()
            if resolved not in result:
                result.append(resolved)
        except OSError:
            pass
    return result

def get_game_folder(appid, env):
    direct = env.get("STEAM_COMPAT_INSTALL_PATH", "")
    if direct and Path(direct).is_dir():
        return Path(direct)

    for library in get_libraries():
        manifest = library / "steamapps" / ("appmanifest_" + appid + ".acf")
        if not manifest.is_file():
            continue
        for line in manifest.read_text(errors="replace").splitlines():
            parts = line.strip().split(chr(34))
            if len(parts) >= 4 and parts[1] == "installdir":
                folder = library / "steamapps/common" / parts[3]
                if folder.is_dir():
                    return folder
    return None

def get_exe_names(pid):
    names = []
    try:
        args = Path("/proc/%s/cmdline" % pid).read_bytes().split(bytes([0]))
        for arg in args:
            value = arg.decode(errors="replace").replace(chr(92), "/")
            name = value.rsplit("/", 1)[-1].strip()
            if name.lower().endswith(".exe") and name.lower() not in names:
                names.append(name.lower())
    except OSError:
        pass
    try:
        comm = Path("/proc/%s/comm" % pid).read_text().strip()
        if comm and not comm.lower().endswith(".exe"):
            names.append((comm + ".exe").lower())
    except OSError:
        pass
    return names

def find_exe(pid, folder):
    if not folder:
        return None
    names = get_exe_names(pid)
    if not names:
        return None
    for parent, dirs, files in os.walk(folder):
        dirs[:] = [d for d in dirs if d.lower() not in
                   ("redist", "redistributables", "_commonredist", "support")]
        for filename in files:
            if filename.lower() in names:
                return Path(parent) / filename
    return None

def largest_png(folder):
    files = list(folder.rglob("*.png"))
    if not files:
        return None
    def score(path):
        for part in path.stem.split("_"):
            if "x" in part:
                dims = part.split("x")
                if len(dims) >= 2 and dims[0].isdigit() and dims[1].isdigit():
                    return int(dims[0]) * int(dims[1])
        return 0
    return max(files, key=score)

def extract_icon(appid, pid, env):
    folder = CACHE / appid
    folder.mkdir(parents=True, exist_ok=True)
    icon = folder / "icon.png"

    if icon.is_file() and icon.stat().st_size:
        return str(icon)

    old = largest_png(folder / "png") if (folder / "png").is_dir() else None
    if old:
        shutil.copy2(old, icon)
        return str(icon)

    exe = find_exe(pid, get_game_folder(appid, env))
    if not exe:
        print("Eseguibile non trovato per AppID", appid)
        return ""

    listing = subprocess.run(
        ["wrestool", "-l", "--type=group_icon", str(exe)],
        capture_output=True, text=True
    )
    if listing.returncode or not listing.stdout.strip():
        print("Nessuna icona incorporata:", exe)
        return ""

    with tempfile.TemporaryDirectory(dir=folder) as tmp:
        ico_dir = Path(tmp) / "ico"
        png_dir = Path(tmp) / "png"
        ico_dir.mkdir()
        png_dir.mkdir()

        result = subprocess.run(
            ["wrestool", "-x", "--output=" + str(ico_dir), "-t14", str(exe)],
            capture_output=True
        )
        if result.returncode:
            return ""

        for ico in ico_dir.rglob("*.ico"):
            subprocess.run(
                ["icotool", "-x", "--output=" + str(png_dir), str(ico)],
                capture_output=True
            )

        selected = largest_png(png_dir)
        if selected:
            shutil.copy2(selected, icon)
            print("Icona estratta da:", exe)
            return str(icon)
    return ""

def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        ["hyprctl", "clients", "-j"],
        capture_output=True, text=True
    )
    if result.returncode:
        raise SystemExit("Impossibile leggere Hyprland.")

    clients = json.loads(result.stdout)
    active = {}

    for client in clients:
        pid = int(client.get("pid") or 0)
        if pid <= 0:
            continue

        appid, env = find_steam_env(pid)
        if not appid:
            continue

        title = str(client.get("title") or client.get("class") or appid)
        icon = extract_icon(appid, pid, env)
        info = {"appid": appid, "name": title, "icon": icon}

        for key in (client.get("class"), client.get("initialClass")):
            if key:
                active[str(key).lower()] = info

    data = json.dumps(active, ensure_ascii=False, indent=2, sort_keys=True)
    if not MAP.exists() or MAP.read_text() != data:
        tmp = MAP.with_suffix(".tmp")
        tmp.write_text(data + "\n")
        tmp.replace(MAP)

    print("Giochi Steam rilevati:", len(active))
    for key, info in active.items():
        print(key, "| AppID:", info["appid"], "| Icona:", info["icon"] or "non trovata")

if __name__ == "__main__":
    main()
