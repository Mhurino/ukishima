# Application Dock

The Dock is a native Quickshell layer-shell surface, not a separate desktop application. Each monitor gets a dock view connected to that monitor's Hyprland windows and active workspace.

## Enable and configure

Open the Dock settings surface from Ukishima's settings. Available options are:

| Setting | Options |
|---|---|
| Position | Bottom, Left, Right, Top-left, Top-right |
| Size | XS (26), S (28), M (30), L (34) |
| Dock enabled | On/Off |
| Always visible | Keep the dock on screen instead of revealing it on demand |
| Sort by workspace | Order running applications by workspace |
| Reveal duration | 1, 2, 4, 6, or 10 seconds |

Top-corner positions are unavailable when the pill display is set to **Strip**. The dock is fullscreen-aware and hides on a monitor with a fullscreen application.

## Reveal and layout

With Always visible disabled, move the pointer to the configured screen edge to reveal the dock. Leaving it starts the configured hide delay. The dock supports:

- Bottom and vertical side layouts.
- Top-left and top-right corner layouts.
- Edge-reveal zones and a subtle hidden-state indicator.
- Icon magnification near the pointer.
- A search tile that opens the Ukishima launcher.
- Theme-aware transparency and borders.

## Pinned applications and running windows

The dock combines two types of entries:

1. Pinned applications remain in their configured order, even when not running.
2. Running applications on the monitor are included automatically.

Multiple windows of the same application are grouped into one dock item. The active window is preferred as the representative; when an application has windows on multiple workspaces, the dock can show the workspace label and offer the relevant window selection.

Special Hyprland workspaces are excluded from the regular application list. With **Sort by workspace** enabled, running entries are ordered by workspace; pinned applications that are not running remain at the end. Pinned, non-running entries can be dragged to reorder them.

## Pointer actions

- **Left-click** an entry to launch the application or activate its running window. If the window is on another workspace, the dock activates that workspace and focuses the window.
- **Middle-click** requests that the application's running window(s) be closed.
- **Right-click** opens the entry's action panel when the app is pinned or running.
- The **+** badge pins an unpinned application.
- The action panel can remove a pinned app from the dock, close the app, and toggle a running window between floating and tiled.
- For a pinned app that is not running, the action panel can launch it using the floating-window choice.

When an application has multiple windows, hovering its dock entry can open a window preview/selection panel. Selecting a window focuses that specific toplevel.

## Steam games and icons

The dock has a Steam icon scan helper (`scripts/steam-game-icons.py`) and a cached icon map under `$XDG_STATE_HOME/ukishima/steam-icons/active.json` (default: `~/.local/state/ukishima/steam-icons/active.json`). The scan is debounced and also refreshed periodically while the dock is enabled.

Steam game windows are handled as a special application identity because their Hyprland app IDs do not always resolve like ordinary desktop entries.

## Behavior notes

- The dock ignores minimized windows and special workspaces when building its normal running-app model.
- It groups by application rather than creating one icon per window.
- The model is updated from Hyprland events; it does not rely only on a high-frequency full scan.
- Pin order and dock settings are stored in Ukishima's flags/settings state.
