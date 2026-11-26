pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Obsidian smoked-glass surface anchors (never muddy grey)
    readonly property color voidBg: "#dd08090e"
    readonly property color glassBg: "#cc0e1018"
    readonly property color elevatedBg: "#e6161a26"
    readonly property color backdropBg: "#b805060a"
    readonly property color rim: "#26dce4f7"
    readonly property color sheen: "#12ffffff"
    readonly property color text: "#dce4f7"
    readonly property color muted: "#7e88a6"
    readonly property color ok: "#86c5a9"
    readonly property color warn: "#e2c285"

    // Dynamic Luna accents updated live by matugen colors.json
    property color accent: "#adc6ff"
    property color secondary: "#debcdf"
    property color accentFg: "#08090e"
    property color crit: "#e07a8e"

    readonly property string fontSans: "Geist"
    readonly property string fontMono: "GeistMono Nerd Font"
    readonly property int radius: 6

    FileView {
        id: colorsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/mondlicht/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                if (parsed.accent) root.accent = parsed.accent;
                if (parsed.secondary) root.secondary = parsed.secondary;
                if (parsed.accentFg) root.accentFg = parsed.accentFg;
                if (parsed.crit) root.crit = parsed.crit;
            } catch (e) {
                // Keep previous valid Mondlicht palette on partial writes
            }
        }
    }
}
