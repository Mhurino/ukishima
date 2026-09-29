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

    readonly property var allEntries:
        DesktopEntries.applications.values

    /**
     * One logical entry per application currently visible in this monitor's
     * active workspace. Multiple windows of the same application collapse into
     * one dock item; the active window wins when choosing the representative.
     */
    readonly property var workspaceApps: {
        var ws = currentWorkspace;
        var tops = ws ? ws.toplevels.values : [];
        var out = [];
        var byId = ({});

        for (var i = 0; i < tops.length; i++) {
            var t = tops[i];

            if (!t || !t.wayland || t.wayland.minimized)
                continue;

            var appId = String(t.wayland.appId || "");
            if (appId.length === 0)
                continue;

            var entry = Apps.resolveEntry(appId, allEntries);
            if (!entry || !entry.id)
                continue;

            var key = String(entry.id);
            var existing = byId[key];

            if (!existing) {
                existing = {
                    entry: entry,
                    toplevel: t,
                    active: !!t.activated
                };

                byId[key] = existing;
                out.push(existing);
            } else if (t.activated && !existing.active) {
                existing.toplevel = t;
                existing.active = true;
            }
        }

        return out;
    }

    /**
     * Pinned applications stay visible even when not currently running.
     * Running applications are taken from the active workspace; unpinned
     * running apps are appended after the pinned section.
     */
    readonly property var dockItems: {
        var out = [];
        var seen = ({});

        var running = workspaceApps;

        for (var i = 0; i < Flags.dockApps.length; i++) {
            var id = String(Flags.dockApps[i]);
            var entry = Apps.resolveEntryById(id, allEntries);

            if (!entry || !entry.id)
                continue;

            var item = {
                entry: entry,
                toplevel: null,
                active: false
            };

            for (var j = 0; j < running.length; j++) {
                if (running[j].entry.id === entry.id) {
                    item.toplevel = running[j].toplevel;
                    item.active = running[j].active;
                    break;
                }
            }

            seen[id] = true;
            out.push(item);
        }

        for (var k = 0; k < running.length; k++) {
            var runningItem = running[k];
            var runningId = String(runningItem.entry.id);

            if (seen[runningId])
                continue;

            out.push(runningItem);
        }

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

        if (running && running.wayland) {
            running.wayland.activate();
            return;
        }

        if (entry.execute)
            entry.execute();
    }

    property bool hoverReveal: false

    readonly property bool dockShown:
        Flags.dockEnabled
        && (Flags.dockAlwaysVisible || hoverReveal)

    screen: screenTarget
    visible: screenTarget !== null && Flags.dockEnabled

    color: "transparent"

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ukishima-dock"

    anchors {
        left: true
        right: true
        bottom: true
    }

    implicitHeight: 70 * root.s

    mask: dockMask

    Region {
        id: dockMask

        Region {
            x: 0
            y: root.height - 9 * root.s
            width: root.width
            height: Flags.dockAlwaysVisible ? 0 : 9 * root.s
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
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 9 * root.s

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
        id: dockFrame

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.dockShown
            ? 6 * root.s
            : -(dockFrame.height + 10 * root.s)

        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: Motion.morph
                easing.type: Motion.easeMorph
                easing.bezierCurve: Motion.morphCurve
            }
        }

        width: Math.max(
            104 * root.s,
            dockContent.implicitWidth + 20 * root.s
        )

        height: (Flags.dockSize + 12) * root.s

        radius: height / 2

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

        Row {
            id: dockContent
            anchors.centerIn: parent
            spacing: 5 * root.s

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
                width: 1
                height: 26 * root.s
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
