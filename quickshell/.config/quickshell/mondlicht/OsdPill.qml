import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire

PanelWindow {
    id: win
    required property var shell

    anchors {
        bottom: true
    }
    margins {
        bottom: 96
    }

    property bool active: false
    property int brightPct: 80

    // Click-through non-intrusive OSD (never blocks mouse/keyboard focus)
    visible: win.active || pill.opacity > 0.01
    implicitWidth: 244
    implicitHeight: 50
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "obsidian-popover"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {}

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int volPct: sink && sink.audio ? Math.max(0, Math.min(100, Math.round(sink.audio.volume * 100))) : 0

    readonly property bool isBright: win.shell.osdKind === "brightness"
    readonly property int displayPct: isBright ? win.brightPct : win.volPct
    readonly property bool isMuted: !isBright && win.muted

    Process {
        id: brightProc
        command: ["sh", "-c", "brightnessctl -m 2>/dev/null | awk -F, '{gsub(/%/,\"\",$4); print $4}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const b = parseInt(text.trim(), 10);
                if (!isNaN(b)) win.brightPct = b;
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: win.active = false
    }

    Connections {
        target: win.shell
        function onOsdTokenChanged() {
            if (win.shell.osdKind === "brightness") {
                brightProc.running = true;
            }
            win.active = true;
            hideTimer.restart();
        }
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: 240
        height: 46
        radius: 14
        color: Theme.voidBg
        border.width: 1
        border.color: Theme.rim
        opacity: win.active ? 1.0 : 0.0

        transform: Translate {
            y: win.active ? 0 : 18
            Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutExpo } }
        }
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
            height: 14
            radius: 13
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.sheen }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            Text {
                text: win.isBright
                    ? (win.brightPct > 65 ? "󰃠" : (win.brightPct > 30 ? "󰃟" : "󰃞"))
                    : (win.isMuted ? "󰖁" : (win.volPct < 35 ? "󰕿" : (win.volPct < 70 ? "󰖀" : "󰕾")))
                color: win.isMuted ? Theme.muted : Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: 18
            }

            Item {
                Layout.fillWidth: true
                height: 6
                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: "#1c2233"
                }
                Rectangle {
                    width: win.isMuted ? 0 : Math.max(win.displayPct > 0 ? 6 : 0, parent.width * (win.displayPct / 100.0))
                    height: parent.height
                    radius: 3
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                }
            }

            Text {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                text: win.isMuted ? "Mute" : (win.displayPct + "%")
                color: win.isMuted ? Theme.muted : Theme.text
                font.family: Theme.fontSans
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
    }
}
