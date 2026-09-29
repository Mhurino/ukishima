pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"

Item {
    id: root

    property real s: 1
    property var entry: null
    property bool active: false
    property bool pinned: false
    property bool hovered: body.containsMouse

    signal activated(var entry)
    signal pinRequested(var entry)

    readonly property real tileSize: 48 * s
    readonly property real iconSize: 30 * s

    width: tileSize
    height: tileSize

    Rectangle {
        id: tile
        anchors.fill: parent
        radius: Motion.rTile * root.s
        color: root.active
            ? Qt.alpha(Theme.vermLit, root.hovered ? 0.18 : 0.12)
            : (root.hovered
                ? Qt.alpha(Theme.cream, 0.08)
                : Qt.alpha(Theme.cream, 0.045))
        border.width: root.active ? 1 : 0
        border.color: Qt.alpha(Theme.vermLit, 0.5)

        Behavior on color {
            ColorAnimation {
                duration: Motion.fast
                easing.type: Motion.easeStandard
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Motion.fast
                easing.type: Motion.easeStandard
            }
        }
    }

    Rectangle {
        id: iconBacking
        anchors.centerIn: parent
        width: 34 * root.s
        height: 34 * root.s
        radius: 9 * root.s
        color: Qt.alpha(Theme.cream, 0.045)
        visible: !appIcon.visible
    }

    Image {
        id: appIcon
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        sourceSize.width: Math.round(64 * root.s)
        sourceSize.height: Math.round(64 * root.s)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        visible: status === Image.Ready && source !== ""
        source: root.entry && root.entry.icon
            ? Quickshell.iconPath(root.entry.icon, true)
            : ""
    }

    GlyphIcon {
        id: fallbackIcon
        anchors.centerIn: parent
        width: 22 * root.s
        height: 22 * root.s
        name: "app-window"
        color: root.active ? Theme.vermLit : Theme.iconDim
        stroke: 1.6
        visible: !appIcon.visible
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -4 * root.s
        width: root.active ? 12 * root.s : 0
        height: 2 * root.s
        radius: height / 2
        color: Theme.vermLit

        Behavior on width {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Motion.easeStandard
            }
        }
    }

    Rectangle {
        id: pinBadge
        anchors.right: parent.right
        anchors.top: parent.top
        width: 17 * root.s
        height: 17 * root.s
        radius: width / 2
        color: Theme.cardTop
        border.width: 1
        border.color: Theme.frameBorder
        visible: root.active
              && !root.pinned
              && root.entry
              && root.hovered
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.75
        z: 2

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Motion.easeStandard
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Motion.easeStandard
            }
        }

        Text {
            anchors.centerIn: parent
            text: "+"
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            font.weight: Font.Bold
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -3 * root.s
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pinRequested(root.entry)
        }
    }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        z: 1
        onClicked: root.activated(root.entry)
    }
}
