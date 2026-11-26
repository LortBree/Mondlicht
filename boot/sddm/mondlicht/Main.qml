import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    width: 1440
    height: 960
    color: "#07080d"
    focus: true

    property bool loginOpen: false
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string errorText: ""
    property string nowTime: Qt.formatDateTime(new Date(), "HH:mm")
    property string nowDate: Qt.formatDateTime(new Date(), "dddd, d MMMM")

    readonly property color colVoid: "#dd08090e"
    readonly property color colGlass: "#cc10131e"
    readonly property color colRim: "#2edce4f7"
    readonly property color colAccent: config.Accent || "#b7c4ff"
    readonly property color colText: config.Text || "#dce4f7"
    readonly property color colMuted: config.Muted || "#8b96b5"
    readonly property color colCrit: "#e07a8e"

    function openLogin(initialChar) {
        if (!root.loginOpen) {
            root.loginOpen = true;
            if (initialChar) passwordInput.text += initialChar;
            focusTimer.restart();
        }
    }

    function currentUserName() {
        const idx = userRepeater.itemAt(root.userIndex);
        return idx ? idx.userName : "";
    }

    function currentSessionName() {
        const item = sessionRepeater.itemAt(root.sessionIndex);
        return item ? item.sessionName : "Hyprland";
    }

    function submitLogin() {
        if (passwordInput.text.length === 0) return;
        root.errorText = "";
        sddm.login(currentUserName(), passwordInput.text, root.sessionIndex);
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            const d = new Date();
            root.nowTime = Qt.formatDateTime(d, "HH:mm");
            root.nowDate = Qt.formatDateTime(d, "dddd, d MMMM");
        }
    }

    Timer {
        id: focusTimer
        interval: 60
        onTriggered: passwordInput.forceActiveFocus()
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.errorText = "Incorrect password";
            passwordInput.text = "";
            shakeAnim.restart();
            focusTimer.restart();
        }
        function onLoginSucceeded() {
            root.errorText = "";
        }
    }

    // Hidden repeaters expose userModel & sessionModel roles cleanly in Qt6
    Item {
        visible: false
        Repeater {
            id: userRepeater
            model: userModel
            Item {
                required property string name
                property string userName: name
            }
        }
        Repeater {
            id: sessionRepeater
            model: sessionModel
            Item {
                required property string name
                property string sessionName: name
            }
        }
    }

    // Background wallpaper
    Image {
        anchors.fill: parent
        source: config.Background || "wallpaper.png"
        fillMode: Image.PreserveAspectCrop
        smooth: true
        scale: root.loginOpen ? 1.03 : 1.0
        Behavior on scale { NumberAnimation { duration: 520; easing.type: Easing.OutExpo } }
    }

    // Obsidian dark scrim
    Rectangle {
        anchors.fill: parent
        color: "#05060a"
        opacity: root.loginOpen ? 0.62 : 0.24
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    }

    // Any key or click on curtain reveals user & password input
    Keys.onPressed: function(event) {
        if (!root.loginOpen) {
            if (event.key === Qt.Key_Escape) return;
            const ch = (event.text && event.text.length === 1 && event.text >= " ") ? event.text : "";
            root.openLogin(ch);
            event.accepted = true;
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (!root.loginOpen) root.openLogin("");
            else passwordInput.forceActiveFocus();
        }
    }

    // CLOCK & DATE (Centered large clock + small date directly below; glides up when login opens)
    Column {
        id: clockBlock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.loginOpen ? -146 : -12
        spacing: 6
        scale: root.loginOpen ? 0.68 : 1.0

        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 480; easing.type: Easing.OutExpo } }
        Behavior on scale { NumberAnimation { duration: 480; easing.type: Easing.OutExpo } }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.nowTime
            color: root.colText
            font.family: config.Font || "Geist"
            font.pixelSize: 120
            font.weight: Font.Light
            font.letterSpacing: 3
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.nowDate
            color: root.colMuted
            font.family: config.Font || "Geist"
            font.pixelSize: 16
            font.weight: Font.Medium
            font.letterSpacing: 0.6
        }
    }

    // Subtle curtain hint before interaction
    Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 42
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Click or press any key to unlock"
        color: root.colMuted
        font.family: config.Font || "Geist"
        font.pixelSize: 12
        opacity: root.loginOpen ? 0.0 : 0.65
        Behavior on opacity { NumberAnimation { duration: 240 } }
    }

    // USER & PASSWORD PANEL (hidden initially, revealed smoothly on press/click)
    Column {
        id: loginBlock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.loginOpen ? 56 : 92
        spacing: 14
        opacity: root.loginOpen ? 1.0 : 0.0
        visible: opacity > 0.01

        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 440; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        // Avatar + Username pill (click to cycle if multiple users exist)
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 68
                height: 68
                radius: 34
                color: root.colGlass
                border.width: 1
                border.color: root.colAccent

                Text {
                    anchors.centerIn: parent
                    text: root.currentUserName().slice(0, 1).toUpperCase()
                    color: root.colText
                    font.family: config.Font || "Geist"
                    font.pixelSize: 26
                    font.weight: Font.Medium
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: userTxt.implicitWidth + 24
                height: 28
                radius: 14
                color: userMouse.containsMouse ? "#22dce4f7" : "transparent"

                Text {
                    id: userTxt
                    anchors.centerIn: parent
                    text: root.currentUserName()
                    color: root.colText
                    font.family: config.Font || "Geist"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: userMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (userModel.rowCount() > 1) {
                            root.userIndex = (root.userIndex + 1) % userModel.rowCount();
                        }
                        passwordInput.forceActiveFocus();
                    }
                }
            }
        }

        // Obsidian password rounded rectangle centered cleanly under avatar + external submit arrow on right
        Item {
            id: passRow
            anchors.horizontalCenter: parent.horizontalCenter
            width: passBox.width
            height: passBox.height

            SequentialAnimation on anchors.horizontalCenterOffset {
                id: shakeAnim
                running: false
                NumberAnimation { to: -8; duration: 45 }
                NumberAnimation { to: 8; duration: 60 }
                NumberAnimation { to: -5; duration: 50 }
                NumberAnimation { to: 0; duration: 45 }
            }

            Rectangle {
                id: passBox
                anchors.centerIn: parent
                width: 244
                height: 44
                radius: 8
                color: root.colVoid
                border.width: 1
                border.color: root.errorText.length > 0 ? root.colCrit : (passwordInput.activeFocus ? root.colAccent : root.colRim)

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: root.colText
                    selectionColor: root.colAccent
                    font.family: config.Font || "Geist"
                    font.pixelSize: 14
                    clip: true

                    Keys.onReturnPressed: root.submitLogin()
                    Keys.onEnterPressed: root.submitLogin()
                    Keys.onEscapePressed: {
                        if (passwordInput.text.length > 0) {
                            passwordInput.text = "";
                        } else {
                            root.errorText = "";
                            root.loginOpen = false;
                            root.forceActiveFocus();
                        }
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        visible: passwordInput.text.length === 0
                        text: "Password"
                        color: root.colMuted
                        font.family: config.Font || "Geist"
                        font.pixelSize: 13
                    }
                }
            }

            Rectangle {
                id: submitBtn
                anchors.left: passBox.right
                anchors.leftMargin: 8
                anchors.verticalCenter: passBox.verticalCenter
                width: 44
                height: 44
                radius: 8
                color: submitMouse.containsMouse ? root.colAccent : root.colGlass
                border.width: 1
                border.color: submitMouse.containsMouse ? root.colAccent : root.colRim

                Text {
                    anchors.centerIn: parent
                    text: "→"
                    color: submitMouse.containsMouse ? "#08090e" : root.colText
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: submitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submitLogin()
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 18
            text: root.errorText
            color: root.colCrit
            font.family: config.Font || "Geist"
            font.pixelSize: 12
        }
    }

    // Bottom Session & Power bar (visible only once unlocked)
    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10
        opacity: root.loginOpen ? 0.9 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 280 } }

        Rectangle {
            height: 30
            width: sessTxt.implicitWidth + 24
            radius: 15
            color: root.colGlass
            border.width: 1
            border.color: sessMouse.containsMouse ? root.colAccent : root.colRim
            Text {
                id: sessTxt
                anchors.centerIn: parent
                text: root.currentSessionName()
                color: root.colText
                font.family: config.Font || "Geist"
                font.pixelSize: 11
            }
            MouseArea {
                id: sessMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (sessionModel.rowCount() > 1) {
                        root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount();
                    }
                }
            }
        }

        Rectangle {
            height: 30; width: 64; radius: 15
            color: root.colGlass; border.width: 1
            border.color: suspMouse.containsMouse ? root.colAccent : root.colRim
            Text { anchors.centerIn: parent; text: "Sleep"; color: root.colMuted; font.family: config.Font || "Geist"; font.pixelSize: 11 }
            MouseArea { id: suspMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sddm.suspend() }
        }

        Rectangle {
            height: 30; width: 68; radius: 15
            color: root.colGlass; border.width: 1
            border.color: rebMouse.containsMouse ? root.colAccent : root.colRim
            Text { anchors.centerIn: parent; text: "Reboot"; color: root.colMuted; font.family: config.Font || "Geist"; font.pixelSize: 11 }
            MouseArea { id: rebMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sddm.reboot() }
        }

        Rectangle {
            height: 30; width: 78; radius: 15
            color: root.colGlass; border.width: 1
            border.color: pwrMouse.containsMouse ? root.colCrit : root.colRim
            Text { anchors.centerIn: parent; text: "Power"; color: pwrMouse.containsMouse ? root.colCrit : root.colMuted; font.family: config.Font || "Geist"; font.pixelSize: 11 }
            MouseArea { id: pwrMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sddm.powerOff() }
        }
    }
}
