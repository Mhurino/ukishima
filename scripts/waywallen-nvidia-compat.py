#!/usr/bin/env python3
"""Apply Waywallen's documented NVIDIA web-renderer workaround."""

import os
import re
import shutil
import stat
import sys
import tempfile
import tomllib
from datetime import datetime
from pathlib import Path

APP_ID = "org.waywallen.waywallen"
CONFIG = (
    Path.home()
    / ".var" / "app" / APP_ID / "config" / "waywallen" / "config.toml"
)


def has_nvidia_gpu():
    for vendor_file in Path("/sys/bus/pci/devices").glob("*/vendor"):
        try:
            if vendor_file.read_text(encoding="ascii").strip() == "0x10de":
                return True
        except OSError:
            continue
    return False


def update_config(original):
    newline = "\r\n" if "\r\n" in original else "\n"
    lines = original.splitlines(keepends=True)

    section_re = re.compile(r"^\s*\[plugin\.weweb-renderer\]\s*(?:#.*)?$")
    header_re = re.compile(r"^\s*\[.*\]\s*(?:#.*)?$")
    assignment_re = re.compile(
        r"""^(?P<prefix>\s*shared_texture_enabled\s*=\s*)"""
        r"""(?P<value>"(?:true|false)"|'(?:true|false)'|true|false)"""
        r"""(?P<tail>\s*(?:#.*)?)$"""
    )

    section_start = None
    for index, line in enumerate(lines):
        if section_re.fullmatch(line.rstrip("\r\n")):
            section_start = index
            break

    if section_start is None:
        if original and not original.endswith(newline * 2):
            original += newline
        return (
            original
            + f"[plugin.weweb-renderer]{newline}"
            + f'shared_texture_enabled = "false"{newline}',
            True,
        )

    section_end = len(lines)
    for index in range(section_start + 1, len(lines)):
        if header_re.fullmatch(lines[index].rstrip("\r\n")):
            section_end = index
            break

    for index in range(section_start + 1, section_end):
        line = lines[index]
        body = line.rstrip("\r\n")
        if not re.match(r"^\s*shared_texture_enabled\s*=", body):
            continue

        match = assignment_re.fullmatch(body)
        if not match:
            raise ValueError(
                "shared_texture_enabled esiste ma ha un valore non riconosciuto; "
                "configurazione lasciata invariata."
            )

        value = match.group("value")
        if value in ('"false"', "'false'", "false"):
            return original, False

        quote = value[0] if value.startswith(('"', "'")) else ""
        replacement = f"{quote}false{quote}"
        lines[index] = (
            match.group("prefix")
            + replacement
            + match.group("tail")
            + line[len(body):]
        )
        return "".join(lines), True

    # Add the option inside the existing table, before the next TOML table.
    if section_end > 0 and not lines[section_end - 1].endswith(("\n", "\r")):
        lines[section_end - 1] += newline
    lines.insert(section_end, f'shared_texture_enabled = "false"{newline}')
    return "".join(lines), True


def write_atomically(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    fd, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=str(path.parent)
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as handle:
            handle.write(content)
        os.chmod(temporary_name, mode)
        os.replace(temporary_name, path)
    except Exception:
        try:
            os.unlink(temporary_name)
        except OSError:
            pass
        raise


def main():
    if not has_nvidia_gpu():
        print("not-nvidia")
        return 0

    if CONFIG.is_symlink():
        print(f"Configurazione simbolica non modificata: {CONFIG}", file=sys.stderr)
        return 1

    try:
        original = CONFIG.read_text(encoding="utf-8") if CONFIG.exists() else ""
        if original.strip():
            tomllib.loads(original)

        updated, changed = update_config(original)
        if not changed:
            print("unchanged")
            return 0

        # Validate the complete TOML before creating a backup or replacing it.
        tomllib.loads(updated)

        if CONFIG.exists():
            state_home = Path(
                os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))
            )
            backup_dir = state_home / "ukishima" / "backups"
            backup_dir.mkdir(parents=True, exist_ok=True)
            stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
            backup = backup_dir / f"waywallen-config.toml.{stamp}.bak"
            suffix = 1
            while backup.exists():
                backup = backup_dir / f"waywallen-config.toml.{stamp}-{suffix}.bak"
                suffix += 1
            shutil.copy2(CONFIG, backup)
            print(f"Backup configurazione: {backup}", file=sys.stderr)

        write_atomically(CONFIG, updated)
        print("changed")
        return 0

    except Exception as error:
        print(f"Compatibilità NVIDIA Waywallen: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
