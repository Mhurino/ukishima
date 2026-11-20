pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "."

/*
 * Un solo gestore per tutti i Dock dei monitor.
 * Hyprland viene già aggiornato da shell.qml sugli eventi IPC:
 * qui non ripetiamo refreshToplevels() a intervalli fissi.
 */
Singleton {
    id: root

    property var steamGameIcons: ({})
    property bool scanPending: false

    readonly property string steamIconMapPath:
        (Quickshell.env("XDG_CACHE_HOME")
            || (Quickshell.env("HOME") + "/.cache"))
        + "/ukishima/steam-icons/active.json"

    readonly property string steamIconScript:
        Config.hyprPath("scripts", "steam-game-icons.py")

    function loadMap() {
        try {
            var parsed = JSON.parse(steamIconMapFile.text());
            root.steamGameIcons =
                parsed && typeof parsed === "object" ? parsed : ({});
        } catch (e) {
            root.steamGameIcons = ({});
            console.warn("Ukishima: mappa icone Steam non valida:", e);
        }
    }

    function requestScan() {
        if (!Flags.dockEnabled)
            return;
        scanDebounce.restart();
    }

    function runScan() {
        if (!Flags.dockEnabled)
            return;

        if (scanProc.running) {
            root.scanPending = true;
            return;
        }

        root.scanPending = false;
        scanProc.running = true;
    }

    FileView {
        id: steamIconMapFile
        path: root.steamIconMapPath
        blockLoading: true
        watchChanges: true
        printErrors: false

        onLoaded: root.loadMap()
        onFileChanged: reload()
        onLoadFailed: root.steamGameIcons = ({})
    }

    Process {
        id: scanProc
        command: ["python3", root.steamIconScript]

        onExited: function(exitCode) {
            steamIconMapFile.reload();

            if (root.scanPending && Flags.dockEnabled) {
                root.scanPending = false;
                scanDebounce.restart();
            }
        }
    }

    // Accorpa aperture/chiusure ravvicinate in una sola scansione.
    Timer {
        id: scanDebounce
        interval: 650
        repeat: false
        onTriggered: root.runScan()
    }

    // Controllo di sicurezza: uno solo per l'intera shell, non uno per monitor.
    // Gli eventi Hyprland restano il percorso principale.
    Timer {
        interval: 30000
        repeat: true
        running: Flags.dockEnabled
        onTriggered: root.requestScan()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (!Flags.dockEnabled || !event)
                return;

            if (event.name === "openwindow" || event.name === "closewindow")
                root.requestScan();
        }
    }

    Connections {
        target: Flags

        function onDockEnabledChanged() {
            if (Flags.dockEnabled) {
                root.requestScan();
            } else {
                scanDebounce.stop();
                root.scanPending = false;
            }
        }
    }

    Component.onCompleted: root.requestScan()
}
