pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import "../components"

/** Optional items in the expanded pill. Core status and system controls stay visible. */
SettingsSurface {
    id: root

    backSurface: "interface"
    implicitHeight: content.implicitHeight

    rows: [
        { item: sysmonRow, kind: "toggle", get: function () { return Flags.pillShowSysmon; }, set: function (v) { Flags.pillShowSysmon = v; } },
        { item: recorderRow, kind: "toggle", get: function () { return Flags.pillShowRecorder; }, set: function (v) { Flags.pillShowRecorder = v; } },
        { item: timerRow, kind: "toggle", get: function () { return Flags.pillShowTimer; }, set: function (v) { Flags.pillShowTimer = v; } },
        { item: wallpaperRow, kind: "toggle", get: function () { return Flags.pillShowWallpaper; }, set: function (v) { Flags.pillShowWallpaper = v; } },
        { item: scratchRow, kind: "toggle", get: function () { return Flags.pillShowScratch; }, set: function (v) { Flags.pillShowScratch = v; } },
        { item: launcherRow, kind: "toggle", get: function () { return Flags.pillShowLauncher; }, set: function (v) { Flags.pillShowLauncher = v; } },
        { item: powerRow, kind: "toggle", get: function () { return Flags.pillShowPower; }, set: function (v) { Flags.pillShowPower = v; } }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "組"
            title: "MODULES"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: sysmonRow
            surface: root
            name: "System monitor"
            icon: "monitor"
            sub: "Show the system monitor shortcut"
            LinkToggle { s: root.s; on: Flags.pillShowSysmon; onToggled: Flags.pillShowSysmon = !Flags.pillShowSysmon }
        }

        SettingsRow {
            id: recorderRow
            surface: root
            name: "Recorder"
            icon: "video"
            sub: "Show the screen recorder shortcut"
            LinkToggle { s: root.s; on: Flags.pillShowRecorder; onToggled: Flags.pillShowRecorder = !Flags.pillShowRecorder }
        }

        SettingsRow {
            id: timerRow
            surface: root
            name: "Timer"
            icon: "clock"
            sub: "Show the timer shortcut"
            LinkToggle { s: root.s; on: Flags.pillShowTimer; onToggled: Flags.pillShowTimer = !Flags.pillShowTimer }
        }

        SettingsRow {
            id: wallpaperRow
            surface: root
            name: "Wallpaper"
            icon: "wallpaper"
            sub: "Show the wallpaper browser shortcut"
            LinkToggle { s: root.s; on: Flags.pillShowWallpaper; onToggled: Flags.pillShowWallpaper = !Flags.pillShowWallpaper }
        }

        SettingsRow {
            id: scratchRow
            surface: root
            name: "Scratchpad"
            icon: "type"
            sub: "Show the scratchpad shortcut"
            LinkToggle { s: root.s; on: Flags.pillShowScratch; onToggled: Flags.pillShowScratch = !Flags.pillShowScratch }
        }

        SettingsRow {
            id: launcherRow
            surface: root
            name: "Launcher"
            icon: "app-window"
            sub: "Show the application launcher shortcut"
            LinkToggle { s: root.s; on: Flags.pillShowLauncher; onToggled: Flags.pillShowLauncher = !Flags.pillShowLauncher }
        }

        SettingsRow {
            id: powerRow
            surface: root
            name: "Power"
            icon: "shutdown"
            sub: "Show the power menu shortcut"
            last: true
            LinkToggle { s: root.s; on: Flags.pillShowPower; onToggled: Flags.pillShowPower = !Flags.pillShowPower }
        }
    }
}
