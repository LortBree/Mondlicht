import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

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

    visible: win.shell.overviewOpen || (!win.closingForSwitch && backdrop.opacity > 0.01)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "obsidian-overview"
    WlrLayershell.keyboardFocus: win.shell.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property int selectedWinIndex: 0
    property int selectedAppIndex: 0
    property bool closingForSwitch: false
    property string pendingFocusAddr: ""

    function addrFor(t) {
        const clean = String((t && t.address) || "").replace(/[^0-9a-fA-Fx]/g, "");
        return clean.startsWith("0x") ? clean : ("0x" + clean);
    }

    function appIdFor(t) {
        return (t && t.lastIpcObject && t.lastIpcObject.class)
            || (t && t.wayland && t.wayland.appId)
            || "";
    }

    function windowList() {
        const list = Hyprland.toplevels.values.filter(t => t && t.address);
        list.sort((a, b) => {
            if (a.activated !== b.activated) return a.activated ? -1 : 1;
            const fa = (a.lastIpcObject && a.lastIpcObject.focusHistoryID !== undefined) ? a.lastIpcObject.focusHistoryID : 999;
            const fb = (b.lastIpcObject && b.lastIpcObject.focusHistoryID !== undefined) ? b.lastIpcObject.focusHistoryID : 999;
            return fa - fb;
        });
        return list;
    }

    function activateWindow(t) {
        if (!t || !t.address) return;
        win.pendingFocusAddr = addrFor(t);
        win.closingForSwitch = true;
        win.shell.overviewOpen = false;
        focusDispatchTimer.restart();
    }

    function closeWindow(t) {
        if (!t || !t.address) return;
        Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + addrFor(t) + '" })');
    }

    function normalWorkspaces() {
        return Hyprland.workspaces.values
            .filter(ws => ws.id > 0)
            .sort((a, b) => a.id - b.id);
    }

    function filteredApps() {
        const q = searchInput.text.trim().toLowerCase();
        const all = DesktopEntries.applications.values;
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const app = all[i];
            if (app.noDisplay) continue;
            if (!q || (app.name && app.name.toLowerCase().includes(q)) || (app.comment && app.comment.toLowerCase().includes(q))) {
                out.push(app);
                if (out.length >= 12) break;
            }
        }
        return out;
    }

    function moveSelection(delta) {
        if (searchInput.text.trim().length > 0) {
            const count = filteredApps().length;
            if (count > 0) win.selectedAppIndex = ((win.selectedAppIndex + delta) % count + count) % count;
        } else {
            const count = windowList().length;
            if (count > 0) win.selectedWinIndex = ((win.selectedWinIndex + delta) % count + count) % count;
        }
    }

    function moveGridVertical(rowDelta) {
        if (searchInput.text.trim().length > 0) {
            const count = filteredApps().length;
            if (count > 0) win.selectedAppIndex = Math.max(0, Math.min(count - 1, win.selectedAppIndex + rowDelta * 4));
        } else {
            const count = windowList().length;
            if (count > 0) win.selectedWinIndex = Math.max(0, Math.min(count - 1, win.selectedWinIndex + rowDelta * 3));
        }
    }

    function confirmSelection() {
        if (searchInput.text.trim().length > 0) {
            const matches = filteredApps();
            if (matches.length > 0) {
                const idx = Math.min(win.selectedAppIndex, matches.length - 1);
                matches[idx].execute();
                win.shell.overviewOpen = false;
            }
        } else {
            const wins = windowList();
            if (wins.length > 0) {
                const idx = Math.min(win.selectedWinIndex, wins.length - 1);
                activateWindow(wins[idx]);
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 40
        onTriggered: searchInput.forceActiveFocus()
    }

    Timer {
        id: focusDispatchTimer
        interval: 45
        repeat: false
        onTriggered: {
            const addr = win.pendingFocusAddr;
            win.pendingFocusAddr = "";
            if (!addr) return;
            const luaFn =
                'function() ' +
                'local w = hl.get_window("address:' + addr + '"); ' +
                'if not w then return end; ' +
                'if w.workspace then ' +
                '  local sp = hl.get_active_special_workspace(); ' +
                '  if w.workspace.special then ' +
                '    if not sp or sp.name ~= w.workspace.name then ' +
                '      hl.dispatch(hl.dsp.workspace.toggle_special(w.workspace.name:gsub("^special:", ""))); ' +
                '    end; ' +
                '  else ' +
                '    if sp then hl.dispatch(hl.dsp.workspace.toggle_special(sp.name:gsub("^special:", ""))); end; ' +
                '    hl.dispatch(hl.dsp.focus({ workspace = w.workspace.id })); ' +
                '  end; ' +
                'end; ' +
                'hl.dispatch(hl.dsp.focus({ window = w })); ' +
                'end';
            Hyprland.dispatch(luaFn);
        }
    }

    Connections {
        target: win.shell
        function onOverviewOpenChanged() {
            if (win.shell.overviewOpen) {
                win.closingForSwitch = false;
                Hyprland.refreshToplevels();
                searchInput.text = "";
                win.selectedAppIndex = 0;
                const count = win.windowList().length;
                if (win.shell.overviewOpenedByCycle && count > 1) {
                    win.selectedWinIndex = win.shell.overviewCycleStep < 0 ? count - 1 : 1;
                } else {
                    win.selectedWinIndex = 0;
                }
                win.shell.overviewOpenedByCycle = false;
                focusTimer.restart();
            }
        }
        function onOverviewCycleTokenChanged() {
            if (win.shell.overviewOpen) {
                win.moveSelection(win.shell.overviewCycleStep || 1);
            }
        }
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Theme.backdropBg
        opacity: win.shell.overviewOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: win.shell.overviewOpen = false

        MouseArea {
            anchors.fill: parent
            onClicked: win.shell.overviewOpen = false
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(920, parent.width - 140)
            spacing: 22

            // GNOME-style Search Bar
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 440
                Layout.preferredHeight: 44
                radius: 22
                color: Theme.voidBg
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.accent : Theme.rim

                MouseArea { anchors.fill: parent; onClicked: searchInput.forceActiveFocus() }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    Text {
                        text: "󰍉"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 15
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
                        onTextChanged: win.selectedAppIndex = 0
                        Keys.onEscapePressed: function(e) {
                            if (searchInput.text.length > 0) searchInput.text = "";
                            else win.shell.overviewOpen = false;
                            e.accepted = true;
                        }
                        Keys.onTabPressed: function(e) { win.moveSelection(1); e.accepted = true; }
                        Keys.onBacktabPressed: function(e) { win.moveSelection(-1); e.accepted = true; }
                        Keys.onRightPressed: function(e) { win.moveSelection(1); e.accepted = true; }
                        Keys.onLeftPressed: function(e) { win.moveSelection(-1); e.accepted = true; }
                        Keys.onDownPressed: function(e) { win.moveGridVertical(1); e.accepted = true; }
                        Keys.onUpPressed: function(e) { win.moveGridVertical(-1); e.accepted = true; }
                        Keys.onReturnPressed: function(e) { win.confirmSelection(); e.accepted = true; }
                        Keys.onEnterPressed: function(e) { win.confirmSelection(); e.accepted = true; }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: searchInput.text.length === 0
                            text: "Search apps or Tab / Arrows to switch windows..."
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: 13
                        }
                    }
                }
            }

            // App search results
            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 12
                columnSpacing: 12
                visible: searchInput.text.trim().length > 0

                Repeater {
                    model: win.filteredApps()
                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool isAppSel: index === win.selectedAppIndex
                        Layout.fillWidth: true
                        Layout.preferredHeight: 68
                        radius: 10
                        clip: true
                        color: appHover.containsMouse || isAppSel ? Theme.elevatedBg : Theme.glassBg
                        border.width: 1
                        border.color: isAppSel || appHover.containsMouse ? Theme.accent : Theme.rim

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Image {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                Layout.maximumWidth: 34
                                Layout.maximumHeight: 34
                                sourceSize: Qt.size(34, 34)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : Quickshell.iconPath("application-x-executable", true)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: appHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                modelData.execute();
                                win.shell.overviewOpen = false;
                            }
                        }
                    }
                }
            }

            // Window & Workspace cards when search is empty
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 16
                visible: searchInput.text.trim().length === 0

                // Workspace switcher strip (excluding negative special workspaces)
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10

                    Repeater {
                        model: win.normalWorkspaces()
                        Rectangle {
                            required property var modelData
                            width: 96
                            height: 40
                            radius: 10
                            color: modelData.focused ? Theme.elevatedBg : Theme.glassBg
                            border.width: 1
                            border.color: modelData.focused ? Theme.accent : Theme.rim

                            Text {
                                anchors.centerIn: parent
                                text: "Desktop " + modelData.id
                                color: modelData.focused ? Theme.accent : Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    win.closingForSwitch = true;
                                    win.shell.overviewOpen = false;
                                    Hyprland.dispatch('hl.dsp.focus({ workspace = ' + modelData.id + ' })');
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 10
                        color: newWsMouse.containsMouse ? Theme.elevatedBg : Theme.glassBg
                        border.width: 1
                        border.color: Theme.rim
                        Text { anchors.centerIn: parent; text: "+"; color: Theme.accent; font.pixelSize: 18 }
                        MouseArea {
                            id: newWsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                win.closingForSwitch = true;
                                win.shell.overviewOpen = false;
                                Hyprland.dispatch('hl.dsp.focus({ workspace = "empty" })');
                            }
                        }
                    }
                }

                // Active window cards (MRU order, Hyprland focuswindow on click or Enter)
                GridLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    columns: 3
                    rowSpacing: 12
                    columnSpacing: 12

                    Repeater {
                        model: win.windowList()
                        Rectangle {
                            required property var modelData
                            required property int index
                            readonly property string cls: win.appIdFor(modelData)
                            readonly property var entry: DesktopEntries.heuristicLookup(cls)
                            readonly property bool isSel: index === win.selectedWinIndex

                            Layout.fillWidth: true
                            Layout.preferredHeight: 82
                            radius: 12
                            clip: true
                            color: cardMouse.containsMouse || isSel ? Theme.elevatedBg : Theme.glassBg
                            border.width: isSel ? 2 : 1
                            border.color: isSel ? Theme.accent : (modelData.activated ? Theme.secondary : Theme.rim)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                Image {
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: 36
                                    Layout.maximumWidth: 36
                                    Layout.maximumHeight: 36
                                    sourceSize: Qt.size(36, 36)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                    source: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : Quickshell.iconPath("application-x-executable", true)
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title || cls || "Window"
                                        color: Theme.text
                                        font.family: Theme.fontSans
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: cls + (modelData.workspace
                                            ? (modelData.workspace.id > 0 ? " · Desktop " + modelData.workspace.id : " · Scratchpad")
                                            : "")
                                        color: Theme.muted
                                        font.family: Theme.fontSans
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                z: 1
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.activateWindow(modelData)
                            }

                            Rectangle {
                                z: 2
                                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                width: 26
                                height: 26
                                radius: 6
                                color: closeMouse.containsMouse ? Theme.crit : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: closeMouse.containsMouse ? Theme.accentFg : Theme.muted
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function(m) {
                                        m.accepted = true;
                                        win.closeWindow(modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
