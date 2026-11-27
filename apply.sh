#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=(hypr quickshell systemd spotify fuzzel matugen kitty fastfetch zsh starship gtk qt btop scripts)
DRY_RUN=0

for arg in "$@"; do
    case "${arg}" in
        --dry-run|-n) DRY_RUN=1 ;;
        -h|--help)
            printf 'Usage: %s [--dry-run]\n' "$0"
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "${arg}" >&2
            exit 1
            ;;
    esac
done

MANAGED_PATHS=(
    ".config/hypr/hyprland.lua"
    ".config/hypr/hypridle.conf"
    ".config/hypr/hyprlock.conf"
    ".config/autostart/nm-applet.desktop"
    ".config/autostart/blueman.desktop"
    ".config/autostart/baloo_file.desktop"
    ".config/autostart/polkit-kde-authentication-agent-1.desktop"
    ".config/autostart/print-applet.desktop"
    ".config/quickshell/mondlicht/Theme.qml"
    ".config/quickshell/mondlicht/shell.qml"
    ".config/quickshell/mondlicht/TopCapsule.qml"
    ".config/quickshell/mondlicht/ClockPopover.qml"
    ".config/quickshell/mondlicht/LeftWorkspaces.qml"
    ".config/quickshell/mondlicht/StatusSidebar.qml"
    ".config/quickshell/mondlicht/QuickSettingsPanel.qml"
    ".config/quickshell/mondlicht/NotificationCenter.qml"
    ".config/quickshell/mondlicht/BottomDock.qml"
    ".config/quickshell/mondlicht/AppLauncher.qml"
    ".config/quickshell/mondlicht/WallpaperPicker.qml"
    ".config/quickshell/mondlicht/PowerMenu.qml"
    ".config/quickshell/mondlicht/TopLeftGuide.qml"
    ".config/quickshell/mondlicht/ActivitiesOverview.qml"
    ".config/quickshell/mondlicht/OsdPill.qml"
    ".config/quickshell/mondlicht/SettingsWindow.qml"
    ".config/quickshell/mondlicht/ClipboardPopover.qml"
    ".config/systemd/user/mondlicht-quickshell.service"
    ".config/systemd/user/mondlicht-cliphist-text.service"
    ".config/systemd/user/mondlicht-cliphist-image.service"
    ".config/systemd/user/mondlicht-polkit.service"
    ".config/systemd/user/mondlicht-playerctld.service"
    ".config/systemd/user/mondlicht-udiskie.service"
    ".config/systemd/user/mondlicht-kwallet-pam.service"
    ".config/spotify-launcher.conf"
    ".config/spicetify/Themes/Mondlicht/color.ini"
    ".config/spicetify/Themes/Mondlicht/user.css"
    ".config/spotify-player/app.toml"
    ".config/spotify-player/theme.toml"
    ".config/fuzzel/fuzzel.ini"
    ".config/matugen/config.toml"
    ".config/matugen/templates"
    ".config/kitty/kitty.conf"
    ".config/fastfetch/config.jsonc"
    ".config/starship.toml"
    ".config/gtk-3.0/settings.ini"
    ".config/gtk-3.0/gtk.css"
    ".config/gtk-4.0/settings.ini"
    ".config/gtk-4.0/gtk.css"
    ".config/qt5ct/qt5ct.conf"
    ".config/qt6ct/qt6ct.conf"
    ".config/kdeglobals"
    ".config/btop/btop.conf"
    ".config/btop/themes/mondlicht.theme"
    ".zshrc"
    ".local/bin/set-wall"
    ".local/bin/clip-pick"
    ".local/bin/screenshot"
    ".local/bin/night-light"
    ".local/bin/power-menu"
    ".local/bin/screen-record"
    ".local/bin/mondlicht-settings"
    ".local/share/applications/mondlicht-settings.desktop"
    ".local/share/icons/hicolor/scalable/apps/mondlicht-settings.svg"
)

BACKUP_DIR="${HOME}/.mondlicht-backup-$(date +%Y%m%d-%H%M%S)"
backed_up=0

