pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import "../components"

SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight

    rows: [
        {
            item: positionRow,
            kind: "seg",
            vals: ["bottom", "left", "right", "top-left", "top-right"],
            get: function () { return Flags.dockPosition; },
            set: function (v) { Flags.dockPosition = v; }
        },
        {
            item: sizeRow,
            kind: "seg",
            vals: [30, 36, 42, 50],
            get: function () { return Flags.dockSize; },
            set: function (v) { Flags.dockSize = v; }
        },
        {
            item: enabledRow,
            kind: "toggle",
            get: function () { return Flags.dockEnabled; },
            set: function (v) { Flags.dockEnabled = v; }
        },
        {
            item: alwaysRow,
            kind: "toggle",
            get: function () { return Flags.dockAlwaysVisible; },
            set: function (v) { Flags.dockAlwaysVisible = v; }
        },
        {
            item: durationRow,
            kind: "seg",
            vals: [1, 2, 4, 6, 10],
            get: function () { return Flags.dockRevealSeconds; },
            set: function (v) { Flags.dockRevealSeconds = v; }
        }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "埠"
            title: "DOCK"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: positionRow
            surface: root
            name: "Position"
            sub: "Dock edge and corner"

            SettingsSeg {
                s: root.s
                compact: true
                options: [
                    { label: "Bottom", value: "bottom" },
                    { label: "Left", value: "left" },
                    { label: "Right", value: "right" },
                    { label: "Top L", value: "top-left" },
                    { label: "Top R", value: "top-right" }
                ]
                value: Flags.dockPosition
                onPicked: (v) => Flags.dockPosition = v
            }
        }

        SettingsRow {
            id: sizeRow
            surface: root
            name: "Size"
            sub: "Dock and icon size"

            SettingsSeg {
                s: root.s
                compact: true
                options: [
                    { label: "30", value: 30 },
                    { label: "36", value: 36 },
                    { label: "42", value: 42 },
                    { label: "50", value: 50 }
                ]
                value: Flags.dockSize
                onPicked: (v) => Flags.dockSize = v
            }
        }

        SettingsRow {
            id: enabledRow
            surface: root
            name: "Dock enabled"
            sub: "Enable the floating dock"

            LinkToggle {
                s: root.s
                on: Flags.dockEnabled
                onToggled: Flags.dockEnabled = !Flags.dockEnabled
            }
        }

        SettingsRow {
            id: alwaysRow
            surface: root
            name: "Always visible"
            sub: "Keep the dock on screen"

            LinkToggle {
                s: root.s
                on: Flags.dockAlwaysVisible
                onToggled: Flags.dockAlwaysVisible = !Flags.dockAlwaysVisible
            }
        }

        SettingsRow {
            id: durationRow
            surface: root
            name: "Reveal duration"
            sub: "Seconds before hiding"
            last: true

            SettingsSeg {
                s: root.s
                compact: true
                options: [
                    { label: "1s", value: 1 },
                    { label: "2s", value: 2 },
                    { label: "4s", value: 4 },
                    { label: "6s", value: 6 },
                    { label: "10s", value: 10 }
                ]
                value: Flags.dockRevealSeconds
                onPicked: (v) => Flags.dockRevealSeconds = v
            }
        }
    }
}
