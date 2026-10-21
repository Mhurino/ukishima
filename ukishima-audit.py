#!/usr/bin/env python3
import difflib
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

UPSTREAM = "https://raw.githubusercontent.com/amanhex/Ukishima/main"
FILES = [
    "surfaces/BatterySurface.qml",
    "surfaces/RightClickSurface.qml",
    "surfaces/TimerSurface.qml",
    "surfaces/Wallpaper.qml",
    "launch.sh",
]

def git_root():
    try:
        return Path(subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            text=True, stderr=subprocess.DEVNULL
        ).strip())
    except Exception:
        sys.exit("Errore: esegui lo script dentro il repository Git di Ukishima.")

def main():
    root = git_root()
    report = root / "ukishima-audit-report.txt"
    output = []

    def emit(s=""):
        print(s)
        output.append(s)

    emit(f"Repository: {root}")
    emit("Audit in sola lettura: nessun file del progetto viene modificato.")
    emit(f"Branch: {subprocess.getoutput('git -C ' + repr(str(root)) + ' branch --show-current')}")
    emit()

    for rel in FILES:
        local = root / rel
        emit("=" * 78)
        emit(f"FILE: {rel}")
        emit("=" * 78)

        if not local.is_file():
            emit("Nel fork: FILE ASSENTE")
            emit()
            continue

        try:
            local_text = local.read_text(encoding="utf-8", errors="replace")
        except OSError as e:
            emit(f"Errore lettura file locale: {e}")
            continue

        emit(f"Nel fork: presente ({len(local_text.splitlines())} righe)")
        emit("--- CODICE LOCALE ---")
        emit(local_text)

        url = f"{UPSTREAM}/{rel}"
        try:
            req = urllib.request.Request(
                url, headers={"User-Agent": "ukishima-readonly-audit"}
            )
            with urllib.request.urlopen(req, timeout=15) as response:
                upstream_text = response.read().decode("utf-8", errors="replace")
        except Exception as e:
            emit(f"Upstream non scaricabile ({url}): {e}")
            emit()
            continue

        emit("--- DIFF: fork -> upstream main ---")
        diff = difflib.unified_diff(
            local_text.splitlines(),
            upstream_text.splitlines(),
            fromfile=f"fork/{rel}",
            tofile=f"upstream-main/{rel}",
            lineterm=""
        )
        diff_lines = list(diff)
        emit("\n".join(diff_lines) if diff_lines else "Nessuna differenza testuale.")
        emit()

    report.write_text("\n".join(output) + "\n", encoding="utf-8")
    print(f"\nReport salvato in: {report}")

if __name__ == "__main__":
    main()
