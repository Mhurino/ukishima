#!/usr/bin/env python3
"""Monitora gli sfondi attivi di Waywallen e aggiorna la palette Ukishima."""
from pathlib import Path
import importlib.util
import os
import sys
import time

BRIDGE_PATH = Path(__file__).with_name("waywallen-bridge.py")
spec = importlib.util.spec_from_file_location("ukishima_waywallen_bridge", BRIDGE_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError("Impossibile caricare il bridge Waywallen")

bridge = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = bridge
spec.loader.exec_module(bridge)

STATE_ROOT = Path(os.environ.get(
    "XDG_STATE_HOME", str(Path.home() / ".local/state")
))


def presentation_snapshot(event_bytes):
    """Estrae gli sfondi attivi dall'evento Waywallen."""
    event_fields = bridge.parse_fields(event_bytes)
    snapshot = bridge.first(event_fields, 26, 2)
    if snapshot is None:
        return None

    current = {}
    for number, wire, raw in bridge.parse_fields(snapshot):
        if number != 1 or wire != 2:
            continue

        fields = bridge.parse_fields(raw)
        wallpaper_id = bridge.text_field(fields, 1)
        state = int(bridge.first(fields, 3, 0, 0))
        targets = []

        for target_raw in bridge.values(fields, 2, 2):
            target_fields = bridge.parse_fields(target_raw)
            display_id = bridge.first(target_fields, 1, 0)
            canvas_id = bridge.text_field(target_fields, 2)

            if display_id is not None:
                targets.append(("display", int(display_id)))
            elif canvas_id:
                targets.append(("canvas", canvas_id))

        if wallpaper_id:
            current[wallpaper_id] = (state, tuple(targets))

    return current


def catalog_entry(wallpaper_id):
    """Interroga il catalogo su una connessione separata da quella monitorata."""
    connection = None
    bridge.PENDING_EVENTS.clear()
    try:
        connection = bridge.connect_ws()
        items = bridge.list_wallpapers(connection, 9101)
        return next(
            (item for item in items if str(item.get("id")) == wallpaper_id),
            None,
        )
    finally:
        if connection is not None:
            connection.close()
        bridge.PENDING_EVENTS.clear()


def already_synced(item):
    """Evita un secondo ricalcolo quando Super+W ha già aggiornato la palette."""
    source = bridge.palette_source_for_item(item)
    if not source:
        return False
    state_file = STATE_ROOT / "ukishima-wallpaper-palette-source"
    try:
        return state_file.read_text(encoding="utf-8").strip() == source
    except OSError:
        return False


def watch_connection():
    connection = bridge.connect_ws()
    # Una sessione inattiva deve restare in ascolto, senza riconnettersi
    # periodicamente e ricalcolare inutilmente la palette.
    connection.settimeout(None)
    previous = None

    print("In ascolto degli sfondi Waywallen...", flush=True)
    try:
        while True:
            frame = bridge.parse_fields(bridge.ws_recv_message(connection))
            event_bytes = bridge.first(frame, 2, 2)
            if event_bytes is None:
                continue

            current = presentation_snapshot(event_bytes)
            if current is None:
                continue

            if previous is None:
                changed = [
                    wid for wid, (state, _) in current.items()
                    if state == 2
                ]
            else:
                changed = [
                    wid for wid, value in current.items()
                    if value[0] == 2 and previous.get(wid) != value
                ]

            previous = current
            if not changed:
                continue

            # La palette di Ukishima è globale: usa l'ultima presentazione
            # attiva cambiata nel singolo evento.
            wallpaper_id = changed[-1]
            try:
                item = catalog_entry(wallpaper_id)
                if item is None:
                    print(
                        f"Wallpaper {wallpaper_id} non trovato nel catalogo.",
                        file=sys.stderr, flush=True,
                    )
                    continue

                if already_synced(item):
                    print(
                        f"Palette già aggiornata: {item.get('name', wallpaper_id)}",
                        flush=True,
                    )
                    continue

                bridge.sync_shell_palette(item, STATE_ROOT)
                print(
                    f"Palette sincronizzata: {item.get('name', wallpaper_id)}",
                    flush=True,
                )
            except Exception as error:
                print(
                    f"Errore aggiornando la palette: {error}",
                    file=sys.stderr, flush=True,
                )
    finally:
        connection.close()


def main():
    while True:
        try:
            watch_connection()
        except KeyboardInterrupt:
            return
        except Exception as error:
            print(
                f"Connessione Waywallen persa: {error}; nuovo tentativo tra 3 s.",
                file=sys.stderr, flush=True,
            )
            time.sleep(3)


if __name__ == "__main__":
    main()
