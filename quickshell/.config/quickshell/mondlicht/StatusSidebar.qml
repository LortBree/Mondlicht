import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray

PanelWindow {
    id: win
    required property var shell

    anchors {
        right: true
    }
    margins {
        right: 0
    }

    property bool activeHover: false
    readonly property bool revealed: activeHover || ((win.shell.quickSettingsOpen || win.shell.notifOpen || win.shell.overviewOpen) && win.screen === win.shell.targetScreen)

    // Fixed window bounds + un-animated Region mask eliminates resize buffer churn
    implicitWidth: 68
    implicitHeight: 460
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "obsidian-shell"

    mask: Region {
        item: win.revealed ? railHit : edgeSensor
    }

    property bool wifiEnabled: true
    property bool btPowered: true

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int volPct: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property int batPct: UPower.displayDevice && UPower.displayDevice.ready ? Math.round(UPower.displayDevice.percentage * 100) : -1
    readonly property bool batCharging: UPower.displayDevice && UPower.displayDevice.state === UPowerDeviceState.Charging

    function filteredTray() {
        return SystemTray.items.values.filter(item => {
            const id = ((item.id || "") + " " + (item.title || "")).toLowerCase();
            return !id.includes("nm-applet") && !id.includes("networkmanager") && !id.includes("blueman");
        });
    }

    Process {
        id: stateProc
        command: ["sh", "-c", "printf '%s|%s\n' \"$(nmcli radio wifi 2>/dev/null || echo enabled)\" \"$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2; exit}')\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|");
                win.wifiEnabled = (parts[0] === "enabled");
                win.btPowered = (parts[1] === "yes");
            }
        }
    }

    Timer {
        interval: 15000
        running: win.revealed
        repeat: true
        triggeredOnStart: true
        onTriggered: stateProc.running = true
    }

    onRevealedChanged: {
        if (revealed) stateProc.running = true;
    }

    Timer {
        id: hideTimer
        interval: 450
        onTriggered: win.activeHover = false
    }

    Item {
        id: fullArea
        anchors.fill: parent

        Item {
            id: edgeSensor
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            width: 6
            height: 260
        }

        Item {
            id: railHit
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            width: 68
            height: Math.max(160, col.implicitHeight + 36)
        }

        HoverHandler {
            id: rootHover
            onHoveredChanged: {
                if (hovered) {
                    hideTimer.stop();
                    win.activeHover = true;
                } else {
                    hideTimer.restart();
                }
            }
        }

        Rectangle {
            id: rail
            anchors {
                right: parent.right
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            implicitWidth: 50
            implicitHeight: col.implicitHeight + 22
            radius: 25
            color: Theme.voidBg
            border.width: 1
            border.color: win.shell.quickSettingsOpen || win.shell.notifOpen ? Theme.accent : Theme.rim
            opacity: win.revealed ? 1.0 : 0.0

            transform: Translate {
                x: win.revealed ? 0 : 62
                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: col
                anchors.centerIn: parent
                spacing: 10

                // Windows-ordered status cluster (Wi-Fi, BT, Volume, Battery)
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 38
                    implicitHeight: winCluster.implicitHeight + 14
                    radius: 14
                    color: clusterHover.hovered || win.shell.quickSettingsOpen ? Theme.elevatedBg : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }

                    ColumnLayout {
                        id: winCluster
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: win.wifiEnabled ? "󰖩" : "󰖪"
                            color: win.wifiEnabled ? Theme.text : Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 19
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: win.btPowered ? "󰂯" : "󰂲"
                            color: win.btPowered ? Theme.text : Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 19
                        }

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            width: 30
                            height: 24
                            Text {
                                anchors.centerIn: parent
                                text: win.muted ? "󰖁" : (win.volPct < 35 ? "󰕿" : (win.volPct < 70 ? "󰖀" : "󰕾"))
                                color: win.muted ? Theme.muted : Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: 19
                            }
                            WheelHandler {
                                onWheel: function(event) {
                                    const delta = event.angleDelta.y > 0 ? "5%+" : "5%-";
                                    Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", delta]);
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            visible: win.batPct >= 0
                            spacing: 2
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: win.batCharging ? "󰂄" : (win.batPct > 80 ? "󰁹" : (win.batPct > 50 ? "󰂀" : (win.batPct > 25 ? "󰁾" : "󰁺")))
                                color: win.batPct <= 15 && !win.batCharging ? Theme.crit : (win.batPct <= 25 && !win.batCharging ? Theme.warn : Theme.text)
                                font.family: Theme.fontMono
                                font.pixelSize: 19
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: win.batPct + "%"
                                color: Theme.muted
                                font.family: Theme.fontSans
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    HoverHandler { id: clusterHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.shell.openOnly("quickSettings", win.screen)
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 22
                    height: 1
                    color: Theme.rim
                }

                // Native Notification Center bell
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 34
                    height: 34
                    radius: 12
                    color: win.shell.notifOpen ? Theme.elevatedBg : (bellHover.hovered ? Theme.elevatedBg : "transparent")
                    Text {
                        anchors.centerIn: parent
                        text: win.shell.dndOn ? "󰂛" : "󰂜"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 19
                    }
                    Rectangle {
                        visible: win.shell.notifModel.values.length > 0 && !win.shell.dndOn
                        anchors { top: parent.top; right: parent.right; margins: 6 }
                        width: 7; height: 7; radius: 4
                        color: Theme.secondary
                    }
                    HoverHandler { id: bellHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.shell.openOnly("notif", win.screen)
                    }
                }

                // Filtered System Tray (excluding duplicate network/bluetooth applets)
                Rectangle {
                    visible: win.filteredTray().length > 0
                    Layout.alignment: Qt.AlignHCenter
                    width: 22
                    height: 1
                    color: Theme.rim
                }

                Repeater {
                    model: win.filteredTray()
                    Item {
                        required property var modelData
                        Layout.alignment: Qt.AlignHCenter
                        width: 24
                        height: 24
                        Image {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            sourceSize: Qt.size(18, 18)
                            fillMode: Image.PreserveAspectFit
                            source: modelData.icon
                            smooth: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) modelData.secondaryActivate();
                                else modelData.activate();
                            }
                        }
                    }
                }
            }
        }
    }
}
