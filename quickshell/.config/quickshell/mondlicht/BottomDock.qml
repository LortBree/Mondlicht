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
    property bool ctxOpen: false
    property string ctxLabel: ""
    property var ctxToplevel: null
    property var ctxCmd: null
    property string ctxDesktopId: ""
    property real ctxCenterX: 0

    property string hoverText: ""
    property real hoverCenterX: 0

    readonly property bool revealed: activeHover || ctxOpen || (win.shell.overviewOpen && win.screen === win.shell.targetScreen) || (win.screen === win.shell.ambientScreen)

    // Fixed Wayland layer-surface size + un-animated Region mask eliminates resize buffer stutter
    implicitWidth: win.screen ? Math.min(win.screen.width, 960) : 960
    implicitHeight: 184
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "obsidian-dock"

    mask: Region {
        item: win.ctxOpen ? fullArea : (win.revealed ? dockHoverArea : edgeSensor)
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

    function openContextMenu(tileItem, label, toplevel, desktopId, cmd) {
        win.ctxLabel = label || "Window";
        win.ctxToplevel = toplevel || null;
        win.ctxDesktopId = desktopId || "";
        win.ctxCmd = cmd || null;
        win.ctxCenterX = tileItem.mapToItem(fullArea, tileItem.width / 2, 0).x;
        win.ctxOpen = true;
        win.hoverText = "";
    }

    function launchNewInstance(desktopId, cmd) {
        if (desktopId) {
            const entry = DesktopEntries.byId(desktopId) || DesktopEntries.heuristicLookup(desktopId);
            if (entry) { entry.execute(); return; }
        }
        if (cmd) Quickshell.execDetached(cmd);
    }

    Timer {
        id: hideTimer
        interval: 450
        onTriggered: {
            if (!win.ctxOpen && !rootHover.hovered && win.hoverText.length === 0) win.activeHover = false;
        }
    }

    Item {
        id: fullArea
        anchors.fill: parent

        HoverHandler {
            id: rootHover
            onHoveredChanged: {
                if (hovered) {
                    hideTimer.stop();
                    win.activeHover = true;
                } else {
                    win.hoverText = "";
                    hideTimer.restart();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            visible: win.ctxOpen
            onClicked: win.ctxOpen = false
        }

        Item {
            id: edgeSensor
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
            }
            width: Math.max(360, dockRow.implicitWidth + 48)
            height: 6
        }

        Item {
            id: dockHoverArea
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
            }
            width: Math.max(360, dockRow.implicitWidth + 48)
            height: 82
        }

        // Hover Tooltip Pill
        Rectangle {
            id: tooltipPill
            visible: opacity > 0.01
            opacity: (win.revealed && win.hoverText.length > 0 && !win.ctxOpen) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 140 } }

            anchors {
                bottom: dockBox.top
                bottomMargin: 8
            }
            x: Math.max(8, Math.min(fullArea.width - width - 8, win.hoverCenterX - width / 2))
            width: tipTxt.implicitWidth + 18
            height: 26
            radius: 8
            color: Theme.voidBg
            border.width: 1
            border.color: Theme.rim

            Text {
                id: tipTxt
                anchors.centerIn: parent
                text: win.hoverText
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        // Right-Click Context Menu
        Rectangle {
            id: ctxMenu
            visible: win.ctxOpen
            anchors {
                bottom: dockBox.top
                bottomMargin: 10
            }
            x: Math.max(8, Math.min(fullArea.width - width - 8, win.ctxCenterX - width / 2))
            width: 156
            height: ctxCol.implicitHeight + 12
            radius: 12
            color: Theme.voidBg
            border.width: 1
            border.color: Theme.rim

            MouseArea {
                anchors.fill: parent
                onClicked: function(m) { m.accepted = true; }
            }

            ColumnLayout {
                id: ctxCol
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: 6
                }
                spacing: 3

                Text {
                    text: win.ctxLabel
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.bottomMargin: 2
                }

                Rectangle {
                    visible: win.ctxToplevel !== null
                    Layout.fillWidth: true
                    height: 28
                    radius: 7
                    color: fHov.hovered ? Theme.elevatedBg : "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 8
                        Text { text: "󰖯"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 13 }
                        Text { text: "Focus Window"; color: Theme.text; font.family: Theme.fontSans; font.pixelSize: 11; Layout.fillWidth: true }
                    }
                    HoverHandler { id: fHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (win.ctxToplevel) win.ctxToplevel.activate();
                            win.ctxOpen = false;
                            win.ctxToplevel = null;
                        }
                    }
                }

                Rectangle {
                    visible: win.ctxDesktopId.length > 0 || win.ctxCmd !== null
                    Layout.fillWidth: true
                    height: 28
                    radius: 7
                    color: nwHov.hovered ? Theme.elevatedBg : "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 8
                        Text { text: "󰐕"; color: Theme.ok; font.family: Theme.fontMono; font.pixelSize: 13 }
                        Text { text: "New Window"; color: Theme.text; font.family: Theme.fontSans; font.pixelSize: 11; Layout.fillWidth: true }
                    }
                    HoverHandler { id: nwHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.launchNewInstance(win.ctxDesktopId, win.ctxCmd);
                            win.ctxOpen = false;
                            win.ctxToplevel = null;
                        }
                    }
                }

                Rectangle {
                    visible: win.ctxToplevel !== null
                    Layout.fillWidth: true
                    height: 28
                    radius: 7
                    color: clHov.hovered ? Theme.crit : "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 8
                        Text { text: "󰅖"; color: clHov.hovered ? Theme.accentFg : Theme.crit; font.family: Theme.fontMono; font.pixelSize: 13 }
                        Text { text: "Close Window"; color: clHov.hovered ? Theme.accentFg : Theme.crit; font.family: Theme.fontSans; font.pixelSize: 11; Layout.fillWidth: true }
                    }
                    HoverHandler { id: clHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (win.ctxToplevel) win.ctxToplevel.close();
                            win.ctxOpen = false;
                            win.ctxToplevel = null;
                        }
                    }
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
                        id: pinnedTile
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

                        HoverHandler {
                            id: tileHover
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (hovered) {
                                    win.hoverText = modelData.label;
                                    win.hoverCenterX = pinnedTile.mapToItem(fullArea, pinnedTile.width / 2, 0).x;
                                } else if (win.hoverText === modelData.label) {
                                    win.hoverText = "";
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    win.openContextMenu(pinnedTile, modelData.label, isRunning ? matches[0] : null, modelData.id, modelData.cmd);
                                    return;
                                }
                                win.ctxOpen = false;
                                if (isRunning) {
                                    matches[0].activate();
                                } else {
                                    win.launchNewInstance(modelData.id, modelData.cmd);
                                }
                            }
                        }
                    }
                }

                Repeater {
                    model: win.extraRunning()
                    Rectangle {
                        id: extraTile
                        required property var modelData
                        readonly property var entry: DesktopEntries.heuristicLookup(modelData.appId)
                        readonly property string appLabel: (entry && entry.name) ? entry.name : (modelData.appId || "App")

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

                        HoverHandler {
                            id: runHover
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (hovered) {
                                    win.hoverText = extraTile.appLabel;
                                    win.hoverCenterX = extraTile.mapToItem(fullArea, extraTile.width / 2, 0).x;
                                } else if (win.hoverText === extraTile.appLabel) {
                                    win.hoverText = "";
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    win.openContextMenu(extraTile, extraTile.appLabel, modelData, entry ? entry.id : modelData.appId, null);
                                    return;
                                }
                                win.ctxOpen = false;
                                modelData.activate();
                            }
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
                    id: wallTile
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
                    HoverHandler {
                        id: wallHover
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered) {
                                win.hoverText = "Wallpapers";
                                win.hoverCenterX = wallTile.mapToItem(fullArea, wallTile.width / 2, 0).x;
                            } else if (win.hoverText === "Wallpapers") {
                                win.hoverText = "";
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.ctxOpen = false;
                            win.shell.openOnly("wallpaper", win.screen);
                        }
                    }
                }

                // GNOME Show Applications
                Rectangle {
                    id: gridTile
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
                    HoverHandler {
                        id: gridHover
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered) {
                                win.hoverText = "Show Applications";
                                win.hoverCenterX = gridTile.mapToItem(fullArea, gridTile.width / 2, 0).x;
                            } else if (win.hoverText === "Show Applications") {
                                win.hoverText = "";
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.ctxOpen = false;
                            win.shell.openOnly("launcher", win.screen);
                        }
                    }
                }
            }
        }
    }
}
