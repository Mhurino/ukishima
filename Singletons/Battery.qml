pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

/**
 * Laptop-battery state for the pill, sourced from UPower's display device and
 * gated so a desktop without a battery reports `present` false (the hover
 * cluster and 蓄 surface stay hidden). Exposes percentage, charge state, a
 * signed draw/charge wattage, capacity and optional health, plus a formatted
 * time-to-empty/full string. `low` flags a discharging battery at or below 20%.
 */
Singleton {
    id: root

    readonly property var dev: UPower.displayDevice

    readonly property bool present: dev !== null && dev.ready && dev.isLaptopBattery && dev.isPresent
    readonly property real frac: dev ? Math.max(0, Math.min(1, dev.percentage)) : 0
    readonly property int pct: Math.round(frac * 100)
    readonly property int state: dev ? dev.state : UPowerDeviceState.Unknown

    readonly property bool charging: state === UPowerDeviceState.Charging
    readonly property bool full: state === UPowerDeviceState.FullyCharged || pct >= 100
    readonly property bool discharging: state === UPowerDeviceState.Discharging
    readonly property bool low: !charging && pct <= 20

    readonly property real rateW: !dev ? 0
        : (discharging ? -dev.changeRate : (charging ? dev.changeRate : 0))
    readonly property real capacityWh: dev ? dev.energyCapacity : 0

    readonly property bool healthSupported: dev ? dev.healthSupported : false
    readonly property int health: dev ? Math.round(dev.healthPercentage) : 0

    readonly property bool hasTime: !dev ? false
        : (charging ? dev.timeToFull > 0 : (discharging ? dev.timeToEmpty > 0 : false))
    readonly property string timeStr: !dev ? ""
        : (charging ? fmt(dev.timeToFull) : (discharging ? fmt(dev.timeToEmpty) : ""))

    readonly property string stateLabel: charging ? "Charging"
        : (full ? "On AC · Full"
        : (discharging ? "Discharging" : "On AC"))

    /** Power profile state used by Game Mode. The PowerProfiles service is only
     * touched after systemd reports the daemon active, avoiding a stale D-Bus
     * connection when power-profiles-daemon is masked or unavailable. */
    property int profile: PowerProfile.Balanced
    property bool hasPerformance: true
    property bool _ppAttached: false

    function _attachPP() {
        if (root._ppAttached)
            return;
        root._ppAttached = true;
        PowerProfiles.profileChanged.connect(function () {
            root.profile = PowerProfiles.profile;
        });
        PowerProfiles.hasPerformanceProfileChanged.connect(function () {
            root.hasPerformance = PowerProfiles.hasPerformanceProfile;
        });
        root.profile = PowerProfiles.profile;
        root.hasPerformance = PowerProfiles.hasPerformanceProfile;
    }

    function setProfile(p) {
        if (root._ppAttached)
            PowerProfiles.profile = p;
        root.profile = p;
    }

    readonly property string daemonState: root._daemonState
    readonly property bool daemonReady: root._daemonState === "active"
    property string _daemonState: "unknown"

    function checkDaemon() {
        daemonProbe.running = true;
    }

    Component.onCompleted: root.checkDaemon()

    Process {
        id: daemonProbe
        command: ["sh", "-c",
            "a=$(systemctl is-active power-profiles-daemon 2>/dev/null); "
            + "e=$(systemctl is-enabled power-profiles-daemon 2>/dev/null); "
            + "printf '%s|%s\\n' \"$a\" \"$e\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text.trim().split("|");
                var active = out[0] || "";
                var enabled = out[1] || "";
                root._daemonState = active === "active" ? "active"
                    : enabled === "masked" ? "masked"
                    : enabled === "enabled" || enabled === "static" || enabled === "indirect" ? "inactive"
                    : /Failed|not[ -]found|No such|does not exist/i.test(enabled) ? "missing"
                    : "unknown";
                if (root._daemonState === "active")
                    root._attachPP();
            }
        }
    }

    function fmt(sec) {
        var s = Math.max(0, Math.round(sec));
        var h = Math.floor(s / 3600);
        var m = Math.floor((s % 3600) / 60);
        if (h > 0)
            return h + "h " + m + "m";
        return m + "m";
    }
}
