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
    property var pendingFloatLaunch: null
    property var pendingFloatResize: null

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

    function fallbackEntry(appId, toplevel) {
        var id = String(appId || "");

        if (!id)
            return null;

        var title = id;

        if (toplevel && toplevel.title)
            title = String(toplevel.title);

        return {
            id: id,
            name: title,
            icon: id,
            startupClass: id
        };
    }

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

            if (!entry)
                entry = root.fallbackEntry(appId, t);

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

            if (!entry) {
                for (var r = 0; r < running.length; r++) {
                    if (String(running[r].entry.id) === id) {
                        entry = running[r].entry;
                        break;
                    }
                }
            }

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
        // Posizione originale: spareggio deterministico.
        for (var oi = 0; oi < out.length; oi++)
            out[oi]._i = oi;

        // Opzione: ordina le app aperte per workspace.
        if (Flags.dockSortByWorkspace) {
        out.sort(function (a, b) {
            var aRunning = !!a.running;
            var bRunning = !!b.running;

            if (aRunning !== bRunning)
                return aRunning ? -1 : 1;

            if (!aRunning && !bRunning)
                return a._i - b._i;

            var aWs = a.workspace ? Number(a.workspace.id) : 2147483647;
            var bWs = b.workspace ? Number(b.workspace.id) : 2147483647;

            if (aWs !== bWs)
                return aWs - bWs;

            // A parità di workspace resta invariato l'ordine originale.
            return a._i - b._i;
        });
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

    function unpinEntry(entry) {
        if (!entry || !entry.id)
            return;

        var id = String(entry.id);

        Flags.dockApps = Flags.dockApps.filter(function(appId) {
            return String(appId) !== id;
        });
    }


    /**
     * Drop of a dragged pinned-but-not-running app. Only those apps are re-sorted,
     * by their visual position along the dock axis (delta = drag distance in px),
     * and written back into their own slots of Flags.dockApps. Running apps keep
     * their workspace ordering untouched.
     */
    function dropPinned(entry, delta, repeater) {
        if (!entry || !entry.id || !repeater)
            return;

        var dragId = String(entry.id);
        var movable = [];

        for (var i = 0; i < repeater.count; i++) {
            var it = repeater.itemAt(i);
            if (!it || !it.entry || !it.pinned
                    || (it.running && Flags.dockSortByWorkspace))
                continue;

            var base = root.dockVertical
                ? it.y + it.height / 2
                : it.x + it.width / 2;

            movable.push({
                id: String(it.entry.id),
                pos: String(it.entry.id) === dragId ? base + delta : base,
                seq: movable.length
            });
        }

        movable.sort(function (a, b) {
            return a.pos !== b.pos ? a.pos - b.pos : a.seq - b.seq;
        });

        var movableIds = ({});
        var order = [];
        for (var m = 0; m < movable.length; m++) {
            movableIds[movable[m].id] = true;
            order.push(movable[m].id);
        }

        var apps = Flags.dockApps.slice();
        var slots = [];
        for (var si = 0; si < apps.length; si++) {
            if (movableIds[String(apps[si])])
                slots.push(si);
        }

        if (slots.length !== order.length)
            return;

        for (var n = 0; n < slots.length; n++)
            apps[slots[n]] = order[n];

        var changed = false;
        for (var c = 0; c < apps.length; c++) {
            if (String(apps[c]) !== String(Flags.dockApps[c])) {
                changed = true;
                break;
            }
        }

        if (changed)
            Flags.dockApps = apps;
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

            if (resolved && String(resolved.id) === String(entry.id))
                return t;

            if (String(appId).toLowerCase() === String(entry.id).toLowerCase())
                return t;
        }

        return null;
    }

    function setFloatingEntry(toplevel) {
        if (!toplevel || toplevel.address === undefined
                || String(toplevel.address).length === 0)
            return;

        var address = String(toplevel.address).replace(/^0x/i, "");
        var ipc = toplevel.lastIpcObject || ({});
        var flag = ipc.floating;
        var floating = flag === true || flag === 1 || flag === "1";

        if (Hyprland.usingLua) {
            var action = floating ? "unset" : "set";
            Hyprland.dispatch(
                'hl.dsp.window.float({ action = "' + action
                + '", window = "address:0x' + address + '" })'
            );
        } else {
            Hyprland.dispatch(
                (floating ? "settiled" : "setfloating") + " address:0x" + address
            );
        }
    }

    function closeEntry(entry) {
        if (!entry)
            return;

        var running = root.runningApps;

        for (var i = 0; i < running.length; i++) {
            if (String(running[i].entry.id) !== String(entry.id))
                continue;

            var top = running[i].toplevel;

            if (top && top.wayland) {
                top.wayland.close();
                return;
            }
        }
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


    function normalizedWindowAddress(toplevel) {
        if (!toplevel || toplevel.address === undefined
                || String(toplevel.address).length === 0)
            return "";
        return String(toplevel.address)
            .replace(/^0x/i, "").toLowerCase();
    }

    function openEntryFloating(entry) {
        if (!entry || !entry.id || !entry.execute)
            return;

        // Evita di confondere la nuova finestra con quelle già esistenti.
        var previous = ({});
        var tops = Hyprland.toplevels.values;
        for (var i = 0; i < tops.length; i++) {
            var key = root.normalizedWindowAddress(tops[i]);
            if (key.length > 0)
                previous[key] = true;
        }

        root.pendingFloatLaunch = {
            entryId: String(entry.id),
            previous: previous,
            ticks: 180
        };

        try {
            entry.execute();
        } catch (e) {
            root.pendingFloatLaunch = null;
            console.warn("Ukishima: impossibile avviare l'app:", e);
        }
    }

    function forceFloatingEntry(toplevel) {
        var address = root.normalizedWindowAddress(toplevel);
        if (!address)
            return;

        if (Hyprland.usingLua) {
            Hyprland.dispatch(
                'hl.dsp.window.float({ action = "set", window = "address:0x'
                + address + '" })'
            );
        } else {
            Hyprland.dispatch("setfloating address:0x" + address);
        }
    }


    function scheduleFloatingLaunchResize(toplevel) {
        var address = root.normalizedWindowAddress(toplevel);
        if (!address)
            return;

        root.pendingFloatResize = {
            address: address,
            monitorName: toplevel.monitor
                ? toplevel.monitor.name
                : root.monitorName
        };
        floatingLaunchResizeTimer.restart();
    }

    function applyFloatingLaunchResize() {
        var target = root.pendingFloatResize;
        root.pendingFloatResize = null;
        if (!target)
            return;

        var screen = null;
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name === target.monitorName) {
                screen = screens[i];
                break;
            }
        }
        if (!screen)
            screen = root.screenTarget;
        if (!screen || screen.width < 400 || screen.height < 300)
            return;

        var sw = screen.width;
        var sh = screen.height;
        var w = Math.min(Math.round(sw * 0.55), sw - 40);
        var h = Math.min(Math.round(sh * 0.60), sh - 40);
        var x = Math.round((sw - w) / 2);
        var y = Math.round((sh - h) / 2);
        var selector = "address:0x" + target.address;

        if (Hyprland.usingLua) {
            Hyprland.dispatch(
                'hl.dsp.window.resize({ window = "' + selector
                + '", x = ' + w + ', y = ' + h
                + ', relative = false })'
            );
            Hyprland.dispatch(
                'hl.dsp.window.move({ window = "' + selector
                + '", x = ' + x + ', y = ' + y
                + ', relative = false })'
            );
        } else {
            Hyprland.dispatch(
                "resizewindowpixel exact " + w + " " + h + "," + selector
            );
            Hyprland.dispatch(
                "movewindowpixel exact " + x + " " + y + "," + selector
            );
        }
    }

    function pollFloatingLaunch() {
        var pending = root.pendingFloatLaunch;
        if (!pending)
            return;

        var tops = Hyprland.toplevels.values;
        for (var i = 0; i < tops.length; i++) {
            var t = tops[i];
            if (!t || !t.wayland)
                continue;

            var address = root.normalizedWindowAddress(t);
            if (!address || pending.previous[address])
                continue;

            var appId = String(t.wayland.appId || "");
            if (!appId)
                continue;

            var resolved = Apps.resolveEntry(appId, root.allEntries);
            var matches = (resolved
                    && String(resolved.id) === pending.entryId)
                || appId.toLowerCase() === pending.entryId.toLowerCase();

            if (!matches)
                continue;

            root.forceFloatingEntry(t);
            root.scheduleFloatingLaunchResize(t);
            root.pendingFloatLaunch = null;
            return;
        }

        pending.ticks -= 1;
        if (pending.ticks <= 0)
            root.pendingFloatLaunch = null;
    }

    // Evita il "salto" visibile: il dock resta nascosto finche' la geometria
    // non si e' assestata (avvio) o l'animazione di spostamento non e' finita.
    Timer {
        id: floatingLaunchResizeTimer
        interval: 250
        repeat: false
        onTriggered: root.applyFloatingLaunchResize()
    }

    Timer {
        id: floatingLaunchPoll
        interval: 100
        repeat: true
        running: root.pendingFloatLaunch !== null
        onTriggered: root.pollFloatingLaunch()
    }

    readonly property int startupSettleMs: 1000
    readonly property int moveSettleMs: 500
    readonly property int resizeSettleMs: Math.round(Motion.morph + 120)
    property bool settling: true

    function settleForGeometry(delayMs) {
        root.settling = true;
        settleTimer.interval = delayMs;
        settleTimer.restart();
    }

    Timer {
        id: settleTimer
        interval: root.startupSettleMs
        running: true
        repeat: false
        onTriggered: root.settling = false
    }

    Connections {
        target: Flags
        function onDockPositionChanged() {
            root.settleForGeometry(root.moveSettleMs);
        }
    }

    // Il modello JS del Repeater può essere ricostruito quando cambia il focus.
    // Aspettiamo che il conteggio si stabilizzi e nascondiamo la dock solo se
    // il numero finale di elementi è davvero diverso da quello precedente.
    property int stableDockItemCount: -1

    Timer {
        id: dockCountDebounce
        interval: 80
        running: true
        repeat: false
        onTriggered: {
            var count = dockRepeater.count;
            if (root.stableDockItemCount >= 0
                    && count !== root.stableDockItemCount) {
                root.settleForGeometry(root.resizeSettleMs);
            }
            root.stableDockItemCount = count;
        }
    }

    Connections {
        target: dockRepeater
        function onCountChanged() {
            dockCountDebounce.restart();
        }
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
            height: root.dockAtBottom ? root.height - edgeReveal.y : edgeReveal.height
        }

        Region {
            // Durante l'assestamento lasciamo attiva solo la zona di rivelazione
            // sul bordo, così il dock trasparente non intercetta i clic.
            item: root.settling ? null : dockFrame
        }
    }

    Timer {
        id: hideTimer
        interval: Math.max(1, Math.round(Flags.dockRevealSeconds * 1000))
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
            && !root.settling

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
        visible: true
        enabled: !root.settling
        opacity: root.settling ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: root.settling ? Motion.fast : Motion.morph
                easing.type: Motion.easeMorph
                easing.bezierCurve: Motion.morphCurve
            }
        }


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

        radius: Math.min(20 * root.s, height / 2)

        color: Flags.glass ? Qt.alpha(Theme.cardBot, 0.62) : Theme.cardBot
        border.width: 1
        border.color: Flags.glass ? Qt.alpha(Theme.cream, 0.14) : Theme.frameBorder

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
            radius: parent.radius - 2
            color: Qt.alpha(Theme.cream, 0.025)
        }

        HoverHandler {
            id: dockHover

            onHoveredChanged: {
                if (hovered) {
                    hideTimer.stop();
                    root.hoverReveal = true;
                } else if (!Flags.dockAlwaysVisible && !root.settling) {
                    hideTimer.restart();
                }
            }
        }

        Grid {
            id: dockContent
            anchors.centerIn: parent
            spacing: 2 * root.s
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
                    toplevel: modelData.toplevel
                    workspaceHere: modelData.workspaceHere
                    workspaceLabel: modelData.workspaceLabel
                    pinned: root.isPinned(modelData.entry)
                    vertical: root.dockVertical

                    tooltipGravity:
                        root.dockAtBottom
                            ? Edges.Top
                            : root.dockAtLeft
                                ? Edges.Right
                                : root.dockAtRight
                                    ? Edges.Left
                                    : Edges.Bottom

                    onActivated:
                        (entry) => root.activateEntry(entry)

                    onCloseRequested:
                        (entry) => root.closeEntry(entry)

                    onFloatRequested:
                        (toplevel) => root.setFloatingEntry(toplevel)

                    onOpenFloatingRequested:
                        (entry) => root.openEntryFloating(entry)

                    onPinRequested:
                        (entry) => root.pinEntry(entry)

                    onUnpinRequested:
                        (entry) => root.unpinEntry(entry)

                    onDragDropped:
                        (entry, delta) => root.dropPinned(entry, delta, dockRepeater)
                }
            }
        }
    }
}
