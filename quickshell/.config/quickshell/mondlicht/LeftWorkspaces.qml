import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: win
    required property var shell

    anchors {
        left: true
    }
    margins {
        left: 0
    }

    property bool activeHover: false
    readonly property bool revealed: activeHover || (win.shell.overviewOpen && win.screen === win.shell.targetScreen)

    // Fixed window dimensions + Region mask prevents pointer-leave resize flicker
    implicitWidth: 64
    implicitHeight: Math.max(280, rail.implicitHeight + 24)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "obsidian-shell"

    mask: Region {
        item: win.revealed ? fullArea : edgeSensor
    }

    function normalWorkspaces() {
        return Hyprland.workspaces.values
            .filter(ws => ws.id > 0)
            .sort((a, b) => a.id - b.id);
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
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            width: 6
            height: 240
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
                left: parent.left
                leftMargin: 10
                verticalCenter: parent.verticalCenter
            }
            implicitWidth: 44
            implicitHeight: col.implicitHeight + 20
            radius: 22
            color: Theme.voidBg
            border.width: 1
            border.color: Theme.rim
            opacity: win.revealed ? 1.0 : 0.0

            transform: Translate {
                x: win.revealed ? 0 : -60
                Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutExpo } }
            }
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: col
                anchors.centerIn: parent
                spacing: 10

                // GNOME Activities button
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 30
                    height: 30
                    radius: 15
                    color: win.shell.overviewOpen ? Theme.accent : (actHover.hovered ? Theme.elevatedBg : "transparent")
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰀻"
                        color: win.shell.overviewOpen ? Theme.accentFg : Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 16
                    }

                    HoverHandler { id: actHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.shell.openOnly("overview", win.screen)
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 20
                    height: 1
                    color: Theme.rim
                }

                Repeater {
                    model: win.normalWorkspaces()

                    Rectangle {
                        required property var modelData
                        readonly property bool isFocused: modelData.focused
                        Layout.alignment: Qt.AlignHCenter
                        width: 28
                        implicitHeight: isFocused ? 34 : 24
                        radius: 12
                        color: isFocused ? Theme.accent : (wsHover.hovered ? Theme.elevatedBg : "#1a2030")
                        border.width: isFocused ? 0 : 1
                        border.color: Theme.rim

                        Behavior on implicitHeight { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.id
                            color: isFocused ? Theme.accentFg : Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: 12
                            font.weight: isFocused ? Font.Bold : Font.Medium
                        }

                        HoverHandler { id: wsHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch('hl.dsp.focus({ workspace = ' + modelData.id + ' })')
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 28
                    height: 28
                    radius: 14
                    color: addHover.hovered ? Theme.elevatedBg : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: 16
                    }

                    HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch('hl.dsp.focus({ workspace = "empty" })')
                    }
                }
            }

            WheelHandler {
                onWheel: function(event) {
                    if (event.angleDelta.y > 0) Hyprland.dispatch('hl.dsp.focus({ workspace = "e-1" })');
                    else if (event.angleDelta.y < 0) Hyprland.dispatch('hl.dsp.focus({ workspace = "e+1" })');
                }
            }
        }
    }
}
