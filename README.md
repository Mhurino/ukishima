# Pill Quickshell dynamic island

Pill is a Quickshell widget layer designed for Hyprland systems, with a dynamic-island style interface and a modular settings surface.

The project is fully self-contained: the config folder holds the QML surfaces, its own scripts and the Hyprland-compat files it generates, so nothing is copied into or sourced from another dotfiles tree.

## Layout

All paths resolve at runtime relative to this project folder (`Singletons/Config.qml` self-locates it), so the shell works regardless of where it was launched from or whether it was installed via `install.sh`:

- shell entry: `shell.qml` (+ the pill body `Pill.qml` at the root)
- surfaces: `surfaces/` — the QML module of panels the pill morphs into (launcher, wallpaper strip, settings sub-pages, mixer, OSD, toasts, …)
- components: `components/` — the QML module of reusable widgets (`PillSurface` base, `GlyphIcon`, `SearchField`, settings row kit, …)
- singletons: `Singletons/` — one per-service QML singleton (`Config`, `Flags`, `Theme`, `Walls`, `Players`, …)
- helpers: `lib/` — pure JS (`fuzzy.js`, `calc.js`, `binds.js`, …)
- scripts: `scripts/` — wallpaper set/thumb/search, palette (`wallpaper.sh`, `wallcolors.py`, …)
- Hyprland-compat outputs: `modules/*.lua`, `hypridle.conf`, `hyprsunset.conf` under this folder
- state: `$XDG_STATE_HOME/pill` (default `~/.local/state/pill`) — flags, events, wallpaper state, launcher usage
- cache: `$XDG_CACHE_HOME/pill` (default `~/.cache/pill`) — palette JSON, weather, rec thumbs; wallpaper previews under `pill-wp-thumbs/`

## Install

```bash
./install.sh
```

This copies the project to `~/.local/share/quickshell/pill` (override with `PILL_INSTALL_ROOT`). The copy is self-contained, so point quickshell at it and run.

## Launch

```bash
quickshell --config "$HOME/.config/quickshell/pill"
```

After an install:

```bash
quickshell --config "$HOME/.local/share/quickshell/pill"
```

## Hyprland integration

The shell writes generated config files under its own folder (`modules/`, `hypridle.conf`, `hyprsunset.conf`). To load them, `source` those paths from your Hyprland config:

```bash
source = ~/.config/quickshell/pill/modules/*.lua
exec-once = hypridle -c ~/.config/quickshell/pill/hypridle.conf
```

This repo never touches `~/.config/hypr` by default.
