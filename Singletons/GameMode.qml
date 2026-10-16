pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

/**
 * Game mode: one flag that strips Hyprland's eye-candy and quiets the desktop for
 * gaming or deep focus. Entering snapshots the focus flags, forces do-not-disturb
 * and keep-awake on, pauses the visualizer, and runs the visual strip; leaving
 * restores each to what it was before. The strip itself lives in gamemode.sh so
 * the original decoration values survive a pill restart. `Flags.gameMode` is the
 * single source of truth, flipped by the mixer chip, the keybind, or IPC.
 */
Singleton {
    id: root

    readonly property bool active: Flags.gameMode
    readonly property string script: Config.hyprPath("scripts", "gamemode.sh")
    property string pending: ""

    onActiveChanged: active ? root.enter() : root.leave()

    function enter() {
        Flags.gamePrevDnd = Flags.dnd;
        Flags.gamePrevViz = Flags.musicViz;
        Flags.gamePrevAwake = Flags.keepAwake;
        if (!Flags.gameDockStateSaved) {
            Flags.gamePrevDockEnabled = Flags.dockEnabled;
            Flags.gameDockStateSaved = true;
        }
        Flags.dockEnabled = false;
        // Only change the profile when the daemon and hardware support it.
        if (Battery.daemonReady && Battery.hasPerformance) {
            Flags.gamePrevProfile = String(Battery.profile);
            Battery.setProfile(PowerProfile.Performance);
        } else {
            Flags.gamePrevProfile = "";
        }
        Flags.dnd = true;
        Flags.musicViz = false;
        Flags.keepAwake = true;
        root.run("on");
    }

    function leave() {
        root.run("off");
        Flags.dnd = Flags.gamePrevDnd;
        Flags.musicViz = Flags.gamePrevViz;
        Flags.keepAwake = Flags.gamePrevAwake;
        Flags.dockEnabled = Flags.gamePrevDockEnabled;
        Flags.gameDockStateSaved = false;
        if (Flags.gamePrevProfile !== "") {
            var previous = parseInt(Flags.gamePrevProfile, 10);
            if (!isNaN(previous))
                Battery.setProfile(previous);
            Flags.gamePrevProfile = "";
        }
    }

    function run(arg) {
        if (proc.running) {
            root.pending = arg;
            return;
        }
        proc.command = ["bash", root.script, arg];
        proc.running = true;
    }

    Process {
        id: proc
        onExited: {
            if (root.pending.length === 0)
                return;
            var a = root.pending;
            root.pending = "";
            proc.command = ["bash", root.script, a];
            proc.running = true;
        }
    }
}