for rel in "${MANAGED_PATHS[@]}" ".config/hypr/hyprland.conf"; do
    target="${HOME}/${rel}"
    if [[ -e "${target}" || -L "${target}" ]]; then
        resolved="$(readlink -f "${target}" 2>/dev/null || true)"
        if [[ "${resolved}" != "${DOTFILES_DIR}/"* ]]; then
            if [[ "${DRY_RUN}" -eq 1 ]]; then
                printf '[DRY-RUN] Backup conflict: %s -> %s/%s\n' "${target}" "${BACKUP_DIR}" "${rel}"
            else
                mkdir -p "${BACKUP_DIR}/$(dirname "${rel}")"
                mv "${target}" "${BACKUP_DIR}/${rel}"
                backed_up=1
            fi
        fi
    fi
done

if [[ "${DRY_RUN}" -eq 1 ]]; then
    printf '[DRY-RUN] stow -R -d %s -t %s %s\n' "${DOTFILES_DIR}" "${HOME}" "${PACKAGES[*]}"
    printf '[DRY-RUN] Generate starter wallpapers (if missing) & apply gsettings dark theme\n'
    exit 0
fi

[[ "${backed_up}" -eq 1 ]] && printf 'Backed up conflicting files to %s\n' "${BACKUP_DIR}"

mkdir -p \
    "${HOME}/.config/hypr" \
    "${HOME}/.config/autostart" \
    "${HOME}/.config/quickshell/mondlicht" \
    "${HOME}/.config/systemd/user" \
    "${HOME}/.config/spicetify/Themes/Mondlicht" \
    "${HOME}/.config/spotify-player" \
    "${HOME}/.config/fuzzel" \
    "${HOME}/.config/brave-mondlicht-theme" \
    "${HOME}/.config/matugen" \
    "${HOME}/.config/kitty" \
    "${HOME}/.config/fastfetch" \
    "${HOME}/.config/gtk-3.0" \
    "${HOME}/.config/gtk-4.0" \
    "${HOME}/.config/qt5ct" \
    "${HOME}/.config/qt6ct" \
    "${HOME}/.config/btop/themes" \
    "${HOME}/.local/bin" \
    "${HOME}/.local/share/applications" \
    "${HOME}/.local/share/icons/hicolor/scalable/apps" \
    "${HOME}/.local/share/mondlicht" \
    "${HOME}/.cache" \
    "${HOME}/Pictures/Wallpapers" \
    "${HOME}/Pictures/Screenshots" \
    "${HOME}/Videos/Recordings"

touch "${HOME}/.local/share/mondlicht/notes.md"

stow -R -d "${DOTFILES_DIR}" -t "${HOME}" "${PACKAGES[@]}"

# Generate 3 Mondlicht starter wallpapers (2160x1440) if missing
generate_wallpapers() {
    local wdir="${HOME}/Pictures/Wallpapers"
    if ! command -v magick >/dev/null 2>&1; then
        printf 'Warning: imagemagick (magick) not found, skipping starter wallpapers.\n' >&2
        return 0
    fi

    if [[ ! -f "${wdir}/mondlicht-eclipse.png" ]]; then
        magick -size 540x360 xc:"#06070b" \
            -fill "rgba(28,35,62,0.55)" -draw "circle 270,170 270,260" \
            -blur 0x40 \
            -fill "rgba(183,166,232,0.22)" -draw "circle 270,170 270,228" \
            -blur 0x16 \
            -resize 2160x1440! \
            -fill "rgba(220,228,247,0.88)" -draw "circle 1080,680 1080,840" \
            -blur 0x6 \
            -fill "#07080d" -draw "circle 1094,690 1094,842" \
            -attenuate 0.18 +noise Gaussian \
            -depth 8 "${wdir}/mondlicht-eclipse.png"
    fi

    if [[ ! -f "${wdir}/mondlicht-shards.png" ]]; then
        magick -size 2160x1440 radial-gradient:"#181c2b-#05060a" \
            -fill "rgba(169,188,235,0.10)" -draw "polygon 0,1440 820,420 1240,1440" \
            -fill "rgba(183,166,232,0.08)" -draw "polygon 760,1440 1560,280 2160,1440" \
            -fill "rgba(10,12,19,0.72)" -draw "polygon 260,1440 1120,620 1980,1440" \
            -blur 0x2 \
            -attenuate 0.20 +noise Gaussian \
            -depth 8 "${wdir}/mondlicht-shards.png"
    fi

    if [[ ! -f "${wdir}/mondlicht-horizon.png" ]]; then
        magick -size 540x360 gradient:"#05060a-#111524" \
            -fill "rgba(169,188,235,0.24)" -draw "ellipse 270,240 225,30 0,360" \
            -blur 0x22 \
            -resize 2160x1440! \
            -fill "rgba(220,228,247,0.55)" -draw "circle 1540,420 1540,490" \
            -blur 0x3 \
            -attenuate 0.16 +noise Gaussian \
            -depth 8 "${wdir}/mondlicht-horizon.png"
    fi
}
generate_wallpapers

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' || true
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || true
    gsettings set org.gnome.desktop.interface cursor-theme 'capitaine-cursors' || true
    gsettings set org.gnome.desktop.interface font-name 'Geist 10' || true
