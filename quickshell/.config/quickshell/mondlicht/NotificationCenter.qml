import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    id: root
    required property var shell

    // 1. Floating Top-Right Toasts
    PanelWindow {
        id: toastWin
        anchors {
            top: true
            right: true
        }
        margins {
            top: 14
            right: 18
        }

        visible: root.shell.toastItems.length > 0 && !root.shell.notifOpen
        implicitWidth: 348
        implicitHeight: Math.max(10, toastCol.implicitHeight)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "obsidian-popover"

        ColumnLayout {
            id: toastCol
            width: parent.width
            spacing: 8

            Repeater {
                model: root.shell.toastItems
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: toastInner.implicitHeight + 20
                    radius: 12
                    color: Theme.voidBg
                    border.width: 1
                    border.color: Theme.rim

                    ColumnLayout {
                        id: toastInner
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: 12
                        }
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: modelData.appName || "Notification"
                                color: Theme.accent
                                font.family: Theme.fontSans
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "✕"
                                color: Theme.muted
                                font.pixelSize: 10
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.summary || ""
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: (modelData.body || "").length > 0
                            Layout.fillWidth: true
                            text: modelData.body || ""
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shell.removeToast(modelData)
                    }
                }
            }
        }
    }

    // 2. Notification Center Drawer (click outside to dismiss)
    PanelWindow {
        id: drawerWin

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        visible: root.shell.notifOpen || card.opacity > 0.01
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "obsidian-popover"
        WlrLayershell.keyboardFocus: root.shell.notifOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.shell.notifOpen = false
        }

        Rectangle {
            id: card
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 70
            }
            width: 364
            height: 470
            radius: 14
            color: Theme.voidBg
            border.width: 1
            border.color: Theme.rim
            opacity: root.shell.notifOpen ? 1.0 : 0.0

            transform: Translate {
                x: root.shell.notifOpen ? 0 : 54
                Behavior on x { NumberAnimation { duration: 360; easing.type: Easing.OutExpo } }
            }
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            Keys.onEscapePressed: root.shell.notifOpen = false

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

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Header: Title + DND + Clear All
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Notifications"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: dndTxt.implicitWidth + 16
                        implicitHeight: 26
                        radius: 8
                        color: root.shell.dndOn ? Theme.accent : Theme.glassBg
                        border.width: 1
                        border.color: root.shell.dndOn ? Theme.accent : Theme.rim
                        Text {
                            id: dndTxt
                            anchors.centerIn: parent
                            text: root.shell.dndOn ? "󰂛 DND" : "󰂜 DND"
                            color: root.shell.dndOn ? Theme.accentFg : Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shell.dndOn = !root.shell.dndOn
                        }
                    }

                    Rectangle {
                        visible: root.shell.notifModel.values.length > 0
                        implicitWidth: clrTxt.implicitWidth + 16
                        implicitHeight: 26
                        radius: 8
                        color: clrHov.hovered ? Theme.elevatedBg : Theme.glassBg
                        border.width: 1
                        border.color: Theme.rim
                        Text {
                            id: clrTxt
                            anchors.centerIn: parent
                            text: "Clear"
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: 11
                        }
                        HoverHandler { id: clrHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shell.clearNotifications()
                        }
                    }
                }

                // Empty state
                Item {
                    visible: root.shell.notifModel.values.length === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰂜"
                            color: Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 32
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "All caught up"
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: 12
                        }
                    }
                }

                // Notification History List
                ListView {
                    visible: root.shell.notifModel.values.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: root.shell.notifModel

                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        implicitHeight: nInner.implicitHeight + 20
                        radius: 10
                        color: Theme.glassBg
                        border.width: 1
                        border.color: Theme.rim

                        ColumnLayout {
                            id: nInner
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                margins: 10
                            }
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.appName || "App"
                                    color: Theme.accent
                                    font.family: Theme.fontSans
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                }
                                Rectangle {
                                    width: 20; height: 20; radius: 6
                                    color: dHov.hovered ? Theme.elevatedBg : "transparent"
                                    Text { anchors.centerIn: parent; text: "✕"; color: Theme.muted; font.pixelSize: 10 }
                                    HoverHandler { id: dHov; cursorShape: Qt.PointingHandCursor }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: modelData.dismiss()
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.summary || ""
                                color: Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                wrapMode: Text.Wrap
                            }

                            Text {
                                visible: (modelData.body || "").length > 0
                                Layout.fillWidth: true
                                text: modelData.body || ""
                                color: Theme.muted
                                font.family: Theme.fontSans
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
        }
    }
}
