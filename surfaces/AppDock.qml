pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import "../Singletons"
import "../components"
import "../lib/apps.js" as Apps

PanelWindow {
    id: root

    property var screenTarget: null

    signal launcherRequested(string monitorName)

    readonly property real s:
        screenTarget ? (screenTarget.height / 1080) * Flags.uiScale : 1

    readonly property string monitorName:
        screenTarget ? screenTarget.name : ""

    readonly property var hyprMonitor:
        screenTarget ? Hyprland.monitorFor(screenTarget) : null

    readonly property var currentWorkspace:
        hyprMonitor ? hyprMonitor.activeWorkspace : null

    readonly property bool monFullscreen: {
        var tops = Hyprland.toplevels.values;

        for (var i = 0; i < tops.length; i++) {
            var t = tops[i];

            if (!t || !t.activated || !t.monitor)
                continue;

            if (t.monitor.name !== root.monitorName)
                continue;

            var wl = t.wayland;
            return !!(wl && wl.fullscreen);
        }

        return false;
    }

    readonly property var allEntries:
        DesktopEntries.applications.values

    /**
     * One logical entry per application currently visible in this monitor's
     * active workspace. Multiple windows of the same application collapse into
     * one dock item; the active window wins when choosing the representative.
     */
    /**
     * All applications currently running on this monitor.
     *
     * Unlike the old workspaceApps model, this intentionally scans every
     * toplevel on the monitor, so applications living on another workspace
     * remain visible in the dock and can be activated from here.
     */
    readonly property var runningApps: {
        var tops = Hyprland.toplevels.values;
        var out = [];
        var byId = ({});

        var activeWs = currentWorkspace;

        for (var i = 0; i < tops.length; i++) {
            var t = tops[i];

            if (!t || !t.monitor || !t.wayland || t.wayland.minimized)
                continue;

            if (t.monitor.name !== root.monitorName)
                continue;

            if (!t.workspace)
                continue;

            var workspaceName = String(t.workspace.name || "");

            // Do not put special workspaces into the application dock.
            if (workspaceName.indexOf("special:") === 0)
                continue;

            var appId = String(t.wayland.appId || "");
            if (appId.length === 0)
                continue;

            var entry = Apps.resolveEntry(appId, allEntries);
            if (!entry || !entry.id)
                continue;

            var key = String(entry.id);
            var here = activeWs && t.workspace.id === activeWs.id;
            var active = !!t.activated;

            var existing = byId[key];

            if (!existing) {
                existing = {
                    entry: entry,
                    toplevel: t,
                    workspace: t.workspace,
                    workspaceLabel: workspaceName,
                    workspaceHere: here,
                    running: true,
                    active: active
                };

                byId[key] = existing;
                out.push(existing);
                continue;
            }

            // Prefer the active window, then a window on the current workspace.
            var better =
                (active && !existing.active)
                || (here && !existing.workspaceHere);

            if (better) {
                existing.toplevel = t;
                existing.workspace = t.workspace;
                existing.workspaceLabel = workspaceName;
                existing.workspaceHere = here;
                existing.active = active;
            }
        }

        return out;
    }

    /**
     * Final dock model:
     * 1. pinned apps always stay in their configured order;
     * 2. every running app on this monitor is included;
     * 3. duplicates are collapsed by DesktopEntry id.
     */
    readonly property var dockItems: {
        var out = [];
        var seen = ({});
        var running = root.runningApps;

        // Pinned apps first.
        for (var i = 0; i < Flags.dockApps.length; i++) {
            var id = String(Flags.dockApps[i]);
            var entry = Apps.resolveEntryById(id, allEntries);

            if (!entry || !entry.id)
                continue;

            var item = {
                entry: entry,
                toplevel: null,
                workspace: null,
                workspaceLabel: "",
                workspaceHere: false,
                running: false,
                active: false
            };

            for (var j = 0; j < running.length; j++) {
                if (String(running[j].entry.id) === id) {
                    item.toplevel = running[j].toplevel;
                    item.workspace = running[j].workspace;
                    item.workspaceLabel = running[j].workspaceLabel;
                    item.workspaceHere = running[j].workspaceHere;
                    item.running = true;
                    item.active = running[j].active;
                    break;
                }
            }

            seen[id] = true;
            out.push(item);
        }

        // Then all currently running apps that are not pinned.
        for (var k = 0; k < running.length; k++) {
            var runningItem = running[k];
            var runningId = String(runningItem.entry.id);

            if (seen[runningId])
                continue;

            out.push(runningItem);
            seen[runningId] = true;
        }

        // Ordine visuale:
        // workspace 1, workspace 2, workspace 3...
        // Le app pinnate ma non aperte restano sempre alla fine.
        out.sort(function (a, b) {
            var aRunning = !!a.running;
            var bRunning = !!b.running;

            if (aRunning !== bRunning)
                return aRunning ? -1 : 1;

            if (!aRunning && !bRunning)
                return 0;

            var aWs = a.workspace ? Number(a.workspace.id) : 2147483647;
            var bWs = b.workspace ? Number(b.workspace.id) : 2147483647;

            if (aWs !== bWs)
                return aWs - bWs;

            // A parità di workspace resta invariato l'ordine originale.
            return 0;
        });

        return out;
    }

    function isPinned(entry) {
        if (!entry || !entry.id)
            return false;

        return Flags.dockApps.indexOf(String(entry.id)) !== -1;
    }

    function pinEntry(entry) {
        if (!entry || !entry.id || isPinned(entry))
            return;

        var next = Flags.dockApps.slice();
        next.push(String(entry.id));
        Flags.dockApps = next;
    }

    function findRunningEntry(entry) {
        if (!entry || !entry.id)
            return null;

        var tops = Hyprland.toplevels.values;

        for (var i = 0; i < tops.length; i++) {
            var t = tops[i];

            if (!t || !t.monitor || !t.wayland || t.wayland.minimized)
                continue;

            var appId = String(t.wayland.appId || "");
            if (appId.length === 0)
                continue;

            var resolved = Apps.resolveEntry(appId, allEntries);

            if (resolved && resolved.id === entry.id)
                return t;
        }

        return null;
    }

    function activateEntry(entry) {
        if (!entry)
            return;

        var running = findRunningEntry(entry);

        if (running && running.workspace) {
            var ws = running.workspace;

            // First move to the workspace containing the application.
            if (!currentWorkspace || ws.id !== currentWorkspace.id) {
                ws.activate();

                // Once the workspace is active, focus the actual window.
                Qt.callLater(function() {
                    if (running.wayland)
                        running.wayland.activate();
                });
            } else if (running.wayland) {
                running.wayland.activate();
            }

            return;
        }

        // Not running: launch the desktop entry.
        if (entry.execute)
            entry.execute();
    }

    property bool hoverReveal: false

    readonly property bool dockAtBottom:
        Flags.dockPosition === "bottom"

    readonly property bool dockAtLeft:
        Flags.dockPosition === "left"

    readonly property bool dockAtRight:
        Flags.dockPosition === "right"

    readonly property bool dockAtTopLeft:
        Flags.dockPosition === "top-left"

    readonly property bool dockAtTopRight:
        Flags.dockPosition === "top-right"

    readonly property bool dockAtTop:
        dockAtTopLeft || dockAtTopRight

    readonly property bool dockVertical:
        dockAtLeft || dockAtRight

    readonly property real shellTopGap:
        8 * Flags.topGap * root.s


    onMonFullscreenChanged: {
        if (monFullscreen) {
            hoverReveal = false;
            hideTimer.stop();
        }
    }

    readonly property bool dockShown:
        Flags.dockEnabled
        && !monFullscreen
        && (Flags.dockAlwaysVisible || hoverReveal)

    screen: screenTarget
    visible:
        screenTarget !== null
        && Flags.dockEnabled
        && !monFullscreen

    color: "transparent"

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ukishima-dock"

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    mask: dockMask

    Region {
        id: dockMask

        Region {
            x: edgeReveal.x
            y: edgeReveal.y
            width: edgeReveal.width
            height: edgeReveal.height
        }

        Region {
            item: dockFrame
        }
    }

    Timer {
        id: hideTimer
        interval: 3500
        repeat: false

        onTriggered: {
            if (!Flags.dockAlwaysVisible
                && !dockHover.hovered
                && !edgeReveal.containsMouse) {
                root.hoverReveal = false;
            }
        }
    }

    MouseArea {
        id: edgeReveal

        x: {
            if (root.dockAtLeft || root.dockAtTopLeft)
                return 0;

            if (root.dockAtRight || root.dockAtTopRight)
                return root.width - width;

            return 0;
        }

        y: {
            if (root.dockAtBottom)
                return root.height - height;

            return 0;
        }

        width: {
            if (root.dockAtLeft || root.dockAtRight)
                return 9 * root.s;

            if (root.dockAtTopLeft || root.dockAtTopRight)
                return Math.min(
                    root.width,
                    Math.max(120 * root.s, dockFrame.width + 20 * root.s)
                );

            return root.width;
        }

        height: {
            if (root.dockAtLeft || root.dockAtRight)
                return root.height;

            return 9 * root.s;
        }

        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onEntered: {
            if (!Flags.dockAlwaysVisible) {
                hideTimer.stop();
                root.hoverReveal = true;
            }
        }

        onExited: {
            if (!Flags.dockAlwaysVisible)
                hideTimer.restart();
        }
    }

    Rectangle {
        id: dockRevealAura

        visible:
            Flags.dockEnabled
            && !Flags.dockAlwaysVisible
            && !root.dockShown
            && !root.monFullscreen

        z: 20

        width: dockFrame.width
        height: dockFrame.height

        x: {
            if (root.dockAtLeft)
                return -width + 5 * root.s;

            if (root.dockAtRight)
                return root.width - 5 * root.s;

            if (root.dockAtTopLeft)
                return 6 * root.s;

            if (root.dockAtTopRight)
                return root.width - width - 6 * root.s;

            return (root.width - width) / 2;
        }

        y: {
            if (root.dockAtBottom)
                return root.height - 5 * root.s;

            if (root.dockAtLeft || root.dockAtRight)
                return (root.height - height) / 2;

            if (root.dockAtTopLeft || root.dockAtTopRight)
                return -height + 3 * root.s;

            return (root.height - height) / 2;
        }

        radius: dockFrame.radius

        color:
            (root.dockAtTopLeft || root.dockAtTopRight)
                ? Qt.alpha(Theme.cardBot, 0.42)
                : Qt.alpha(Theme.cardBot, 0.40)

        border.width: 1
        border.color:
            (root.dockAtTopLeft || root.dockAtTopRight)
                ? Qt.alpha(Theme.cream, 0.055)
                : Qt.alpha(Theme.cream, 0.05)

        opacity: 1

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Motion.easeStandard
            }
        }
    }

    Rectangle {
        id: dockFrame

        x: {
            if (root.dockAtLeft)
                return root.dockShown
                    ? 6 * root.s
                    : -(width + 10 * root.s);

            if (root.dockAtRight)
                return root.dockShown
                    ? root.width - width - 6 * root.s
                    : root.width + 10 * root.s;

            if (root.dockAtTopLeft)
                return root.dockShown
                    ? 6 * root.s
                    : -(width + 10 * root.s);

            if (root.dockAtTopRight)
                return root.dockShown
                    ? root.width - width - 6 * root.s
                    : root.width + 10 * root.s;

            return (root.width - width) / 2;
        }

        y: {
            if (root.dockAtBottom)
                return root.dockShown
                    ? root.height - height - 6 * root.s
                    : root.height + 10 * root.s;

            if (root.dockAtTopLeft || root.dockAtTopRight)
                return root.dockShown
                    ? root.shellTopGap
                    : -(height + 10 * root.s);

            return (root.height - height) / 2;
        }

        Behavior on x {
            NumberAnimation {
                duration: Motion.morph
                easing.type: Motion.easeMorph
                easing.bezierCurve: Motion.morphCurve
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Motion.morph
                easing.type: Motion.easeMorph
                easing.bezierCurve: Motion.morphCurve
            }
        }

        width: root.dockVertical
            ? (Flags.dockSize + 12) * root.s
            : Math.max(
                104 * root.s,
                dockContent.implicitWidth + 20 * root.s
            )

        height: root.dockVertical
            ? Math.max(
                104 * root.s,
                dockContent.implicitHeight + 20 * root.s
            )
            : (Flags.dockSize + 12) * root.s

        radius: Math.min(width, height) / 2

        color: Theme.cardBot
        border.width: 1
        border.color: Theme.frameBorder

        Behavior on width {
            NumberAnimation {
                duration: Motion.morph
                easing.type: Motion.easeMorph
                easing.bezierCurve: Motion.morphCurve
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Motion.morph
                easing.type: Motion.easeMorph
                easing.bezierCurve: Motion.morphCurve
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: Qt.alpha(Theme.cream, 0.025)
        }

        HoverHandler {
            id: dockHover

            onHoveredChanged: {
                if (hovered) {
                    hideTimer.stop();
                    root.hoverReveal = true;
                } else if (!Flags.dockAlwaysVisible) {
                    hideTimer.restart();
                }
            }
        }

        Grid {
            id: dockContent
            anchors.centerIn: parent
            spacing: 5 * root.s
            columns: root.dockVertical
                ? 1
                : dockRepeater.count + 2

            Item {
                width: Flags.dockSize * root.s
                height: Flags.dockSize * root.s

                Rectangle {
                    anchors.fill: parent
                    radius: Motion.rTile * root.s
                    color: searchMouse.containsMouse
                        ? Qt.alpha(Theme.cream, 0.10)
                        : Qt.alpha(Theme.cream, 0.055)

                    Behavior on color {
                        ColorAnimation {
                            duration: Motion.fast
                            easing.type: Motion.easeStandard
                        }
                    }
                }

                GlyphIcon {
                    anchors.centerIn: parent
                    width: Flags.dockSize * 0.58 * root.s
                    height: Flags.dockSize * 0.58 * root.s
                    name: "search"
                    color: searchMouse.containsMouse
                        ? Theme.cream
                        : Theme.iconDim
                    stroke: 1.8
                }

                MouseArea {
                    id: searchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked:
                        root.launcherRequested(root.monitorName)
                }
            }

            Rectangle {
                width: root.dockVertical
                    ? 26 * root.s
                    : 1
                height: root.dockVertical
                    ? 1
                    : 26 * root.s
                color: Theme.hairSoft
                visible: dockRepeater.count > 0
            }

            Repeater {
                id: dockRepeater

                model: root.dockItems

                delegate: AppDockItem {
                    required property var modelData

                    s: root.s
                    size: Flags.dockSize
                    entry: modelData.entry
                    active: modelData.active
                    running: modelData.running
                    workspaceHere: modelData.workspaceHere
                    workspaceLabel: modelData.workspaceLabel
                    pinned: root.isPinned(modelData.entry)

                    onActivated:
                        (entry) => root.activateEntry(entry)

                    onPinRequested:
                        (entry) => root.pinEntry(entry)
                }
            }
        }
    }
}
