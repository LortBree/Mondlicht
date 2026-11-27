import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

PanelWindow {
    id: win
    required property var shell
    screen: win.shell.targetScreen

    // Fullscreen transparent click-outside catcher (no X close button)
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: win.shell.quickSettingsOpen || card.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "obsidian-popover"
    WlrLayershell.keyboardFocus: win.shell.quickSettingsOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property string page: "main" // "main" | "wifi" | "bluetooth" | "audio"

    property bool hasWifi: true
    property bool wifiOn: true
    property string wifiSsid: "Wi-Fi"
    property bool ethConnected: false
    property string ethIp: ""
    property int brightPct: 80
    property bool hasBacklight: false

    property var wifiNetworks: []
    property bool wifiScanning: false
    property string wifiBusySsid: ""
    property string wifiSelectedSsid: ""
    property string wifiStatusMsg: ""
    property bool wifiStatusError: false
    property bool wifiShowPass: false

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool hasBluetooth: btAdapter !== null
    readonly property bool btOn: btAdapter ? btAdapter.enabled : false
    readonly property string btSubtitle: {
        if (!btOn) return "Off";
        const devs = btDevicesList();
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].connected) return devs[i].name || devs[i].deviceName || "Connected";
        }
        return "On";
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool audioMuted: sink && sink.audio ? sink.audio.muted : false
    readonly property int audioPct: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property string audioLabel: sink ? (sink.description || sink.nickname || sink.name || "Speaker") : "No output"
    readonly property var mic: Pipewire.defaultAudioSource
    readonly property bool micMuted: mic && mic.audio ? mic.audio.muted : false
    readonly property int micPct: mic && mic.audio ? Math.round(mic.audio.volume * 100) : 0
    readonly property int batPct: UPower.displayDevice && UPower.displayDevice.ready ? Math.round(UPower.displayDevice.percentage * 100) : -1
    readonly property bool batCharging: UPower.displayDevice && UPower.displayDevice.state === UPowerDeviceState.Charging

    function fmtDuration(secs) {
        if (!secs || secs <= 60) return "";
        const h = Math.floor(secs / 3600);
        const m = Math.round((secs % 3600) / 60);
        return h > 0 ? (h + "h " + m + "m") : (m + "m");
    }

    function fmtBatFooter() {
        if (win.batPct < 0) return "";
        const dev = UPower.displayDevice;
        const secs = win.batCharging ? (dev ? dev.timeToFull : 0) : (dev ? dev.timeToEmpty : 0);
        const dur = fmtDuration(secs);
        const rate = dev && dev.changeRate ? Math.abs(dev.changeRate) : 0;
        let out = (win.batCharging ? "󰂄 " : "󰁹 ") + win.batPct + "%";
        if (dur) out += " · " + dur;
        else if (win.batCharging) out += " · Charging";
        if (rate >= 0.5) out += " · " + rate.toFixed(1) + "W";
        return out;
    }

    function splitTerse(line) {
        return line.replace(/\\:/g, "\u0001").split(":").map(s => s.replace(/\u0001/g, ":"));
    }

    function audioSinks() {
        const list = Pipewire.nodes.values;
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const n = list[i];
            if (n && n.ready && n.audio && n.isSink && !n.isStream) out.push(n);
        }
        return out;
    }

    function sinkIconFor(node) {
        const tag = (((node && node.name) || "") + " " + ((node && node.description) || "")).toLowerCase();
        if (tag.includes("bluez")) return "󰂯";
        if (tag.includes("headphone") || tag.includes("headset")) return "󰋋";
        if (tag.includes("hdmi") || tag.includes("displayport")) return "󰡁";
        return "󰕾";
    }

    function btDevicesList() {
        if (!btAdapter) return [];
        const raw = btAdapter.devices.values.slice();
        const filtered = raw.filter(d => d && (d.paired || (d.name && d.name.length > 0) || (d.deviceName && d.deviceName.length > 0)));
        filtered.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return (a.name || a.deviceName || "").localeCompare(b.name || b.deviceName || "");
        });
        return filtered;
    }

    function btIconFor(dev) {
        const ic = ((dev && dev.icon) || "").toLowerCase();
        if (ic.includes("headset") || ic.includes("headphone")) return "󰋋";
        if (ic.includes("audio")) return "󰓃";
        if (ic.includes("mouse")) return "󰍽";
        if (ic.includes("keyboard")) return "󰌌";
        if (ic.includes("phone")) return "󰏲";
        return "󰂯";
    }

    function wifiSignalIcon(sig) {
        if (sig >= 75) return "󰤨";
        if (sig >= 50) return "󰤥";
        if (sig >= 25) return "󰤢";
        return "󰤟";
    }

    function openPage(target) {
        win.wifiStatusMsg = "";
        win.wifiStatusError = false;
        win.wifiSelectedSsid = "";
        win.page = target;
        if (target === "wifi") {
            wifiListProc.running = true;
            if (win.wifiOn && !wifiRescanProc.running) {
                win.wifiScanning = true;
                wifiRescanProc.running = true;
            }
        }
    }

    function runWifiAction(ssid, argv, label) {
        if (wifiActionProc.running) return;
        win.wifiBusySsid = ssid;
        win.wifiStatusMsg = label;
        win.wifiStatusError = false;
        wifiActionProc.lastActionLabel = label;
        wifiActionProc.exec(argv);
    }

    Process {
        id: refreshProc
        command: [
            "sh", "-c",
            "HAS_WIFI=$(nmcli -t -f TYPE dev 2>/dev/null | grep -qx wifi && echo 1 || (ls -d /sys/class/net/*/wireless >/dev/null 2>&1 && echo 1 || echo 0)); " +
            "ETH_DEV=$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | awk -F: '$2==\"ethernet\" && $3==\"connected\"{print $1; exit}'); " +
            "ETH_CONN=$([ -n \"$ETH_DEV\" ] && echo 1 || echo 0); " +
            "ETH_IP=$([ -n \"$ETH_DEV\" ] && ip -4 -o addr show dev \"$ETH_DEV\" 2>/dev/null | awk '{sub(/\\/.*/,\"\",$4); print $4; exit}' || true); " +
            "IDLE_ON=$(pgrep -x hypridle >/dev/null 2>&1 && echo 1 || echo 0); " +
            "printf '%s|%s|%s|%s|%s|%s|%s\\n' " +
            "\"$(nmcli radio wifi 2>/dev/null || echo disabled)\" " +
            "\"$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; exit}')\" " +
            "\"$(brightnessctl -m 2>/dev/null | awk -F, '{gsub(/%/,\"\",$4); print $4}')\" " +
            "\"$HAS_WIFI\" \"$ETH_CONN\" \"$ETH_IP\" \"$IDLE_ON\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("|");
                win.wifiOn = (p[0] === "enabled");
                win.wifiSsid = p[1] ? p[1] : (win.wifiOn ? "Disconnected" : "Off");
                const b = parseInt(p[2], 10);
                win.hasBacklight = !isNaN(b);
                if (!isNaN(b)) win.brightPct = b;
                win.hasWifi = (p[3] === "1");
                win.ethConnected = (p[4] === "1");
                win.ethIp = p[5] || "";
                win.shell.keepAwakeOn = (p[6] === "0");
            }
        }
    }

    Component.onCompleted: refreshProc.running = true

    Process {
        id: wifiListProc
        command: [
            "sh", "-c",
            "nmcli -t -f NAME,TYPE connection show 2>/dev/null; echo '---WIFI---'; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const halves = text.split("---WIFI---");
                const savedMap = {};
                if (halves[0]) {
                    const cLines = halves[0].split("\n");
                    for (let i = 0; i < cLines.length; i++) {
                        const row = cLines[i].trim();
                        if (!row) continue;
                        const parts = win.splitTerse(row);
                        if (parts.length >= 2 && parts[parts.length - 1] === "802-11-wireless") {
                            savedMap[parts.slice(0, parts.length - 1).join(":")] = true;
                        }
                    }
                }
                const bySsid = {};
                if (halves[1]) {
                    const wLines = halves[1].split("\n");
                    for (let i = 0; i < wLines.length; i++) {
                        const row = wLines[i].trim();
                        if (!row) continue;
                        const parts = win.splitTerse(row);
                        if (parts.length < 4) continue;
                        const active = (parts[0] === "*");
                        const sec = parts[parts.length - 1] || "";
                        const sig = parseInt(parts[parts.length - 2], 10) || 0;
                        const ssid = parts.slice(1, parts.length - 2).join(":");
                        if (!ssid) continue;
                        const prev = bySsid[ssid];
                        if (!prev || active || (!prev.active && sig > prev.signal)) {
                            bySsid[ssid] = {
                                ssid: ssid,
                                active: active,
                                saved: !!savedMap[ssid],
                                signal: sig,
                                security: sec,
                                secured: sec.length > 0 && sec !== "--"
                            };
                        }
                    }
                }
                const nets = Object.keys(bySsid).map(k => bySsid[k]);
                nets.sort((a, b) => {
                    if (a.active !== b.active) return a.active ? -1 : 1;
                    if (a.saved !== b.saved) return a.saved ? -1 : 1;
                    return b.signal - a.signal;
                });
                win.wifiNetworks = nets;
            }
        }
    }

    Process {
        id: wifiRescanProc
        command: ["nmcli", "dev", "wifi", "rescan"]
        onExited: function() {
            win.wifiScanning = false;
            wifiListProc.running = true;
        }
    }

    Process {
        id: wifiActionProc
        property string lastActionLabel: ""
        property string errOut: ""
        stderr: StdioCollector {
            onStreamFinished: wifiActionProc.errOut = text.trim()
        }
        onExited: function(exitCode) {
            win.wifiBusySsid = "";
            if (exitCode === 0) {
                win.wifiStatusMsg = "";
                win.wifiStatusError = false;
                win.wifiSelectedSsid = "";
                win.wifiShowPass = false;
            } else {
                const detail = wifiActionProc.errOut.split("\n")[0] || "Failed";
                win.wifiStatusMsg = detail.replace(/^Error:\s*/i, "");
                win.wifiStatusError = true;
            }
            wifiActionProc.errOut = "";
            refreshProc.running = true;
            wifiListProc.running = true;
        }
    }

    Connections {
        target: win.shell
        function onQuickSettingsOpenChanged() {
            if (win.shell.quickSettingsOpen) {
                refreshProc.running = true;
            } else {
                win.page = "main";
                win.wifiSelectedSsid = "";
                win.wifiStatusMsg = "";
                win.wifiShowPass = false;
                if (win.btAdapter && win.btAdapter.discovering) win.btAdapter.discovering = false;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.shell.quickSettingsOpen = false
    }

    component VolumeSliderRow: RowLayout {
        spacing: 10
        property bool showOutputArrow: false

        Text {
            text: win.audioMuted ? "󰖁" : "󰕾"
            color: win.audioMuted ? Theme.muted : Theme.text
            font.family: Theme.fontMono
            font.pixelSize: 17
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
            }
        }
        Item {
            Layout.fillWidth: true
            height: 18
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 5; radius: 3
                color: "#1c2233"
                Rectangle {
                    width: Math.max(6, parent.width * (Math.min(100, win.audioPct) / 100.0))
                    height: parent.height; radius: 3
                    color: win.audioMuted ? Theme.muted : Theme.accent
                }
            }
            Rectangle {
                x: Math.max(0, Math.min(parent.width - width, parent.width * (Math.min(100, win.audioPct) / 100.0) - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14; radius: 7
                color: Theme.text
                border.width: 2; border.color: win.audioMuted ? Theme.muted : Theme.accent
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function applyVol(mx) {
                    const pct = Math.max(0, Math.min(100, Math.round((mx / width) * 100)));
                    Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", pct + "%"]);
                }
                onPressed: function(m) { applyVol(m.x); }
                onPositionChanged: function(m) { if (pressed) applyVol(m.x); }
            }
        }
        Text {
            text: win.audioPct + "%"
            color: Theme.muted
            font.family: Theme.fontSans
            font.pixelSize: 11
            Layout.preferredWidth: 32
            horizontalAlignment: Text.AlignRight
        }
        Rectangle {
            visible: showOutputArrow
            width: 24; height: 22; radius: 6
            color: audioOutHov.hovered ? Theme.elevatedBg : "transparent"
            Text {
                anchors.centerIn: parent
                text: "›"
                color: audioOutHov.hovered ? Theme.text : Theme.muted
                font.pixelSize: 15
            }
            HoverHandler { id: audioOutHov; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: win.openPage("audio")
            }
        }
    }

    Rectangle {
        id: card
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 70
        }
        width: 364
        height: 456
        radius: 14
        color: Theme.voidBg
        border.width: 1
        border.color: Theme.rim
        opacity: win.shell.quickSettingsOpen ? 1.0 : 0.0

        transform: Translate {
            x: win.shell.quickSettingsOpen ? 0 : 48
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: {
            if (win.page !== "main") {
                win.page = "main";
                win.wifiSelectedSsid = "";
                win.wifiStatusMsg = "";
                win.wifiShowPass = false;
            } else {
                win.shell.quickSettingsOpen = false;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: function(m) { m.accepted = true; }
        }

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
            height: 22
            radius: 13
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.sheen }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // MAIN QUICK SETTINGS PAGE
        ColumnLayout {
            visible: win.page === "main"
            anchors.fill: parent
            anchors.margins: 16
            spacing: 11

            Text {
                text: "Quick Settings"
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            // 2x3 Win11 Quick Tiles
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                // 1. Wi-Fi (Laptop / wireless adapter)
                Rectangle {
                    visible: win.hasWifi
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    radius: 10
                    color: win.wifiOn ? Theme.accent : Theme.glassBg
                    border.width: 1
                    border.color: win.wifiOn ? Theme.accent : Theme.rim

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Text {
                            text: win.wifiOn ? "󰖩" : "󰖪"
                            color: win.wifiOn ? Theme.accentFg : Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: 19
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: "Wi-Fi"
                                color: win.wifiOn ? Theme.accentFg : Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                text: win.wifiSsid
                                color: win.wifiOn ? Theme.accentFg : Theme.muted
                                opacity: 0.82
                                font.family: Theme.fontSans
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                        Text {
                            text: "›"
                            color: win.wifiOn ? Theme.accentFg : Theme.muted
                            font.pixelSize: 16
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.openPage("wifi")
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: 28
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.wifiOn = !win.wifiOn;
                            win.wifiSsid = win.wifiOn ? "Connecting..." : "Off";
                            Quickshell.execDetached(["nmcli", "radio", "wifi", win.wifiOn ? "on" : "off"]);
                            refreshDelay.restart();
                        }
                    }
                }

                // 1b. Keep Awake / Caffeine (PC without Wi-Fi)
                Rectangle {
                    visible: !win.hasWifi
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    radius: 10
                    color: win.shell.keepAwakeOn ? Theme.accent : Theme.glassBg
                    border.width: 1
                    border.color: win.shell.keepAwakeOn ? Theme.accent : Theme.rim

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Text {
                            text: win.shell.keepAwakeOn ? "󰅶" : "󰛊"
                            color: win.shell.keepAwakeOn ? Theme.accentFg : Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: 19
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: "Keep Awake"
                                color: win.shell.keepAwakeOn ? Theme.accentFg : Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                text: win.shell.keepAwakeOn ? "Awake" : "Auto sleep"
                                color: win.shell.keepAwakeOn ? Theme.accentFg : Theme.muted
                                opacity: 0.82
                                font.family: Theme.fontSans
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.shell.keepAwakeOn = !win.shell.keepAwakeOn;
                            Quickshell.execDetached([
                                "sh", "-c",
                                win.shell.keepAwakeOn
                                    ? "systemctl --user stop hypridle.service >/dev/null 2>&1 || pkill -x hypridle >/dev/null 2>&1 || true"
                                    : "systemctl --user start hypridle.service >/dev/null 2>&1 || pgrep -x hypridle >/dev/null 2>&1 || setsid -f hypridle </dev/null >/dev/null 2>&1"
                            ]);
                        }
                    }
                }

                // 2. Bluetooth (shown when Bluetooth adapter exists)
                Rectangle {
                    visible: win.hasBluetooth
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    radius: 10
                    color: win.btOn ? Theme.accent : Theme.glassBg
                    border.width: 1
                    border.color: win.btOn ? Theme.accent : Theme.rim

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Text {
                            text: win.btOn ? "󰂯" : "󰂲"
                            color: win.btOn ? Theme.accentFg : Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: 19
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: "Bluetooth"
                                color: win.btOn ? Theme.accentFg : Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                text: win.btSubtitle
                                color: win.btOn ? Theme.accentFg : Theme.muted
                                opacity: 0.82
                                font.family: Theme.fontSans
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                        Text {
                            text: "›"
                            color: win.btOn ? Theme.accentFg : Theme.muted
                            font.pixelSize: 16
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.openPage("bluetooth")
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: 28
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (win.btAdapter) win.btAdapter.enabled = !win.btAdapter.enabled;
                        }
                    }
                }

                // 2b. Microphone Mute (PC without Bluetooth)
                Rectangle {
                    visible: !win.hasBluetooth
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    radius: 10
                    color: (win.mic && !win.micMuted) ? Theme.accent : Theme.glassBg
                    border.width: 1
                    border.color: (win.mic && !win.micMuted) ? Theme.accent : Theme.rim

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Text {
                            text: win.micMuted || !win.mic ? "󰍭" : "󰍬"
                            color: (win.mic && !win.micMuted) ? Theme.accentFg : Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: 19
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: "Microphone"
                                color: (win.mic && !win.micMuted) ? Theme.accentFg : Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                text: !win.mic ? "None" : (win.micMuted ? "Muted" : "Live")
                                color: (win.mic && !win.micMuted) ? Theme.accentFg : Theme.muted
                                opacity: 0.82
                                font.family: Theme.fontSans
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (win.mic) Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
                        }
                    }
                }

                // 3. Night Light
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    radius: 10
                    color: win.shell.nightLightOn ? Theme.accent : Theme.glassBg
                    border.width: 1
                    border.color: win.shell.nightLightOn ? Theme.accent : Theme.rim

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Text {
                            text: win.shell.nightLightOn ? "󰖔" : "󰖨"
                            color: win.shell.nightLightOn ? Theme.accentFg : Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: 18
                        }
                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: "Night Light"
                                color: win.shell.nightLightOn ? Theme.accentFg : Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: win.shell.nightLightOn ? "4200K" : "Off"
                                color: win.shell.nightLightOn ? Theme.accentFg : Theme.muted
                                opacity: 0.82
                                font.family: Theme.fontSans
                                font.pixelSize: 10
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/night-light"])
                    }
                }

                // 4. Do Not Disturb
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    radius: 10
                    color: win.shell.dndOn ? Theme.accent : Theme.glassBg
                    border.width: 1
                    border.color: win.shell.dndOn ? Theme.accent : Theme.rim

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Text {
                            text: win.shell.dndOn ? "󰂛" : "󰂜"
                            color: win.shell.dndOn ? Theme.accentFg : Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: 18
                        }
                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: "Do Not Disturb"
                                color: win.shell.dndOn ? Theme.accentFg : Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: win.shell.dndOn ? "Muted" : "Active"
                                color: win.shell.dndOn ? Theme.accentFg : Theme.muted
                                opacity: 0.82
                                font.family: Theme.fontSans
                                font.pixelSize: 10
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.shell.dndOn = !win.shell.dndOn
                    }
                }

                // 5. Screenshot
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: 10
                    color: shotHover.hovered ? Theme.elevatedBg : Theme.glassBg
                    border.width: 1
                    border.color: Theme.rim
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10; spacing: 8
                        Text { text: "󰹑"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: 18 }
                        Text { text: "Screenshot"; color: Theme.text; font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.DemiBold }
                    }
                    HoverHandler { id: shotHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.shell.quickSettingsOpen = false;
                            Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/screenshot", "region"]);
                        }
                    }
                }

                // 6. Wallpaper
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: 10
                    color: wallHover.hovered ? Theme.elevatedBg : Theme.glassBg
                    border.width: 1
                    border.color: Theme.rim
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 10; spacing: 8
                        Text { text: "󰸉"; color: Theme.secondary; font.family: Theme.fontMono; font.pixelSize: 18 }
                        Text { text: "Wallpaper"; color: Theme.text; font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.DemiBold }
                    }
                    HoverHandler { id: wallHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.shell.openOnly("wallpaper", win.screen)
                    }
                }
            }

            // Power Mode Segmented Selector (tuned-ppd via UPower PowerProfiles)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 10
                color: Theme.glassBg
                border.width: 1
                border.color: Theme.rim

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Repeater {
                        model: {
                            const items = [
                                { profile: PowerProfile.PowerSaver, icon: "󰌪", label: "Saver" },
                                { profile: PowerProfile.Balanced, icon: "󰾅", label: "Balanced" }
                            ];
                            if (PowerProfiles.hasPerformanceProfile) {
                                items.push({ profile: PowerProfile.Performance, icon: "󰓅", label: "Perf" });
                            }
                            return items;
                        }
                        Rectangle {
                            required property var modelData
                            readonly property bool active: PowerProfiles.profile === modelData.profile
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 7
                            color: active ? Theme.accent : (pwrModeHov.hovered ? Theme.elevatedBg : "transparent")
                            Behavior on color { ColorAnimation { duration: 140 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: modelData.icon
                                    color: active ? Theme.accentFg : Theme.muted
                                    font.family: Theme.fontMono
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: modelData.label
                                    color: active ? Theme.accentFg : Theme.text
                                    font.family: Theme.fontSans
                                    font.pixelSize: 11
                                    font.weight: active ? Font.DemiBold : Font.Medium
                                }
                            }
                            HoverHandler { id: pwrModeHov; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: PowerProfiles.profile = modelData.profile
                            }
                        }
                    }
                }
            }

            // Sliders (Brightness on laptop OR Mic Gain on PC + Volume with Sound Output chevron)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: (win.hasBacklight || (!win.hasBacklight && win.mic !== null)) ? 84 : 46
                radius: 10
                color: Theme.glassBg
                border.width: 1
                border.color: Theme.rim

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        visible: win.hasBacklight
                        Layout.fillWidth: true
                        spacing: 10
                        Text { text: "󰃟"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: 17 }
                        Item {
                            Layout.fillWidth: true
                            height: 18
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 5; radius: 3
                                color: "#1c2233"
                                Rectangle {
                                    width: Math.max(6, parent.width * (win.brightPct / 100.0))
                                    height: parent.height; radius: 3
                                    color: Theme.accent
                                }
                            }
                            Rectangle {
                                x: Math.max(0, Math.min(parent.width - width, parent.width * (win.brightPct / 100.0) - width / 2))
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14; height: 14; radius: 7
                                color: Theme.text
                                border.width: 2; border.color: Theme.accent
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                function applyX(mx) {
                                    const pct = Math.max(5, Math.min(100, Math.round((mx / width) * 100)));
                                    win.brightPct = pct;
                                    Quickshell.execDetached(["brightnessctl", "set", pct + "%"]);
                                }
                                onPressed: function(m) { applyX(m.x); }
                                onPositionChanged: function(m) { if (pressed) applyX(m.x); }
                            }
                        }
                        Text {
                            text: win.brightPct + "%"
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: 11
                            Layout.preferredWidth: 32
                            horizontalAlignment: Text.AlignRight
                        }
                        Item { width: 24; height: 1 }
                    }

                    RowLayout {
                        visible: !win.hasBacklight && win.mic !== null
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: win.micMuted ? "󰍭" : "󰍬"
                            color: win.micMuted ? Theme.crit : Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: 17
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                            height: 18
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 5; radius: 3
                                color: "#1c2233"
                                Rectangle {
                                    width: Math.max(6, parent.width * (Math.min(100, win.micPct) / 100.0))
                                    height: parent.height; radius: 3
                                    color: win.micMuted ? Theme.muted : Theme.accent
                                }
                            }
                            Rectangle {
                                x: Math.max(0, Math.min(parent.width - width, parent.width * (Math.min(100, win.micPct) / 100.0) - width / 2))
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14; height: 14; radius: 7
                                color: Theme.text
                                border.width: 2; border.color: win.micMuted ? Theme.muted : Theme.accent
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                function applyMic(mx) {
                                    const pct = Math.max(0, Math.min(100, Math.round((mx / width) * 100)));
                                    Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SOURCE@", pct + "%"]);
                                }
                                onPressed: function(m) { applyMic(m.x); }
                                onPositionChanged: function(m) { if (pressed) applyMic(m.x); }
                            }
                        }
                        Text {
                            text: win.micMuted ? "Mute" : (win.micPct + "%")
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: 11
                            Layout.preferredWidth: 32
                            horizontalAlignment: Text.AlignRight
                        }
                        Item { width: 24; height: 1 }
                    }

                    VolumeSliderRow {
                        Layout.fillWidth: true
                        showOutputArrow: true
                    }
                }
            }

            // Footer
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    visible: win.batPct >= 0
                    text: win.fmtBatFooter()
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: win.batPct < 0
                    text: win.ethConnected ? ("󰈀 " + (win.ethIp || "Ethernet")) : "󰈂 Offline"
                    color: win.ethConnected ? Theme.muted : Theme.crit
                    font.family: Theme.fontSans
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 32; height: 30; radius: 8
                    color: win.shell.ecoModeOn ? Theme.accent : (ecoHov.hovered ? Theme.elevatedBg : Theme.glassBg)
                    border.width: 1; border.color: win.shell.ecoModeOn ? Theme.accent : Theme.rim
                    Text {
                        anchors.centerIn: parent
                        text: "󰌪"
                        color: win.shell.ecoModeOn ? Theme.accentFg : Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 15
                    }
                    HoverHandler { id: ecoHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.shell.ecoModeOn = !win.shell.ecoModeOn;
                            const v = win.shell.ecoModeOn ? "false" : "true";
                            Quickshell.execDetached([
                                "hyprctl", "eval",
                                "hl.config({ decoration = { blur = { enabled = " + v + " }, shadow = { enabled = " + v + " }, glow = { enabled = " + v + " } } })"
                            ]);
                        }
                    }
                }

                Rectangle {
                    width: 32; height: 30; radius: 8
                    color: cfgHov.hovered ? Theme.elevatedBg : Theme.glassBg
                    border.width: 1; border.color: Theme.rim
                    Image {
                        anchors.centerIn: parent
                        width: 18; height: 18
                        sourceSize: Qt.size(36, 36)
                        smooth: true
                        source: "file://" + Quickshell.env("HOME") + "/.local/share/icons/hicolor/scalable/apps/mondlicht-settings.svg"
                    }
                    HoverHandler { id: cfgHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: win.shell.openSettings()
                    }
                }

                Rectangle {
                    width: 32; height: 30; radius: 8
                    color: guideHov.hovered ? Theme.elevatedBg : Theme.glassBg
                    border.width: 1; border.color: Theme.rim
                    Text { anchors.centerIn: parent; text: "?"; color: Theme.accent; font.family: Theme.fontSans; font.pixelSize: 13; font.weight: Font.Bold }
                    HoverHandler { id: guideHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: win.shell.openOnly("guide", win.screen)
                    }
                }

                Rectangle {
                    width: 32; height: 30; radius: 8
                    color: lockHov.hovered ? Theme.elevatedBg : Theme.glassBg
                    border.width: 1; border.color: Theme.rim
                    Text { anchors.centerIn: parent; text: "󰌾"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: 15 }
                    HoverHandler { id: lockHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { win.shell.quickSettingsOpen = false; Quickshell.execDetached(["hyprlock"]); }
                    }
                }

                Rectangle {
                    width: 32; height: 30; radius: 8
                    color: pwrHov.hovered ? Theme.elevatedBg : Theme.glassBg
                    border.width: 1; border.color: Theme.rim
                    Text { anchors.centerIn: parent; text: "󰐥"; color: Theme.crit; font.family: Theme.fontMono; font.pixelSize: 15 }
                    HoverHandler { id: pwrHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: win.shell.openOnly("power", win.screen)
                    }
                }
            }
        }

        // WIFI SUB-PAGE
        ColumnLayout {
            visible: win.page === "wifi"
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: wBackHov.hovered ? Theme.elevatedBg : Theme.glassBg
                    border.width: 1; border.color: Theme.rim
                    Text { anchors.centerIn: parent; text: "←"; color: Theme.text; font.pixelSize: 14 }
                    HoverHandler { id: wBackHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.openPage("main") }
                }

                Text {
                    text: "Wi-Fi"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: win.wifiScanning ? Theme.accent : (wScanHov.hovered ? Theme.elevatedBg : Theme.glassBg)
                    border.width: 1; border.color: win.wifiScanning ? Theme.accent : Theme.rim
                    Text {
                        anchors.centerIn: parent
                        text: "󰑓"
                        color: win.wifiScanning ? Theme.accentFg : Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 15
                    }
                    HoverHandler { id: wScanHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (win.wifiOn && !wifiRescanProc.running) {
                                win.wifiScanning = true;
                                wifiRescanProc.running = true;
                            }
                        }
                    }
                }

                Rectangle {
                    width: 44; height: 24; radius: 12
                    color: win.wifiOn ? Theme.accent : Theme.glassBg
                    border.width: 1; border.color: win.wifiOn ? Theme.accent : Theme.rim
                    Text {
                        anchors.centerIn: parent
                        text: win.wifiOn ? "On" : "Off"
                        color: win.wifiOn ? Theme.accentFg : Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.wifiOn = !win.wifiOn;
                            Quickshell.execDetached(["nmcli", "radio", "wifi", win.wifiOn ? "on" : "off"]);
                            refreshDelay.restart();
                        }
                    }
                }
            }

            Rectangle {
                visible: win.wifiStatusMsg.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 8
                color: win.wifiStatusError ? "#33e07a8e" : Theme.glassBg
                border.width: 1
                border.color: win.wifiStatusError ? Theme.crit : Theme.rim
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: win.wifiStatusMsg
                    color: win.wifiStatusError ? Theme.crit : Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Item {
                visible: !win.wifiOn || win.wifiNetworks.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                Text {
                    anchors.centerIn: parent
                    text: !win.wifiOn ? "Wi-Fi is off" : (win.wifiScanning ? "Scanning networks..." : "No Wi-Fi networks found")
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                }
            }

            Flickable {
                visible: win.wifiOn && win.wifiNetworks.length > 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: wifiCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: wifiCol
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: win.wifiNetworks
                        Rectangle {
                            required property var modelData
                            readonly property bool expanded: win.wifiSelectedSsid === modelData.ssid
                            readonly property bool busy: win.wifiBusySsid === modelData.ssid
                            Layout.fillWidth: true
                            Layout.preferredHeight: netRowCol.implicitHeight + 16
                            radius: 10
                            color: modelData.active ? Theme.elevatedBg : (expanded ? Theme.elevatedBg : Theme.glassBg)
                            border.width: 1
                            border.color: modelData.active || expanded ? Theme.accent : Theme.rim

                            ColumnLayout {
                                id: netRowCol
                                anchors { fill: parent; margins: 8 }
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: win.wifiSignalIcon(modelData.signal)
                                        color: modelData.active ? Theme.accent : Theme.text
                                        font.family: Theme.fontMono
                                        font.pixelSize: 16
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.ssid
                                            color: Theme.text
                                            font.family: Theme.fontSans
                                            font.pixelSize: 12
                                            font.weight: modelData.active ? Font.DemiBold : Font.Medium
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: busy ? "Working..." : (modelData.active ? "Connected" : (modelData.saved ? "Saved" : (modelData.secured ? "Secured" : "Open")))
                                            color: modelData.active ? Theme.accent : Theme.muted
                                            font.family: Theme.fontSans
                                            font.pixelSize: 10
                                        }
                                    }

                                    Text {
                                        visible: modelData.secured && !modelData.active
                                        text: "󰌾"
                                        color: Theme.muted
                                        font.family: Theme.fontMono
                                        font.pixelSize: 13
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (expanded) {
                                                win.wifiSelectedSsid = "";
                                                win.wifiShowPass = false;
                                                return;
                                            }
                                            if (!modelData.active && !modelData.saved && !modelData.secured) {
                                                win.runWifiAction(modelData.ssid, ["nmcli", "dev", "wifi", "connect", modelData.ssid], "Connecting to " + modelData.ssid + "...");
                                            } else if (!modelData.active && modelData.saved) {
                                                win.runWifiAction(modelData.ssid, ["nmcli", "connection", "up", modelData.ssid], "Connecting to " + modelData.ssid + "...");
                                            } else {
                                                win.wifiSelectedSsid = modelData.ssid;
                                                win.wifiStatusMsg = "";
                                                win.wifiShowPass = false;
                                            }
                                        }
                                    }
                                }

                                // Inline action / password drawer
                                ColumnLayout {
                                    visible: expanded
                                    Layout.fillWidth: true
                                    spacing: 6

                                    // Password input for new secured network
                                    RowLayout {
                                        visible: !modelData.active && !modelData.saved && modelData.secured
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 34
                                            radius: 8
                                            color: Theme.voidBg
                                            border.width: 1
                                            border.color: wifiPassInput.activeFocus ? Theme.accent : Theme.rim

                                            TextInput {
                                                id: wifiPassInput
                                                anchors.fill: parent
                                                anchors.leftMargin: 10; anchors.rightMargin: 28
                                                verticalAlignment: TextInput.AlignVCenter
                                                echoMode: win.wifiShowPass ? TextInput.Normal : TextInput.Password
                                                color: Theme.text
                                                selectionColor: Theme.accent
                                                font.family: Theme.fontSans
                                                font.pixelSize: 12
                                                clip: true
                                                onVisibleChanged: {
                                                    if (visible) {
                                                        text = "";
                                                        forceActiveFocus();
                                                    }
                                                }
                                                Keys.onReturnPressed: {
                                                    if (text.length > 0) {
                                                        const p = text;
                                                        text = "";
                                                        win.runWifiAction(modelData.ssid, ["nmcli", "dev", "wifi", "connect", modelData.ssid, "password", p], "Connecting to " + modelData.ssid + "...");
                                                    }
                                                }
                                                Text {
                                                    anchors.fill: parent
                                                    verticalAlignment: Text.AlignVCenter
                                                    visible: wifiPassInput.text.length === 0
                                                    text: "Network password"
                                                    color: Theme.muted
                                                    font.family: Theme.fontSans
                                                    font.pixelSize: 11
                                                }
                                            }

                                            Text {
                                                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                                text: win.wifiShowPass ? "󰈈" : "󰈉"
                                                color: Theme.muted
                                                font.family: Theme.fontMono
                                                font.pixelSize: 14
                                                MouseArea {
                                                    anchors.fill: parent
                                                    anchors.margins: -4
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: win.wifiShowPass = !win.wifiShowPass
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 74
                                            Layout.preferredHeight: 34
                                            radius: 8
                                            color: wifiPassInput.text.length > 0 ? Theme.accent : Theme.glassBg
                                            border.width: 1; border.color: wifiPassInput.text.length > 0 ? Theme.accent : Theme.rim
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Connect"
                                                color: wifiPassInput.text.length > 0 ? Theme.accentFg : Theme.muted
                                                font.family: Theme.fontSans
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (wifiPassInput.text.length > 0) {
                                                        const p = wifiPassInput.text;
                                                        wifiPassInput.text = "";
                                                        win.runWifiAction(modelData.ssid, ["nmcli", "dev", "wifi", "connect", modelData.ssid, "password", p], "Connecting to " + modelData.ssid + "...");
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Disconnect / Forget buttons for active or saved networks
                                    RowLayout {
                                        visible: modelData.active || modelData.saved
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Rectangle {
                                            visible: modelData.active
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 30
                                            radius: 8
                                            color: Theme.glassBg
                                            border.width: 1; border.color: Theme.rim
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Disconnect"
                                                color: Theme.text
                                                font.family: Theme.fontSans
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: win.runWifiAction(modelData.ssid, ["nmcli", "connection", "down", modelData.ssid], "Disconnecting...")
                                            }
                                        }

                                        Rectangle {
                                            visible: modelData.saved
                                            Layout.preferredWidth: 84
                                            Layout.preferredHeight: 30
                                            radius: 8
                                            color: Theme.glassBg
                                            border.width: 1; border.color: Theme.rim
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Forget"
                                                color: Theme.crit
                                                font.family: Theme.fontSans
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: win.runWifiAction(modelData.ssid, ["nmcli", "connection", "delete", modelData.ssid], "Forgetting " + modelData.ssid + "...")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // BLUETOOTH SUB-PAGE
        ColumnLayout {
            visible: win.page === "bluetooth"
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: bBackHov.hovered ? Theme.elevatedBg : Theme.glassBg
                    border.width: 1; border.color: Theme.rim
                    Text { anchors.centerIn: parent; text: "←"; color: Theme.text; font.pixelSize: 14 }
                    HoverHandler { id: bBackHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (win.btAdapter && win.btAdapter.discovering) win.btAdapter.discovering = false;
                            win.openPage("main");
                        }
                    }
                }

                Text {
                    text: "Bluetooth"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: win.btOn && !!win.btAdapter
                    width: 28; height: 28; radius: 8
                    color: (win.btAdapter && win.btAdapter.discovering) ? Theme.accent : (bScanHov.hovered ? Theme.elevatedBg : Theme.glassBg)
                    border.width: 1; border.color: (win.btAdapter && win.btAdapter.discovering) ? Theme.accent : Theme.rim
                    Text {
                        anchors.centerIn: parent
                        text: "󰑓"
                        color: (win.btAdapter && win.btAdapter.discovering) ? Theme.accentFg : Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 15
                    }
                    HoverHandler { id: bScanHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (win.btAdapter) win.btAdapter.discovering = !win.btAdapter.discovering;
                        }
                    }
                }

                Rectangle {
                    width: 44; height: 24; radius: 12
                    color: win.btOn ? Theme.accent : Theme.glassBg
                    border.width: 1; border.color: win.btOn ? Theme.accent : Theme.rim
                    Text {
                        anchors.centerIn: parent
                        text: win.btOn ? "On" : "Off"
                        color: win.btOn ? Theme.accentFg : Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (win.btAdapter) win.btAdapter.enabled = !win.btAdapter.enabled;
                        }
                    }
                }
            }

            Item {
                visible: !win.btOn || win.btDevicesList().length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                Text {
                    anchors.centerIn: parent
                    text: !win.btOn ? "Bluetooth is off" : (win.btAdapter && win.btAdapter.discovering ? "Scanning nearby devices..." : "No devices found - tap scan")
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                }
            }

            Flickable {
                visible: win.btOn && win.btDevicesList().length > 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: btCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: btCol
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: win.btDevicesList()
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54
                            radius: 10
                            color: modelData.connected ? Theme.elevatedBg : Theme.glassBg
                            border.width: 1
                            border.color: modelData.connected ? Theme.accent : Theme.rim

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Text {
                                    text: win.btIconFor(modelData)
                                    color: modelData.connected ? Theme.accent : Theme.text
                                    font.family: Theme.fontMono
                                    font.pixelSize: 17
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name || modelData.deviceName || modelData.address
                                        color: Theme.text
                                        font.family: Theme.fontSans
                                        font.pixelSize: 12
                                        font.weight: modelData.connected ? Font.DemiBold : Font.Medium
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: modelData.pairing ? "Pairing..."
                                            : (modelData.connected
                                                ? (modelData.batteryAvailable ? "Connected · " + Math.round(modelData.battery * 100) + "%" : "Connected")
                                                : (modelData.paired ? "Paired" : "Available"))
                                        color: modelData.connected ? Theme.accent : Theme.muted
                                        font.family: Theme.fontSans
                                        font.pixelSize: 10
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 74
                                    Layout.preferredHeight: 28
                                    radius: 7
                                    color: modelData.connected ? Theme.glassBg : Theme.accent
                                    border.width: 1; border.color: modelData.connected ? Theme.rim : Theme.accent
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.connected ? "Disconnect" : (modelData.paired ? "Connect" : "Pair")
                                        color: modelData.connected ? Theme.text : Theme.accentFg
                                        font.family: Theme.fontSans
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.connected) {
                                                modelData.disconnect();
                                            } else if (modelData.paired) {
                                                modelData.connect();
                                            } else {
                                                modelData.trusted = true;
                                                modelData.pair();
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: modelData.paired
                                    width: 28; height: 28; radius: 7
                                    color: Theme.glassBg
                                    border.width: 1; border.color: Theme.rim
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰆴"
                                        color: Theme.crit
                                        font.family: Theme.fontMono
                                        font.pixelSize: 14
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: modelData.forget()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // AUDIO OUTPUT SUB-PAGE
        ColumnLayout {
            visible: win.page === "audio"
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: aBackHov.hovered ? Theme.elevatedBg : Theme.glassBg
                    border.width: 1; border.color: Theme.rim
                    Text { anchors.centerIn: parent; text: "←"; color: Theme.text; font.pixelSize: 14 }
                    HoverHandler { id: aBackHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.openPage("main") }
                }

                Text {
                    text: "Sound Output"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: sinkCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: sinkCol
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: win.audioSinks()
                        Rectangle {
                            required property var modelData
                            readonly property bool active: win.sink && modelData.id === win.sink.id
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: 10
                            color: active ? Theme.elevatedBg : (sinkHov.hovered ? Theme.elevatedBg : Theme.glassBg)
                            border.width: 1
                            border.color: active ? Theme.accent : Theme.rim

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Text {
                                    text: win.sinkIconFor(modelData)
                                    color: active ? Theme.accent : Theme.text
                                    font.family: Theme.fontMono
                                    font.pixelSize: 17
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.description || modelData.nickname || modelData.name
                                    color: Theme.text
                                    font.family: Theme.fontSans
                                    font.pixelSize: 12
                                    font.weight: active ? Font.DemiBold : Font.Medium
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    visible: active
                                    width: 8; height: 8; radius: 4
                                    color: Theme.accent
                                }
                            }

                            HoverHandler { id: sinkHov; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Pipewire.preferredDefaultAudioSink = modelData;
                                    Quickshell.execDetached(["wpctl", "set-default", String(modelData.id)]);
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 10
                color: Theme.glassBg
                border.width: 1; border.color: Theme.rim
                VolumeSliderRow {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    showOutputArrow: false
                }
            }
        }
    }

    Timer {
        id: refreshDelay
        interval: 900
        onTriggered: {
            refreshProc.running = true;
            if (win.page === "wifi") wifiListProc.running = true;
        }
    }
}
