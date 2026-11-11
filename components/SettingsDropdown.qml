pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"

Item {
    id: root

    property real s: 1
    property var options: []
    property var value: ""
    property bool open: false

    signal picked(var value)
    signal requestToggle()

    readonly property real chipHeight: 26 * root.s
    readonly property real panelHeight: root.open
        ? Math.min(root.options.length * 23 * root.s + 4 * root.s, 154 * root.s)
        : 0

    readonly property string currentLabel: {
        for (var i = 0; i < root.options.length; i++) {
            if (String(root.options[i].value) === String(root.value))
                return root.options[i].label;
        }
        return root.options.length > 0 ? root.options[0].label : "";
    }

    width: 138 * root.s
    implicitHeight: chipHeight
        + (root.open ? 4 * root.s + panelHeight : 0)
    height: implicitHeight
    z: root.open ? 80 : 0

    Rectangle {
        id: chip
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.chipHeight
        radius: 9 * root.s
        color: root.open ? Qt.alpha(Theme.onGlow, 0.14)
            : (chipHover.hovered ? Theme.frameBg : "transparent")
        border.width: 1
        border.color: root.open ? Qt.alpha(Theme.onGlow, 0.5) : Theme.hairSoft

        Behavior on color {
            ColorAnimation { duration: Motion.fast }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10 * root.s
            anchors.right: arrow.left
            anchors.rightMargin: 5 * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentLabel
            elide: Text.ElideRight
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
            font.weight: Font.DemiBold
        }

        GlyphIcon {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 13 * root.s
            height: 13 * root.s
            name: root.open ? "chevron-up" : "chevron-down"
            color: Theme.iconDim
            stroke: 2
        }

        HoverHandler { id: chipHover }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.requestToggle()
        }
    }

    Rectangle {
        id: panel
        anchors.top: chip.bottom
        anchors.topMargin: root.open ? 4 * root.s : 0
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.panelHeight
        visible: root.open
        clip: true
        radius: 9 * root.s

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }
        border.width: 1
        border.color: Theme.frameBorder

        ListView {
            anchors.fill: parent
            anchors.margins: 2 * root.s
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.options

            delegate: Rectangle {
                id: optionRow
                required property var modelData

                readonly property bool selected:
                    String(root.value) === String(optionRow.modelData.value)
                readonly property bool allowed:
                    optionRow.modelData.enabled !== false

                width: ListView.view.width
                height: 23 * root.s
                radius: 7 * root.s
                color: optionHover.hovered
                    ? Theme.frameBg
                    : (optionRow.selected ? Qt.alpha(Theme.onGlow, 0.16) : "transparent")

                HoverHandler { id: optionHover }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 9 * root.s
                    anchors.right: parent.right
                    anchors.rightMargin: 7 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: optionRow.modelData.label
                    elide: Text.ElideRight
                    color: !optionRow.allowed ? Qt.alpha(Theme.subtle, 0.45)
                        : (optionRow.selected ? Theme.cream : Theme.subtle)
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
                    font.weight: optionRow.selected ? Font.Bold : Font.Medium
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: optionRow.allowed
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.picked(optionRow.modelData.value)
                }
            }
        }
    }
}
