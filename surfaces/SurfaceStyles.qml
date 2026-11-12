pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import "../components"

SettingsSurface {
    id: root

    backSurface: "theme"
    implicitHeight: content.implicitHeight
    property int openPicker: 0

    Component.onCompleted: {
        if (["default", "matrix", "cassette"].indexOf(Flags.styleMedia) < 0)
            Flags.styleMedia = "default";
    }

    readonly property var displayChoices: [
        { label: "Dynamic", value: "custom" },
        { label: "Status", value: "minimal" },
        { label: "Classic", value: "classic" },
        { label: "System", value: "system" },
        {
            label: "Strip",
            value: "strip",
            enabled: Flags.dockPosition !== "top-left"
                && Flags.dockPosition !== "top-right"
        }
    ]

    readonly property var mediaStyleChoices: [
        { label: "Default", value: "default" },
        { label: "Matrix", value: "matrix" },
        { label: "Musicassetta", value: "cassette" }
    ]

    readonly property var scratchChoices: [
        { label: "Default", value: "default" },
        { label: "Cassette", value: "cassette" },
        { label: "Index", value: "index" },
        { label: "Console", value: "console" },
        { label: "Ash", value: "ash" }
    ]

    rows: [
        {
            item: pillStyleRow,
            kind: "seg",
            vals: ["custom", "minimal", "classic", "system", "strip"],
            get: function () { return Flags.mainDisplay; },
            set: function (v) {
                if (v === "strip"
                        && (Flags.dockPosition === "top-left"
                            || Flags.dockPosition === "top-right"))
                    return;
                Flags.mainDisplay = v;
            }
        },
        {
            item: mediaStyleRow,
            kind: "seg",
            vals: ["default", "matrix", "cassette"],
            get: function () { return Flags.styleMedia; },
            set: function (v) { Flags.styleMedia = v; }
        },
        {
            item: scratchStyleRow,
            kind: "seg",
            vals: ["default", "cassette", "index", "console", "ash"],
            get: function () { return Flags.styleScratch; },
            set: function (v) { Flags.styleScratch = v; }
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
            glyph: "枠"
            title: "SURFACE STYLES"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: pillStyleRow
            surface: root
            name: "Pill display"
            icon: "clock"
            sub: "Layout of the resting pill"
            z: root.openPicker === 1 ? 20 : 0

            SettingsDropdown {
                s: root.s
                options: root.displayChoices
                value: Flags.mainDisplay
                open: root.openPicker === 1
                onRequestToggle: root.openPicker = root.openPicker === 1 ? 0 : 1
                onPicked: (v) => {
                    if (v === "strip"
                            && (Flags.dockPosition === "top-left"
                                || Flags.dockPosition === "top-right"))
                        return;
                    Flags.mainDisplay = v;
                    root.openPicker = 0;
                }
            }
        }

        SettingsRow {
            id: mediaStyleRow
            surface: root
            name: "Media Player"
            icon: "music"
            sub: "Choose the player card design"
            z: root.openPicker === 2 ? 20 : 0

            SettingsDropdown {
                s: root.s
                options: root.mediaStyleChoices
                value: Flags.styleMedia
                open: root.openPicker === 2

                onRequestToggle: root.openPicker =
                    root.openPicker === 2 ? 0 : 2

                onPicked: (v) => {
                    Flags.styleMedia = v;
                    root.openPicker = 0;
                }
            }
        }

        SettingsRow {
            id: scratchStyleRow
            surface: root
            name: "Scratchpad"
            icon: "type"
            sub: "Choose the notes deck layout"
            z: root.openPicker === 3 ? 20 : 0
            last: true

            SettingsDropdown {
                s: root.s
                options: root.scratchChoices
                value: Flags.styleScratch
                open: root.openPicker === 3
                onRequestToggle: root.openPicker = root.openPicker === 3 ? 0 : 3
                onPicked: (v) => {
                    Flags.styleScratch = v;
                    root.openPicker = 0;
                }
            }
        }
    }
}
