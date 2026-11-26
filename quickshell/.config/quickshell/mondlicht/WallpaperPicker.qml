import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

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

    visible: win.shell.wallpaperOpen || card.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "obsidian-popover"
    WlrLayershell.keyboardFocus: win.shell.wallpaperOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var wallpapers: []
    property string currentWall: ""

    FileView {
        id: cacheFile
        path: Quickshell.env("HOME") + "/.cache/current-wallpaper"
        onLoaded: win.currentWall = text().trim()
    }

    Process {
        id: listProc
        command: ["find", Quickshell.env("HOME") + "/Pictures/Wallpapers", "-maxdepth", "2", "-type", "f", "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(s => s.length > 0).sort();
                win.wallpapers = lines;
            }
        }
    }

    onVisibleChanged: {
        if (win.shell.wallpaperOpen) {
            cacheFile.reload();
            listProc.running = true;
            card.forceActiveFocus();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.shell.wallpaperOpen = false
    }

    Rectangle {
        id: card
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 24
        }
        width: 780
        height: 292
        radius: 18
        color: Theme.voidBg
        border.width: 1
        border.color: Theme.rim
        opacity: win.shell.wallpaperOpen ? 1.0 : 0.0

        transform: Translate {
            y: win.shell.wallpaperOpen ? 0 : 110
            Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutExpo } }
        }
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: win.shell.wallpaperOpen = false

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
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Wallpapers & Dynamic Accent"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
                Text {
                    text: win.wallpapers.length + " in ~/Pictures/Wallpapers"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: 11
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: ListView.Horizontal
                spacing: 14
                clip: true
                model: win.wallpapers

                delegate: Rectangle {
                    required property string modelData
                    readonly property bool isCurrent: modelData === win.currentWall
                    readonly property string baseName: modelData.split("/").pop()

                    width: 232
                    height: ListView.view.height
                    radius: 12
                    color: Theme.glassBg
                    border.width: isCurrent || itemHov.hovered ? 2 : 1
                    border.color: isCurrent ? Theme.accent : (itemHov.hovered ? Theme.secondary : Theme.rim)
                    clip: true

                    Image {
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            bottom: labelRow.top
                            margins: 6
                        }
                        source: "file://" + modelData
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 360
                        asynchronous: true
                        smooth: true
                        scale: itemHov.hovered ? 1.04 : 1.0
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }

                    RowLayout {
                        id: labelRow
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                            margins: 8
                        }
                        height: 24
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: baseName
                            color: isCurrent ? Theme.accent : Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: 11
                            font.weight: isCurrent ? Font.DemiBold : Font.Medium
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            visible: isCurrent
                            implicitWidth: actTxt.implicitWidth + 10
                            implicitHeight: 18
                            radius: 9
                            color: Theme.accent
                            Text {
                                id: actTxt
                                anchors.centerIn: parent
                                text: "Active"
                                color: Theme.accentFg
                                font.family: Theme.fontSans
                                font.pixelSize: 9
                                font.weight: Font.Bold
                            }
                        }
                    }

                    HoverHandler { id: itemHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.shell.wallpaperOpen = false;
                            Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/set-wall", modelData]);
                        }
                    }
                }
            }
        }
    }
}
