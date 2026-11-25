# Screen recording, replay, and audio mixer

This guide covers the Recorder surface, its quick-record path, the replay action, and the PipeWire Mixer.

## Recorder

The Recorder surface controls `gpu-screen-recorder` through the `ScreenRec` singleton.

### Capture target

The target is selected before recording starts:

- **Screen** captures a connected monitor. When more than one monitor is available, a monitor selector appears.
- **Window / Region** opens the Hyprland-aware `slurp` picker. Clicking a client rectangle selects that window; dragging selects a freeform rectangular region.

After the target is resolved, the configured countdown runs. Tapping the main action during the countdown cancels it. Pressing the action while recording stops the capture and saves the file.

### Capture settings

The options drawer provides:

| Setting | Options |
|---|---|
| Frame rate | 30, 60, 120, 144 FPS |
| Quality | Medium, High, Ultra, Loss |
| Capture cursor | On/Off |
| Countdown | Off, 3, 5, or 10 seconds |

The UI's **Loss** choice maps to GPU Screen Recorder's `ultra` quality preset. The upstream encoder does not expose a literal lossless preset through this mapping, so the label should not be interpreted as a guarantee of mathematically lossless output.

The two audio rows independently enable/disable the default microphone input and desktop output capture, and expose their levels through PipeWire.

### Output folder and recent clips

- Default output folder: `~/Videos/Recordings`.
- Use **Change** to select another directory. The folder picker uses `kdialog` or `zenity`, depending on what is installed.
- Use **Open** to open the current folder.
- Recent clips are displayed as a filmstrip. `ffmpeg` extracts a thumbnail into `$XDG_CACHE_HOME/ukishima/rec-thumbs` (default: `~/.cache/ukishima/rec-thumbs`).
- Deleting a clip is a two-step action in the recent list.
- **Clear** hides the current recent entries from the list; it does **not** delete the video files. Newer recordings can still appear after the saved watermark.

### Quick recording without opening the surface

The shell exposes **Super+D** as a quick-record flow:

1. Open the standalone source chooser.
2. Choose Screen or Window/Region (and a monitor when needed).
3. The same configured countdown runs.
4. Press Super+D again to cancel the countdown or stop an active recording; pressing it while the chooser is open closes the chooser.

The quick chooser and countdown appear on the targeted monitor's pill. The Recorder surface does not need to be open.

## 30-second replay

The Recorder surface includes a **Replay 30s** action that calls:

```bash
gsr-cli -ipc /run/user/1000/gsr.sock save-replay 30
```

This is a save-replay request to an already running GPU Screen Recorder IPC endpoint; it is separate from starting/stopping a normal recording through the Recorder surface. The GPU Screen Recorder replay buffer and its IPC socket must therefore already be available.

**Current implementation detail:** the socket path is hard-coded as `/run/user/1000/gsr.sock`. Systems whose user ID or GSR IPC socket differs need that path adjusted in `surfaces/Recorder.qml`. The replay action refreshes the recent list after a successful response.

## Requirements

The Recorder implementation calls:

- `gpu-screen-recorder` at `/usr/bin/gpu-screen-recorder`.
- `gsr-cli` for the replay action.
- `slurp` for Window/Region selection.
- `ffmpeg` for recent-video thumbnails.
- PipeWire for default microphone and desktop audio controls.
- `kdialog` or `zenity` for the optional output-folder picker.
- `notify-send` for recording notifications.

The quick capture target also uses Hyprland window information. Ensure the encoder and capture tools are installed and usable in the current Wayland session.

## Mixer

The Mixer surface combines quick system controls with audio faders.

### Audio

- Default output device: choose from available real PipeWire sinks.
- Default input device: choose from available real capture sources.
- Master output volume: adjust the default sink.
- Microphone level and mute: adjust the default source.
- Active application streams: each listed playback stream has its own volume slider.
- Utility streams such as CAVA and GPU Screen Recorder's default output helper are filtered from the visible application list; their PipeWire nodes are not altered by that UI filter.

The device pickers change the preferred default output/input device. Per-application sliders affect the corresponding stream's PipeWire volume, not the global master volume.

### Quick controls

The Mixer header provides:

- **Do not disturb** — silence ordinary notifications.
- **Keep awake** — block system sleep and screen-off while enabled.
- **Night Light** — toggle the warm color filter; its temperature slider ranges from about 2200 K to 6000 K.
- **Game mode** — switch to the shell's reduced-effects/quiet desktop behavior.

Night Light is controlled through `hyprsunset`. PipeWire and the Quickshell PipeWire service are required for the audio controls; the keep-awake and game-mode effects also depend on the user's Hyprland/session configuration.
