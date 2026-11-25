# Feature guide

This page is the map of the user-facing features in this fork. The detailed operating guides are linked below.

- [Application Dock](DOCK.md)
- [Media and Beats](MEDIA-BEATS.md)
- [Screen recording, replay, and audio mixer](RECORDING-AUDIO.md)
- [System surfaces and Hyprland workflows](SYSTEM-SURFACES.md)
- [Waywallen integration](WAYWALLEN.md)

## The pill and its navigation

Ukishima's pill is the main entry point for its surfaces. It is instantiated per monitor and reacts to the Hyprland monitor, workspace, window, and fullscreen state.

- Hovering or tapping the pill expands it; the tap behavior can be set to expand the pill or open Media.
- A surface grows out of the pill and occupies the same shell area rather than opening a separate desktop application.
- Right-clicking the pill cycles through **Media**, **Timer**, and up to two configurable extra stops.
- The optional fourth and fifth stops are configured in **Settings → Appearance → Interface → Right-click cycle**.
- The **Modules** page controls which shortcuts are shown in the pill. Hiding a shortcut does not remove the underlying surface.
- The **Memory Saver** setting unloads eligible inactive surfaces after their idle period. Reopening a surface cancels its pending unload.

The right-click cycle's extra stops can be set to Off or to Calendar, Weather, Launcher, Clipboard, Scratchpad, Wallpaper, Power, Beats, Mixer, Link/Inbox, Wi-Fi, Bluetooth, Battery, Recorder, System Monitor, Appearance, or Profile.

## Timer

The Timer is a countdown owned by the `Countdown` singleton, not by its visible card.

- Presets: **1, 5, 10, 15, and 25 minutes**.
- Custom duration: **1–600 minutes**.
- Controls: Start, Pause, Resume, and Reset.
- Completion sends a desktop notification and plays the desktop completion sound.
- Closing the Timer surface does not stop the countdown.
- The Timer is session-scoped: it is **not persisted across a Quickshell/Ukishima restart**.

Timer is one of the fixed right-click-cycle stops after Media. Its pill shortcut can be shown or hidden under **Settings → Appearance → Interface → Modules → Timer**.

## Clipboard history

The Clipboard surface uses `cliphist` and `wl-clipboard`.

- A background `wl-paste --watch` process notices clipboard changes; updates are debounced before the history is refreshed.
- Search filters the cached history snapshot.
- Text entries and supported image entries are listed. Image items can show cached thumbnails and image metadata.
- **Enter/Return** copies the selected entry.
- **Ctrl+X** deletes the selected entry.
- Hold the clear-history control to wipe the complete cliphist history.

Image thumbnails are cached under `$XDG_CACHE_HOME/ukishima/cliphist-thumbs` (default: `~/.cache/ukishima/cliphist-thumbs`). The history itself is managed by cliphist, not by that thumbnail cache.

Required tools: `cliphist`, `wl-paste`, and `wl-copy`. The feature also needs a working Wayland clipboard session.

## Scratchpad

Scratchpad is a local notes deck. Each note is a plain-text Markdown file and the note title is its filename.

- **New note** opens a naming step; a file is created only when the note is given a name.
- The title can be renamed. Enter commits the name; Escape abandons the naming step.
- Body edits are autosaved after a short debounce (about **500 ms**).
- Notes can be pinned/unpinned. Pinned notes sort before unpinned notes; within each group newer notes sort first.
- The body can be cleared separately from deleting the note.
- Deletion is protected by a press-and-hold action.
- The editor and note model are shared across the visual deck styles, so switching layout does not change note data.

Storage:

- Notes: `$XDG_STATE_HOME/ukishima/notes` (default: `~/.local/state/ukishima/notes`).
- Pin metadata: `$XDG_STATE_HOME/ukishima/scratch-pins.json`.

The Markdown files can be backed up or edited outside Ukishima. Keep the pin metadata file as well when you want to retain pinned status.

## Weather

Weather uses **Open-Meteo**, without an API key.

- With no manual city configured, the initial city and coordinates are resolved from the public IP lookup.
- Click the city label in the Weather surface to enter a city manually. The city is geocoded with Open-Meteo.
- Resolved coordinates are cached under `$XDG_CACHE_HOME/ukishima/weather` (default: `~/.cache/ukishima/weather`), so a shell restart can reuse the location.
- The surface presents current temperature, conditions and humidity, a short hourly grid, and a **five-day** daily forecast.
- Forecast data is fetched after location resolution and refreshed every **20 minutes**.
- Layout: **Default** or **Breeze**, selected under Surface Styles.

The default automatic location lookup uses the public IP and may therefore identify an ISP exit point rather than the exact physical location. Setting a city manually gives the user control over the forecast location. Network access and `curl` are required.

## Themes, palettes, and Surface Styles

Open **Settings → Appearance** for the main appearance controls.

### Theme modes

- **Light** and **Dark** select a fixed palette.
- **Dynamic** generates the shell palette from the active wallpaper.
- **Manual** exposes hue and saturation controls plus a light/dark choice.
- Accent color can be adjusted independently. OLED mode is also available.
- When a dynamic wallpaper has no readable source image or preview, palette generation may be unavailable; the Waywallen guide explains how palette synchronization handles this case.

### Surface Styles

Open **Settings → Appearance → Surface Styles**. Each selector changes a surface's layout without changing the underlying feature or its saved data.

| Surface | Available styles |
|---|---|
| Pill display | Dynamic, Status, Classic, System, Strip |
| Media Player | Default, Matrix, Musicassetta |
| Scratchpad | Default, Cassette, Index, Console, Ash |
| Weather | Default, Breeze |

The **Strip** pill display is unavailable with a top-corner dock position because those layouts conflict.

### Interface behavior

The Interface page exposes:

- UI scale: 90%, 100%, 110%, or 125%.
- Pill tap action: expand the pill or open Media.
- Animation style: Standard, Snap, Float, or Bounce.
- Reduce motion.
- Auto hide.
- Memory Saver.
- Module visibility.
- The configurable right-click cycle.

## Other surfaces

The fork also includes the following integrated surfaces. Their controls and prerequisites are described in [System surfaces and Hyprland workflows](SYSTEM-SURFACES.md).

- **Calendar** — local all-day and timed events, multi-day spans, monthly/yearly recurrence, and timed reminders.
- **Launcher** — fuzzy-ranked application search, launch history, calculator expressions, and AppImage entry management.
- **Inbox/Link** — notifications grouped by application, with unread tracking and bulk dismissal.
- **Wi-Fi** — NetworkManager connections, saved profiles, password entry, and a configurable hotspot.
- **Bluetooth** — device discovery, pairing, connect/disconnect, forget, and reported device battery.
- **Battery** — charge, state, estimated time, rate, health, and capacity when UPower exposes them.
- **System Monitor** — CPU, memory, GPU when supported, temperatures, network, disk, swap, VRAM, and uptime, with a network test.
- **Power** — lock, logout, suspend, restart, and shutdown actions.

## Main additional components

- [Application Dock](DOCK.md) — native per-monitor dock, pinned apps, workspace-aware running apps, floating/tiled actions.
- [Media and Beats](MEDIA-BEATS.md) — MPRIS media card and the separate Beats music interface.
- [Screen recording and audio](RECORDING-AUDIO.md) — GPU Screen Recorder capture, the 30-second replay action, PipeWire mixer, and quick controls.
- [Waywallen](WAYWALLEN.md) — external wallpaper backend, Flatpak lifecycle, Hyprland layer-shell, NVIDIA compatibility, FPS settings, and palette sync.
