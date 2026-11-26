import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win
    required property var shell

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: win.shell.powerOpen || card.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "obsidian-popover"
    WlrLayershell.keyboardFocus: win.shell.powerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property int selectedIndex: 0

    readonly property var actions: [
        { label: "Lock",     key: "L", icon: "󰌾", danger: false, cmd: ["hyprlock"] },
        { label: "Suspend",  key: "S", icon: "󰤄", danger: false, cmd: ["systemctl", "suspend"] },
        { label: "Logout",   key: "E", icon: "󰍃", danger: false, cmd: ["sh", "-c", "uwsm stop || hyprctl dispatch 'hl.dsp.exit()'"] },
        { label: "Reboot",   key: "R", icon: "󰜉", danger: true,  cmd: ["systemctl", "reboot"] },
        { label: "Shutdown", key: "P", icon: "󰐥", danger: true,  cmd: ["systemctl", "poweroff"] }
    ]

    function triggerAction(idx) {
        if (idx >= 0 && idx < actions.length) {
            win.shell.powerOpen = false;
            Quickshell.execDetached(actions[idx].cmd);
        }
    }

    onVisibleChanged: {
        if (win.shell.powerOpen) {
            win.selectedIndex = 0;
            card.forceActiveFocus();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.shell.powerOpen = false
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 580
        height: 184
        radius: 20
        color: Theme.voidBg
        border.width: 1
        border.color: Theme.rim
        opacity: win.shell.powerOpen ? 1.0 : 0.0
        scale: win.shell.powerOpen ? 1.0 : 0.92

        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutExpo } }

        Keys.onEscapePressed: win.shell.powerOpen = false
        Keys.onLeftPressed: win.selectedIndex = (win.selectedIndex - 1 + actions.length) % actions.length
        Keys.onRightPressed: win.selectedIndex = (win.selectedIndex + 1) % actions.length
        Keys.onReturnPressed: win.triggerAction(win.selectedIndex)
        Keys.onEnterPressed: win.triggerAction(win.selectedIndex)
        Keys.onPressed: function(e) {
            const k = e.text.toUpperCase();
            for (let i = 0; i < actions.length; i++) {
                if (actions[i].key === k) {
                    win.triggerAction(i);
                    break;
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: function(m) { m.accepted = true; }
        }

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
            height: 24
            radius: 19
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.sheen }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Power"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
                Text {
                    text: "←/→ select · Enter confirm · Esc cancel"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: 11
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                Repeater {
                    model: win.actions
                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool active: itemHover.hovered || index === win.selectedIndex

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: active ? Theme.elevatedBg : Theme.glassBg
                        border.width: 1
                        border.color: active ? (modelData.danger ? Theme.crit : Theme.accent) : Theme.rim
                        Behavior on color { ColorAnimation { duration: 140 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.icon
                                color: active ? (modelData.danger ? Theme.crit : Theme.accent) : Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: 28
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.label
                                color: Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 20
                                height: 16
                                radius: 4
                                color: "#181d2c"
                                border.width: 1
                                border.color: Theme.rim
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    color: Theme.muted
                                    font.family: Theme.fontMono
                                    font.pixelSize: 9
                                }
                            }
                        }

                        HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.triggerAction(index)
                        }
                    }
                }
            }
        }
    }
}
