pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string scriptPath: Config.hyprPath("scripts", "waywallen.sh")
    property string requestedMode: ""
    readonly property bool busy: actionProc.running

    function setEnabled(enabled) {
        if (actionProc.running)
            return;
        requestedMode = enabled ? "enable" : "disable";
        actionProc.command = ["bash", root.scriptPath, requestedMode];
        actionProc.running = true;
    }

    function ensureStarted() {
        if (!Flags.waywallenEnabled || actionProc.running)
            return;
        requestedMode = "start";
        actionProc.command = ["bash", root.scriptPath, "start"];
        actionProc.running = true;
    }

    function openUI() {
        if (openProc.running)
            return;
        openProc.command = ["bash", root.scriptPath, "open"];
        openProc.running = true;
    }

    function allowFolder(path) {
        if (!path || !String(path).trim().length || grantProc.running)
            return;
        grantProc.command = ["bash", root.scriptPath, "grant-folder", String(path).trim()];
        grantProc.running = true;
    }

    Process {
        id: actionProc
        command: []
        onExited: function(exitCode) {
            if (exitCode === 0) {
                if (root.requestedMode === "enable" || root.requestedMode === "start")
                    Flags.waywallenEnabled = true;
                else if (root.requestedMode === "disable")
                    Flags.waywallenEnabled = false;
            } else {
                Quickshell.execDetached([
                    "notify-send", "--app-name=Ukishima", "--urgency=normal", "Waywallen",
                    root.requestedMode === "disable"
                        ? "Disattivazione incompleta. Controlla i servizi systemd utente."
                        : "Configurazione non riuscita. Verifica Flatpak, rete e log dei servizi."
                ]);
            }
            root.requestedMode = "";
        }
    }

    Process { id: openProc; command: [] }

    Process {
        id: grantProc
        command: []
        onExited: function(exitCode) {
            if (exitCode !== 0)
                Quickshell.execDetached(["notify-send", "--app-name=Ukishima", "Waywallen", "Impossibile concedere l'accesso alla cartella."]);
        }
    }
}
