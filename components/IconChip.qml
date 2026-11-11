pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"

Rectangle {
    id: chip

    property real s: 1
    property string glyph: ""
    property real glyphSize: 13 * chip.s
    property real stroke: 1.8
    property color glyphColor: chip.hovered ? Theme.vermLit : Theme.iconDim
    property bool hoverFill: true
    property bool hoverBorder: false
    property bool spinning: false
    property string tooltipTitle: ""
    property string tooltipDesc: ""
    signal clicked()

    width: 22 * chip.s
    height: 22 * chip.s
    radius: height / 2
    color: (chip.hoverFill && hover.hovered) ? Theme.frameBg : "transparent"
    border.width: (chip.hoverBorder && hover.hovered) ? 1 : 0
    border.color: Theme.hairSoft

    GlyphIcon {
        id: icon
        anchors.centerIn: parent
        width: chip.glyphSize
        height: chip.glyphSize
        name: chip.glyph
        color: chip.glyphColor
        stroke: chip.stroke

        Behavior on color {
            ColorAnimation { duration: Motion.fast }
        }

        RotationAnimation on rotation {
            running: chip.spinning
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
        }

        Connections {
            target: chip
            function onSpinningChanged() {
                if (!chip.spinning)
                    icon.rotation = 0;
            }
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }

    Tooltip {
        s: chip.s
        placement: "below"
        align: "right"
        title: chip.tooltipTitle
        desc: chip.tooltipDesc
        show: chip.tooltipTitle.length > 0 && hover.hovered
    }
}
