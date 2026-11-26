import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris

PanelWindow {
    id: win
    required property var shell

    // Fullscreen transparent catcher so clicking anywhere outside closes drawer & restores capsule
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: win.shell.clockOpen || card.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "obsidian-popover"
    WlrLayershell.keyboardFocus: win.shell.clockOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property string bigClock: Qt.formatDateTime(new Date(), "HH:mm")
    property string bigSec: Qt.formatDateTime(new Date(), "ss")
    property string fullDate: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")

    readonly property var today: new Date()
    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property string notesPath: Quickshell.env("HOME") + "/.local/share/mondlicht/notes.md"

    Timer {
        interval: 1000
        running: win.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date();
            win.bigClock = Qt.formatDateTime(now, "HH:mm");
            win.bigSec = Qt.formatDateTime(now, "ss");
            win.fullDate = Qt.formatDateTime(now, "dddd, d MMMM yyyy");
        }
    }

    function monthLabel() {
        return Qt.formatDate(new Date(viewYear, viewMonth, 1), "MMMM yyyy");
    }

    function shiftMonth(delta) {
        let m = viewMonth + delta;
        let y = viewYear;
        if (m < 0) { m = 11; y--; }
        else if (m > 11) { m = 0; y++; }
        viewMonth = m;
        viewYear = y;
    }

    function buildCalendarDays() {
        const first = new Date(viewYear, viewMonth, 1);
        const startOffset = (first.getDay() + 6) % 7;
        const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate();
        const prevDays = new Date(viewYear, viewMonth, 0).getDate();
        const cells = [];
        for (let i = 0; i < 42; i++) {
            const num = i - startOffset + 1;
            if (num <= 0) {
                cells.push({ day: prevDays + num, inMonth: false, isToday: false });
            } else if (num > daysInMonth) {
                cells.push({ day: num - daysInMonth, inMonth: false, isToday: false });
            } else {
                const isToday = (viewYear === today.getFullYear() && viewMonth === today.getMonth() && num === today.getDate());
                cells.push({ day: num, inMonth: true, isToday: isToday });
            }
        }
        return cells;
    }

    FileView {
        id: notesFile
        path: win.notesPath
        onLoaded: {
            if (!notesInput.activeFocus) notesInput.text = text();
        }
    }

    Timer {
        id: saveTimer
        interval: 600
        repeat: false
        onTriggered: notesFile.setText(notesInput.text)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.shell.clockOpen = false
    }

    Rectangle {
        id: card
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 12
        }
        width: 620
        height: 416
        radius: 14
        color: Theme.voidBg
        border.width: 1
        border.color: Theme.rim
        opacity: win.shell.clockOpen ? 1.0 : 0.0

        transform: Translate {
            y: win.shell.clockOpen ? 0 : -56
            Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
        }
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: win.shell.clockOpen = false

        // Absorb clicks inside card so only clicking outside dismisses
        MouseArea {
            anchors.fill: parent
            onClicked: function(m) { m.accepted = true; }
        }

        // Top specular rim
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
            height: 24
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

            // TOP: Large Digital Clock Header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 68
                radius: 10
                color: Theme.glassBg
                border.width: 1
                border.color: Theme.rim

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 14

                    RowLayout {
                        spacing: 4
                        Text {
                            text: win.bigClock
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: 34
                            font.weight: Font.Light
                            font.letterSpacing: 1.0
                        }
                        Text {
                            text: ":" + win.bigSec
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 6
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: win.fullDate
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: "Mondlicht"
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: 11
                        }
                    }
                }
            }

            // BOTTOM: Calendar + (Media Player & Quick Notes)
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // LEFT: Interactive Calendar
                Rectangle {
                    Layout.preferredWidth: 274
                    Layout.fillHeight: true
                    radius: 10
                    color: Theme.glassBg
                    border.width: 1
                    border.color: Theme.rim

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: win.monthLabel()
                                color: Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }
                            Rectangle {
                                width: 24; height: 24; radius: 6
                                color: prevHov.hovered ? Theme.elevatedBg : "transparent"
                                Text { anchors.centerIn: parent; text: "‹"; color: Theme.text; font.pixelSize: 15 }
                                HoverHandler { id: prevHov; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.shiftMonth(-1) }
                            }
                            Rectangle {
                                width: 24; height: 24; radius: 6
                                color: todayHov.hovered ? Theme.elevatedBg : "transparent"
                                Text { anchors.centerIn: parent; text: "•"; color: Theme.accent; font.pixelSize: 15 }
                                HoverHandler { id: todayHov; cursorShape: Qt.PointingHandCursor }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { const d = new Date(); win.viewYear = d.getFullYear(); win.viewMonth = d.getMonth(); }
                                }
                            }
                            Rectangle {
                                width: 24; height: 24; radius: 6
                                color: nextHov.hovered ? Theme.elevatedBg : "transparent"
                                Text { anchors.centerIn: parent; text: "›"; color: Theme.text; font.pixelSize: 15 }
                                HoverHandler { id: nextHov; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.shiftMonth(1) }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 7
                            rowSpacing: 4
                            columnSpacing: 4

                            Repeater {
                                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                                Text {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    color: Theme.muted
                                    font.family: Theme.fontSans
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }
                            }

                            Repeater {
                                model: win.buildCalendarDays()
                                Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 29
                                    radius: 6
                                    color: modelData.isToday ? Theme.accent : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.day
                                        color: modelData.isToday ? Theme.accentFg : (modelData.inMonth ? Theme.text : Theme.muted)
                                        opacity: modelData.inMonth || modelData.isToday ? 1.0 : 0.4
                                        font.family: Theme.fontSans
                                        font.pixelSize: 12
                                        font.weight: modelData.isToday ? Font.Bold : Font.Normal
                                    }
                                }
                            }
                        }
                    }
                }

                // RIGHT: Media Player + Quick Notes
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 92
                        radius: 10
                        color: Theme.glassBg
                        border.width: 1
                        border.color: Theme.rim

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Rectangle {
                                width: 64
                                height: 64
                                radius: 8
                                color: Theme.elevatedBg
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: win.player && win.player.trackArtUrl ? win.player.trackArtUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !(win.player && win.player.trackArtUrl)
                                    text: "󰎈"
                                    color: Theme.accent
                                    font.family: Theme.fontMono
                                    font.pixelSize: 22
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: win.player && win.player.trackTitle ? win.player.trackTitle : "Nothing playing"
                                    color: Theme.text
                                    font.family: Theme.fontSans
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: win.player && win.player.trackArtist ? win.player.trackArtist : "MPRIS idle"
                                    color: Theme.muted
                                    font.family: Theme.fontSans
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                                RowLayout {
                                    spacing: 8
                                    Layout.topMargin: 4
                                    Rectangle {
                                        width: 26; height: 24; radius: 6
                                        color: pHov.hovered ? Theme.elevatedBg : "transparent"
                                        Text { anchors.centerIn: parent; text: "󰒮"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: 14 }
                                        HoverHandler { id: pHov; cursorShape: Qt.PointingHandCursor }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (win.player) win.player.previous() }
                                    }
                                    Rectangle {
                                        width: 30; height: 24; radius: 6
                                        color: Theme.accent
                                        Text {
                                            anchors.centerIn: parent
                                            text: win.player && win.player.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                                            color: Theme.accentFg
                                            font.family: Theme.fontMono
                                            font.pixelSize: 14
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (win.player) win.player.togglePlaying() }
                                    }
                                    Rectangle {
                                        width: 26; height: 24; radius: 6
                                        color: nHov.hovered ? Theme.elevatedBg : "transparent"
                                        Text { anchors.centerIn: parent; text: "󰒭"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: 14 }
                                        HoverHandler { id: nHov; cursorShape: Qt.PointingHandCursor }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (win.player) win.player.next() }
                                    }
                                }
                            }
                        }
                    }

                    // Quick Notes
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 10
                        color: Theme.glassBg
                        border.width: 1
                        border.color: notesInput.activeFocus ? Theme.accent : Theme.rim

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Quick Notes"
                                    color: Theme.text
                                    font.family: Theme.fontSans
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: saveTimer.running ? "Saving..." : "Saved"
                                    color: Theme.muted
                                    font.family: Theme.fontSans
                                    font.pixelSize: 10
                                }
                            }

                            Flickable {
                                id: flick
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentWidth: width
                                contentHeight: Math.max(height, notesInput.contentHeight + 8)
                                clip: true

                                TextEdit {
                                    id: notesInput
                                    width: flick.width
                                    height: Math.max(flick.height, contentHeight)
                                    color: Theme.text
                                    selectionColor: Theme.accent
                                    selectedTextColor: Theme.accentFg
                                    font.family: Theme.fontSans
                                    font.pixelSize: 12
                                    wrapMode: TextEdit.Wrap
                                    onTextChanged: {
                                        if (activeFocus) saveTimer.restart();
                                    }
                                }

                                Text {
                                    visible: notesInput.text.length === 0 && !notesInput.activeFocus
                                    text: "Write quick notes here... (auto-saved)"
                                    color: Theme.muted
                                    font.family: Theme.fontSans
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
