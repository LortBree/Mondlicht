import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win
    required property var shell

    anchors {
        bottom: true
    }
    margins {
        bottom: 0
    }

    property bool activeHover: false
    readonly property bool revealed: activeHover || (win.shell.overviewOpen && win.screen === win.shell.targetScreen) || (win.screen === win.shell.ambientScreen)

    // Fixed window bounds + Region input mask eliminates Wayland resize pointer-leave flicker
    implicitWidth: Math.max(360, dockBox.implicitWidth + 24)
    implicitHeight: 84
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "obsidian-dock"

    mask: Region {
        item: win.revealed ? fullArea : edgeSensor
    }

    readonly property var pinnedSpecs: [
        { id: "kitty", label: "Kitty", icon: "kitty", cmd: ["kitty"] },
        { id: "brave-browser", label: "Brave", icon: "brave-desktop", cmd: ["brave"] },
        { id: "org.kde.dolphin", label: "Dolphin", icon: "org.kde.dolphin", cmd: ["dolphin"] },
        { id: "antigravity", label: "Antigravity", icon: "antigravity", cmd: ["antigravity"] }
    ]

    function findRunning(appId) {
        const list = ToplevelManager.toplevels.values;
        const needle = appId.toLowerCase();
        const matches = [];
        for (let i = 0; i < list.length; i++) {
            const id = (list[i].appId || "").toLowerCase();
            if (id === needle || id.includes(needle) || needle.includes(id)) {
                matches.push(list[i]);
            }
        }
        return matches;
    }

    function extraRunning() {
        const list = ToplevelManager.toplevels.values;
        const extras = [];
        const seen = {};
        for (let i = 0; i < list.length; i++) {
            const rawId = list[i].appId || "";
            const low = rawId.toLowerCase();
            if (!low) continue;
            let isPinned = false;
            for (let j = 0; j < pinnedSpecs.length; j++) {
                const p = pinnedSpecs[j].id.toLowerCase();
                if (low === p || low.includes(p) || p.includes(low)) { isPinned = true; break; }
            }
            if (!isPinned && !seen[low]) {
                seen[low] = true;
                extras.push(list[i]);
            }
        }
        return extras;
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
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
            }
            width: 340
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

        // GNOME Dash Obsidian Dock
        Rectangle {
            id: dockBox
            anchors {
                bottom: parent.bottom
                bottomMargin: 10
                horizontalCenter: parent.horizontalCenter
            }
            implicitWidth: dockRow.implicitWidth + 24
            implicitHeight: 66
            radius: 18
            color: Theme.voidBg
            border.width: 1
            border.color: Theme.rim
            opacity: win.revealed ? 1.0 : 0.0
            transform: Translate {
                y: win.revealed ? 0 : 82
                Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutExpo } }
            }
            Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on implicitWidth { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                height: 18
                radius: 17
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.sheen }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            RowLayout {
                id: dockRow
                anchors.centerIn: parent
                spacing: 8

                Repeater {
                    model: win.pinnedSpecs
                    Rectangle {
                        required property var modelData
                        readonly property var matches: win.findRunning(modelData.id)
                        readonly property bool isRunning: matches.length > 0
                        readonly property bool isActive: isRunning && matches.some(t => t.activated)

                        width: 50
                        height: 52
                        radius: 12
                        color: tileHover.hovered ? Theme.elevatedBg : (isActive ? "#19dce4f7" : "transparent")
                        border.width: tileHover.hovered ? 1 : 0
                        border.color: Theme.rim
                        Behavior on color { ColorAnimation { duration: 180 } }

                        Image {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -2
                            width: 36
                            height: 36
                            sourceSize: Qt.size(36, 36)
                            fillMode: Image.PreserveAspectFit
                            source: Quickshell.iconPath(modelData.icon, true)
                            smooth: true
                            scale: tileHover.hovered ? 1.10 : 1.0
                            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        }

                        Rectangle {
                            visible: isRunning
                            anchors { bottom: parent.bottom; bottomMargin: 3; horizontalCenter: parent.horizontalCenter }
                            width: isActive ? 12 : 5
                            height: 4
                            radius: 2
                            color: isActive ? Theme.accent : Theme.muted
                            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        }

                        HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (isRunning) {
                                    matches[0].activate();
                                } else {
                                    const entry = DesktopEntries.byId(modelData.id);
                                    if (entry) entry.execute();
                                    else Quickshell.execDetached(modelData.cmd);
                                }
                            }
                        }
                    }
                }

                Repeater {
                    model: win.extraRunning()
                    Rectangle {
                        required property var modelData
                        readonly property var entry: DesktopEntries.heuristicLookup(modelData.appId)

                        width: 50
                        height: 52
                        radius: 12
                        color: runHover.hovered ? Theme.elevatedBg : (modelData.activated ? "#19dce4f7" : "transparent")
                        border.width: runHover.hovered ? 1 : 0
                        border.color: Theme.rim
                        Behavior on color { ColorAnimation { duration: 180 } }

                        Image {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -2
                            width: 36
                            height: 36
                            sourceSize: Qt.size(36, 36)
                            fillMode: Image.PreserveAspectFit
                            source: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : Quickshell.iconPath("application-x-executable", true)
                            smooth: true
                            scale: runHover.hovered ? 1.10 : 1.0
                            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        }

                        Rectangle {
                            anchors { bottom: parent.bottom; bottomMargin: 3; horizontalCenter: parent.horizontalCenter }
                            width: modelData.activated ? 12 : 5
                            height: 4
                            radius: 2
                            color: modelData.activated ? Theme.accent : Theme.muted
                        }

                        HoverHandler { id: runHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.activate()
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: 32
                    color: Theme.rim
                }

                // Wallpaper switcher
                Rectangle {
                    width: 44
                    height: 48
                    radius: 12
                    color: win.shell.wallpaperOpen ? Theme.accent : (wallHover.hovered ? Theme.elevatedBg : "transparent")
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰸉"
                        color: win.shell.wallpaperOpen ? Theme.accentFg : Theme.secondary
                        font.family: Theme.fontMono
                        font.pixelSize: 22
                    }
                    HoverHandler { id: wallHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.shell.openOnly("wallpaper", win.screen)
                    }
                }

                // GNOME Show Applications
                Rectangle {
                    width: 44
                    height: 48
                    radius: 12
                    color: win.shell.launcherOpen ? Theme.accent : (gridHover.hovered ? Theme.elevatedBg : "transparent")
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰀻"
                        color: win.shell.launcherOpen ? Theme.accentFg : Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 22
                    }
                    HoverHandler { id: gridHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.shell.openOnly("launcher", win.screen)
                    }
                }
            }
        }
    }
}
