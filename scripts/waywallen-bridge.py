#!/usr/bin/env python3
"""Minimal stdlib WebSocket/protobuf bridge to Waywallen's local control API."""
from __future__ import annotations
import base64, hashlib, json, os, random, re, socket, struct, subprocess, sys, time
from pathlib import Path
from urllib.parse import unquote, urlparse

BUS = "org.waywallen.waywallen.Daemon"
OBJ = "/org/waywallen/waywallen/Daemon"
IFACE = "org.waywallen.waywallen.Daemon1"
GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

# Eventi asincroni ricevuti durante le richieste al daemon.
PENDING_EVENTS = []
class BridgeError(RuntimeError): pass

def varint(value):
    value = int(value)
    out = bytearray()
    while value > 0x7f:
        out.append((value & 0x7f) | 0x80)
        value >>= 7
    out.append(value)
    return bytes(out)

def read_varint(data, pos):
    value = 0
    shift = 0
    while pos < len(data) and shift <= 70:
        b = data[pos]; pos += 1
        value |= (b & 0x7f) << shift
        if not (b & 0x80):
            return value, pos
        shift += 7
    raise BridgeError("messaggio protobuf con varint non valido")

def pb_bytes(field_no, value):
    if isinstance(value, str): value = value.encode("utf-8")
    return varint((field_no << 3) | 2) + varint(len(value)) + value

def pb_uint(field_no, value):
    return varint(field_no << 3) + varint(value)

def parse_fields(data):
    result = []
    pos = 0
    while pos < len(data):
        key, pos = read_varint(data, pos)
        number, wire = key >> 3, key & 7
        if number == 0: raise BridgeError("campo protobuf nullo")
        if wire == 0:
            value, pos = read_varint(data, pos)
        elif wire == 1:
            if pos + 8 > len(data): raise BridgeError("campo protobuf troncato")
            value, pos = data[pos:pos+8], pos+8
        elif wire == 2:
            length, pos = read_varint(data, pos)
            if pos + length > len(data): raise BridgeError("campo protobuf troncato")
            value, pos = data[pos:pos+length], pos+length
        elif wire == 5:
            if pos + 4 > len(data): raise BridgeError("campo protobuf troncato")
            value, pos = data[pos:pos+4], pos+4
        else:
            raise BridgeError("tipo protobuf non supportato")
        result.append((number, wire, value))
    return result

def values(fields, number, wire=None):
    return [v for n, w, v in fields if n == number and (wire is None or w == wire)]

def first(fields, number, wire=None, default=None):
    found = values(fields, number, wire)
    return found[0] if found else default

def text_field(fields, number, default=""):
    value = first(fields, number, 2)
    return value.decode("utf-8", "replace") if value is not None else default

def ws_send(sock, payload, opcode=2):
    length = len(payload)
    header = bytearray([0x80 | opcode])
    if length < 126:
        header.append(0x80 | length)
    elif length < 65536:
        header.append(0x80 | 126); header.extend(struct.pack("!H", length))
    else:
        header.append(0x80 | 127); header.extend(struct.pack("!Q", length))
    mask = os.urandom(4)
    header.extend(mask)
    masked = bytes(b ^ mask[i & 3] for i, b in enumerate(payload))
    sock.sendall(header + masked)

def recv_exact(sock, length):
    chunks = bytearray()
    while len(chunks) < length:
        chunk = sock.recv(length - len(chunks))
        if not chunk: raise BridgeError("connessione WebSocket chiusa")
        chunks.extend(chunk)
    return bytes(chunks)

def ws_recv_frame(sock):
    head = recv_exact(sock, 2)
    fin, opcode = bool(head[0] & 0x80), head[0] & 0x0f
    masked, length = bool(head[1] & 0x80), head[1] & 0x7f
    if length == 126: length = struct.unpack("!H", recv_exact(sock, 2))[0]
    elif length == 127: length = struct.unpack("!Q", recv_exact(sock, 8))[0]
    mask = recv_exact(sock, 4) if masked else b""
    payload = recv_exact(sock, length)
    if masked: payload = bytes(b ^ mask[i & 3] for i, b in enumerate(payload))
    return fin, opcode, payload

def ws_recv_message(sock):
    parts = []
    started = False
    while True:
        fin, opcode, payload = ws_recv_frame(sock)
        if opcode == 9:
            ws_send(sock, payload, 10); continue
        if opcode == 10: continue
        if opcode == 8: raise BridgeError("Waywallen ha chiuso la connessione WebSocket")
        if opcode in (1, 2):
            parts = [payload]; started = True
        elif opcode == 0 and started:
            parts.append(payload)
        else:
            continue
        if fin:
            return b"".join(parts)

