pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../Singletons"

Item {
    id: root

    property real s: 1
    property var entry: null
    property bool active: false
    property bool pinned: false
    property bool hovered: body.containsMouse
    property bool running: false
    property bool workspaceHere: true
    property string workspaceLabel: ""
    property real size: 42

    signal activated(var entry)
    signal pinRequested(var entry)

    readonly property real tileSize: root.size * s
    readonly property real iconSize: root.size * 0.62 * s

    width: tileSize
    height: tileSize

    Rectangle {
        id: tile
        anchors.fill: parent
        radius: Motion.rTile * root.s
        color: root.active
            ? Qt.alpha(Theme.vermLit, root.hovered ? 0.20 : 0.13)
            : root.running
                ? Qt.alpha(Theme.cream, root.hovered ? 0.11 : 0.075)
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
        width: 30 * root.s
        height: 30 * root.s
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
        width: 19 * root.s
        height: 19 * root.s
        name: "app-window"
        color: root.active ? Theme.vermLit : Theme.iconDim
        stroke: 1.6
        visible: !appIcon.visible
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -4 * root.s

        width: root.active
            ? 12 * root.s
            : root.running
                ? 6 * root.s
                : 0

        height: 2 * root.s
        radius: height / 2

        color: root.active
            ? Theme.vermLit
            : Theme.iconDim

        Behavior on width {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Motion.easeStandard
            }
        }
    }

    Rectangle {
        visible: root.running && !root.workspaceHere
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -6 * root.s
        width: Math.max(14 * root.s, workspaceText.implicitWidth + 6 * root.s)
        height: 14 * root.s
        radius: height / 2
        color: Theme.cardTop
        border.width: 1
        border.color: Theme.frameBorder

        Text {
            id: workspaceText
            anchors.centerIn: parent
            text: root.workspaceLabel
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 8 * root.s
            font.weight: Font.DemiBold
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
