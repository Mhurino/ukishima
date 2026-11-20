#!/usr/bin/env python3
"""Misura PSS/Private RAM di Quickshell durante l'apertura delle superfici."""

import argparse
import csv
import os
import statistics
import time
from datetime import datetime
from pathlib import Path

HOME = Path.home()
STATE = Path(os.environ.get("XDG_STATE_HOME", str(HOME / ".local/state")))
FIELDS = ("Pss", "Private_Clean", "Private_Dirty", "Private_Hugetlb", "SwapPss")

def read_memory(pid):
    values = {}
    try:
        for line in Path(f"/proc/{pid}/smaps_rollup").read_text().splitlines():
            parts = line.split()
            if len(parts) >= 2 and parts[1].isdigit():
                values[parts[0].rstrip(":")] = int(parts[1])
    except (OSError, PermissionError):
        return None
    return values

def quickshell_processes():
    result = []
    proc = Path("/proc")
    try:
        pids = [p for p in proc.iterdir() if p.name.isdigit()]
    except OSError:
        return result

    for entry in pids:
        pid = int(entry.name)
        try:
            comm = (entry / "comm").read_text().strip()
            if comm.lower() not in ("qs", "quickshell"):
                continue
            cmdline = (entry / "cmdline").read_bytes().replace(b"\0", b" ").decode(
                errors="replace"
            ).strip()
            mem = read_memory(pid)
            if mem is None:
                continue
            private = sum(mem.get(k, 0) for k in
                          ("Private_Clean", "Private_Dirty", "Private_Hugetlb"))
            result.append({
                "pid": pid,
                "comm": comm,
                "cmdline": cmdline,
                "pss": mem.get("Pss", 0),
                "private": private,
                "swap_pss": mem.get("SwapPss", 0),
            })
        except (OSError, ProcessLookupError):
            continue
    return result

def snapshot():
    processes = quickshell_processes()
    return {
        "pss": sum(p["pss"] for p in processes),
        "private": sum(p["private"] for p in processes),
        "swap_pss": sum(p["swap_pss"] for p in processes),
        "processes": processes,
    }

def average_snapshot(seconds=5):
    samples = []
    for i in range(seconds):
        samples.append(snapshot())
        if i + 1 < seconds:
            time.sleep(1)
    return {
        key: round(statistics.mean(s[key] for s in samples))
        for key in ("pss", "private", "swap_pss")
    }

def mib(kib):
    return kib / 1024.0

def show_current():
    data = snapshot()
    if not data["processes"]:
        print("Nessun processo Quickshell (qs) trovato.")
        return
    print("Memoria Quickshell — lettura PSS da /proc/*/smaps_rollup")
    for p in data["processes"]:
        print(
            f"PID {p['pid']:>7}  "
            f"PSS {mib(p['pss']):8.1f} MiB  "
            f"Privata {mib(p['private']):8.1f} MiB  "
            f"SwapPSS {mib(p['swap_pss']):6.1f} MiB"
        )
        if p["cmdline"]:
            print("          ", p["cmdline"][:180])
    print("-" * 62)
    print(f"PSS totale:       {mib(data['pss']):.1f} MiB")
    print(f"Memoria privata:  {mib(data['private']):.1f} MiB")
    print(f"Swap PSS:         {mib(data['swap_pss']):.1f} MiB")

def guided():
    print("\nTEST GUIDATO DELLE SUPERFICI UKISHIMA")
    print("Chiudi tutte le superfici e lascia la pill nello stato normale.")
    input("Quando sei pronto, premi INVIO per misurare la baseline... ")

    baseline = average_snapshot(5)
    print(f"Baseline Quickshell: PSS {mib(baseline['pss']):.1f} MiB")

    out_dir = STATE / "ukishima" / "memory-bench"
    out_dir.mkdir(parents=True, exist_ok=True)
    output = out_dir / (
        "surface-memory-" + datetime.now().strftime("%Y%m%d-%H%M%S") + ".csv"
    )

    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow([
            "timestamp", "surface", "phase",
            "pss_mib", "private_mib", "swap_pss_mib"
        ])

        def record(label, phase, data):
            writer.writerow([
                datetime.now().isoformat(timespec="seconds"),
                label, phase,
                round(mib(data["pss"]), 2),
                round(mib(data["private"]), 2),
                round(mib(data["swap_pss"]), 2),
            ])
            handle.flush()

        record("BASELINE", "closed", baseline)

        while True:
            label = input(
                "\nNome della prossima superficie da testare "
                "(es. wallpaper, clipboard, scratch; INVIO per terminare): "
            ).strip()
            if not label:
                break

            input(f"Apri '{label}', attendi che sia completamente visibile, "
                  "poi premi INVIO... ")
            opened = average_snapshot(5)
            record(label, "open", opened)

            input(f"Chiudi '{label}', attendi il ritorno alla pill, "
                  "poi premi INVIO... ")
            closed = average_snapshot(5)
            record(label, "closed", closed)

            print(
                f"  Aperta: PSS {mib(opened['pss']):.1f} MiB "
                f"({mib(opened['pss'] - baseline['pss']):+.1f} rispetto alla baseline)"
            )
            print(
                f"  Chiusa: PSS {mib(closed['pss']):.1f} MiB "
                f"({mib(closed['pss'] - baseline['pss']):+.1f} rispetto alla baseline)"
            )
            print(
                f"  Recupero dopo la chiusura: "
                f"{mib(opened['pss'] - closed['pss']):.1f} MiB"
            )

    print("\nMisurazioni salvate in:")
    print(output)
    print("Nota: PSS misura la quota proporzionale di memoria del processo; "
          "non attribuisce ogni byte a un singolo oggetto QML.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--guided", action="store_true",
        help="test interattivo della memoria aprendo/chiudendo le superfici"
    )
    args = parser.parse_args()
    if args.guided:
        guided()
    else:
        show_current()
