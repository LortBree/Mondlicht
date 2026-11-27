import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris

PanelWindow {
    id: win
    required property var shell

    anchors {
        top: true
    }
    margins {
        top: 0
    }

    property bool activeHover: false
    readonly property bool hiddenByDrawer: win.shell.clockOpen && win.screen === win.shell.targetScreen
    readonly property bool revealed: !hiddenByDrawer && (activeHover || win.screen === win.shell.ambientScreen || (win.shell.recordingOn && win.screen === win.shell.focusedScreen))

    function fmtRec(sec) {
        const m = Math.floor(sec / 60);
        const s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    // Fixed Wayland layer-surface size eliminates buffer reallocation stutter during pill morphs
    implicitWidth: 420
    implicitHeight: 54
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "obsidian-shell"

    mask: Region {
        item: win.revealed ? pillHit : edgeSensor
    }

    property string timeText: Qt.formatDateTime(new Date(), "HH:mm")
    property string dateText: Qt.formatDateTime(new Date(), "ddd, d MMM")

    readonly property bool mediaPlaying: {
        const list = Mpris.players.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing) return true;
        }
        return false;
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            const now = new Date();
            win.timeText = Qt.formatDateTime(now, "HH:mm");
            win.dateText = Qt.formatDateTime(now, "ddd, d MMM");
        }
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
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            width: 220
            height: 6
        }

        Item {
            id: pillHit
            x: pill.x
            y: 0
            width: pill.width
            height: 50
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
            id: pill
            anchors {
                top: parent.top
                topMargin: 8
                horizontalCenter: parent.horizontalCenter
            }
            clip: true
            width: Math.max(180, contentRow.implicitWidth + 32)
            height: 38
            radius: 19
            color: capHover.hovered ? Theme.elevatedBg : Theme.voidBg
            border.width: 1
            border.color: win.shell.recordingOn ? Theme.crit : Theme.rim
            opacity: win.revealed ? 1.0 : 0.0

            transform: Translate {
                y: win.revealed ? 0 : -54
                Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 280; easing.type: Easing.OutCubic } }

            // Specular obsidian sheen along top edge
            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 1
                }
                height: 12
                radius: 18
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.sheen }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            HoverHandler {
                id: capHover
                cursorShape: Qt.PointingHandCursor
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: win.shell.openOnly("clock", win.screen)
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: 0

                // Slot 1: Animated Dynamic-Island REC badge (gap baked into animated width)
                Item {
                    id: recSlot
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    height: 24
                    width: win.shell.recordingOn ? (recBadge.width + 10) : 0
                    visible: width > 0.5
                    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutExpo } }

                    Rectangle {
                        id: recBadge
                        anchors.verticalCenter: parent.verticalCenter
                        x: 0
                        width: recRow.implicitWidth + 16
                        height: 24
                        radius: 12
                        color: recBadgeHov.hovered ? "#4de07a8e" : "#29e07a8e"
                        border.width: 1
                        border.color: Theme.crit
                        opacity: win.shell.recordingOn ? 1.0 : 0.0
                        scale: win.shell.recordingOn ? 1.0 : 0.88
                        transformOrigin: Item.Left

                        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutExpo } }
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Row {
                            id: recRow
                            anchors.centerIn: parent
                            spacing: 6

                            Item {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12
                                height: 12

                                Rectangle {
                                    id: pulseRing
                                    anchors.centerIn: parent
                                    width: 7
                                    height: 7
                                    radius: 4
                                    color: "transparent"
                                    border.width: 1.5
                                    border.color: Theme.crit
                                    opacity: 0.0
                                    scale: 0.7

                                    ParallelAnimation {
                                        running: win.revealed && win.shell.recordingOn
                                        loops: Animation.Infinite
                                        NumberAnimation { target: pulseRing; property: "scale"; from: 0.7; to: 1.9; duration: 1400; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: pulseRing; property: "opacity"; from: 0.65; to: 0.0; duration: 1400; easing.type: Easing.OutCubic }
                                    }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: Theme.crit
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "REC " + win.fmtRec(win.shell.recordingSecs)
                                color: Theme.crit
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                        }

                        HoverHandler { id: recBadgeHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/screen-record", "stop"])
                        }
                    }
                }

                // Slot 2: Animated media playing indicator
                Item {
                    id: mediaSlot
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    height: 14
                    width: win.mediaPlaying ? 18 : 0
                    visible: width > 0.5
                    Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutExpo } }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 0
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.accent
                        opacity: win.mediaPlaying ? 1.0 : 0.0
                        scale: win.mediaPlaying ? 1.0 : 0.6

                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }

                        SequentialAnimation on opacity {
                            running: win.revealed && win.mediaPlaying
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 950; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 950; easing.type: Easing.InOutSine }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.timeText
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    font.letterSpacing: 0.4
                }

                Item { width: 12; height: 1 }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 14
                    color: Theme.rim
                }

                Item { width: 12; height: 1 }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.dateText
                    color: "#b4bfd9"
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }
    }
}
