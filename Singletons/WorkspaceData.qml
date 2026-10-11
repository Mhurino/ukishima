pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Shared workspace snapshot for every per-monitor pill.
 *
 * Workspace views used to run their own hyprctl commands, startup retries,
 * debounce timers and Hyprland event listeners. There can be several views
 * per pill even when most are hidden, so keep the external query and event
 * handling here and let all views rebuild from the same snapshot.
 */
Singleton {
    id: root

    property var snapshot: ({ activeByMonitor: ({}), wsList: [] })
    readonly property var activeByMonitor: snapshot.activeByMonitor
    readonly property var wsList: snapshot.wsList

    property int startupTries: 0
    property bool pendingRefresh: false

    function refreshData() {
        if (proc.running) {
            pendingRefresh = true;
            return;
        }
        proc.running = true;
    }

    function scheduleRefresh() {
        refreshDebounce.restart();
    }

    /**
     * A single query captures both the active workspace per monitor and the
     * full workspace-to-monitor mapping. Events arriving during the command
     * collapse into one trailing refresh rather than spawning overlapping
     * queries or leaving the snapshot stale.
     */
    Timer {
        id: refreshDebounce
        interval: 40
        repeat: false
        onTriggered: root.refreshData()
    }

    Timer {
        id: startupRetry
        interval: 250
        repeat: true
        running: true
        onTriggered: {
            if (Object.keys(root.activeByMonitor).length > 0) {
                startupRetry.stop();
                return;
            }
            root.startupTries += 1;
            root.refreshData();
            if (root.startupTries >= 8)
                startupRetry.stop();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = event.name;
            if (n === "workspace" || n === "workspacev2"
                || n === "createworkspace" || n === "createworkspacev2"
                || n === "destroyworkspace" || n === "destroyworkspacev2"
                || n === "moveworkspace" || n === "moveworkspacev2"
                || n === "renameworkspace" || n === "activespecial"
                || n === "focusedmon" || n === "focusedmonv2"
                || n === "monitoradded" || n === "monitoraddedv2"
                || n === "monitorremoved")
                root.scheduleRefresh();
        }
    }

    Process {
        id: proc
        command: ["sh", "-c", "hyprctl monitors -j; printf '@@@'; hyprctl workspaces -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text;
                var sep = text.indexOf("@@@");
                if (sep < 0)
                    return;

                var active = ({});
                var list = [];
                try {
                    var mons = JSON.parse(text.slice(0, sep));
                    for (var m = 0; m < mons.length; m++) {
                        var mon = mons[m];
                        if (mon && mon.name && mon.activeWorkspace)
                            active[mon.name] = String(mon.activeWorkspace.name);
                    }

                    var arr = JSON.parse(text.slice(sep + 3));
                    for (var w = 0; w < arr.length; w++) {
                        var ws = arr[w];
                        if (ws)
                            list.push({ id: ws.id, monitor: ws.monitor || "" });
                    }
                } catch (e) {
                    return;
                }

                root.snapshot = { activeByMonitor: active, wsList: list };
                if (Object.keys(active).length > 0)
                    startupRetry.stop();
            }
        }
        onExited: {
            if (root.pendingRefresh) {
                root.pendingRefresh = false;
                Qt.callLater(root.refreshData);
            }
        }
    }

    Component.onCompleted: root.refreshData()
}
