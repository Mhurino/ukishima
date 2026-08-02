# Pill Quickshell dynamic island

Pill is a Quickshell widget layer designed for Hyprland systems, with a dynamic-island style interface and a modular settings surface.

This version is structured to run as an independent app rather than as a hardwired patch to a personal Hyprland config tree.

## Goals

- no hardcoded dependency on `~/.config/hypr`
- support independent installation under user-owned config/state/cache directories
- keep Hyprland integration optional via environment overrides
- allow future feature work without touching unrelated dotfiles

## Default runtime paths

The app reads these environment variables first:

- `PILL_CONFIG_DIR` for app-specific config root
- `PILL_HYPR_CONFIG_DIR` for compatibility with Hyprland config files
- `PILL_STATE_DIR` for app state
- `PILL_CACHE_DIR` for cache files

If unset, the defaults are:

- config: `$XDG_CONFIG_HOME/pill` or `$HOME/.config/pill`
- Hyprland compatibility root: `$XDG_CONFIG_HOME/pill/hypr` or `$HOME/.config/pill/hypr`
- state: `$XDG_STATE_HOME/pill` or `$HOME/.local/state/pill`
- cache: `$XDG_CACHE_HOME/pill` or `$HOME/.cache/pill`

## Install

Run the included installer:

```bash
./install.sh
```

The installer creates app-local config folders under the user directory and prints the environment values you can export before launching the shell.

## Launch example

```bash
export PILL_CONFIG_DIR="$HOME/.config/pill"
export PILL_HYPR_CONFIG_DIR="$HOME/.config/pill/hypr"
export PILL_STATE_DIR="$HOME/.local/state/pill"
export PILL_CACHE_DIR="$HOME/.cache/pill"
quickshell --config "$HOME/.local/share/quickshell/pill/shell.qml"
```

## Notes

- This repo intentionally does not overwrite `~/.config/hypr` by default.
- If a machine-specific Hyprland config is needed, it can be supplied through `PILL_HYPR_CONFIG_DIR`.
- Future features should use these environment roots instead of direct `$HOME/.config/hypr/...` paths.
