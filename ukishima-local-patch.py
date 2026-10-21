#!/usr/bin/env python3
from pathlib import Path
from datetime import datetime
import difflib
import subprocess
import sys

def stop(message):
    raise SystemExit(f"\nERRORE: {message}")

# Individua il repository senza presumere dove sia installato.
try:
    ROOT = Path(subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"],
        text=True,
        stderr=subprocess.DEVNULL
    ).strip())
except Exception:
    stop("Apri il terminale dentro il repository Git di Ukishima.")

battery = ROOT / "surfaces/BatterySurface.qml"
launcher = ROOT / "launch.sh"

if not battery.is_file():
    stop(f"File non trovato: {battery}")
if not launcher.is_file():
    stop(f"File non trovato: {launcher}")

original_battery = battery.read_text(encoding="utf-8")
original_launcher = launcher.read_text(encoding="utf-8")

new_battery = original_battery
new_launcher = original_launcher

# 1. Clipping del meter batteria.
marker = "id: meter"
start = new_battery.find(marker)

if start < 0:
    stop("Non trovo 'id: meter' in BatterySurface.qml.")

color_pos = new_battery.find("color: Theme.threadBg", start)
if color_pos < 0:
    stop("Non trovo il colore atteso del meter batteria.")

# Controlla che il colore trovato appartenga al blocco del meter.
close_pos = new_battery.find("\n        }", start)
if close_pos >= 0 and close_pos < color_pos:
    stop("La struttura del meter è diversa da quella attesa.")

line_end = new_battery.find("\n", color_pos)
if line_end < 0:
    line_end = len(new_battery)

meter_block = new_battery[start:line_end + 1]

if "clip: true" not in meter_block:
    line_start = new_battery.rfind("\n", 0, color_pos) + 1
    indent = new_battery[line_start:color_pos]
    new_battery = (
        new_battery[:line_end + 1]
        + indent + "clip: true\n"
        + new_battery[line_end + 1:]
    )
    print("[MODIFICA] BatterySurface.qml: aggiunto clip: true")
else:
    print("[OK] BatterySurface.qml: clip già presente")

# 2. Restituzione della memoria libera al sistema.
old_conf = (
    ': "${MALLOC_CONF:=background_thread:true,'
    'dirty_decay_ms:100,muzzy_decay_ms:100}"'
)
new_conf = (
    ': "${MALLOC_CONF:=background_thread:true,'
    'retain:false,dirty_decay_ms:100,muzzy_decay_ms:100}"'
)

if old_conf in new_launcher:
    new_launcher = new_launcher.replace(old_conf, new_conf, 1)
    print("[MODIFICA] launch.sh: aggiunto retain:false al default")
elif new_conf in new_launcher:
    print("[OK] launch.sh: retain:false già presente")
else:
    stop(
        "La configurazione MALLOC_CONF non corrisponde a quella attesa. "
        "Non ho applicato modifiche."
    )

changes = []
if new_battery != original_battery:
    changes.append((battery, original_battery, new_battery))
if new_launcher != original_launcher:
    changes.append((launcher, original_launcher, new_launcher))

if not changes:
    print("\nNessuna modifica necessaria.")
    sys.exit(0)

# Backup prima di scrivere qualsiasi file.
stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backups = []

for path, old, new in changes:
    backup = path.with_name(path.name + ".bak-" + stamp)
    if backup.exists():
        stop(f"Il backup esiste già: {backup}")
    backups.append((path, backup, old, new))

for path, backup, old, new in backups:
    backup.write_text(old, encoding="utf-8")
    print(f"[BACKUP] {backup}")

try:
    for path, backup, old, new in backups:
        path.write_text(new, encoding="utf-8")
except Exception as exc:
    # Ripristino dei file coinvolti in caso di errore di scrittura.
    for path, backup, old, new in backups:
        path.write_text(old, encoding="utf-8")
    stop(f"Scrittura fallita; file ripristinati. Dettaglio: {exc}")

print("\n=== DIFF DELLE MODIFICHE LOCALI ===")
for path, old, new in changes:
    diff = difflib.unified_diff(
        old.splitlines(True),
        new.splitlines(True),
        fromfile=str(path.relative_to(ROOT)),
        tofile=str(path.relative_to(ROOT)) + " (modificato localmente)"
    )
    sys.stdout.writelines(diff)

print("\nCompletato. Nessun commit e nessun push sono stati eseguiti.")
print("Verifica ora il risultato con:")
print(f"  git -C '{ROOT}' diff --check")
print(f"  git -C '{ROOT}' diff -- surfaces/BatterySurface.qml launch.sh")
