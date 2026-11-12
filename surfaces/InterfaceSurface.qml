pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 面 INTERFACE sub-surface: general shell behaviour that is not tied to the
 * clock or the theme — the UI scale, reduced motion, and whether the pill
 * auto-hides. Reached from the Appearance index and folds back to it on the
 * back chevron or an empty click.
 */
SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight

    rows: [
        { item: scaleRow, kind: "seg", vals: [0.9, 1.0, 1.1, 1.25], get: function () { return Flags.uiScale; }, set: function (v) { Flags.uiScale = v; } },
        { item: tapRow, kind: "seg", vals: ["pill", "media"], get: function () { return Flags.expandTo; }, set: function (v) { Flags.expandTo = v; } },
        { item: motionStyleRow, kind: "seg", vals: ["standard", "snap", "float", "bounce"], get: function () { return Flags.motionStyle; }, set: function (v) { Flags.motionStyle = v; } },
        { item: motionRow, kind: "toggle", get: function () { return Flags.reduceMotion; }, set: function (v) { Flags.reduceMotion = v; } },
        { item: autoHideRow, kind: "toggle", get: function () { return Flags.autoHide; }, set: function (v) { Flags.autoHide = v; } },
        { item: saverRow, kind: "toggle", get: function () { return Flags.memorySaver; }, set: function (v) { Flags.memorySaver = v; } },
        { item: modulesRow, kind: "nav", surface: "modules" },
        { item: rightClickRow, kind: "nav", surface: "rightclick" }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "面"
            title: "INTERFACE"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: scaleRow
            surface: root
            name: "UI scale"
            icon: "scaling"

            SettingsSeg {
                s: root.s
                options: [{ label: "90%", value: 0.9 }, { label: "100%", value: 1.0 }, { label: "110%", value: 1.1 }, { label: "125%", value: 1.25 }]
                value: Flags.uiScale
                onPicked: (v) => Flags.uiScale = v
            }
        }

        SettingsRow {
            id: tapRow
            surface: root
            name: "Pill tap"
            icon: "mouse"
            sub: "Expand the pill or open the media player"

            SettingsSeg {
                s: root.s
                compact: true
                options: [
                    { label: "Expand", value: "pill" },
                    { label: "Media", value: "media" }
                ]
                value: Flags.expandTo
                onPicked: (v) => Flags.expandTo = v
            }
        }

        SettingsRow {
            id: motionStyleRow
            surface: root
            name: "Animation style"
            icon: "sparkles"
            sub: "Standard, Snap, Float or Bounce"

            SettingsSeg {
                s: root.s
                compact: true
                options: [
                    { label: "Standard", value: "standard" },
                    { label: "Snap", value: "snap" },
                    { label: "Float", value: "float" },
                    { label: "Bounce", value: "bounce" }
                ]
                value: Flags.motionStyle
                onPicked: (v) => Flags.motionStyle = v
            }
        }

        SettingsRow {
            id: motionRow
            surface: root
            name: "Reduce motion"
            icon: "waves"

            LinkToggle {
                s: root.s
                on: Flags.reduceMotion
                onToggled: Flags.reduceMotion = !Flags.reduceMotion
            }
        }

        SettingsRow {
            id: autoHideRow
            surface: root
            name: "Auto hide"
            icon: "eye-off"

            LinkToggle {
                s: root.s
                on: Flags.autoHide
                onToggled: Flags.autoHide = !Flags.autoHide
            }
        }

        SettingsRow {
            id: saverRow
            surface: root
            name: "Memory saver"
            icon: "stopwatch"

            LinkToggle {
                s: root.s
                on: Flags.memorySaver
                onToggled: Flags.memorySaver = !Flags.memorySaver
            }
        }

        SettingsRow {
            id: modulesRow
            surface: root
            name: "Modules"
            icon: "mixer"
            sub: "Choose which shortcuts appear in the pill"
            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: modulesRow.focused ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }

        SettingsRow {
            id: rightClickRow
            surface: root
            name: "Right-click cycle"
            icon: "mouse"
            sub: "Choose the extra stops after Media and Timer"
            last: true

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: rightClickRow.focused ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }
    }
}
