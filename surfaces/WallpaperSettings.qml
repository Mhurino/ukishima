pragma ComponentBehavior: Bound

import QtQuick
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

    rows: {
        var out = [
            { item: waywallenRow, kind: "toggle", get: function () { return Flags.waywallenEnabled; }, set: function (v) { Waywallen.setEnabled(v); } }
        ];
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
