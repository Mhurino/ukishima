pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../Singletons"
import "../components"

/**
 * 我 PROFILE sub-surface: who is at this machine. Horizontal card —
 * avatar (auto-detected from ~/.face) with the login name under it on the
 * left, live system facts on the right.
 * Reached from the pill's monitor icon and folds back to the hover pill on
 * the back chevron or an empty click.
 *
 * Each fact row is a small caps label plus its value (host, kernel, WM,
 * shell, GPU on the left; uptime, CPU, packages, memory, disk on the right),
 * sharing one text baseline so the values sit on a line.
 * Nothing here is editable, so the row registry stays empty and the pill's
 * row-soul never lands: the profile is read-only info, not settings.
 * Distro et al are read live rather than stored — a machine that changes
 * kernels should not need the profile edited to stay true.
 */
SettingsSurface {
    id: root

    backSurface: ""
    implicitHeight: content.implicitHeight

    // Purely informational — no rows for the keyboard cursor to walk.
    rows: []
    // ── Avatar: auto-detected, no configuring ────────────────────────────

    /** Avatar: prefer lock avatar path if set, else first of ~/.face* files, else "". */
    property string faceFile: ""
    function expandPath(p) {
        if (!p || p === "")
            return "";
        if (p === "~")
            return Quickshell.env("HOME");
        if (p.indexOf("~/") === 0)
            return (Quickshell.env("HOME") || "") + p.slice(1);
        return p;
    }
    FileView {
        id: flagsView
        path: "file://" + (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ukishima/flags.json"
        printErrors: false
        onLoaded: {
            try {
                const f = JSON.parse(flagsView.text());
                let path = f.lockAvatarPath || "";
                if (path) {
                    root.faceFile = root.expandPath(path);
                    if (root.faceFile)
                        return;
                }
            } catch (e) {}
            // fall back to ~/.face*
            faceProc.running = true;
        }
    }
    Process {
        id: faceProc
        running: false
        command: ["sh", "-c", "for f in \"$HOME/.face\" \"$HOME/.face.icon\" \"$HOME/.face.png\" \"$HOME/.face.jpg\"; do if [ -f \"$f\" ]; then echo \"$f\"; break; fi; done"]
        stdout: SplitParser { onRead: (line) => root.faceFile = line.trim() }
    }

    // ── Live system facts ──────────────────────────────────────────────

    property string distro: ""
    property string distroId: ""
    FileView {
        id: osRelease
        path: "file:///etc/os-release"
        printErrors: false
        onLoaded: {
            const t = osRelease.text();
            let name = "", id = "";
            const lines = t.split("\n");
            for (const line of lines) {
                if (line.indexOf("PRETTY_NAME=") === 0)
                    name = line.slice(12).replace(/^"|"$/g, "");
                else if (line.indexOf("NAME=") === 0 && name === "")
                    id = line.slice(5).replace(/^"|"$/g, "");
                else if (line.indexOf("ID=") === 0)
                    root.distroId = line.slice(3).replace(/^"|"$/g, "").toLowerCase();
            }
            root.distro = name !== "" ? name : id;
        }
    }

    /**
     * Distro logo, auto-detected from the os-release ID and rendered as the
     * matching `linux-*` glyph from the JetBrainsMono Nerd Font. CachyOS maps
     * to linux-cachyos, arch to linux-archlinux, and so on; anything unmapped
     * falls back to the tux penguin so an unknown distro still gets a mark.
     */
    readonly property var distroGlyphs: ({
        "cachyos": 0xf385, "arch": 0xf303, "ubuntu": 0xf31b, "debian": 0xf306,
        "fedora": 0xf30a, "nixos": 0xf313, "manjaro": 0xf312, "garuda": 0xf337,
        "void": 0xf32e, "kali": 0xf327, "linuxmint": 0xf30e, "elementary": 0xf309,
        "solus": 0xf32d, "parrot": 0xf329, "slackware": 0xf318, "gentoo": 0xf30d,
        "centos": 0xf304, "alpine": 0xf300, "mx": 0xf33f, "pop": 0xf32a,
        "zorin": 0xf32f, "opensuse-tumbleweed": 0xf37d, "tumbleweed": 0xf37d,
        "opensuse-leap": 0xf37e, "leap": 0xf37e, "opensuse": 0xf314
    })
    readonly property string distroGlyph: String.fromCodePoint(
        root.distroGlyphs[root.distroId] !== undefined ? root.distroGlyphs[root.distroId] : 0xf31a)

    property string hostName: ""
    FileView {
        id: etcHostname
        path: "file:///etc/hostname"
        printErrors: false
        onLoaded: root.hostName = etcHostname.text().trim()
    }

    property string kernel: ""
    Process {
        running: true
        command: ["uname", "-r"]
        stdout: SplitParser { onRead: (line) => root.kernel = line.trim() }
    }

    readonly property string shellName: {
        const sh = Quickshell.env("SHELL") || "";
        const i = sh.lastIndexOf("/");
        return i >= 0 ? sh.slice(i + 1) : sh;
    }
    readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
    readonly property string wmName: Quickshell.env("XDG_CURRENT_DESKTOP") || (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "Hyprland" : "")

    /** First VGA/3D/display controller line from lspci, else "". */
    property string gpuRaw: ""
    Process {
        running: true
        command: ["sh", "-c", "lspci 2>/dev/null | grep -iE 'VGA|3D controller|Display controller' | head -n 1"]
        stdout: SplitParser { onRead: (line) => root.gpuRaw = line.trim() }
    }
    /**
     * GPU model, e.g. "Lucienne". Same trim treatment as the CPU: strip the
     * bus address and class ("04:00.0 VGA compatible controller: "), the
     * vendor ("Advanced Micro Devices, Inc. [AMD/ATI]"), and the revision
     * ("(rev c1)"), so the value stays a chip name, not a PCI sentence.
     */
    readonly property string gpu: {
        let t = root.gpuRaw.replace(/^[0-9a-fA-F:.]+\s+.*?:\s*/, "");
        t = t.replace(/^(Advanced Micro Devices,?\s*Inc\.?(\s*\[AMD\/ATI\])?|NVIDIA Corporation|Intel Corporation)\s*/i, "");
        t = t.replace(/\s*\(rev\s+[^)]*\)\s*$/i, "");
        return t.trim();
    }

    //* Seconds since boot, from /proc/uptime's first field.
    property real uptimeSec: 0
    FileView {
        id: procUptime
        path: "file:///proc/uptime"
        printErrors: false
        onLoaded: {
            const v = parseFloat(procUptime.text().split(" ")[0]);
            if (!isNaN(v))
                root.uptimeSec = v;
        }
    }
    readonly property string uptime: {
        let s = Math.floor(root.uptimeSec);
        const d = Math.floor(s / 86400); s -= d * 86400;
        const h = Math.floor(s / 3600);  s -= h * 3600;
        const m = Math.floor(s / 60);
        if (d > 0) return d + "d " + h + "h";
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    /** Installed package count, whichever package manager exists. */
    property string pkgCount: ""
    Process {
        running: true
        command: ["sh", "-c", "if command -v pacman >/dev/null; then pacman -Q | wc -l; elif command -v dpkg-query >/dev/null; then dpkg-query -f '${binary:Package}\\n' -W | wc -l; elif command -v rpm >/dev/null; then rpm -qa | wc -l; fi"]
        stdout: SplitParser { onRead: (line) => root.pkgCount = line.trim() }
    }

    /**
     * CPU model name, e.g. "Ryzen 7 5700U". Taken from /proc/cpuinfo and
     * trimmed to the part that identifies the chip: the vendor prefix
     * ("AMD", "Intel") and the integrated-graphics suffix ("with Radeon
     * Graphics", "with Intel UHD Graphics") are noise on a card this size,
     * and leaving them in would triple the value column's width.
     */
    property string cpu: ""
    FileView {
        id: procCpuinfo
        path: "file:///proc/cpuinfo"
        printErrors: false
        onLoaded: {
            const m = procCpuinfo.text().match(/model name\s*:\s*(.+)/);
            if (!m)
                return;
            let name = m[1].trim();
            // Drop the vendor word and any trailing integrated-GPU clause.
            name = name.replace(/^(AMD|Intel|Apple|AuthenticAMD)\s+/i, "");
            name = name.replace(/\s+with\s+.*(Graphics|graphics)$/i, "");
            root.cpu = name;
        }
    }

    /** Used / total RAM in GiB, from /proc/meminfo. */
    property string memUsed: ""
    FileView {
        id: procMeminfo
        path: "file:///proc/meminfo"
        printErrors: false
        onLoaded: {
            const t = procMeminfo.text();
            const m1 = t.match(/MemTotal:\s+(\d+)/);
            const m2 = t.match(/MemAvailable:\s+(\d+)/);
            if (m1 && m2) {
                const total = parseInt(m1[1], 10) / 1048576;
                const used = (parseInt(m1[1], 10) - parseInt(m2[1], 10)) / 1048576;
                root.memUsed = used.toFixed(1) + " / " + total.toFixed(1) + " GiB";
            }
        }
    }

    /** Root filesystem used / total, in GiB, so it reads like MEMORY. */
    property string diskUsed: ""
    Process {
        running: true
        command: ["sh", "-c", "df -B1 / | awk 'NR==2 {printf \"%.1f / %.1f GiB\", $3/1073741824, $2/1073741824}'"]
        stdout: SplitParser { onRead: (line) => root.diskUsed = line.trim() }
    }

    component Fact: Item {
        id: fact
        required property var modelData
        width: parent.width
        implicitHeight: label.implicitHeight + 3 * root.s + value.implicitHeight

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 3 * root.s

            Text {
                id: label
                text: fact.modelData.label
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 8 * root.s
                font.weight: Font.Medium
                font.letterSpacing: 0.8 * root.s
            }

            Text {
                id: value
                width: parent.width
                text: fact.modelData.value !== "" && fact.modelData.value !== undefined ? String(fact.modelData.value) : "—"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "我"
            title: "PROFILE"
            showBack: true
        }

        Item { width: 1; height: 10 * root.s }

        // Identity comes first; technical details are grouped below rather than
        // competing with the account name for attention.
        Row {
            id: identityRow
            width: parent.width
            spacing: 14 * root.s
            height: 58 * root.s

            ClippingRectangle {
                id: avatar
                width: 56 * root.s
                height: 56 * root.s
                radius: 28 * root.s
                color: Theme.frameBg
                anchors.verticalCenter: parent.verticalCenter
                border.width: 1
                border.color: Theme.hair

                Image {
                    id: faceImg
                    anchors.fill: parent
                    source: root.faceFile !== "" ? "file://" + root.faceFile : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                    sourceSize: Qt.size(112 * root.s, 112 * root.s)
                }

                GlyphIcon {
                    anchors.centerIn: parent
                    width: 25 * root.s
                    height: 25 * root.s
                    name: "user"
                    color: Theme.iconDim
                    visible: !faceImg.visible
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - avatar.width - identityRow.spacing
                spacing: 3 * root.s

                Text {
                    width: parent.width
                    text: root.userName !== "" ? root.userName : "User"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 16 * root.s
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Row {
                    width: parent.width
                    spacing: 6 * root.s

                    Text {
                        text: root.distroGlyph
                        color: Theme.flameGlow
                        font.family: "JetBrainsMono NFM"
                        font.pixelSize: 14 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        width: parent.width - 24 * root.s
                        text: root.distro !== "" ? root.distro : "Linux"
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    width: parent.width
                    text: [root.hostName, root.wmName].filter(function (v) { return v !== ""; }).join(" · ")
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9.5 * root.s
                    elide: Text.ElideRight
                }
            }
        }

        Item { width: 1; height: 8 * root.s }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        Item { width: 1; height: 9 * root.s }

        Row {
            width: parent.width
            spacing: 16 * root.s

            Column {
                id: systemFacts
                width: (parent.width - parent.spacing) / 2
                spacing: 8 * root.s

                Text {
                    text: "SYSTEM"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.5 * root.s
                }

                Repeater {
                    model: [
                        { label: "KERNEL", value: root.kernel },
                        { label: "SHELL", value: root.shellName },
                        { label: "UPTIME", value: root.uptime },
                        { label: "PACKAGES", value: root.pkgCount }
                    ]
                    delegate: Fact {}
                }
            }

            Rectangle {
                width: 1
                height: 154 * root.s
                color: Theme.hairSoft
            }

            Column {
                id: hardwareFacts
                width: systemFacts.width
                spacing: 8 * root.s

                Text {
                    text: "HARDWARE"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.5 * root.s
                }

                Repeater {
                    model: [
                        { label: "CPU", value: root.cpu },
                        { label: "GPU", value: root.gpu },
                        { label: "MEMORY", value: root.memUsed },
                        { label: "DISK", value: root.diskUsed }
                    ]
                    delegate: Fact {}
                }
            }
        }

        Item { width: 1; height: 4 * root.s }

    }
}
