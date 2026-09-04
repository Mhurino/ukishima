import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import "../Singletons"

PillSurface {
    id: root

    mTop: 13
    mLeft: 14
    mRight: 14
    mBottom: 12

    property string page: "main"
    property string message: ""
    property string manageName: ""
    property string manageUrl: ""

    readonly property string helper:
        "/home/francesco/.config/hypr/UserScripts/UkishimaBeats.sh"

    property var onlineItems: []
    property var localItems: []

    function loadOnline() {
        onlineProc.running = true;
    }

    function loadLocal() {
        localProc.running = true;
    }

    function playOnline(name) {
        Quickshell.execDetached([helper, "play-online", name]);
        root.message = "Playing " + name;
        root.page = "main";
    }

    function playLocal(path, label) {
        Quickshell.execDetached([helper, "play-local", path]);
        root.message = "Playing " + label;
        root.page = "main";
    }

    function shuffle() {
        Quickshell.execDetached([helper, "shuffle"]);
        root.message = "Shuffle";
    }

    function stop() {
        Quickshell.execDetached([helper, "stop"]);
        root.message = "Stopped";
    }


    function addStation() {
        var name = root.manageName.trim();
        var url = root.manageUrl.trim();

        if (!name || !url) {
            root.message = "Name and URL required";
            return;
        }

        Quickshell.execDetached([root.helper, "add", name, url]);
        root.manageName = "";
        root.manageUrl = "";
        root.message = "Added " + name;
        root.loadOnline();
    }

    function removeStation(name) {
        if (!name)
            return;

        Quickshell.execDetached([root.helper, "remove", name]);
        root.message = "Removed " + name;
        root.loadOnline();
    }

    component ActionRow: Rectangle {
        id: row

        property string glyph: ""
        property string title: ""
        property string subtitle: ""
        signal activated()

        width: parent ? parent.width : 0
        height: 38 * root.s
        radius: 9 * root.s
        color: rowHover.hovered ? Theme.frameBg : "transparent"
        border.width: 1
        border.color: Theme.border

        HoverHandler { id: rowHover }

        GlyphIcon {
            anchors.left: parent.left
            anchors.leftMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 18 * root.s
            height: 18 * root.s
            name: row.glyph
            color: rowHover.hovered ? Theme.cream : Theme.iconDim
            stroke: 1.7
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 40 * root.s
            anchors.right: parent.right
            anchors.rightMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: row.title
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }
    }

    Component {
        id: mediaRow

        Rectangle {
            id: media

            property string label: ""
            property string value: ""
            property bool selected: false
            signal chosen()

            width: parent ? parent.width : 0
            height: 34 * root.s
            radius: 8 * root.s
            color: mediaHover.hovered ? Theme.frameBg : "transparent"
            border.width: 1
            border.color: selected ? Theme.frameBorder : Theme.border

            HoverHandler { id: mediaHover }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 11 * root.s
                anchors.right: parent.right
                anchors.rightMargin: 11 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: media.label
                elide: Text.ElideRight
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 10 * root.s
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: media.chosen()
            }
        }
    }

    Process {
        id: onlineProc
        command: [root.helper, "list-online"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var out = [];

                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i])
                        continue;

                    var parts = lines[i].split("\t");
                    if (parts.length >= 2)
                        out.push({ label: parts[0], value: parts.slice(1).join("\t") });
                }

                root.onlineItems = out;
            }
        }
    }

    Process {
        id: localProc
        command: [root.helper, "list-local"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var out = [];

                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i])
                        continue;

                    var parts = lines[i].split("\t");
                    if (parts.length >= 2)
                        out.push({ label: parts[0], value: parts.slice(1).join("\t") });
                }

                root.localItems = out;
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 6 * root.s

        Row {
            width: parent.width
            height: 22 * root.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Flags.showGlyphs ? "音  BEATS" : "BEATS"
                color: Theme.subtle
                font.family: Flags.showGlyphs ? Theme.fontJp : Theme.font
                font.pixelSize: Flags.showGlyphs ? 15 * root.s : 10 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: Flags.showGlyphs ? 0 : 1.6 * root.s
            }

            Item {
                width: parent.width - 62 * root.s
                height: 1
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.page === "main" ? "" : "‹"
                color: Theme.cream
                font.pixelSize: 20 * root.s
                visible: root.page !== "main"

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.page = "main"
                }
            }
        }

        Item {
            width: parent.width
            height: 1
        }

        Column {
            width: parent.width
            spacing: 7 * root.s
            visible: root.page === "main"

            ActionRow {
                glyph: "music"
                title: "Online Stations"
                onActivated: {
                    root.page = "online";
                    root.loadOnline();
                }
            }

            ActionRow {
                glyph: "folder"
                title: "Local Music"
                onActivated: {
                    root.page = "local";
                    root.loadLocal();
                }
            }

            Row {
                width: parent.width
                spacing: 7 * root.s

                ActionRow {
                    width: (parent.width - 7 * root.s) / 2
                    glyph: "shuffle"
                    title: "Shuffle"
                    onActivated: root.shuffle()
                }

                ActionRow {
                    width: (parent.width - 7 * root.s) / 2
                    glyph: "stop"
                    title: "Stop"
                    onActivated: root.stop()
                }
            }

            ActionRow {
                glyph: "settings"
                title: "Manage Music"
                onActivated: root.page = "manage"
            }

            Text {
                width: parent.width
                height: 18 * root.s
                text: root.message
                color: Theme.subtle
                horizontalAlignment: Text.AlignHCenter
                visible: text.length > 0
                font.family: Theme.font
                font.pixelSize: 9 * root.s
            }
        }

        Column {
            visible: root.page === "manage"
            width: parent.width
            spacing: 7 * root.s

            Text {
                width: parent.width
                text: "ADD STATION"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 8.5 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1 * root.s
            }

            Rectangle {
                width: parent.width
                height: 34 * root.s
                radius: 8 * root.s
                color: Theme.frameBg
                border.width: 1
                border.color: Theme.border

                TextInput {
                    anchors.fill: parent
                    anchors.leftMargin: 10 * root.s
                    anchors.rightMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.manageName
                    onTextChanged: root.manageName = text
                    color: Theme.cream
                    selectionColor: Theme.onGlow
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    verticalAlignment: TextInput.AlignVCenter
                }
            }

            Rectangle {
                width: parent.width
                height: 34 * root.s
                radius: 8 * root.s
                color: Theme.frameBg
                border.width: 1
                border.color: Theme.border

                TextInput {
                    anchors.fill: parent
                    anchors.leftMargin: 10 * root.s
                    anchors.rightMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.manageUrl
                    onTextChanged: root.manageUrl = text
                    color: Theme.cream
                    selectionColor: Theme.onGlow
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    verticalAlignment: TextInput.AlignVCenter
                }
            }

            Row {
                width: parent.width
                spacing: 7 * root.s

                Rectangle {
                    width: (parent.width - 7 * root.s) / 2
                    height: 36 * root.s
                    radius: 9 * root.s
                    color: addHover.hovered ? Theme.frameBg : Qt.alpha(Theme.onGlow, 0.10)
                    border.width: 1
                    border.color: Theme.frameBorder

                    HoverHandler { id: addHover }

                    Text {
                        anchors.centerIn: parent
                        text: "＋  Add"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.addStation()
                    }
                }

                Rectangle {
                    width: (parent.width - 7 * root.s) / 2
                    height: 36 * root.s
                    radius: 9 * root.s
                    color: backHover.hovered ? Theme.frameBg : "transparent"
                    border.width: 1
                    border.color: Theme.border

                    HoverHandler { id: backHover }

                    Text {
                        anchors.centerIn: parent
                        text: "‹  Back"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.page = "main"
                    }
                }
            }

            Text {
                width: parent.width
                text: "REMOVE / VIEW"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 8.5 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1 * root.s
            }

            ListView {
                width: parent.width
                height: 430 * root.s
                clip: true
                spacing: 4 * root.s
                boundsBehavior: Flickable.StopAtBounds
                model: root.onlineItems

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 28 * root.s
                    radius: 7 * root.s
                    color: removeHover.hovered ? Theme.frameBg : "transparent"
                    border.width: 1
                    border.color: Theme.border

                    HoverHandler { id: removeHover }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 9 * root.s
                        anchors.right: removeButton.left
                        anchors.rightMargin: 6 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        id: removeButton
                        anchors.right: parent.right
                        anchors.rightMargin: 4 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22 * root.s
                        height: 22 * root.s
                        radius: 6 * root.s
                        color: "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "−"
                            color: Theme.vermLit
                            font.pixelSize: 14 * root.s
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.removeStation(modelData.label)
                        }
                    }
                }
            }

            Text {
                width: parent.width
                text: root.message
                color: Theme.subtle
                horizontalAlignment: Text.AlignHCenter
                visible: text.length > 0
                font.family: Theme.font
                font.pixelSize: 9 * root.s
            }
        }

        ListView {
            visible: root.page === "online"
            width: parent.width
            height: Math.max(160 * root.s, parent.height - y)
            clip: true
            spacing: 5 * root.s
            boundsBehavior: Flickable.StopAtBounds
            model: root.onlineItems

            delegate: Loader {
                width: ListView.view.width
                sourceComponent: mediaRow

                onLoaded: {
                    item.label = modelData.label;
                    item.value = modelData.value;
                    item.chosen.connect(function() {
                        root.playOnline(modelData.label);
                    });
                }
            }
        }

        ListView {
            visible: root.page === "local"
            width: parent.width
            height: 132 * root.s
            clip: true
            spacing: 5 * root.s
            model: root.localItems

            delegate: Loader {
                width: ListView.view.width
                sourceComponent: mediaRow

                onLoaded: {
                    item.label = modelData.label;
                    item.value = modelData.value;
                    item.chosen.connect(function() {
                        root.playLocal(modelData.value, modelData.label);
                    });
                }
            }
        }
    }
}