def get_ws_port():
    cmd = ["busctl", "--user", "get-property", BUS, OBJ, IFACE, "WsPort"]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=3)
        if proc.returncode == 0:
            match = re.search(r"\bq\s+(\d+)\b", proc.stdout)
            if match and int(match.group(1)) > 0: return int(match.group(1))
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    cmd = ["gdbus", "call", "--session", "--dest", BUS, "--object-path", OBJ,
           "--method", "org.freedesktop.DBus.Properties.Get", IFACE, "WsPort"]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=3)
        match = re.search(r"uint16\s+(\d+)", proc.stdout)
        if proc.returncode == 0 and match and int(match.group(1)) > 0:
            return int(match.group(1))
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    raise BridgeError("daemon Waywallen non raggiungibile sul bus D-Bus; verifica che il servizio sia avviato")

def connect_ws():
    port = get_ws_port()
    sock = socket.create_connection(("127.0.0.1", port), timeout=5)
    sock.settimeout(12)
    key = base64.b64encode(os.urandom(16)).decode("ascii")
    request = (f"GET / HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\n"
               f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n")
    sock.sendall(request.encode("ascii"))
    response = bytearray()
    while b"\r\n\r\n" not in response:
        chunk = sock.recv(4096)
        if not chunk: sock.close(); raise BridgeError("handshake WebSocket interrotto")
        response.extend(chunk)
        if len(response) > 16384: sock.close(); raise BridgeError("risposta HTTP inattesa dal daemon")
    head = bytes(response).split(b"\r\n\r\n", 1)[0].decode("latin1", "replace")
    expected = base64.b64encode(hashlib.sha1((key + GUID).encode("ascii")).digest()).decode("ascii")
    if " 101 " not in head or f"Sec-WebSocket-Accept: {expected}".lower() not in head.lower():
        sock.close(); raise BridgeError("il daemon Waywallen ha rifiutato la connessione WebSocket")
    return sock

def request(sock, request_id, request_field, body=b""):
    payload = pb_uint(1, request_id) + pb_bytes(request_field, body)
    ws_send(sock, payload)
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        frame = ws_recv_message(sock)
        # Conserva gli eventi ricevuti prima della risposta alla richiesta.
        frame_fields = parse_fields(frame)
        event = first(frame_fields, 2, 2)
        if event is not None:
            PENDING_EVENTS.append(event)
        response = first(frame_fields, 1, 2)
        if response is None: continue
        parsed = parse_fields(response)
        rid = first(parsed, 1, 0, 0)
        if rid != request_id: continue
        status = first(parsed, 2, 0, 1)
        error_code = first(parsed, 4, 0, 0)
        if status != 1 or error_code != 0:
            message = text_field(parsed, 3, "errore senza dettagli")
            raise BridgeError(f"Waywallen ha rifiutato l'operazione (codice {error_code}): {message}")
        return parsed
    raise BridgeError("timeout nella risposta del daemon Waywallen")

def list_wallpapers(sock, request_id):
    response = request(sock, request_id, 19)  # WallpaperListRequest, page_size=0 means all.
    body = first(response, 19, 2, b"")
    items = []
    for number, wire, item_bytes in parse_fields(body):
        if number != 1 or wire != 2: continue
        entry = parse_fields(item_bytes)
        items.append({
            "id": text_field(entry, 1),
            "name": text_field(entry, 2),
            "type": text_field(entry, 3),
            "resource": text_field(entry, 4),
            "preview": text_field(entry, 5),
        })
    return items

def scan_library(sock, request_id):
    # WallpaperScanRequest is field 20; scanning is asynchronous.
    request(sock, request_id, 20)


def wait_for_scan(sock, timeout=45):
    """Attende l'evento WallpaperSyncFinished del daemon Waywallen."""
    deadline = time.monotonic() + timeout
    previous_timeout = sock.gettimeout()

    try:
        while time.monotonic() < deadline:
            if PENDING_EVENTS:
                event_bytes = PENDING_EVENTS.pop(0)
            else:
                sock.settimeout(max(0.1, deadline - time.monotonic()))
                try:
                    frame_fields = parse_fields(ws_recv_message(sock))
                except socket.timeout:
                    break

                event_bytes = first(frame_fields, 2, 2)
                if event_bytes is None:
                    continue

            event_fields = parse_fields(event_bytes)
            sync = first(event_fields, 11, 2)
            if sync is None:
                continue

            sync_fields = parse_fields(sync)
            error = text_field(sync_fields, 2)
            if error:
                raise BridgeError("Scansione Waywallen non riuscita: " + error)

            return int(first(sync_fields, 1, 0, 0))
    finally:
        sock.settimeout(previous_timeout)

    raise BridgeError(
        f"Timeout in attesa della scansione Waywallen ({timeout}s)"
    )

def normal_path(value):
    value = str(value or "")
    if value.startswith("file://"):
        value = unquote(urlparse(value).path)
    return os.path.realpath(os.path.expanduser(value))

def file_sha256(path):
    import hashlib
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.digest()


def matching_wallpaper(items, wanted):
    desired = normal_path(wanted)
    wanted_path = Path(desired)
    wanted_digest = None

    for item in items:
        if not item.get("id") or not item.get("resource"):
            continue

        resource = normal_path(item["resource"])
        if resource == desired:
            return item

        # Flatpak document portal: lo stesso file può avere un percorso diverso.
        candidate = Path(resource)
        if candidate.name != wanted_path.name:
            continue

        try:
            if not wanted_path.is_file() or not candidate.is_file():
                continue
            if candidate.stat().st_size != wanted_path.stat().st_size:
                continue

            if wanted_digest is None:
                wanted_digest = file_sha256(wanted_path)

            if file_sha256(candidate) == wanted_digest:
                return item
        except OSError:
            continue

    return None


def lookup_path(sock, start_id, wanted):
    items = list_wallpapers(sock, start_id)
    match = matching_wallpaper(items, wanted)
    if match:
        return match

    scan_library(sock, start_id + 1)
    for attempt in range(8):
        time.sleep(0.75)
        items = list_wallpapers(sock, start_id + 2 + attempt)
        match = matching_wallpaper(items, wanted)
        if match:
            return match

    raise BridgeError("file non presente nella libreria Waywallen. Apri 'Open Waywallen' → Libraries, aggiungi questa cartella e attendi la scansione. File: " + wanted)

def display_target(sock, request_id, output):
    response = request(sock, request_id, 23)  # DisplayListRequest
    body = first(response, 23, 2, b"")
    displays = []
    for number, wire, item_bytes in parse_fields(body):
        if number != 1 or wire != 2: continue
        item = parse_fields(item_bytes)
        displays.append({
            "id": first(item, 1, 0, 0),
            "name": text_field(item, 2),
            "canvas": text_field(item, 17),
            "selectable": bool(first(item, 20, 0, 0)),
        })
    found = next((d for d in displays if d["name"] == output), None)
    if not found:
        raise BridgeError("Waywallen non ha un display registrato chiamato '" + output + "'. Verifica che waywallen-layer-shell sia avviato.")
    if found["canvas"]:
        return pb_bytes(2, found["canvas"])
    if not found["id"] or not found["selectable"]:
        raise BridgeError("il display '" + output + "' non è selezionabile in Waywallen")
    return pb_uint(1, found["id"])


def palette_source_for_item(item):
    kind = str(item.get("type", "")).lower()
    resource = str(item.get("resource", ""))
    preview = str(item.get("preview", ""))
    candidate = ""

    if kind == "scene":
        candidate = preview
    elif kind == "video":
        helper = Path(__file__).with_name("waywallen-thumb.sh")
        if helper.is_file():
            try:
                result = subprocess.run(
                    ["bash", str(helper), str(item.get("id", "")), resource],
                    capture_output=True, text=True, timeout=26, check=False
                )
                if result.returncode == 0 and result.stdout.strip():
                    candidate = result.stdout.strip().splitlines()[-1]
            except (OSError, subprocess.SubprocessError):
                pass
        if not candidate:
            candidate = preview
    elif kind == "image":
        candidate = resource
    else:
        candidate = preview

    if candidate:
        path = Path(candidate).expanduser()
        if path.is_file():
            return str(path)
    return ""


def sync_shell_palette(item, state_root):
    """Keep Ukishima's dynamic/manual palette coherent with Waywallen."""
    palette_source = palette_source_for_item(item)
    palette_file = state_root / "ukishima-wallpaper-palette-source"

    if palette_source:
        tmp = palette_file.with_suffix(".tmp")
        tmp.write_text(palette_source + "\n", encoding="utf-8")
        tmp.replace(palette_file)
    else:
        try:
            palette_file.unlink()
        except FileNotFoundError:
            pass

    flags_path = state_root / "ukishima" / "flags.json"
    try:
        flags = json.loads(flags_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        flags = {}

    wallcolors = Path(__file__).with_name("wallcolors.py")
    if flags.get("paletteMode") == "manual":
        mode = "dark" if flags.get("manualDark", True) else "light"
        args = [
            sys.executable, str(wallcolors), "--hue",
            str(flags.get("manualHue", 30)), mode,
            str(flags.get("manualSat", 0.5))
        ]
    elif palette_source:
        args = [sys.executable, str(wallcolors), palette_source]
    else:
        # Niente anteprima leggibile: non sostituire i colori correnti
        # con una palette neutra generata a partire da scene.pkg.
        return

    try:
        result = subprocess.run(
            args, capture_output=True, text=True, timeout=45, check=False
        )
        if result.returncode != 0:
            print(
                "Palette Ukishima non aggiornata: " +
                (result.stderr.strip() or "wallcolors.py ha restituito un errore"),
                file=sys.stderr
            )
            return

        subprocess.run(
            ["hyprctl", "reload"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            timeout=5, check=False
        )
        subprocess.run(
            [
                "busctl", "--user", "call",
                "com.mitchellh.ghostty", "/com/mitchellh/ghostty",
                "org.gtk.Actions", "Activate", "sava{sv}",
                "reload-config", "0", "0"
            ],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            timeout=5, check=False
        )
    except (OSError, subprocess.SubprocessError) as exc:
        print("Aggiornamento palette: " + str(exc), file=sys.stderr)


def apply_entry(sock, item, output="", request_id=100):
    body = pb_bytes(1, item["id"])
    if output:
        target = display_target(sock, request_id, output)
        body += pb_bytes(5, target)  # PresentationTarget
        request_id += 1
    response = request(sock, request_id, 22, body)  # WallpaperApplyRequest
    result = first(response, 22, 2, b"")
    applied = parse_fields(result)
    resource = item["resource"]
    state_root = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
    state_file = state_root / "ukishima-wallpaper"
    state_file.parent.mkdir(parents=True, exist_ok=True)
    state_tmp = state_file.with_suffix(".tmp")
    state_tmp.write_text(resource + "\n", encoding="utf-8")
    state_tmp.replace(state_file)
    try:
        sync_shell_palette(item, state_root)
    except Exception as exc:
        # La palette non deve impedire l'applicazione del wallpaper.
        print("Aggiornamento palette Ukishima: " + str(exc), file=sys.stderr)
    print(f"Sfondo impostato con Waywallen: {item['name'] or resource}")

def main():
    if len(sys.argv) < 2 or sys.argv[1] not in (
        "apply", "apply-id", "list", "refresh", "random"
    ):
        raise BridgeError(
            "uso: waywallen-bridge.py list | refresh | apply FILE [DISPLAY] "
            "| apply-id ID [DISPLAY] | random"
        )
    mode = sys.argv[1]
    sock = connect_ws()
    try:
        if mode == "list":
            print(json.dumps(list_wallpapers(sock, 1), ensure_ascii=False))
        elif mode == "refresh":
            scan_library(sock, 1)
            wait_for_scan(sock)
            print(json.dumps(list_wallpapers(sock, 2), ensure_ascii=False))
        elif mode == "apply-id":
            if len(sys.argv) < 3:
                raise BridgeError("per apply-id serve l'ID del wallpaper")
            items = list_wallpapers(sock, 1)
            item = next((entry for entry in items if entry["id"] == sys.argv[2]), None)
            if not item:
                raise BridgeError("wallpaper non trovato nel catalogo Waywallen: " + sys.argv[2])
            output = sys.argv[3] if len(sys.argv) > 3 else ""
            apply_entry(sock, item, output, 100)
        elif mode == "apply":
            if len(sys.argv) < 3:
                raise BridgeError("per apply serve il percorso del file")
            item = lookup_path(sock, 1, sys.argv[2])
            output = sys.argv[3] if len(sys.argv) > 3 else ""
            apply_entry(sock, item, output, 100)
        else:
            items = list_wallpapers(sock, 1)
            if not items:
                raise BridgeError("la libreria Waywallen è vuota; aggiungi prima una cartella in Libraries")
            item = random.choice(items)
            apply_entry(sock, item, "", 100)
    finally:
        sock.close()

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("Waywallen: " + str(exc), file=sys.stderr)
        try:
            subprocess.run(["notify-send", "--app-name=Ukishima", "Waywallen", str(exc)], timeout=2, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass
        sys.exit(1)
