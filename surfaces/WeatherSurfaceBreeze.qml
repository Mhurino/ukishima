pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * Breeze: an alternate weather layout. The existing Weather singleton remains
 * the only data source; this surface only changes presentation and adds the
 * hourly wind speed/direction already exposed by that singleton.
 */
PillSurface {
    id: root

    // -1 keeps live conditions; otherwise show the selected forecast day.
    property int selectedDayIndex: -1
    readonly property var selectedDay: selectedDayIndex >= 0
        && selectedDayIndex < Weather.daily.length
        ? Weather.daily[selectedDayIndex] : null

    mTop: 16
    mLeft: 18
    mRight: 18
    mBottom: 16

    implicitWidth: 344 * s
    implicitHeight: content.implicitHeight

    ameForm: "off"

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10 * root.s

        Item {
            id: header
            width: parent.width
            height: 22 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.showGlyphs
                    text: "天"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "WEATHER"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.6 * root.s
                }
            }

            Item {
                id: cityBox
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(cityText.implicitWidth, cityField.implicitWidth) + 4 * root.s
                height: 16 * root.s
                property bool editing: false

                Text {
                    id: cityText
                    visible: !cityBox.editing
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.city.length ? Weather.city : "set town"
                    color: cityArea.containsMouse ? Theme.subtle : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 9.5 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.8 * root.s
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: cityArea
                    visible: !cityBox.editing
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        cityField.text = Flags.weatherCity;
                        cityBox.editing = true;
                        cityField.forceActiveFocus();
                        cityField.selectAll();
                    }
                }
                TextField {
                    id: cityField
                    visible: cityBox.editing
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(cityText.implicitWidth, 104 * root.s)
                    background: null
                    padding: 0
                    horizontalAlignment: TextInput.AlignRight
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 9.5 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.8 * root.s
                    placeholderText: "town"
                    placeholderTextColor: Theme.faint
                    selectByMouse: true
                    selectionColor: Theme.verm
                    onAccepted: {
                        Flags.weatherCity = text.trim();
                        cityBox.editing = false;
                    }
                    Keys.onEscapePressed: cityBox.editing = false
                    onActiveFocusChanged: if (!activeFocus) cityBox.editing = false
                }
            }
        }

        Row {
            id: currentConditions
            width: parent.width
            spacing: 17 * root.s
            visible: Weather.ready

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (root.selectedDay ? root.selectedDay.temp : Weather.tempNow) + "°C"
                color: (root.selectedDay ? root.selectedDay.code : Weather.codeNow) >= 95
                    ? Theme.vermLit : Theme.cream
                font.family: Theme.font
                font.pixelSize: 48 * root.s
                font.weight: Font.Bold
                font.letterSpacing: -1.4 * root.s
                font.features: { "tnum": 1 }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5 * root.s

                Row {
                    spacing: 7 * root.s
                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 23 * root.s
                        height: 23 * root.s
                        name: Weather.glyphFor(root.selectedDay ? root.selectedDay.code : Weather.codeNow, root.selectedDay ? true : Weather.isDay)
                        color: Theme.flameGlow
                        stroke: 1.7
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.labelFor(root.selectedDay ? root.selectedDay.code : Weather.codeNow)
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                        font.weight: Font.DemiBold
                    }
                }

                Row {
                    spacing: 1 * root.s
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.selectedDay ? root.selectedDay.rh : Weather.humidity) + "%"
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12 * root.s
                        height: 12 * root.s
                        name: "droplet"
                        color: Theme.subtle
                        stroke: 1.6
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
            visible: Weather.ready
        }

        Column {
            id: hourlySection
            width: parent.width
            spacing: 8 * root.s
            visible: Weather.ready

            Item {
                width: parent.width
                height: 12 * root.s

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "HOURLY FORECAST"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 8.5 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.15 * root.s
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "WIND FROM · KM/H"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 8 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.7 * root.s
                }
            }

            Row {
                id: hourlyCards
                width: parent.width
                spacing: 6 * root.s

                Repeater {
                    model: Weather.hourly.slice(0, 6)

                    Rectangle {
                        id: hourCard
                        required property var modelData
                        width: Math.max(0, (hourlyCards.width - 5 * hourlyCards.spacing) / 6)
                        height: 94 * root.s
                        radius: 9 * root.s
                        color: Theme.frameBg
                        border.color: Theme.frameBorder
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 5 * root.s
                            spacing: 3 * root.s

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: hourCard.modelData.hour + "h"
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: 8.5 * root.s
                                font.weight: Font.Medium
                                font.features: { "tnum": 1 }
                            }
                            GlyphIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 19 * root.s
                                height: 19 * root.s
                                name: Weather.glyphFor(hourCard.modelData.code, true)
                                color: Theme.iconDim
                                stroke: 1.7
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: hourCard.modelData.temp + "°C"
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 12 * root.s
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 2 * root.s

                                GlyphIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 11 * root.s
                                    height: 11 * root.s
                                    name: "wind"
                                    color: Theme.flameGlow
                                    stroke: 1.8
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: hourCard.modelData.windSpeed === null
                                        ? "—" : String(hourCard.modelData.windSpeed)
                                    color: Theme.subtle
                                    font.family: Theme.font
                                    font.pixelSize: 8.5 * root.s
                                    font.weight: Font.Medium
                                    font.features: { "tnum": 1 }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "↑"
                                    rotation: hourCard.modelData.windDirection === null
                                        ? 0 : hourCard.modelData.windDirection
                                    color: Theme.flameGlow
                                    font.family: Theme.font
                                    font.pixelSize: 11 * root.s
                                    font.weight: Font.Bold
                                    visible: hourCard.modelData.windDirection !== null
                                    transformOrigin: Item.Center
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
            visible: Weather.ready
        }

        Column {
            id: dailySection
            width: parent.width
            spacing: 6 * root.s
            visible: Weather.ready

            Text {
                text: "5 DAY FORECAST"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 8.5 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.15 * root.s
            }

            Repeater {
                model: Weather.daily

                Row {
                    id: dayRow
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 25 * root.s
                    spacing: 6 * root.s

                    Text {
                        width: 42 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: dayRow.modelData.day
                        color: root.selectedDayIndex === dayRow.index ? Theme.cream : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                    }
                    GlyphIcon {
                        width: 17 * root.s
                        height: 17 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        name: Weather.glyphFor(dayRow.modelData.code, true)
                        color: Theme.iconDim
                        stroke: 1.7
                    }
                    Text {
                        width: Math.max(0, parent.width - 42 * root.s - 17 * root.s
                            - 42 * root.s - 42 * root.s - 24 * root.s)
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.labelFor(dayRow.modelData.code)
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    Row {
                        width: 42 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1 * root.s

                        Text {
                            width: 30 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: dayRow.modelData.rh + "%"
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }
                        GlyphIcon {
                            width: 10 * root.s
                            height: 10 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            name: "droplet"
                            color: Theme.faint
                            stroke: 1.5
                        }
                    }
                    Text {
                        width: 42 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: dayRow.modelData.temp + "°C"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    TapHandler {
                        onTapped: root.selectedDayIndex = dayRow.index
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 5 * root.s
            visible: !Weather.ready

            Text {
                width: parent.width
                text: Weather.city.length ? Weather.city : "Weather"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 14 * root.s
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: "Waiting for forecast…"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
            }
        }
    }
}
