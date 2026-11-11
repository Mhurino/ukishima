pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

Item {
    id: deck

    property var host: null

    readonly property real s: deck.host ? deck.host.s : 1
    readonly property real shellW: 340 * s
    readonly property real shellH: 142 * s
    readonly property real railW: 112 * s
    readonly property real gap: 14 * s
    readonly property real groupW: shellW + gap + railW
    readonly property real groupX: Math.max(8 * s, (width - groupW) / 2)

    // ---------------------------------------------------------
    // CORPO DELLA MUSICASSETTA
    // ---------------------------------------------------------

    Rectangle {
        id: shell

        x: deck.groupX
        y: 4 * deck.s
        width: deck.shellW
        height: deck.shellH

        radius: 4 * deck.s
        color: Theme.cardBot
        border.width: 1
        border.color: Theme.border

        // Etichetta semplice con titolo e artista.
        Rectangle {
            id: label

            x: 8 * deck.s
            y: 7 * deck.s
            width: parent.width - 16 * deck.s
            height: 47 * deck.s

            radius: 2 * deck.s
            color: Theme.cardTop
            border.width: 1
            border.color: Qt.alpha(Theme.cream, 0.12)

            Marquee {
                x: 10 * deck.s
                y: 7 * deck.s
                width: parent.width - 20 * deck.s
                height: 15 * deck.s

                text: deck.host ? deck.host.title : "Nothing playing"
                color: Theme.cream
                pixelSize: 11 * deck.s
                weight: Font.DemiBold
                fontFamily: Theme.font
                active: deck.host ? deck.host.active : false
            }

            Text {
                x: 10 * deck.s
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 7 * deck.s
                width: parent.width - 20 * deck.s

                text: deck.host ? deck.host.sub : ""
                color: Theme.subtle
                elide: Text.ElideRight

                font.family: Theme.font
                font.pixelSize: 9 * deck.s
            }
        }

        // Finestra del nastro.
        Rectangle {
            id: tapeWindow

            x: 9 * deck.s
            y: label.y + label.height + 5 * deck.s

            width: parent.width - 18 * deck.s
            height: parent.height - y - 8 * deck.s

            radius: 3 * deck.s
            color: Theme.tileBg
            border.width: 1
            border.color: Qt.alpha(Theme.cream, 0.16)

            // Nastro tra le bobine.
            Rectangle {
                anchors.left: leftReel.right
                anchors.right: rightReel.left
                anchors.verticalCenter: parent.verticalCenter

                height: 2 * deck.s
                color: Qt.alpha(Theme.cream, 0.45)
            }

            Reel {
                id: leftReel

                anchors.left: parent.left
                anchors.leftMargin: 82 * deck.s
                anchors.verticalCenter: parent.verticalCenter

                s: deck.s
                spinning: deck.host ? deck.host.playing : false
                direction: 1
            }

            Reel {
                id: rightReel

                anchors.right: parent.right
                anchors.rightMargin: 82 * deck.s
                anchors.verticalCenter: parent.verticalCenter

                s: deck.s
                spinning: deck.host ? deck.host.playing : false
                direction: -1
            }

            // Pattino centrale.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3 * deck.s

                width: 16 * deck.s
                height: 4 * deck.s
                radius: 1 * deck.s

                color: Theme.cardTop
                border.width: 1
                border.color: Qt.alpha(Theme.cream, 0.2)
            }
        }
    }

    // ---------------------------------------------------------
    // COLLEGAMENTI LATERALI
    // ---------------------------------------------------------

    Column {
        id: sideLinks

        x: shell.x + shell.width + deck.gap
        anchors.verticalCenter: shell.verticalCenter

        width: deck.railW
        spacing: 13 * deck.s

        // Wi-Fi.
        Row {
            width: parent.width
            height: 17 * deck.s
            spacing: 7 * deck.s

            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 13 * deck.s
                height: 13 * deck.s
                name: "wifi"
                color: Theme.iconDim
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 20 * deck.s

                text: deck.host && deck.host.netOk
                    ? "↓ " + deck.host.fmtNet(deck.host.netDown)
                      + "  ↑ " + deck.host.fmtNet(deck.host.netUp)
                    : "Not connected"

                elide: Text.ElideRight
                color: deck.host && deck.host.netOk
                    ? Theme.cream : Theme.subtle

                font.family: Theme.font
                font.pixelSize: 9 * deck.s
            }
        }

        // Bluetooth / cuffie.
        Row {
            width: parent.width
            height: 17 * deck.s
            spacing: 6 * deck.s

            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 13 * deck.s
                height: 13 * deck.s

                name: deck.host && deck.host.btName.length > 0
                    ? deck.host.btGlyph : "bluetooth"

                color: Theme.iconDim
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter

                width: parent.width - 21 * deck.s
                    - (deck.host && deck.host.btBat >= 0 ? 25 * deck.s : 0)

                text: deck.host && deck.host.btName.length > 0
                    ? deck.host.btName : "Not connected"

                elide: Text.ElideRight
                color: deck.host && deck.host.btName.length > 0
                    ? Theme.dim : Theme.subtle

                font.family: Theme.font
                font.pixelSize: 9 * deck.s
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: deck.host && deck.host.btBat >= 0

                width: 25 * deck.s
                text: deck.host && deck.host.btBat >= 0
                    ? deck.host.btBat + "%" : ""

                horizontalAlignment: Text.AlignRight
                color: deck.host ? deck.host.btBatColor : Theme.subtle

                font.family: Theme.font
                font.pixelSize: 8.5 * deck.s
            }
        }

        // Estensione.
        Item {
            width: parent.width
            height: 19 * deck.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7 * deck.s

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 13 * deck.s
                    height: 13 * deck.s
                    name: "layers"
                    color: extendArea.containsMouse
                        ? Theme.cream : Theme.iconDim
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Extended"
                    color: extendArea.containsMouse
                        ? Theme.cream : Theme.dim

                    font.family: Theme.font
                    font.pixelSize: 9 * deck.s
                }
            }

            MouseArea {
                id: extendArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    if (deck.host)
                        deck.host.requestExpand()
                }
            }
        }
    }

    // ---------------------------------------------------------
    // BARRA INFERIORE CLASSICA
    // ---------------------------------------------------------

    Item {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        anchors.leftMargin: 15 * deck.s
        anchors.rightMargin: 15 * deck.s
        anchors.bottomMargin: 7 * deck.s

        height: 20 * deck.s

        MediaSources {
            id: sources

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            width: 92 * deck.s
            height: 18 * deck.s

            host: deck.host
            plain: true
        }

        // Barra di avanzamento.
        Item {
            id: seekBar

            anchors.left: sources.right
            anchors.leftMargin: 10 * deck.s
            anchors.right: transport.left
            anchors.rightMargin: 12 * deck.s
            anchors.verticalCenter: parent.verticalCenter

            height: 18 * deck.s

            readonly property real progress: deck.host
                ? Math.max(0, Math.min(1,
                    deck.host.dragging
                        ? deck.host.dragFrac
                        : deck.host.frac))
                : 0

            readonly property bool canSeek: deck.host
                && deck.host.hasPlayer
                && deck.host.player
                && deck.host.player.canSeek
                && deck.host.player.positionSupported
                && deck.host.lengthSec > 0
                && !deck.host.live

            // Traccia.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                height: 3 * deck.s
                radius: height / 2
                color: Qt.alpha(Theme.cream, 0.2)
            }

            // Parte riprodotta.
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                width: parent.width * seekBar.progress
                height: 3 * deck.s
                radius: height / 2
                color: Theme.cream
            }

            // Pallino classico.
            Rectangle {
                x: Math.max(
                    0,
                    Math.min(
                        parent.width - width,
                        parent.width * seekBar.progress - width / 2
                    )
                )

                anchors.verticalCenter: parent.verticalCenter

                width: 8 * deck.s
                height: 8 * deck.s
                radius: width / 2

                color: Theme.cream
                border.width: 1
                border.color: Theme.cardBot
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4 * deck.s
                enabled: seekBar.canSeek
                cursorShape: Qt.PointingHandCursor

                function seekAt(x) {
                    if (!deck.host || !deck.host.lengthSec)
                        return

                    deck.host.dragFrac = Math.max(
                        0,
                        Math.min(1, x / Math.max(1, width))
                    )
                }

                onPressed: (event) => {
                    seekAt(event.x)
                    deck.host.dragging = true
                }

                onPositionChanged: (event) => {
                    if (pressed)
                        seekAt(event.x)
                }

                onReleased: {
                    if (deck.host && deck.host.player) {
                        deck.host.player.position =
                            deck.host.dragFrac * deck.host.lengthSec
                        deck.host.dragging = false
                    }
                }

                onCanceled: {
                    if (deck.host)
                        deck.host.dragging = false
                }
            }
        }

        // Tre controlli semplici.
        Row {
            id: transport

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            spacing: 7 * deck.s
            height: 20 * deck.s

            component TransportButton: Item {
                id: button

                property string glyph: ""
                property bool available: true
                property bool emphasized: false

                signal activated()

                width: 19 * deck.s
                height: 20 * deck.s

                Text {
                    anchors.centerIn: parent

                    text: button.glyph
                    color: hit.containsMouse
                        ? Theme.cream
                        : (button.emphasized ? Theme.cream : Theme.subtle)

                    opacity: button.available ? 1 : 0.35
                    font.family: Theme.font
                    font.pixelSize: button.emphasized
                        ? 13 * deck.s : 14 * deck.s

                    Behavior on color {
                        ColorAnimation { duration: Motion.fast }
                    }
                }

                MouseArea {
                    id: hit
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: button.available
                    cursorShape: Qt.PointingHandCursor
                    onClicked: button.activated()
                }
            }

            TransportButton {
                glyph: "‹"
                available: deck.host && deck.host.hasPlayer
                    && deck.host.player.canGoPrevious

                onActivated: {
                    if (deck.host && deck.host.player)
                        deck.host.player.previous()
                }
            }

            TransportButton {
                glyph: deck.host && deck.host.playing ? "Ⅱ" : "▶"
                emphasized: true

                available: deck.host && deck.host.hasPlayer
                    && deck.host.player.canTogglePlaying

                onActivated: {
                    if (deck.host && deck.host.player)
                        deck.host.player.togglePlaying()
                }
            }

            TransportButton {
                glyph: "›"
                available: deck.host && deck.host.hasPlayer
                    && deck.host.player.canGoNext

                onActivated: {
                    if (deck.host && deck.host.player)
                        deck.host.player.next()
                }
            }
        }
    }

    // ---------------------------------------------------------
    // BOBINA
    // ---------------------------------------------------------

    component Reel: Item {
        id: reel

        property real s: 1
        property bool spinning: false
        property real direction: 1

        width: 36 * s
        height: 36 * s

        Rectangle {
            anchors.fill: parent
            radius: width / 2

            color: Theme.cardTop
            border.width: 1
            border.color: Qt.alpha(Theme.cream, 0.4)
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 5 * reel.s

            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.cream, 0.22)
        }

        Item {
            id: rotor
            anchors.fill: parent

            Repeater {
                model: 3

                delegate: Rectangle {
                    required property int index

                    x: parent.width / 2 - width / 2
                        + Math.cos(index * Math.PI * 2 / 3)
                            * 8 * reel.s

                    y: parent.height / 2 - height / 2
                        + Math.sin(index * Math.PI * 2 / 3)
                            * 8 * reel.s

                    width: 4 * reel.s
                    height: 4 * reel.s
                    radius: width / 2
                    color: Theme.tileBg
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 6 * reel.s
                height: 6 * reel.s
                radius: width / 2
                color: Theme.cream
            }
        }

        RotationAnimator {
            target: rotor
            from: 0
            to: 360 * reel.direction
            duration: 2600
            loops: Animation.Infinite
            running: reel.spinning
        }
    }
}
