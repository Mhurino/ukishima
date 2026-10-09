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
    property bool tooltipVisible: false
    property bool confirmVisible: false

    // Tooltip direction relative to the dock item.
    property int tooltipGravity: Edges.Top

    signal activated(var entry)
    signal closeRequested(var entry)
    signal pinRequested(var entry)
    signal unpinRequested(var entry)

    readonly property real tileSize: root.size * s
    readonly property real iconSize: root.size * 0.62 * s

    readonly property string resolvedIconSource: {
        if (!root.entry)
            return "";

        var icon = root.entry.icon
            ? String(root.entry.icon).trim()
            : "";

        // Absolute path or file:// icon from a desktop entry.
        if (icon.indexOf("/") === 0 || icon.indexOf("file://") === 0)
            return icon;

        // Normal themed icon.
        if (icon.length > 0) {
            var themed = Quickshell.iconPath(icon, true);
            if (themed !== "")
                return themed;
        }

        // Fallbacks for applications whose desktop entry has no icon.
        var candidates = [
            root.entry.startupClass,
            root.entry.id
        ];

        for (var i = 0; i < candidates.length; i++) {
            if (!candidates[i])
                continue;

            var name = String(candidates[i]).trim();

            if (name.length === 0)
                continue;

            var path = Quickshell.iconPath(name, true);

            if (path !== "")
                return path;
        }

        return "";
    }

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
        source: root.resolvedIconSource
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

    Timer {
        id: tooltipTimer
        interval: 1000
        repeat: false

        onTriggered: {
            if (root.hovered)
                root.tooltipVisible = true;
        }
    }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        z: 1

        onEntered: {
            root.tooltipVisible = false;
            tooltipTimer.restart();
        }

        onExited: {
            tooltipTimer.stop();
            root.tooltipVisible = false;
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                tooltipTimer.stop();
                root.tooltipVisible = false;

                    if (root.pinned || root.running)
                    root.confirmVisible = true;

                return;
            }

            if (mouse.button === Qt.MiddleButton) {
                root.closeRequested(root.entry);
                return;
            }

            root.activated(root.entry);
        }
    }

    PopupWindow {
        id: titlePopup

        color: "transparent"

        anchor.item: root
        anchor.gravity: root.tooltipGravity
        anchor.adjustment: PopupAdjustment.All

        visible:
            root.tooltipVisible
            && root.entry
            && root.entry.name
            && String(root.entry.name).trim() !== ""

        implicitWidth: Math.min(
            280 * root.s,
            Math.max(
                72 * root.s,
                titleText.implicitWidth + 20 * root.s
            )
        )

        implicitHeight: 26 * root.s

        Rectangle {
            anchors.fill: parent
            radius: 8 * root.s
            color: Theme.cardTop
            border.width: 0

            Text {
                id: titleText
                anchors.fill: parent
                anchors.leftMargin: 10 * root.s
                anchors.rightMargin: 10 * root.s

                text: root.entry ? String(root.entry.name || "") : ""

                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold

                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }

    PopupWindow {
        id: removePopup

        color: "transparent"
        grabFocus: true

        onVisibleChanged: {
            if (!visible)
                root.confirmVisible = false;
        }

        anchor.item: root
        anchor.gravity: root.tooltipGravity
        anchor.adjustment: PopupAdjustment.All

        visible: root.confirmVisible && root.entry
                 && (root.pinned || root.running)

        implicitWidth: popupContent.implicitWidth + 16 * root.s
        implicitHeight: popupContent.implicitHeight + 12 * root.s

        Rectangle {
            anchors.fill: parent
            radius: 8 * root.s
            color: Theme.cardTop
            border.width: 0

            Column {
                id: popupContent
                anchors.centerIn: parent
                spacing: 4 * root.s

                readonly property real buttonWidth: 24 * root.s
                readonly property real buttonHeight: 20 * root.s
                readonly property real rowSpacing: 5 * root.s
                readonly property real labelWidth: removeLabel.implicitWidth

                Row {
                    id: removeRow
                    visible: root.pinned
                    spacing: popupContent.rowSpacing

                    Text {
                        id: removeLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Remove from dock?"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        width: popupContent.buttonWidth
                        height: popupContent.buttonHeight
                        radius: 6 * root.s
                        color: yesArea.containsMouse
                            ? Qt.alpha(Theme.vermLit, 0.24)
                            : Qt.alpha(Theme.vermLit, 0.12)

                        Text {
                            anchors.centerIn: parent
                            text: "Yes"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 9 * root.s
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: yesArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.confirmVisible = false;
                                root.unpinRequested(root.entry);
                            }
                        }
                    }

                    Rectangle {
                        width: popupContent.buttonWidth
                        height: popupContent.buttonHeight
                        radius: 6 * root.s
                        color: noArea.containsMouse
                            ? Qt.alpha(Theme.cream, 0.11)
                            : Qt.alpha(Theme.cream, 0.055)

                        Text {
                            anchors.centerIn: parent
                            text: "No"
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 9 * root.s
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: noArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.confirmVisible = false
                        }
                    }
                }

                Row {
                    id: closeRow
                    visible: root.running
                    spacing: popupContent.rowSpacing

                    Text {
                        width: root.pinned
                            ? popupContent.labelWidth
                            : closeLabel.implicitWidth
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Close app"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.DemiBold
                    }

                    Item {
                        visible: root.pinned
                        width: popupContent.buttonWidth
                        height: popupContent.buttonHeight
                    }

                    Rectangle {
                        width: popupContent.buttonWidth
                        height: popupContent.buttonHeight
                        radius: 6 * root.s
                        color: closeArea.containsMouse
                            ? Qt.alpha(Theme.vermLit, 0.24)
                            : Qt.alpha(Theme.vermLit, 0.12)

                        GlyphIcon {
                            anchors.centerIn: parent
                            width: 11 * root.s
                            height: 11 * root.s
                            name: "close"
                            color: closeArea.containsMouse
                                ? Theme.cream
                                : Theme.vermLit
                            stroke: 1.8
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.confirmVisible = false;
                                root.closeRequested(root.entry);
                            }
                        }
                    }

                    Text {
                        id: closeLabel
                        visible: false
                        text: "Close app"
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                    }
                }
            }
        }
    }

}
