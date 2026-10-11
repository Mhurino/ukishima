pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Live audio spectrum for the rest-pill visualizer. A headless cava captures the
 * default sink monitor, so the bars answer to any system sound (music, a
 * background video, a game) instead of one MPRIS player. cava runs the FFT and
 * smoothing; we only parse its raw ascii frames into normalized 0..1 levels.
 *
 * Silence arrives as an all-zero frame every tick, which `active` debounces into
 * a clean play/stop signal so the glyph morph does not flap between tracks.
 *
 * cava is an optional dependency: the in-app updater only merges config files and
 * never installs packages, so a machine that pulled an update without cava on it
 * must degrade cleanly. We probe for the binary once and only ever spawn it when
 * it is actually present, which keeps the plain clock on those machines.
 */
Singleton {
    id: root

    readonly property int bars: 5
    property var levels: []
    property bool active: false

    property bool available: false
    readonly property bool wanted: Flags.musicViz && available && audioPlaying

    /**
     * autosens is off so a silent browser holding the sink stays at zero bars
     * instead of autosens amplifying the noise floor up to full range and tripping
     * the visualizer on dead silence. The trade is a fixed gain, tuned so real
     * music fills the bars while silence stays under the activate threshold.
     */
    readonly property string config: "[general]\n"
        + "bars = " + bars + "\nframerate = 60\nautosens = 0\nsensitivity = 5500\n"
        + "[input]\nmethod = pulse\nsource = auto\n"
        + "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\n"
        + "ascii_max_range = 1000\nbar_delimiter = 59\nframe_delimiter = 10\n"
        + "channels = mono\nmono_option = average\n"
        + "[smoothing]\nnoise_reduction = 0.77\n"

    onWantedChanged: cavaProc.running = wanted
    Component.onCompleted: cavaProc.running = wanted

Process {
    running: true
    command: ["/usr/bin/cava", "-v"]
    onExited: (code) => root.available = (code === 0)
}
    Process {
        id: cavaProc
        command: ["sh", "-c", "printf '%s' \"$1\" | cava -p /dev/stdin", "_", root.config]
        stdout: SplitParser {
            onRead: (line) => {
                if (!line)
                    return;
                const parts = line.split(";");
                const out = [];
                let peak = 0;
                for (let i = 0; i < root.bars; i++) {
                    const v = (parseInt(parts[i]) || 0) / 1000;
                    out.push(v);
                    if (v > peak)
                        peak = v;
                }
                /**
                 * Silence frames stop mattering once the morph has settled back
                 * to the clock, so skip the 60Hz levels churn while both the
                 * frame and the stored levels are already flat.
                 */
                const flat = peak <= 0.001 && !root.active;
                if (!flat)
                    root.levels = out;
                if (peak > 0.02) {
                    root.active = true;
                    idle.restart();
                }
            }
        }
        /** A crash while cava is still wanted earns one relaunch after a beat, never a tight respawn loop. */
        onExited: if (root.wanted) relaunch.restart()
    }

    Timer {
        id: relaunch
        interval: 1500
        onTriggered: if (root.wanted) cavaProc.running = true
    }

    /** Short debounce so inter-track gaps do not snap the morph back to the clock. */
    Timer {
        id: idle
        interval: 450
        onTriggered: root.active = false
    }

    /**
     * On-demand capture: cava only runs while some stream is actually playing.
     * `pactl subscribe` sits idle until the audio graph changes; each burst of
     * events is debounced, then one JSON query decides whether any sink input is
     * uncorked and unmuted. Turning off is delayed so track changes don't thrash
     * the cava process.
     */
    property bool audioPlaying: false
    readonly property bool watching: Flags.musicViz && available

    Connections {
        target: root
        function onWatchingChanged() {
            audioWatch.running = root.watching;
            if (!root.watching)
                root.audioPlaying = false;
        }
    }

    Process {
        id: audioWatch
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            onRead: (line) => {
                if (line.indexOf("sink-input") >= 0 || line.indexOf("server") >= 0)
                    audioCheck.restart();
            }
        }
        onRunningChanged: if (running) audioCheck.restart()
        onExited: if (root.watching) audioWatchRestart.restart()
    }

    Timer {
        id: audioWatchRestart
        interval: 3000
        onTriggered: if (root.watching) audioWatch.running = true
    }

    Timer {
        id: audioCheck
        interval: 250
        onTriggered: audioQuery.running = true
    }

    Timer {
        id: audioOff
        interval: 4000
        onTriggered: root.audioPlaying = false
    }

    Process {
        id: audioQuery
        command: ["pactl", "--format=json", "list", "sink-inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                let playing = false;
                try {
                    const arr = JSON.parse(text);
                    playing = arr.some(i => i.corked === false && i.mute !== true);
                } catch (e) {
                    return;
                }
                if (playing) {
                    audioOff.stop();
                    root.audioPlaying = true;
                } else if (root.audioPlaying) {
                    audioOff.restart();
                }
            }
        }
    }
}
