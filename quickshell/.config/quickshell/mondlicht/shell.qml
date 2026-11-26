import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    function isScreenEmpty(scr) {
        if (!scr) return false;
        const mon = Hyprland.monitorFor(scr);
        if (!mon || !mon.activeWorkspace) return true;
        return mon.activeWorkspace.toplevels.values.length === 0;
    }

    readonly property var focusedScreen: {
        const fm = Hyprland.focusedMonitor;
        const screens = Quickshell.screens;
        if (fm) {
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === fm.name) return screens[i];
            }
        }
        return screens.length > 0 ? screens[0] : null;
    }

    // Prefer focused monitor if empty desktop; otherwise hand off ambient panels to another empty monitor
    readonly property var ambientScreen: {
        void Hyprland.workspaces.values.length;
        void Hyprland.toplevels.values.length;
        if (root.isScreenEmpty(root.focusedScreen)) return root.focusedScreen;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (root.isScreenEmpty(screens[i])) return screens[i];
        }
        return null;
    }

    readonly property bool desktopEmpty: ambientScreen !== null
    property var modalScreen: null
    readonly property var targetScreen: modalScreen || focusedScreen

    property bool clockOpen: false
    property bool overviewOpen: false
    property bool overviewOpenedByCycle: false
    property int overviewCycleToken: 0
    property int overviewCycleStep: 1
    property bool quickSettingsOpen: false
    property bool notifOpen: false
    property bool launcherOpen: false
    property bool wallpaperOpen: false
    property bool powerOpen: false
    property bool guideOpen: false
    property bool nightLightOn: false
    property bool dndOn: false
    property string osdKind: "volume"
    property int osdToken: 0

    property var toastItems: []
    readonly property alias notifModel: notifServer.trackedNotifications

    function openOnly(panel, preferredScreen) {
        if (panel) root.modalScreen = preferredScreen || root.focusedScreen || root.ambientScreen;
        root.clockOpen = (panel === "clock") ? !root.clockOpen : false;
        root.overviewOpen = (panel === "overview") ? !root.overviewOpen : false;
        root.quickSettingsOpen = (panel === "quickSettings") ? !root.quickSettingsOpen : false;
        root.notifOpen = (panel === "notif") ? !root.notifOpen : false;
        root.launcherOpen = (panel === "launcher") ? !root.launcherOpen : false;
        root.wallpaperOpen = (panel === "wallpaper") ? !root.wallpaperOpen : false;
        root.powerOpen = (panel === "power") ? !root.powerOpen : false;
        root.guideOpen = (panel === "guide") ? !root.guideOpen : false;
    }

    function removeToast(notif) {
        root.toastItems = root.toastItems.filter(n => n !== notif);
    }

    function clearNotifications() {
        const list = notifServer.trackedNotifications.values.slice();
        for (let i = 0; i < list.length; i++) {
            list[i].dismiss();
        }
        root.toastItems = [];
    }

    NotificationServer {
        id: notifServer
        bodySupported: true
        actionsSupported: true
        persistenceSupported: true
        imageSupported: true

        onNotification: function(notification) {
            notification.tracked = true;
            if (!root.dndOn && !root.notifOpen) {
                const next = root.toastItems.slice();
                next.unshift(notification);
                if (next.length > 3) next.pop();
                root.toastItems = next;
                const timer = Qt.createQmlObject(
                    'import QtQuick; Timer { interval: 5000; repeat: false }',
                    root
                );
                timer.triggered.connect(function() {
                    root.removeToast(notification);
                    timer.destroy();
                });
                timer.start();
            }
        }
    }

    IpcHandler {
        target: "shell"

        function toggleOverview(): void { root.overviewOpenedByCycle = false; root.openOnly("overview"); }
        function cycleOverview(step: int): void {
            root.overviewCycleStep = step || 1;
            if (!root.overviewOpen) {
                root.overviewOpenedByCycle = true;
                root.openOnly("overview");
            } else {
                root.overviewCycleToken++;
            }
        }
        function gestureUp(): void {
            if (root.overviewOpen) {
                root.openOnly("launcher");
            } else if (!root.launcherOpen) {
                root.overviewOpenedByCycle = false;
                root.openOnly("overview");
            }
        }
        function gestureDown(): void {
            if (root.launcherOpen) {
                root.overviewOpenedByCycle = false;
                root.openOnly("overview");
            } else if (root.overviewOpen || root.quickSettingsOpen || root.clockOpen || root.notifOpen || root.wallpaperOpen || root.powerOpen || root.guideOpen) {
                root.openOnly("");
            }
        }
        function toggleClock(): void { root.openOnly("clock"); }
        function toggleQuickSettings(): void { root.openOnly("quickSettings"); }
        function toggleNotifications(): void { root.openOnly("notif"); }
        function toggleLauncher(): void { root.openOnly("launcher"); }
        function toggleWallpaper(): void { root.openOnly("wallpaper"); }
        function togglePower(): void { root.openOnly("power"); }
        function toggleGuide(): void { root.openOnly("guide"); }
        function setNightLight(on: bool): void { root.nightLightOn = on; }
        function showOsd(kind: string): void { root.osdKind = kind || "volume"; root.osdToken++; }
        function closeAll(): void { root.openOnly(""); }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: screenScope
            required property var modelData

            TopCapsule { shell: root; screen: screenScope.modelData }
            LeftWorkspaces { shell: root; screen: screenScope.modelData }
            StatusSidebar { shell: root; screen: screenScope.modelData }
            BottomDock { shell: root; screen: screenScope.modelData }
        }
    }

    ClockPopover { shell: root }
    QuickSettingsPanel { shell: root }
    NotificationCenter { shell: root }
    AppLauncher { shell: root }
    WallpaperPicker { shell: root }
    PowerMenu { shell: root }
    TopLeftGuide { shell: root }
    ActivitiesOverview { shell: root }
    OsdPill { shell: root }
}
