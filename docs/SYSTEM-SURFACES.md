# System surfaces and Hyprland workflows

This guide documents the smaller surfaces that make Ukishima function as a desktop control center.

## Launcher and calculator

The Launcher searches installed desktop entries using fuzzy ranking. Results are influenced by prior launch frequency, shared with the standalone launcher.

- Type to filter/rank applications; Enter launches the selected result.
- The usage history is stored in `$XDG_STATE_HOME/ukishima/launcher-usage.json` (default: `~/.local/state/ukishima/launcher-usage.json`).
- Calculator expressions are evaluated inline. The result can be copied to the Wayland clipboard.
- AppImage entries managed by the fork can be renamed or removed from the launcher.
- The Launcher also accepts the AppImage drop workflow shown in its empty/help state; AppImage installation and management are handled by the fork's `scripts/app-install.sh`.

The launcher is integrated with the pill and the Dock search tile; it is not a separate application menu.

## Calendar

Calendar is a local event calendar stored by Ukishima.

- Browse months and return to Today.
- Select a day to view its events.
- Create **all-day** or **timed** events. Timed entries accept a start and optional end time.
- Create a multi-day span by selecting a start and end date.
- Set an event to repeat **Once**, **Monthly**, or **Yearly**.
- Birthday-like titles can be recognized and suggested as yearly repeats; the repeat selector can still be changed manually.
- Event rows can be deleted from the selected day.

The event model stores events as JSON at `$XDG_STATE_HOME/pill/events.json` (default: `~/.local/state/pill/events.json`). Each item can include a date, optional end date, start/end time, title, and recurrence.

Timed event reminders are checked by the session and can notify at **24 hours, 12 hours, 1 hour, and 30 minutes** before the event. The reminder schedule is local to the running Ukishima session; keep the shell running for reminders to be delivered.

## Inbox / notifications

The **Link** surface is presented as **INBOX** in the UI.

- Notifications are grouped by application.
- Critical notifications are kept prominent.
- Unread count and per-entry age are shown.
- Opening Inbox marks notifications as seen after a short delay.
- Expand/collapse an application's group.
- Dismiss an individual notification, dismiss an application's notifications, or clear all.
- Do Not Disturb is exposed in the Mixer.

The Inbox operates on the notification server used by the current desktop session. It is a notification center, not a separate notification daemon.

## Wi-Fi and hotspot

The Wi-Fi surface uses Quickshell Networking for live device state and `nmcli` for saved profiles and connection details.

- Enable/disable Wi-Fi.
- Rescan nearby access points.
- Networks are ordered by signal strength.
- Connect to an open network or enter a password for a secured network.
- Saved profiles can be connected, disconnected, forgotten, and (where NetworkManager exposes it) have their saved password revealed.
- The connected row can show IPv4 address, band, and bitrate.

### Hotspot

The same surface can configure and toggle a NetworkManager Wi-Fi hotspot. Its profile is named `UkishimaHotspot` by default, with the default network name `Ukishima`. The SSID and password can be edited; WPA-PSK requires at least eight password characters. If no valid password is set when saving/enabling, the UI can generate one.

Required: NetworkManager and `nmcli`, plus a Wi-Fi adapter/driver that supports access-point mode. Hotspot support depends on the adapter and driver.

## Bluetooth

The Bluetooth surface uses Quickshell Bluetooth/BlueZ and `bluetoothctl` for pairing actions.

- Enable/disable the adapter.
- Scan for nearby devices; scanning automatically stops after about 25 seconds.
- Connect or disconnect paired devices.
- Pair an unpaired device; the helper flow pairs, trusts, then connects it.
- Forget a paired device.
- Show the reported battery level when the device provides it.

Required: BlueZ, a working Bluetooth adapter, and `bluetoothctl`.

## Battery and power information

The Battery surface reads UPower's display device. On supported laptops it can show:

- Charge percentage and charging/discharging/full state.
- Estimated time remaining or time to full, when UPower reports it.
- Charge/discharge rate in watts.
- Battery health and energy capacity when those fields are supported by the device/UPower.

On desktops or systems without a present laptop battery, battery-only fields may be absent.

## System Monitor

The System Monitor surface polls live system data while open:

- CPU utilization and temperature.
- Memory usage and swap.
- Network throughput.
- Root filesystem usage.
- Uptime.
- GPU utilization and temperature when a supported NVIDIA or AMD GPU is detected.
- VRAM usage/capacity when the detected driver exposes it.

The GPU dial and VRAM cell disappear when no supported discrete GPU is detected. NVIDIA readings use `nvidia-smi`; AMD readings use the available DRM/sysfs counters. CPU, memory, network, disk, and uptime are read from Linux proc/sys interfaces.

The surface also includes a small network test for ping, download, and upload. It uses `curl` requests and therefore requires network connectivity. Results depend on the endpoint, route, and current network conditions; they are not a guaranteed ISP benchmark.

## Power menu

The Power surface exposes Lock, Logout, Sleep, Restart, and Shutdown.

- Lock uses the personal script at `~/.config/hypr/UserScripts/LockScreen.sh`.
- Logout uses the Hyprland session exit dispatch.
- Sleep uses `systemctl suspend`.
- Restart and Shutdown use `systemctl reboot` and `systemctl poweroff`.
- Restart and Shutdown are deliberately guarded by a press-and-hold interaction rather than a single tap.

The lock action requires the user's lock script at the configured path. The system actions depend on the current user session and systemd-logind permissions.

## Hyprland and multi-monitor behavior

The shell consumes Hyprland state for monitors, active workspaces, toplevel windows, focus, and fullscreen status.

- The pill and Dock are created per monitor.
- The Dock groups an application's windows and can activate the workspace containing a selected window.
- Fullscreen applications suppress appropriate shell overlays/dock visibility on that monitor.
- Special workspaces can be reflected in the pill's status area; the normal Dock list excludes special workspaces.
- The shell updates its window/workspace models from Hyprland events and debounces bursts of related IPC changes.
- The workspace OSD and other transient overlays can temporarily expand the pill without leaving a permanent hover latch.

These behaviors depend on the active Hyprland session and its IPC integration; other compositors are not the target environment of this fork.
