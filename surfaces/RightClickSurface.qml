pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import "../components"

SettingsSurface {
    id: root

    backSurface: "interface"
    implicitHeight: content.implicitHeight
    property int openPicker: 0

    // Fixed stops are Media and Timer; these are the available optional stops.
    readonly property var cycleChoices: [
        { label: "Off", value: "" },
        { label: "Calendar", value: "calendar" },
        { label: "Weather", value: "weather" },
        { label: "Launcher", value: "launcher" },
        { label: "Clipboard", value: "clipboard" },
        { label: "Scratchpad", value: "scratch" },
        { label: "Wallpaper", value: "wallpaper" },
        { label: "Power", value: "power" },
        { label: "Beats", value: "beats" },
        { label: "Mixer", value: "mixer" },
        { label: "Link", value: "link" },
        { label: "Wi-Fi", value: "wifi" },
        { label: "Bluetooth", value: "bt" },
        { label: "Battery", value: "battery" },
        { label: "Recorder", value: "recorder" },
        { label: "System Monitor", value: "sysmon" },
        { label: "Appearance", value: "appearance" },
        { label: "Profile", value: "profile" }
    ]

    readonly property var cycleVals: {
        var out = [];
        for (var i = 0; i < root.cycleChoices.length; i++)
            out.push(root.cycleChoices[i].value);
        return out;
    }

    rows: [
        {
            item: slot4Row,
            kind: "seg",
            vals: root.cycleVals,
            get: function () { return Flags.cycleSlot4; },
            set: function (v) { Flags.cycleSlot4 = v; }
        },
        {
            item: slot5Row,
            kind: "seg",
            vals: root.cycleVals,
            get: function () { return Flags.cycleSlot5; },
            set: function (v) { Flags.cycleSlot5 = v; }
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
            glyph: "右"
            title: "RIGHT-CLICK"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: slot4Row
            surface: root
            name: "4th stop"
            icon: "mouse"
            sub: Flags.cycleSlot4 === ""
                ? "Off · skipped in the cycle"
                : "After Media and Timer"
            z: root.openPicker === 4 ? 20 : 0

            SettingsDropdown {
                s: root.s
                options: root.cycleChoices
                value: Flags.cycleSlot4
                open: root.openPicker === 4
                onRequestToggle: root.openPicker = root.openPicker === 4 ? 0 : 4
                onPicked: (v) => {
                    Flags.cycleSlot4 = v;
                    root.openPicker = 0;
                }
            }
        }

        SettingsRow {
            id: slot5Row
            surface: root
            name: "5th stop"
            icon: "mouse"
            sub: Flags.cycleSlot5 === ""
                ? "Off · right-click closes after stop 4"
                : "After the 4th stop"
            z: root.openPicker === 5 ? 20 : 0
            last: true

            SettingsDropdown {
                s: root.s
                options: root.cycleChoices
                value: Flags.cycleSlot5
                open: root.openPicker === 5
                onRequestToggle: root.openPicker = root.openPicker === 5 ? 0 : 5
                onPicked: (v) => {
                    Flags.cycleSlot5 = v;
                    root.openPicker = 0;
                }
            }
        }
    }
}
