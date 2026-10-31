pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../Singletons"
import "../components"

/**
 * 色 THEME sub-surface: the theme switch (light or dark pill, dynamic
 * per-wallpaper, or a manually chosen hue) with the manual hue editor that
 * unfolds beneath it, and the wallpaper folder that feeds the rotation.
 * Reached from the Appearance index and folds back to it on the back chevron
 * or an empty click.
 *
 * Manual palette mode reveals a rainbow hue strip and a dark/light choice; moving
 * either rebuilds the rice colour set from that hue through wallcolors.py --hue
 * and reloads Hyprland and the terminal, debounced so a drag does not spawn a
 * build per pixel.
 */
SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight

    property string hueArg: String(Math.round(Flags.manualHue))
    property string modeArg: Flags.manualDark ? "dark" : "light"
    property string satArg: String(Flags.manualSat)

    /** Current theme key; legacy "static" reads as the dark pill. */
    readonly property string themeMode: Flags.paletteMode === "static" ? "dark" : Flags.paletteMode

    /** Accent override on: a custom hex is pinned and wins over every palette mode. */
    readonly property bool accentCustom: Flags.accentOverride.length > 0

    /** The live accent colour — the pinned hex when custom, else the scheme's. */
    readonly property color accentColorValue: root.accentCustom ? Flags.accentOverride : Theme.accent
    /* QML color hsl* are 0-1 fractions in this build (not 0-359/0-255); the
     * guards collapse undefined hues (grayscale/black report NaN) to 0.
     * The sat/light values carry a visibility floor: with only hue and
     * saturation sliders there is no lightness control, so a black or grey
     * accent typed into the hex field would otherwise be unmovable — every
     * drag would write black again. Flooring the working sat/light makes any
     * slider change from a degenerate accent land on a clearly visible colour. */
    readonly property real accentHue01: accentColorValue.hslHue >= 0 ? Math.min(1, accentColorValue.hslHue) : 0
    readonly property real accentSat01: accentColorValue.hslSaturation >= 0 ? Math.max(0.3, Math.min(1, accentColorValue.hslSaturation)) : 0.3
    readonly property real accentLight01: accentColorValue.hslLightness >= 0 ? Math.max(0.35, Math.min(1, accentColorValue.hslLightness)) : 0.35
    /* The knob fill stays a fixed light grey instead of the live colour so the
     * circle never disappears into the track it sits on (the track paints the
     * picked colour, so a self-tinted knob would blend right in). A soft dark
     * ring keeps the edge visible even over the lightest track segments. */
    readonly property color sliderKnob: "#e6e6e6"
    readonly property color sliderKnobRing: Qt.rgba(0, 0, 0, 0.45)

    /* The one hex conversion lives in Theme; see `hexUpper` there for why it is
     * not a private copy per surface. */
    function rgbHex(c) {
        return Theme.hexUpper(c);
    }

    /** Row caption: custom state, plus the scheme accent when following it. */
    readonly property string accentSub: root.accentCustom
        ? "Custom · " + Flags.accentOverride.toUpperCase()
        : ("Follows theme · " + root.rgbHex(Theme.accent))

    function setAccentCustom(on) {
        if (on) {
            if (Flags.accentOverride.length === 0)
                Flags.accentOverride = root.rgbHex(Theme.accent);
            accentHueSlider.value = root.accentHue01;
            accentSatSlider.value = root.accentSat01;
        } else {
            Flags.accentOverride = "";
        }
    }

    /** Rebuild the pinned hex from hue (0-359) / sat (0-1) / light (0-1). */
    function setAccentHsl(hDeg, s01, l01) {
        var hue01 = Math.max(0, Math.min(1, hDeg / 360));
        /* Floor sat/light so a drag from a degenerate (black/gray) seed never
         * writes #000000 — the sliders must always produce a visible colour. */
        var col = Qt.hsla(hue01, Math.max(0.05, Math.min(1, s01)), Math.max(0.05, Math.min(1, l01)), 1);
        Flags.accentOverride = root.rgbHex(col);
    }

    readonly property color accentColor: Qt.hsla(Flags.manualHue / 360, Flags.manualSat, Flags.manualDark ? 0.5 : 0.62, 1)
    readonly property string currentHex: {
        var c = accentColor;
        function h(x) { return ("0" + Math.round(x * 255).toString(16)).slice(-2); }
        return ("#" + h(c.r) + h(c.g) + h(c.b)).toUpperCase();
    }

    function applyManual() {
        hueArg = String(Math.round(Flags.manualHue));
        modeArg = Flags.manualDark ? "dark" : "light";
        satArg = String(Flags.manualSat);
        applyTimer.restart();
    }

    function applyMode(v) {
        if (v !== root.themeMode)
            Flags.oled = false;
        Flags.paletteMode = v;
        if (v === "manual")
            applyManual();
        else if (v === "dynamic")
            dynamicProc.running = true;
    }

    Timer {
        id: applyTimer
        interval: 260
        repeat: false
        onTriggered: paletteProc.running = true
    }

    Process {
        id: paletteProc
        command: ["sh", "-c",
            "wallscript=\"" + Config.hyprPath("scripts", "wallcolors.py") + "\"; python3 \"$wallscript\" --hue \"$1\" \"$2\" \"$3\" && hyprctl reload >/dev/null 2>&1; busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions Activate \"sava{sv}\" reload-config 0 0 >/dev/null 2>&1 || true",
            "sh", root.hueArg, root.modeArg, root.satArg]
    }

    Process {
        id: dynamicProc
        command: ["sh", "-c",
            "f=\"${XDG_STATE_HOME:-$HOME/.local/state}/ukishima-wallpaper\"; pic=$(cat \"$f\" 2>/dev/null); case \"$pic\" in *.[Mm][Pp]4|*.[Ww][Ee][Bb][Mm]|*.[Mm][Kk][Vv]|*.[Mm][Oo][Vv]) pic=\"${XDG_STATE_HOME:-$HOME/.local/state}/ukishima-wallpaper-still.png\";; esac; palette_file=\"${XDG_STATE_HOME:-$HOME/.local/state}/ukishima-wallpaper-palette-source\"; palette_pic=$(cat \"$palette_file\" 2>/dev/null); [ -f \"$palette_pic\" ] && pic=\"$palette_pic\"; wallscript=\"" + Config.hyprPath("scripts", "wallcolors.py") + "\"; [ -f \"$pic\" ] && python3 \"$wallscript\" \"$pic\" >/dev/null 2>&1; hyprctl reload >/dev/null 2>&1; busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions Activate \"sava{sv}\" reload-config 0 0 >/dev/null 2>&1 || true"]
    }

    Connections {
        target: Flags
        function onManualHueChanged() {
            if (Flags.paletteMode === "manual")
                root.applyManual();
        }
        function onManualSatChanged() {
            if (Flags.paletteMode === "manual")
                root.applyManual();
        }
        function onPaletteModeChanged() {
            if (root.themeMode !== "dark" && Flags.oled)
                Flags.oled = false;
        }
    }

    rows: {
        var out = [
            { item: paletteRow, kind: "seg", vals: ["light", "dark", "dynamic", "manual"], get: function () { return root.themeMode; }, set: function (v) { root.applyMode(v); } }
        ];
        if (root.themeMode === "dark")
            out.push({ item: oledRow, kind: "toggle", get: function () { return Flags.oled; }, set: function (v) { Flags.oled = v; } });
        out.push({ item: accentRow, kind: "toggle", get: function () { return root.accentCustom; }, set: function (v) { root.setAccentCustom(v); } });
        out.push({ item: glassRow, kind: "toggle", get: function () { return Flags.glass; }, set: function (v) { Flags.glass = v; } });
        if (Flags.glass)
            out.push({ item: glassTextRow, kind: "seg", vals: [0, 0.5, 1], get: function () { return Flags.glassTransparency; }, set: function (v) { Flags.glassTransparency = v; } });
        out.push({ item: colorPalettesRow, kind: "toggle", get: function () { return Flags.showColorPalettes; }, set: function (v) { Flags.showColorPalettes = v; } });
        out.push({ item: waywallenRow, kind: "toggle", get: function () { return Flags.waywallenEnabled; }, set: function (v) { Waywallen.setEnabled(v); } });
        if (Flags.waywallenEnabled) {
            out.push({ item: waywallenOpenRow, kind: "text", activate: function () { Waywallen.openUI(); } });
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
            glyph: "色"
            title: "THEME"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: paletteRow
            surface: root
            name: "Theme"
            icon: "palette"

            SettingsSeg {
                s: root.s
                options: [{ label: "Light", value: "light" }, { label: "Dark", value: "dark" }, { label: "Dynamic", value: "dynamic" }, { label: "Manual", value: "manual" }]
                value: root.themeMode
                onPicked: (v) => root.applyMode(v)
            }
        }

        SettingsRow {
            id: oledRow
            surface: root
            name: "OLED"
            icon: "moon"
            visible: root.themeMode === "dark"

            LinkToggle {
                s: root.s
                on: Flags.oled
                onToggled: Flags.oled = !Flags.oled
            }
        }

        SettingsRow {
            id: accentRow
            surface: root
            name: "Accent color"
            icon: "sparkles"
            sub: root.accentSub

            Item {
                width: accentChip.width + 10 * root.s + accentToggle.width
                height: 26 * root.s

                Rectangle {
                    id: accentChip
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20 * root.s
                    height: 20 * root.s
                    radius: 6 * root.s
                    color: root.accentColorValue
                    border.width: 1
                    border.color: Theme.hairSoft
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                LinkToggle {
                    id: accentToggle
                    anchors.left: accentChip.right
                    anchors.leftMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.s
                    on: root.accentCustom
                    onToggled: root.setAccentCustom(!root.accentCustom)
                }
            }
        }

        Item {
            id: accentSection
            width: parent.width
            height: root.accentCustom ? accentPanel.implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

            Column {
                id: accentPanel
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12 * root.s
                anchors.rightMargin: 12 * root.s
                topPadding: 4 * root.s
                bottomPadding: 16 * root.s
                spacing: 14 * root.s

                Item {
                    width: parent.width
                    height: 26 * root.s

                    Slider {
                        id: accentHueSlider
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26 * root.s
                        from: 0
                        to: 1
                        stepSize: 0.005
                        onValueChanged: if (pressed) root.setAccentHsl(Math.round(accentHueSlider.value * 359), root.accentSat01, root.accentLight01)
                        onMoved: root.setAccentHsl(Math.round(accentHueSlider.value * 359), root.accentSat01, root.accentLight01)
                        Component.onCompleted: accentHueSlider.value = root.accentHue01

                        background: Rectangle {
                            y: accentHueSlider.availableHeight / 2 - 7 * root.s
                            width: accentHueSlider.availableWidth
                            height: 14 * root.s
                            radius: 7 * root.s
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.hsla(0.0, 0.7, 0.5, 1) }
                                GradientStop { position: 1 / 6; color: Qt.hsla(1 / 6, 0.7, 0.5, 1) }
                                GradientStop { position: 2 / 6; color: Qt.hsla(2 / 6, 0.7, 0.5, 1) }
                                GradientStop { position: 3 / 6; color: Qt.hsla(3 / 6, 0.7, 0.5, 1) }
                                GradientStop { position: 4 / 6; color: Qt.hsla(4 / 6, 0.7, 0.5, 1) }
                                GradientStop { position: 5 / 6; color: Qt.hsla(5 / 6, 0.7, 0.5, 1) }
                                GradientStop { position: 1.0; color: Qt.hsla(1.0, 0.7, 0.5, 1) }
                            }
                        }
                        handle: Rectangle {
                            x: accentHueSlider.leftPadding + accentHueSlider.visualPosition * (accentHueSlider.availableWidth - width)
                            y: accentHueSlider.availableHeight / 2 - height / 2
                            width: 16 * root.s
                            height: 16 * root.s
                            radius: width / 2
                            color: root.sliderKnob
                            border.width: 2.5 * root.s
                            border.color: root.sliderKnobRing
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 26 * root.s

                    Slider {
                        id: accentSatSlider
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26 * root.s
                        from: 0
                        to: 1
                        stepSize: 0.005
                        onValueChanged: if (pressed) root.setAccentHsl(root.accentHue01 * 359, accentSatSlider.value, root.accentLight01)
                        onMoved: root.setAccentHsl(root.accentHue01 * 359, accentSatSlider.value, root.accentLight01)
                        Component.onCompleted: accentSatSlider.value = root.accentSat01

                        background: Rectangle {
                            y: accentSatSlider.availableHeight / 2 - 7 * root.s
                            width: accentSatSlider.availableWidth
                            height: 14 * root.s
                            radius: 7 * root.s
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.hsla(root.accentHue01, 0.0, 0.5, 1) }
                                GradientStop { position: 0.5; color: Qt.hsla(root.accentHue01, 0.5, 0.5, 1) }
                                GradientStop { position: 1.0; color: Qt.hsla(root.accentHue01, 1.0, 0.5, 1) }
                            }
                        }
                        handle: Rectangle {
                            x: accentSatSlider.leftPadding + accentSatSlider.visualPosition * (accentSatSlider.availableWidth - width)
                            y: accentSatSlider.availableHeight / 2 - height / 2
                            width: 16 * root.s
                            height: 16 * root.s
                            radius: width / 2
                            color: root.sliderKnob
                            border.width: 2.5 * root.s
                            border.color: root.sliderKnobRing
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Math.max(34 * root.s, accentHexField.implicitHeight)

                    Rectangle {
                        id: accentPickSwatch
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34 * root.s
                        height: 34 * root.s
                        radius: 9 * root.s
                        color: root.accentColorValue
                        border.width: 1
                        border.color: Theme.border
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    Text {
                        id: accentHexHint
                        anchors.left: accentPickSwatch.right
                        anchors.leftMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: "#"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 14 * root.s
                        font.weight: Font.DemiBold
                    }

                    TextField {
                        id: accentHexField
                        anchors.left: accentHexHint.right
                        anchors.leftMargin: 6 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        background: null
                        padding: 0
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                        font.features: { "tnum": 1 }
                        selectByMouse: true
                        selectionColor: Theme.verm
                        maximumLength: 6

                        onActiveFocusChanged: if (!activeFocus) text = "";

                        function commit() {
                            var c = Theme.parseHex(text);
                            if (c) {
                                Flags.accentOverride = Theme.hexUpper(c);
                                accentHueSlider.value = root.accentHue01;
                                accentSatSlider.value = root.accentSat01;
                            }
                            text = "";
                            focus = false;
                        }

                        onAccepted: commit()
                        onEditingFinished: commit()

                        /* Enter/Space must apply, not leak into the surface's row
                         * activation (which would flip the Custom toggle and revert
                         * the hex). Accepting the key at the field stops it before
                         * the shell's settings-activate handler sees it. */
                        Keys.onPressed: (e) => {
                            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                commit();
                                e.accepted = true;
                            } else if (e.key === Qt.Key_Space) {
                                e.accepted = true;
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: accentHexField.left
                        anchors.right: accentHexField.right
                        anchors.top: accentHexField.bottom
                        anchors.topMargin: 3 * root.s
                        height: 1
                        color: Theme.faint
                        opacity: accentHexField.activeFocus ? 0.7 : 0.18
                        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                    }
                }
            }
        }

        SettingsRow {
            id: glassRow
            surface: root
            name: "Transparency mode"
            icon: "droplet"
            sub: "Translucent palette-tinted surfaces"
            LinkToggle {
                s: root.s
                on: Flags.glass
                onToggled: Flags.glass = !Flags.glass
            }
        }

        SettingsRow {
            id: glassTextRow
            surface: root
            name: "Transparency"
            icon: "droplet"
            sub: "Choose glass transparency"
            visible: Flags.glass
            enabled: Flags.glass
            SettingsSeg {
                s: root.s
                options: [
                    { label: "Low", value: 0 },
                    { label: "Medium", value: 0.5 },
                    { label: "High", value: 1 }
                ]
                value: Flags.glassTransparency
                onPicked: (v) => Flags.glassTransparency = v
            }
        }

        /**
         * Manual hue editor, folded shut unless the palette is on Manual. Holds a
         * rainbow strip with a draggable thumb, then a single line pairing a live
         * accent swatch and its hex caption with the dark/light choice, and a hex
         * input that drives both hue and saturation. The strip is mouse-driven and
         * stays out of the keyboard row registry.
         */
        SettingsRow {
            id: colorPalettesRow
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

        Item {
            id: manualSection
            width: parent.width
            height: Flags.paletteMode === "manual" ? manualCol.implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

            Column {
                id: manualCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12 * root.s
                anchors.rightMargin: 12 * root.s
                topPadding: 4 * root.s
                bottomPadding: 16 * root.s
                spacing: 14 * root.s

                Item {
                    width: parent.width
                    height: 14 * root.s

                    Rectangle {
                        id: hueStrip
                        anchors.fill: parent
                        radius: 7 * root.s
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.hsla(0.0, 0.7, 0.5, 1) }
                            GradientStop { position: 1 / 6; color: Qt.hsla(1 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 2 / 6; color: Qt.hsla(2 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 3 / 6; color: Qt.hsla(3 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 4 / 6; color: Qt.hsla(4 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 5 / 6; color: Qt.hsla(5 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 1.0; color: Qt.hsla(1.0, 0.7, 0.5, 1) }
                        }

                        Rectangle {
                            id: hueThumb
                            width: 16 * root.s
                            height: 16 * root.s
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: (Flags.manualHue / 359) * (hueStrip.width - width)
                            color: root.accentColor
                            border.width: 2.5 * root.s
                            border.color: Theme.cream
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            function setHue(mx) {
                                if (Flags.manualSat < 0.05)
                                    Flags.manualSat = 0.5;
                                Flags.manualHue = Math.round(Math.max(0, Math.min(1, mx / hueStrip.width)) * 359);
                            }
                            onPressed: (mouse) => setHue(mouse.x)
                            onPositionChanged: (mouse) => setHue(mouse.x)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Math.max(34 * root.s, toneSeg.implicitHeight)

                    Rectangle {
                        id: accentSwatch
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34 * root.s
                        height: 34 * root.s
                        radius: 9 * root.s
                        color: root.accentColor
                        border.width: 1
                        border.color: Theme.border
                    }

                    Column {
                        anchors.left: accentSwatch.right
                        anchors.leftMargin: 12 * root.s
                        anchors.right: toneSeg.left
                        anchors.rightMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3 * root.s

                        Text {
                            text: "Accent hue"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: root.currentHex + " · " + (Flags.manualDark ? "dark" : "light")
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            font.features: { "tnum": 1 }
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    SettingsSeg {
                        id: toneSeg
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        s: root.s
                        options: [{ label: "Dark", value: true }, { label: "Light", value: false }]
                        value: Flags.manualDark
                        onPicked: (v) => { Flags.manualDark = v; root.applyManual(); }
                    }
                }

                Item {
                    width: parent.width
                    height: 30 * root.s

                    Text {
                        id: hexHint
                        anchors.left: parent.left
                        anchors.leftMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: "#"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 14 * root.s
                        font.weight: Font.DemiBold
                    }

                    TextField {
                        id: hexField
                        anchors.left: hexHint.right
                        anchors.leftMargin: 6 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        background: null
                        padding: 0
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                        font.features: { "tnum": 1 }
                        placeholderText: root.currentHex
                        placeholderTextColor: Theme.faint
                        selectByMouse: true
                        selectionColor: Theme.verm
                        maximumLength: 7

                        onActiveFocusChanged: if (!activeFocus) text = "";

                        function commit() {
                            var raw = text.trim();
                            var clean = raw.charAt(0) === "#" ? raw.slice(1) : raw;
                            if (/^[0-9a-fA-F]{6}$/.test(clean)) {
                                var c = Qt.color("#" + clean);
                                if (c.hslHue >= 0) {
                                    Flags.manualHue = Math.round(c.hslHue);
                                    Flags.manualSat = c.hslSaturation / 255;
                                } else {
                                    Flags.manualSat = 0;
                                }
                                root.applyManual();
                            }
                            text = "";
                            focus = false;
                        }

                        onAccepted: commit()
                        onEditingFinished: commit()
                    }

                    Rectangle {
                        anchors.left: hexField.left
                        anchors.right: hexField.right
                        anchors.top: hexField.bottom
                        anchors.topMargin: 3 * root.s
                        height: 1
                        color: Theme.faint
                        opacity: hexField.activeFocus ? 0.7 : 0.18
                        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                    }
                }
            }
        }

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
