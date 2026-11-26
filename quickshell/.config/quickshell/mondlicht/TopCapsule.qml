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
    readonly property bool hiddenByDrawer: win.shell.clockOpen
    readonly property bool revealed: !hiddenByDrawer && (activeHover || win.shell.desktopEmpty)

    // Fixed window bounds + Region mask prevents Wayland resize pointer-leave flicker
    implicitWidth: Math.max(220, pill.implicitWidth + 24)
    implicitHeight: 54
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "obsidian-shell"

    mask: Region {
        item: win.revealed ? fullArea : edgeSensor
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
            implicitWidth: row.implicitWidth + 36
            implicitHeight: 38
            radius: 19
            color: capHover.hovered ? Theme.elevatedBg : Theme.voidBg
            border.width: 1
            border.color: Theme.rim
            opacity: win.revealed ? 1.0 : 0.0

            transform: Translate {
                y: win.revealed ? 0 : -54
                Behavior on y { NumberAnimation { duration: 360; easing.type: Easing.OutExpo } }
            }
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

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

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 12

            Rectangle {
                visible: win.mediaPlaying
                width: 8
                height: 8
                radius: 4
                color: Theme.accent

                SequentialAnimation on opacity {
                    running: win.mediaPlaying
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            Text {
                text: win.timeText
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: 14
                font.weight: Font.Bold
                font.letterSpacing: 0.4
            }

            Rectangle {
                width: 1
                height: 14
                color: Theme.rim
            }

            Text {
                text: win.dateText
                color: "#b4bfd9"
                font.family: Theme.fontSans
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        HoverHandler {
            id: capHover
            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: win.shell.openOnly("clock")
        }
    }
    }
}