fi

launch_detached() {
    setsid -f sh -c "$1" </dev/null >/dev/null 2>&1
}

if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    if ! awww query >/dev/null 2>&1; then
        launch_detached "awww-daemon"
        sleep 0.5
    fi

    wall="${HOME}/Pictures/Wallpapers/mondlicht-eclipse.png"
    if [[ -f "${HOME}/.cache/current-wallpaper" ]]; then
        cached="$(cat "${HOME}/.cache/current-wallpaper")"
        [[ -f "${cached}" ]] && wall="${cached}"
    fi
    if [[ -f "${wall}" ]]; then
        "${HOME}/.local/bin/set-wall" "${wall}"
    fi

    pkill -x dunst >/dev/null 2>&1 || true
    pkill -x waybar >/dev/null 2>&1 || true
    pkill -x swaync >/dev/null 2>&1 || true
    pkill -x nm-applet >/dev/null 2>&1 || true
    pkill -f '[b]lueman-(applet|tray)' >/dev/null 2>&1 || true

    if command -v balooctl6 >/dev/null 2>&1; then
        balooctl6 disable >/dev/null 2>&1 || true
        balooctl6 purge >/dev/null 2>&1 || true
    fi
    systemctl --user stop 'app-print\x2dapplet@autostart.service' >/dev/null 2>&1 || pkill -f '[p]rint-applet' >/dev/null 2>&1 || true

    # Hand off session daemons to systemd --user units
    pkill -x qs >/dev/null 2>&1 || true
    pkill -x hypridle >/dev/null 2>&1 || true
    pkill -f '[p]olkit-kde-authentication-agent-1' >/dev/null 2>&1 || true
    pkill -f '[c]liphist store' >/dev/null 2>&1 || true
    systemctl --user daemon-reload
    systemctl --user enable \
        mondlicht-quickshell.service \
        mondlicht-cliphist-text.service \
        mondlicht-cliphist-image.service \
        mondlicht-polkit.service \
        mondlicht-playerctld.service \
        mondlicht-udiskie.service \
        mondlicht-kwallet-pam.service \
        hypridle.service >/dev/null 2>&1 || true
    if [[ ! -f "${HOME}/.config/kwalletrc" ]] || grep -q '^Default Wallet=Default Keyring$' "${HOME}/.config/kwalletrc" 2>/dev/null; then
        cat <<'EOF' > "${HOME}/.config/kwalletrc"
[Wallet]
Close When Idle=false
Close on Screensaver=false
Default Wallet=kdewallet
Enabled=true
First Use=false
Leave Open=true
Prompt on Open=false
EOF
    fi
    systemctl --user restart mondlicht-quickshell.service
    systemctl --user start \
        mondlicht-cliphist-text.service \
        mondlicht-cliphist-image.service \
        mondlicht-polkit.service \
        mondlicht-playerctld.service \
        hypridle.service
    if [[ -x /usr/bin/udiskie ]]; then
        systemctl --user start mondlicht-udiskie.service
    fi
    systemctl --user try-restart xdg-desktop-portal >/dev/null 2>&1 || true
fi

printf 'Mondlicht dotfiles applied successfully.\n'
