import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

    visible: win.shell.clipboardOpen || card.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "obsidian-popover"
    WlrLayershell.keyboardFocus: win.shell.clipboardOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var allItems: []
    property var filteredItems: []
    property int selectedIndex: 0

    function applyFilter() {
        const q = searchInput.text.trim().toLowerCase();
        const out = [];
        for (let i = 0; i < win.allItems.length; i++) {
            const it = win.allItems[i];
            if (!q || (it.preview || "").toLowerCase().includes(q)) {
                out.push(it);
            }
        }
        win.filteredItems = out;
        win.selectedIndex = 0;
    }

    function pickItem(item) {
        if (!item) return;
        Quickshell.execDetached([
            "python3", "-c",
            "import subprocess,sys; p=subprocess.run(['cliphist','decode'], input=sys.argv[1].encode(), stdout=subprocess.PIPE); subprocess.run(['wl-copy'], input=p.stdout)",
            item.rawLine
        ]);
        win.shell.clipboardOpen = false;
    }

    function deleteItem(item) {
        if (!item) return;
        delProc.exec([
            "python3", "-c",
            "import subprocess,sys; subprocess.run(['cliphist','delete'], input=sys.argv[1].encode())",
            item.rawLine
        ]);
    }

    function clearAll() {
        wipeProc.running = true;
    }

    Component.onCompleted: {
        if (win.shell.clipboardOpen) {
            searchInput.text = "";
            loadProc.running = false;
            loadProc.running = true;
            searchInput.forceActiveFocus();
        }
    }

    onVisibleChanged: {
        if (win.shell.clipboardOpen) {
            searchInput.text = "";
            loadProc.running = false;
            loadProc.running = true;
            searchInput.forceActiveFocus();
        }
    }

    Process {
        id: loadProc
        command: [
            "python3", "-c",
            `import json, os, re, subprocess
cache_dir = "/tmp/mondlicht-clip"
os.makedirs(cache_dir, exist_ok=True)
try:
    raw = subprocess.check_output(["cliphist", "list"], text=True, stderr=subprocess.DEVNULL)
except Exception:
    raw = ""
lines = [l for l in raw.splitlines() if l.strip()][:40]
active_ids = set()
items = []
for line in lines:
    parts = line.split("\\t", 1)
    cid = parts[0].strip()
    preview = parts[1] if len(parts) > 1 else line
    active_ids.add(cid)
    is_img = bool(re.search(r"\\[\\[\\s*binary data.*\\b(png|jpe?g|webp|bmp|gif)\\b", preview, re.I))
    img_path = ""
    if is_img:
        dest = os.path.join(cache_dir, cid + ".img")
        if not os.path.exists(dest) or os.path.getsize(dest) == 0:
            try:
                data = subprocess.check_output(["cliphist", "decode"], input=(line + "\\n").encode(), stderr=subprocess.DEVNULL)
                with open(dest, "wb") as f:
                    f.write(data)
            except Exception:
                pass
        if os.path.exists(dest) and os.path.getsize(dest) > 0:
            img_path = "file://" + dest
    items.append({"id": cid, "rawLine": line, "preview": preview, "isImage": is_img, "imgPath": img_path})
for fn in os.listdir(cache_dir):
    if fn.endswith(".img") and fn[:-4] not in active_ids:
        try:
            os.remove(os.path.join(cache_dir, fn))
        except Exception:
            pass
print(json.dumps(items))`
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    win.allItems = JSON.parse(text);
                } catch (e) {
                    win.allItems = [];
                }
                win.applyFilter();
            }
        }
    }

    Process {
        id: delProc
        onExited: {
            loadProc.running = false;
            loadProc.running = true;
        }
    }

    Process {
        id: wipeProc
        command: ["sh", "-c", "cliphist wipe && rm -rf /tmp/mondlicht-clip"]
        onExited: {
            win.allItems = [];
            win.filteredItems = [];
            win.selectedIndex = 0;
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.shell.clipboardOpen = false
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 520
        height: 520
        radius: 18
        color: Theme.voidBg
        border.width: 1
        border.color: Theme.rim
        opacity: win.shell.clipboardOpen ? 1.0 : 0.0
        scale: win.shell.clipboardOpen ? 1.0 : 0.96

        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

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

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰅌"
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 16
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: "Clipboard History"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignVCenter
                }
                Rectangle {
                    radius: 8
                    color: Theme.elevatedBg
                    border.width: 1; border.color: Theme.rim
                    implicitWidth: countTxt.implicitWidth + 12
                    implicitHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        id: countTxt
                        anchors.centerIn: parent
                        text: win.filteredItems.length
                        color: Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    visible: win.allItems.length > 0
                    radius: 8
                    implicitWidth: clrLbl.implicitWidth + 18
                    implicitHeight: 26
                    color: clrHov.hovered ? Theme.crit : Theme.glassBg
                    border.width: 1
                    border.color: clrHov.hovered ? Theme.crit : Theme.rim
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Text {
                        id: clrLbl
                        anchors.centerIn: parent
                        text: "Clear All"
                        color: clrHov.hovered ? Theme.accentFg : Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    HoverHandler { id: clrHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.clearAll()
                    }
                }
            }

            // Search bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 11
                color: Theme.glassBg
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.accent : Theme.rim

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: "󰍉"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: 13
                        selectByMouse: true
                        onTextChanged: win.applyFilter()
                        Keys.onEscapePressed: win.shell.clipboardOpen = false
                        Keys.onDownPressed: {
                            if (win.selectedIndex + 1 < win.filteredItems.length) {
                                win.selectedIndex++;
                                clipList.positionViewAtIndex(win.selectedIndex, ListView.Contain);
                            }
                        }
                        Keys.onUpPressed: {
                            if (win.selectedIndex > 0) {
                                win.selectedIndex--;
                                clipList.positionViewAtIndex(win.selectedIndex, ListView.Contain);
                            }
                        }
                        Keys.onReturnPressed: {
                            if (win.filteredItems.length > 0) {
                                win.pickItem(win.filteredItems[win.selectedIndex]);
                            }
                        }
                        Keys.onEnterPressed: {
                            if (win.filteredItems.length > 0) {
                                win.pickItem(win.filteredItems[win.selectedIndex]);
                            }
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: searchInput.text.length === 0
                            text: "Filter clipboard entries..."
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: 12
                        }
                    }
                }
            }

            // History list
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    anchors.centerIn: parent
                    visible: win.filteredItems.length === 0
                    text: win.allItems.length === 0 ? "Clipboard history is empty" : "No matching entries"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                }

                ListView {
                    id: clipList
                    anchors.fill: parent
                    clip: true
                    spacing: 6
                    model: win.filteredItems
                    currentIndex: win.selectedIndex

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool isSel: index === win.selectedIndex

                        width: clipList.width
                        height: modelData.isImage ? 72 : 50
                        radius: 10
                        color: isSel ? Theme.elevatedBg : (rowHov.hovered ? Theme.glassBg : "#5510131e")
                        border.width: 1
                        border.color: isSel ? Theme.accent : (rowHov.hovered ? Theme.rim : "#14dce4f7")
                        Behavior on color { ColorAnimation { duration: 120 } }

                        HoverHandler { id: rowHov; cursorShape: Qt.PointingHandCursor }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.pickItem(modelData)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 10

                            Rectangle {
                                visible: modelData.isImage
                                width: 82
                                height: 52
                                radius: 7
                                color: Theme.elevatedBg
                                border.width: 1; border.color: Theme.rim
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: modelData.imgPath || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.isImage ? ("Image · " + modelData.preview) : modelData.preview
                                color: Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                width: 26
                                height: 26
                                radius: 7
                                Layout.alignment: Qt.AlignVCenter
                                color: delHov.hovered ? Theme.crit : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴"
                                    color: delHov.hovered ? Theme.accentFg : Theme.muted
                                    font.family: Theme.fontMono
                                    font.pixelSize: 13
                                }
                                HoverHandler { id: delHov; cursorShape: Qt.PointingHandCursor }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function(m) {
                                        m.accepted = true;
                                        win.deleteItem(modelData);
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
