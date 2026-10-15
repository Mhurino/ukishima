pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"

// Palette-tinted Liquid Glass. Turning Glass off restores the old gradient.
Rectangle {
    id: glass

    property string style: "regular"
    property real materialOpacity: -1
    property real legacyOpacity: 1
    property real accent: 0.06
    property real sheenScale: 1
    property real veil: 0
    property color borderColor: glass.glassy ? Qt.alpha(Theme.cream, 0.14) : Theme.border
    property bool hovered: false
    property bool pressed: false
    property bool active: false

    readonly property bool glassy: Flags.glass
    readonly property real veilAlpha: glass.glassy
        ? Math.min(0.3, glass.veil)
        : 0
    readonly property real styleTint: glass.materialOpacity >= 0
        ? glass.materialOpacity : (glass.style === "clear" ? 0.62 : 0.78)
    readonly property real tintAlpha: {
        if (!glass.glassy)
            return glass.legacyOpacity;
        if (Theme.oled)
            return 1;
        // Low = less transparent; High = more transparent.
        var level = Math.max(0, Math.min(1, Flags.glassTransparency));
        var a = glass.styleTint * Flags.pillOpacity * (1.25 - 0.5 * level);
        if (glass.hovered) a += 0.05;
        if (glass.pressed) a -= 0.06;
        if (glass.active) a += 0.02;
        return Math.max(0.35, Math.min(0.95, a));
    }

    function blend(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, a.a);
    }

    readonly property color accentColor: Theme.onGlow
    readonly property color tintTop: glass.glassy && !Theme.oled
        ? Qt.alpha(blend(Theme.cardTop, accentColor, accent * (glass.active ? 1.3 : 1)), tintAlpha)
        : Qt.alpha(Theme.cardTop, tintAlpha)
    readonly property color tintBot: glass.glassy && !Theme.oled
        ? Qt.alpha(blend(Theme.cardBot, accentColor, accent * 0.6), tintAlpha)
        : Qt.alpha(Theme.cardBot, tintAlpha)

    border.width: 1
    border.color: glass.borderColor
    gradient: Gradient {
        GradientStop { position: 0.0; color: glass.tintTop }
        GradientStop { position: 1.0; color: glass.tintBot }
    }

    // Contrast veil is only painted when Glass is enabled.
    Rectangle {
        anchors.fill: parent
        anchors.margins: glass.border.width
        radius: Math.max(0, glass.radius - glass.border.width)
        visible: glass.glassy && glass.veilAlpha > 0
        color: Qt.rgba(0, 0, 0, glass.veilAlpha)
    }

    // Fine top highlight; when Glass is disabled this uses the legacy sheen.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.leftMargin: parent.radius * 0.6
        anchors.rightMargin: parent.radius * 0.6
        height: 1
        color: glass.glassy
            ? Qt.alpha(Theme.cream, 0.10 * glass.sheenScale * (glass.pressed ? 0.5 : 1))
            : Theme.sheen
    }
}
