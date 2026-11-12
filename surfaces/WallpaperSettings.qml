pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "../Singletons"
import "../components"

/**
 * Wallpaper-related settings grouped under Theme > Wallpaper.
 * The existing Waywallen and local wallpaper-folder behavior is preserved.
 */
SettingsSurface {
    id: root

    backSurface: "theme"
    implicitHeight: content.implicitHeight


    readonly property string waywallenBridgeScript:
        Config.hyprPath("scripts", "waywallen-bridge.py")

    property int waywallenFpsValue: 30
    property int pendingWaywallenFps: 0
    property int queuedWaywallenFps: 0
    property string fpsError: ""

    readonly property int fpsValue: Flags.waywallenEnabled
        ? root.waywallenFpsValue : Flags.wallpaperFps

    function refreshFps() {
        if (!Flags.waywallenEnabled || !root.active)
            return;

        if (fpsGetProc.running || fpsSetProc.running)
            return;

        fpsGetProc.command = [
            "python3", root.waywallenBridgeScript, "fps-get"
        ];
        fpsGetProc.running = true;
    }

    function setFps(value) {
        const fps = Number(value);

        if ([15, 24, 30, 60].indexOf(fps) < 0)
            return;

        root.fpsError = "";

        // Modalità locale: usa il gestore mpvpaper già esistente.
        if (!Flags.waywallenEnabled) {
            Flags.wallpaperFps = fps;
            Walls.applyFps(fps);
            return;
        }

        // Se una lettura è ancora in corso, interromperla prima della scrittura.
        if (fpsGetProc.running)
            fpsGetProc.running = false;

        // Conserva soltanto l'ultima scelta durante una scrittura in corso.
        if (fpsSetProc.running) {
            root.queuedWaywallenFps = fps;
            return;
        }

        root.pendingWaywallenFps = fps;
        fpsSetProc.command = [
            "python3", root.waywallenBridgeScript, "fps-set", String(fps)
        ];
        fpsSetProc.running = true;
    }

    property bool fitApplyQueued: false
    property string queuedFit: ""

    function setWallpaperFit(value) {
        if (Flags.waywallenEnabled || ["crop", "fit", "stretch", "no"].indexOf(value) < 0)
            return;
        Flags.wallpaperFit = value;
        if (fitApplyProc.running) {
            root.fitApplyQueued = true;
            root.queuedFit = value;
            return;
        }
        fitApplyProc.command = ["bash", Config.hyprPath("scripts", "wallpaper.sh"), "fit", value];
        fitApplyProc.running = true;
    }

    Process {
        id: fitApplyProc
        command: ["bash", Config.hyprPath("scripts", "wallpaper.sh"), "fit", String(Flags.wallpaperFit)]
        onExited: {
            if (root.fitApplyQueued) {
                const nextFit = root.queuedFit;
                root.fitApplyQueued = false;
                root.queuedFit = "";
                fitApplyProc.command = ["bash", Config.hyprPath("scripts", "wallpaper.sh"), "fit", nextFit];
                fitApplyProc.running = true;
            }
        }
    }

    onActiveChanged: {
        if (active)
            Qt.callLater(root.refreshFps);
    }

    Component.onCompleted: {
        if (root.active)
            Qt.callLater(root.refreshFps);
    }

    Connections {
        target: Flags

        function onWaywallenEnabledChanged() {
            if (root.active)
                Qt.callLater(root.refreshFps);
        }
    }

    Process {
        id: fpsGetProc

        stdout: StdioCollector {
            onStreamFinished: {
                const value = Number(this.text.trim());

                if (Number.isInteger(value) && value >= 1 && value <= 240) {
                    root.waywallenFpsValue = value;
                    root.fpsError = "";
                } else {
                    root.fpsError = "Valore FPS Waywallen non valido";
                }
            }
        }

        onExited: function(exitCode) {
            if (exitCode !== 0)
                root.fpsError = "Impossibile leggere gli FPS da Waywallen";
        }
    }

    Process {
        id: fpsSetProc

        onExited: function(exitCode) {
            const applied = root.pendingWaywallenFps;
            root.pendingWaywallenFps = 0;

            if (exitCode === 0 && applied > 0) {
                root.waywallenFpsValue = applied;
                root.fpsError = "";
            } else {
                root.fpsError = "Impossibile applicare gli FPS in Waywallen";
                Qt.callLater(root.refreshFps);
            }

            const next = root.queuedWaywallenFps;
            root.queuedWaywallenFps = 0;

            if (next > 0 && next !== root.waywallenFpsValue) {
                Qt.callLater(function() {
                    root.setFps(next);
                });
            }
        }
    }

    rows: {
        var out = [
            { item: waywallenRow, kind: "toggle", get: function () { return Flags.waywallenEnabled; }, set: function (v) { Waywallen.setEnabled(v); } }
        ];
        out.push({
            item: fpsRow,
            kind: "seg",
            vals: [15, 24, 30, 60],
            get: function () { return root.fpsValue; },
            set: function (v) { root.setFps(v); }
        });
        if (!Flags.waywallenEnabled)
            out.push({ item: fitRow, kind: "seg", vals: ["crop", "fit", "stretch", "no"], get: function () { return Flags.wallpaperFit; }, set: function (v) { root.setWallpaperFit(v); } });
        out.push({ item: paletteRow, kind: "toggle", get: function () { return Flags.showColorPalettes; }, set: function (v) { Flags.showColorPalettes = v; } });
        if (Flags.waywallenEnabled)
            out.push({ item: waywallenOpenRow, kind: "text", activate: function () { Waywallen.openUI(); } });
        if (Flags.waywallenEnabled) {
            out.push({ item: waywallenDirRow, kind: "text", activate: function () {
                waywallenDirRow.editing = !waywallenDirRow.editing;
                if (waywallenDirRow.editing) {
                    waywallenDirField.text = Flags.waywallenWallpaperDir;
                    Qt.callLater(waywallenDirField.forceActiveFocus);
                }
            } });
        } else {
            out.push({ item: wpDirRow, kind: "text", activate: function () {
                wpDirRow.editing = !wpDirRow.editing;
                if (wpDirRow.editing) {
                    wpDirField.text = Flags.wallpaperDir;
                    Qt.callLater(wpDirField.forceActiveFocus);
                }
            } });
        }
        return out;
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "壁"
            title: "WALLPAPER"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: waywallenRow
            surface: root
            name: "Waywallen (Flatpak)"
            icon: "wallpaper"
            sub: Waywallen.busy ? "Configuring Waywallen…" :
                 (Flags.waywallenEnabled ? "Enabled · starts at login" : "Use Waywallen to choose wallpapers")
            LinkToggle {
                s: root.s
                enabled: !Waywallen.busy
                on: Flags.waywallenEnabled
                onToggled: Waywallen.setEnabled(!Flags.waywallenEnabled)
            }
        }

        SettingsRow {
            id: fpsRow
            surface: root
            name: "Animated wallpaper FPS"
            icon: "video"
            sub: root.fpsError.length > 0
                ? root.fpsError
                : (Flags.waywallenEnabled
                    ? "Frame rate for Waywallen video wallpapers"
                    : "Frame rate for local animated wallpapers")

            SettingsSeg {
                s: root.s
                compact: true
                options: [
                    { label: "15", value: 15 },
                    { label: "24", value: 24 },
                    { label: "30", value: 30 },
                    { label: "60", value: 60 }
                ]
                value: root.fpsValue
                onPicked: (v) => root.setFps(v)
            }
        }

        SettingsRow {
            id: paletteRow
            surface: root
            name: "Show color palettes"
            icon: "palette"
            sub: "Show palette dots in the wallpaper picker"
            LinkToggle {
                s: root.s
                on: Flags.showColorPalettes
                onToggled: Flags.showColorPalettes = !Flags.showColorPalettes
            }
        }

        SettingsRow {
            id: fitRow
            visible: !Flags.waywallenEnabled
            surface: root
            name: "Wallpaper fit"
            icon: "image"
            sub: "How local wallpapers fill the screen"

            SettingsSeg {
                s: root.s
                compact: true
                options: [
                    { label: "Cover", value: "crop" },
                    { label: "Contain", value: "fit" },
                    { label: "Stretch", value: "stretch" },
                    { label: "Center", value: "no" }
                ]
                value: Flags.wallpaperFit
                onPicked: (v) => root.setWallpaperFit(v)
            }
        }

        SettingsRow {
            id: waywallenOpenRow
            visible: Flags.waywallenEnabled
            surface: root
            name: "Open Waywallen"
            icon: "wallpaper"
            sub: "Manage libraries and choose wallpapers"
            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: waywallenOpenRow.focused ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }

        SettingsRow {
            id: waywallenDirRow
            visible: Flags.waywallenEnabled
            surface: root
            name: "Waywallen folder"
            icon: "wallpaper"
            sub: waywallenDirRow.editing ? "Return to save · Esc to cancel" :
                (Flags.waywallenWallpaperDir.length > 0 ? "Allowed by Flatpak · add it in Waywallen → Libraries" : "Optional · for folders outside Pictures/Videos")
            captionOnFocus: true
            last: true
            property bool editing: false

            Item {
                width: waywallenDirRow.editing ? 200 * root.s : 26 * root.s
                height: 26 * root.s
                Behavior on width { NumberAnimation { duration: Motion.fast } }
                Rectangle {
                    anchors.fill: parent
                    radius: 9 * root.s
                    visible: waywallenDirRow.editing
                    color: Qt.alpha(Theme.frameBg, 0.7)
                    border.width: 1
                    border.color: waywallenDirField.activeFocus ? Qt.alpha(Theme.vermLit, 0.7) : Theme.hairSoft
                }
                TextInput {
                    id: waywallenDirField
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10 * root.s
                    anchors.rightMargin: 10 * root.s
                    visible: waywallenDirRow.editing
                    clip: true
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    selectByMouse: true
                    selectionColor: Theme.verm
                    Keys.onPressed: (e) => {
                        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            var nextPath = text.trim();
                            Flags.waywallenWallpaperDir = nextPath;
                            Flags.wallpaperDir = nextPath;
                            if (nextPath.length > 0) Waywallen.allowFolder(nextPath);
                            Qt.callLater(Walls.refresh);
                            waywallenDirRow.editing = false;
                            focus = false;
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Escape) {
                            waywallenDirRow.editing = false;
                            focus = false;
                            e.accepted = true;
                        }
                    }
                }
                GlyphIcon {
                    anchors.centerIn: parent
                    visible: !waywallenDirRow.editing
                    width: 15 * root.s
                    height: 15 * root.s
                    name: "wallpaper"
                    color: waywallenDirRow.focused ? Theme.cream : Theme.iconDim
                    stroke: 1.7
                }
            }
        }

        SettingsRow {
            id: wpDirRow
            visible: !Flags.waywallenEnabled
            surface: root
            name: "Wallpaper folder"
            icon: "wallpaper"
            sub: wpDirRow.editing ? "Return to save · Esc to cancel" : Walls.wpDir
            captionOnFocus: true
            last: true
            property bool editing: false

            Item {
                width: wpDirRow.editing ? 200 * root.s : 26 * root.s
                height: 26 * root.s
                Behavior on width { NumberAnimation { duration: Motion.fast } }
                Rectangle {
                    anchors.fill: parent
                    radius: 9 * root.s
                    visible: wpDirRow.editing
                    color: Qt.alpha(Theme.frameBg, 0.7)
                    border.width: 1
                    border.color: wpDirField.activeFocus ? Qt.alpha(Theme.vermLit, 0.7) : Theme.hairSoft
                }
                TextInput {
                    id: wpDirField
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10 * root.s
                    anchors.rightMargin: 10 * root.s
                    visible: wpDirRow.editing
                    clip: true
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    selectByMouse: true
                    selectionColor: Theme.verm
                    Keys.onPressed: (e) => {
                        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            Flags.wallpaperDir = text.trim();
                            Walls.refresh();
                            wpDirRow.editing = false;
                            focus = false;
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Escape) {
                            wpDirRow.editing = false;
                            focus = false;
                            e.accepted = true;
                        }
                    }
                }
                GlyphIcon {
                    anchors.centerIn: parent
                    visible: !wpDirRow.editing
                    width: 15 * root.s
                    height: 15 * root.s
                    name: "wallpaper"
                    color: wpDirRow.focused ? Theme.cream : Theme.iconDim
                    stroke: 1.7
                }
            }
        }
    }
}
