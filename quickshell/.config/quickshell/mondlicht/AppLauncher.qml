import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win
    required property var shell
    screen: win.shell.targetScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: win.shell.launcherOpen || card.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "obsidian-popover"
    WlrLayershell.keyboardFocus: win.shell.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property int selectedIndex: 0
    property var appResults: []

    function refreshResults() {
        const q = searchInput.text.trim().toLowerCase();
        const all = DesktopEntries.applications.values;
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const app = all[i];
            if (app.noDisplay) continue;
            if (!q || (app.name && app.name.toLowerCase().includes(q)) || (app.comment && app.comment.toLowerCase().includes(q))) {
                out.push(app);
            }
        }
        out.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
        win.appResults = out;
        win.selectedIndex = 0;
    }

    function launchSelected() {
        if (win.appResults.length > 0 && win.selectedIndex >= 0 && win.selectedIndex < win.appResults.length) {
            win.appResults[win.selectedIndex].execute();
            win.shell.launcherOpen = false;
        }
    }

    onVisibleChanged: {
        if (win.shell.launcherOpen) {
            searchInput.text = "";
            win.refreshResults();
            searchInput.forceActiveFocus();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.shell.launcherOpen = false
    }

    Rectangle {
        id: card
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 24
        }
        width: 680
        height: 460
        radius: 18
        color: Theme.voidBg
        border.width: 1
        border.color: Theme.rim
        opacity: win.shell.launcherOpen ? 1.0 : 0.0

        transform: Translate {
            y: win.shell.launcherOpen ? 0 : 110
            Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutExpo } }
        }
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: function(m) { m.accepted = true; }
        }

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
            height: 24
            radius: 17
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.sheen }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // Search bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 12
                color: Theme.glassBg
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.accent : Theme.rim

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        text: "󰍉"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 16
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: 14
                        selectByMouse: true
                        onTextChanged: win.refreshResults()
                        Keys.onEscapePressed: win.shell.launcherOpen = false
                        Keys.onReturnPressed: win.launchSelected()
                        Keys.onEnterPressed: win.launchSelected()
                        Keys.onRightPressed: if (win.selectedIndex + 1 < win.appResults.length) win.selectedIndex++
                        Keys.onLeftPressed: if (win.selectedIndex > 0) win.selectedIndex--
                        Keys.onDownPressed: if (win.selectedIndex + 4 < win.appResults.length) win.selectedIndex += 4
                        Keys.onUpPressed: if (win.selectedIndex - 4 >= 0) win.selectedIndex -= 4

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: searchInput.text.length === 0
                            text: "Search applications..."
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: 13
                        }
                    }
                }
            }

            // 4-column grid of apps with strictly constrained icon sizes
            GridView {
                id: appGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Math.floor(width / 4)
                cellHeight: 104
                model: win.appResults
                currentIndex: win.selectedIndex

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: appGrid.cellWidth
                    height: appGrid.cellHeight

                    readonly property bool isSel: index === win.selectedIndex

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: 12
                        clip: true
                        color: isSel ? Theme.elevatedBg : (itemHov.hovered ? Theme.glassBg : "transparent")
                        border.width: isSel || itemHov.hovered ? 1 : 0
                        border.color: isSel ? Theme.accent : Theme.rim
                        Behavior on color { ColorAnimation { duration: 120 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - 16
                            spacing: 8

                            Image {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                Layout.maximumWidth: 42
                                Layout.maximumHeight: 42
                                sourceSize: Qt.size(42, 42)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : Quickshell.iconPath("application-x-executable", true)
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.name || ""
                                color: isSel ? Theme.accent : Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: 11
                                font.weight: isSel ? Font.DemiBold : Font.Medium
                                elide: Text.ElideRight
                            }
                        }

                        HoverHandler { id: itemHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                modelData.execute();
                                win.shell.launcherOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
