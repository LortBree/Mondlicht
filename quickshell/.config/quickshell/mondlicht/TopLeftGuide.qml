import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: win
    required property var shell
    screen: win.shell.targetScreen

    // Fullscreen transparent click-outside catcher (no persistent top-left hover intercept)
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: win.shell.guideOpen || card.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "obsidian-popover"
    WlrLayershell.keyboardFocus: win.shell.guideOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property int page: 0
    property var allPackages: []

    readonly property var shortcutsModel: [
        { keys: "Cmd + /", desc: "Shortcuts & Installed Packages Guide" },
        { keys: "Cmd + Space", desc: "Slide-up App Launcher" },
        { keys: "Cmd + R", desc: "Quick App Runner (Fuzzel)" },
        { keys: "Cmd + Tab / Alt + Tab", desc: "Window Switcher (+ Shift reverse)" },
        { keys: "3-Finger ↑ (1x / 2x)", desc: "Overview -> App Launcher (touchpad)" },
        { keys: "3-Finger ↓", desc: "Step back / close Overview (touchpad)" },
        { keys: "Ctrl + ← / →", desc: "Prev / Next Desktop (or 3-finger ←/→)" },
        { keys: "Ctrl + Shift + ← / →", desc: "Move window to Prev / Next Desktop" },
        { keys: "Cmd + 1..9", desc: "Switch to Desktop 1..9" },
        { keys: "Cmd + Shift + 1..9", desc: "Move window to Desktop 1..9" },
        { keys: "Cmd + S", desc: "Show / Hide Scratchpad overlay" },
        { keys: "Cmd + Shift + S", desc: "Stash / Pull window to/from Scratchpad" },
        { keys: "Cmd + ← / → / ↑ / ↓", desc: "Focus window by direction" },
        { keys: "Cmd + Shift + ←/→/↑/↓", desc: "Move / swap window position" },
        { keys: "Cmd + Alt + ←/→/↑/↓", desc: "Resize active window" },
        { keys: "Cmd + Drag / R-Drag", desc: "Move / Resize floating or tiled window" },
        { keys: "Cmd + Q", desc: "Close active window" },
        { keys: "Cmd + F / Shift + F", desc: "Fullscreen / Maximize window" },
        { keys: "Cmd + Shift + Space", desc: "Toggle Floating window" },
        { keys: "Cmd + J / Cmd + P", desc: "Toggle split / Pseudotile window" },
        { keys: "Cmd + Enter", desc: "Open Terminal (Kitty)" },
        { keys: "Cmd + E", desc: "Open File Manager (Dolphin)" },
        { keys: "Cmd + A", desc: "Win11 Quick Settings (Wi-Fi/BT/Audio)" },
        { keys: "Cmd + ,", desc: "Open Mondlicht Settings App" },
        { keys: "Cmd + T", desc: "Clock, Calendar, Media & Quick Notes" },
        { keys: "Cmd + N", desc: "Notification Center" },
        { keys: "Cmd + Shift + W", desc: "Wallpaper Preview Switcher" },
        { keys: "Cmd + Shift + V", desc: "Clipboard History" },
        { keys: "Cmd + Shift + 4 / 3", desc: "Screenshot Region / Fullscreen" },
        { keys: "Cmd + Shift + 5 / 6", desc: "Record Screen Region / Full (toggle)" },
        { keys: "Cmd + B", desc: "Toggle Night Light (4200K)" },
        { keys: "Cmd + Ctrl + Q / Cmd + L", desc: "Lock Screen (Hyprlock)" },
        { keys: "Cmd + Esc / Cmd + M", desc: "Power Menu / Logout" }
    ]

    function filteredPackages() {
        const q = pkgFilter.text.trim().toLowerCase();
        if (!q) return allPackages;
        return allPackages.filter(p => p.name.toLowerCase().includes(q));
    }

    Process {
        id: pkgProc
        command: ["pacman", "-Qe"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const list = [];
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].trim().split(/\s+/);
                    if (parts.length >= 2) {
                        list.push({ name: parts[0], version: parts[1] });
                    }
                }
                win.allPackages = list;
            }
        }
    }

    Connections {
        target: win.shell
        function onGuideOpenChanged() {
            if (win.shell.guideOpen) {
                pkgFilter.text = "";
                if (win.allPackages.length === 0) pkgProc.running = true;
                card.forceActiveFocus();
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.shell.guideOpen = false
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 480
        height: 520
        radius: 14
        color: Theme.voidBg
        border.width: 1
        border.color: Theme.rim
        opacity: win.shell.guideOpen ? 1.0 : 0.0
        scale: win.shell.guideOpen ? 1.0 : 0.94

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }

        Keys.onEscapePressed: win.shell.guideOpen = false

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
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    implicitWidth: t1.implicitWidth + 18
                    implicitHeight: 28
                    radius: 8
                    color: win.page === 0 ? Theme.accent : Theme.glassBg
                    border.width: 1
                    border.color: win.page === 0 ? Theme.accent : Theme.rim
                    Text {
                        id: t1
                        anchors.centerIn: parent
                        text: "Shortcuts"
                        color: win.page === 0 ? Theme.accentFg : Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.page = 0 }
                }

                Rectangle {
                    implicitWidth: t2.implicitWidth + 18
                    implicitHeight: 28
                    radius: 8
                    color: win.page === 1 ? Theme.accent : Theme.glassBg
                    border.width: 1
                    border.color: win.page === 1 ? Theme.accent : Theme.rim
                    Text {
                        id: t2
                        anchors.centerIn: parent
                        text: "Packages (" + win.allPackages.length + ")"
                        color: win.page === 1 ? Theme.accentFg : Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.page = 1;
                            pkgFilter.forceActiveFocus();
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: (win.page + 1) + " / 2"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: 11
                }
            }

            // PAGE 1: macOS Shortcuts & Gestures
            ListView {
                visible: win.page === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: win.shortcutsModel

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 34
                    radius: 8
                    color: Theme.glassBg
                    border.width: 1
                    border.color: Theme.rim

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Rectangle {
                            implicitWidth: keyTxt.implicitWidth + 12
                            implicitHeight: 22
                            radius: 5
                            color: Theme.elevatedBg
                            border.width: 1
                            border.color: Theme.rim
                            Text {
                                id: keyTxt
                                anchors.centerIn: parent
                                text: modelData.keys
                                color: Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.desc
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // PAGE 2: Installed Explicit Packages (pacman -Qe)
            ColumnLayout {
                visible: win.page === 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 8
                    color: Theme.glassBg
                    border.width: 1
                    border.color: pkgFilter.activeFocus ? Theme.accent : Theme.rim

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text { text: "󰍉"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 13 }
                        TextInput {
                            id: pkgFilter
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: 12
                            selectByMouse: true
                            Keys.onEscapePressed: function(e) {
                                if (pkgFilter.text.length > 0) pkgFilter.text = "";
                                else win.shell.guideOpen = false;
                                e.accepted = true;
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: pkgFilter.text.length === 0
                                text: "Filter packages..."
                                color: Theme.muted
                                font.family: Theme.fontSans
                                font.pixelSize: 11
                            }
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: win.filteredPackages()

                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 28
                        radius: 6
                        color: Theme.glassBg
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.version
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }
}
