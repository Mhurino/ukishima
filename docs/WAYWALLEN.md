# Waywallen integration

Ukishima can use the **Waywallen Flatpak** as its wallpaper renderer while keeping the local Ukishima wallpaper workflow available. The integration includes a catalog bridge, a Hyprland layer-shell display client, animated-wallpaper frame-rate controls, and automatic shell-palette synchronization.

## Requirements

- Waywallen installed as the Flatpak app `org.waywallen.waywallen`.
- A Wayland session with Hyprland.
- `flatpak`, `systemd --user`, `python3`, `curl`, and `jq`.
- The Waywallen layer-shell executable is installed by the integration when it is missing. Updating it later is a separate, explicit operation (see below).

Install Waywallen separately and complete its first launch before enabling the Ukishima integration.

## Enable and configure

The preferred setup is through Ukishima:

1. Open **Settings → Appearance → Wallpaper**.
2. Enable **Waywallen (Flatpak)**.
3. Use **Open Waywallen** to manage wallpaper libraries and select wallpapers.
4. For a library outside the locations already accessible to Flatpak, set **Waywallen folder** in the same settings page, then add that folder in Waywallen → Libraries.

Enabling the integration configures and enables the user services so Waywallen starts with the session. Ukishima grants custom library folders read-only access to the Flatpak.

The Wallpaper settings page also provides:

- **Animated wallpaper FPS**: 15, 24, 30, or 60. When Waywallen is enabled, the value is written to the Waywallen video plugin settings.
- **Show color palettes**: show palette indicators in the wallpaper picker.
- **Open Waywallen**: open the Waywallen application.
- **Waywallen folder**: grant Flatpak read-only access to a custom wallpaper directory. The directory must also be added to Waywallen's Libraries.

Waywallen's own library scan determines which entries are available. A wallpaper must be supported by the installed renderer/plugin before it can be applied.

## Services and lifecycle

The integration creates three user-level systemd services:

| Service | Role |
|---|---|
| `ukishima-waywallen.service` | Runs and supervises the Waywallen Flatpak daemon. |
| `ukishima-waywallen-layer-shell.service` | Presents Waywallen output as a layer-shell surface on Hyprland. |
| `ukishima-waywallen-palette.service` | Watches Waywallen wallpaper changes and synchronizes the Ukishima palette. |

The daemon unit keeps a supervisor process attached to systemd even when the Flatpak launcher hands off to a detached application instance. Stopping the unit runs `flatpak kill`; the layer-shell and palette services are tied to the daemon lifecycle, so they stop with it and follow its restart.

Useful checks:

```bash
systemctl --user status ukishima-waywallen.service --no-pager
systemctl --user status ukishima-waywallen-layer-shell.service --no-pager
systemctl --user status ukishima-waywallen-palette.service --no-pager
flatpak ps
```

Follow the logs:

```bash
journalctl --user -u ukishima-waywallen.service -f
journalctl --user -u ukishima-waywallen-layer-shell.service -f
journalctl --user -u ukishima-waywallen-palette.service -f
```

To disable the integration from a terminal:

```bash
bash scripts/waywallen.sh disable
```

This disables the three services, terminates the Flatpak instance, and restores the wallpaper state that Ukishima had before Waywallen was enabled. You can also disable the integration using the Waywallen switch in **Settings → Appearance → Wallpaper**.

## Layer-shell updates are explicit

The integration does **not** update the layer-shell executable during every normal startup. If the executable is missing, the integration installs it; otherwise the installed version is kept.

To deliberately install the latest available layer-shell release:

```bash
bash scripts/waywallen.sh update-layer-shell
```

Use this command when you specifically need a newer layer-shell release or a release containing a fix. It is not required for every Waywallen Flatpak update. The updater uses the GitHub release metadata and requires `curl` and `jq`.

## NVIDIA Web-renderer compatibility

Waywallen documents a known issue for Web wallpapers on NVIDIA GPUs: its Web renderer should have shared textures disabled. See the [Waywallen README](https://github.com/waywallen/waywallen#known-issue).

Ukishima includes `scripts/waywallen-nvidia-compat.py`. During Waywallen setup/start it checks the PCI vendor ID for NVIDIA (0x10de). On NVIDIA systems it ensures that the Flatpak configuration contains:

```toml
[plugin.weweb-renderer]
shared_texture_enabled = "false"
```

The helper validates the TOML before replacing the file, writes atomically, and saves the previous configuration under `$XDG_STATE_HOME/ukishima/backups` (default: `~/.local/state/ukishima/backups`). If the setting needs to change, the existing Waywallen instance is stopped so the renderer restarts with the new setting. On non-NVIDIA systems, this workaround is not applied.

The helper uses Python's standard-library `tomllib` module (Python 3.11 or newer).

## Wallpaper Engine content through Steam

Wallpaper Engine content can be exposed to Waywallen through the external [Open Wallpaper Engine plugin](https://github.com/waywallen/open-wallpaper-engine).

1. Install the plugin using its current upstream instructions and release package.
2. In Waywallen, add the relevant Steam Workshop or Wallpaper Engine content directory under **Libraries**.
3. Grant Flatpak access to custom library directories through Ukishima's **Waywallen folder** setting when needed.
4. Wait for Waywallen's library scan, then browse the available entries from Ukishima's wallpaper picker or Waywallen itself.

Scene and Web rendering depend on the plugin and its installed renderer. Not every Wallpaper Engine item is guaranteed to work; support and preview availability depend on the content and renderer.

## Automatic palette synchronization

The `ukishima-waywallen-palette.service` listens for wallpaper presentation changes from Waywallen. It identifies the active catalog entry and reuses Ukishima's existing palette-generation script.

- Image wallpapers use their source image.
- Video wallpapers use a generated still when available, otherwise a readable preview.
- Scene and other plugin wallpapers use a readable preview when one is available.
- If there is no usable image or preview, the current palette is left unchanged rather than replaced with an unrelated fallback.

To enable/configure palette synchronization from the repository root:

```bash
bash scripts/enable-waywallen-palette-sync.sh
```

Check the watcher with:

```bash
systemctl --user status ukishima-waywallen-palette.service --no-pager
journalctl --user -u ukishima-waywallen-palette.service -f
```

Disable only the palette watcher (leaving the other Waywallen services alone):

```bash
systemctl --user disable --now ukishima-waywallen-palette.service
```

## Waywallen log location

For the Flatpak build, Waywallen's daemon logs are normally stored in:

```text
~/.var/app/org.waywallen.waywallen/.local/state/waywallen/logs/daemon/
```

The active log is exposed as `waywallen-current.log`. For renderer errors, compare the log timestamps with the time the wallpaper was applied and check the daemon and layer-shell service journals as well.
