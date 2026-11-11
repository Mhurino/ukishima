pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"
import "../../lib/scratch.js" as ScratchNav

/**
 * Cassette deck: every note is presented as a physical audio cassette.
 * The note title is printed on the cassette label and follows renames.
 * The shared note editor, pinning and delete behavior remain unchanged.
 */
Item {
    id: cassette

    property var host: null
    readonly property real s: cassette.host ? cassette.host.s : 1
    readonly property color line: Theme.border
    readonly property var notes: Scratch.notes

    readonly property string summary: notes.length === 0
        ? "nothing recorded"
        : notes.length + (notes.length === 1 ? " cassette" : " cassettes")

    function locateCurrent() {
        grid.currentIndex = ScratchNav.locate(
            notes, Scratch.currentSlug, grid.currentIndex
        );
    }

    function focusList() {
        grid.forceActiveFocus();
    }

    function openCurrent() {
        ScratchNav.open(cassette.host, notes, grid.currentIndex);
    }

    function removeCurrent() {
        ScratchNav.remove(Scratch, notes, grid.currentIndex);
    }

    Component.onCompleted: {
        locateCurrent();
        grid.forceActiveFocus();
    }

    Connections {
        target: Scratch
        function onNotesChanged() {
            cassette.locateCurrent();
        }
    }

    ScratchHeader {
        id: head
        width: parent.width
        host: cassette.host
        wordmark: "CASSETTE COLLECTION"
        trailing: String(cassette.notes.length).padStart(2, "0") + " / NOTES"
        onNewNote: cassette.host.openCreate()
    }

    Rectangle {
        anchors.top: head.bottom
        anchors.topMargin: 7 * cassette.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: cassette.line
    }

    GridView {
        id: grid
        anchors.top: head.bottom
        anchors.topMargin: 13 * cassette.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: foot.top
        anchors.bottomMargin: 8 * cassette.s

        clip: true
        focus: true
        boundsBehavior: Flickable.StopAtBounds
        model: cassette.notes

        cellWidth: width / 2
        cellHeight: 116 * cassette.s

        Keys.onLeftPressed: decrementCurrentIndex()
        Keys.onRightPressed: incrementCurrentIndex()
        Keys.onUpPressed: decrementCurrentIndex()
        Keys.onDownPressed: incrementCurrentIndex()
        Keys.onReturnPressed: cassette.openCurrent()
        Keys.onEnterPressed: cassette.openCurrent()
        Keys.onSpacePressed: cassette.openCurrent()
        Keys.onDeletePressed: cassette.removeCurrent()
        Keys.onEscapePressed: cassette.host.requestClose()

        delegate: Item {
            id: slot

            required property int index
            required property var modelData

            width: grid.cellWidth
            height: grid.cellHeight

            readonly property bool selected: grid.currentIndex === slot.index
            readonly property bool pinned: slot.modelData.pinned === true
            readonly property string noteTitle:
                String(slot.modelData.title || "UNTITLED")

            HoverHandler {
                id: hover
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onPressed: grid.currentIndex = slot.index
                onClicked: cassette.openCurrent()
            }

            // Selection halo behind the cassette.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 12 * cassette.s
                height: 103 * cassette.s
                radius: 10 * cassette.s
                color: slot.selected
                    ? Qt.alpha(Theme.vermLit, 0.075)
                    : hover.hovered
                        ? Qt.alpha(Theme.cream, 0.035)
                        : "transparent"
                border.width: slot.selected ? 1 : 0
                border.color: Qt.alpha(Theme.vermLit, 0.5)

                Behavior on color {
                    ColorAnimation { duration: Motion.fast }
                }
            }

            // CASSETTE ARTWORK
            Item {
                id: tape
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 8 * cassette.s

                width: Math.min(parent.width - 36 * cassette.s, 220 * cassette.s)
                height: 77 * cassette.s

                // The plastic shell.
                Rectangle {
                    anchors.fill: parent
                    radius: 8 * cassette.s

                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: Theme.frameBg
                        }
                        GradientStop {
                            position: 0.55
                            color: Theme.cardTop
                        }
                        GradientStop {
                            position: 1.0
                            color: Theme.cardBot
                        }
                    }

                    border.width: 1
                    border.color: slot.selected
                        ? Theme.vermLit : Theme.frameBorder
                }

                // Small corner screws.
                Repeater {
                    model: [
                        { x: 8, y: 8 },
                        { x: tape.width / cassette.s - 12, y: 8 },
                        { x: 8, y: 65 },
                        { x: tape.width / cassette.s - 12, y: 65 }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        x: modelData.x * cassette.s
                        y: modelData.y * cassette.s
                        width: 4 * cassette.s
                        height: 4 * cassette.s
                        radius: width / 2
                        color: Theme.faint
                        opacity: 0.55
                    }
                }

                // Printed label with the actual note/song title.
                Rectangle {
                    id: label
                    anchors.top: parent.top
                    anchors.topMargin: 7 * cassette.s
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 42 * cassette.s
                    height: 22 * cassette.s
                    radius: 3 * cassette.s
                    color: Theme.tileBg
                    border.width: 1
                    border.color: Theme.hairSoft

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3 * cassette.s
                        color: Theme.vermLit
                        opacity: 0.85
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 9 * cassette.s
                        anchors.right: parent.right
                        anchors.rightMargin: 4 * cassette.s
                        anchors.verticalCenter: parent.verticalCenter

                        text: slot.noteTitle
                        color: Theme.cream
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 10 * cassette.s
                        font.weight: Font.DemiBold
                    }

                }

                // Tape window.
                Rectangle {
                    id: window
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 9 * cassette.s
                    width: 62 * cassette.s
                    height: 29 * cassette.s
                    radius: 4 * cassette.s
                    color: Theme.tileBg
                    border.width: 1
                    border.color: Theme.border

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 12 * cassette.s
                        height: 3 * cassette.s
                        radius: 2 * cassette.s
                        color: Theme.faint
                        opacity: 0.38
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 6 * cassette.s
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 1
                        color: Theme.hairSoft
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 6 * cassette.s
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 1
                        color: Theme.hairSoft
                    }
                }

                // Two visible tape reels.
                Repeater {
                    model: [0, 1]

                    delegate: Item {
                        required property int index

                        readonly property real diameter: 27 * cassette.s

                        x: index === 0
                            ? 25 * cassette.s
                            : tape.width - width - 25 * cassette.s
                        y: tape.height - height - 10 * cassette.s
                        width: diameter
                        height: diameter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Theme.cardBot
                            border.width: 2 * cassette.s
                            border.color: Theme.faint

                            Rectangle {
                                anchors.centerIn: parent
                                width: 17 * cassette.s
                                height: 17 * cassette.s
                                radius: width / 2
                                color: Theme.frameBg
                                border.width: 1
                                border.color: Theme.border

                                Repeater {
                                    model: 3

                                    Rectangle {
                                        required property int index
                                        anchors.centerIn: parent
                                        width: 1.5 * cassette.s
                                        height: 13 * cassette.s
                                        radius: 1
                                        color: Theme.vermLit
                                        opacity: 0.7
                                        rotation: index * 120
                                    }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 4 * cassette.s
                                    height: 4 * cassette.s
                                    radius: width / 2
                                    color: Theme.faint
                                }
                            }
                        }
                    }
                }
            }

            // Date on the bottom-left, note number on the bottom-right.
            Item {
                anchors.top: tape.bottom
                anchors.topMargin: 3 * cassette.s
                anchors.left: parent.left
                anchors.leftMargin: 19 * cassette.s
                anchors.right: parent.right
                anchors.rightMargin: 19 * cassette.s
                height: 14 * cassette.s

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: slot.modelData.age || ""
                    color: Theme.faint
                    font.family: Theme.fontMono
                    font.pixelSize: 8 * cassette.s
                    font.features: { "tnum": 1 }
                }

                Text {
                    id: noteNumber
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(slot.index + 1).padStart(2, "0")
                    color: slot.selected ? Theme.vermLit : Theme.faint
                    font.family: Theme.fontMono
                    font.pixelSize: 8 * cassette.s
                    font.features: { "tnum": 1 }
                }

                GlyphIcon {
                    anchors.right: noteNumber.left
                    anchors.rightMargin: 6 * cassette.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: slot.pinned
                    width: 10 * cassette.s
                    height: 10 * cassette.s
                    name: "pin"
                    color: Theme.vermLit
                    stroke: 1.8
                }
            }
        }
    }

    WheelScroller {
        anchors.fill: grid
        s: cassette.s
        flick: grid
    }

    Text {
        anchors.centerIn: grid
        visible: cassette.notes.length === 0
        text: "no tapes in the collection"
        color: Theme.faint
        font.family: Theme.fontMono
        font.pixelSize: 10 * cassette.s
        font.letterSpacing: 0.6
    }

    Item {
        id: foot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 13 * cassette.s

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: cassette.summary
            color: Theme.faint
            font.family: Theme.fontMono
            font.pixelSize: 8 * cassette.s
            font.features: { "tnum": 1 }
        }
    }
}
