#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
    printf 'Run theme-apply.sh as your normal user, not root (sudo runs only for packages).\n' >&2
    exit 1
fi

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
INSTALL_PKGS=1

for arg in "$@"; do
    case "${arg}" in
        --dry-run|-n)  DRY_RUN=1 ;;
        --no-packages) INSTALL_PKGS=0 ;;
        -h|--help)
            cat <<'EOF'
Mondlicht Theme-Only Installer & Applier (preserves your custom panel & Hyprland/systemd setup)

Usage: ./theme-apply.sh [--dry-run] [--no-packages]

Applies:
  - Arch + AUR theme packages (breeze, breeze-icons, qt6ct-kde, qt5ct, adw-gtk-theme, papirus, geist, matugen, spicetify-bin)
  - Dolphin / Qt6 / Qt5 / KDE decimal-RGB Obsidian Luna theme & minimal toolbar chrome
  - GTK 3/4, Matugen dynamic colors, Spicetify Mondlicht theme, Brave theme dir, Kitty, Fuzzel, Btop, Fastfetch

Does NOT touch: Quickshell/panel, Hyprland configs, systemd services, zsh, starship, scripts, or boot.
EOF
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "${arg}" >&2
            exit 1
            ;;
    esac
done

run_step() {
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        printf '[DRY-RUN] %s\n' "$*"
    else
        "$@"
    fi
}

# 1. Install theme packages (swap legacy Kvantum for Breeze + qt6ct-kde)
OFFICIAL_PKGS=(
    stow
    matugen
    qt5-wayland
    qt6-wayland
    qt5ct
    breeze
    breeze-icons
    adw-gtk-theme
    papirus-icon-theme
    capitaine-cursors
    otf-geist-mono-nerd
)
AUR_PKGS=(
    ttf-geist
    ttf-geist-mono
    qt6ct-kde
    spicetify-bin
)

if [[ "${INSTALL_PKGS}" -eq 1 ]]; then
    for old_pkg in kvantum kvantum-qt5; do
        if pacman -Q "${old_pkg}" >/dev/null 2>&1; then
            run_step sudo pacman -Rns --noconfirm "${old_pkg}"
        fi
    done

    run_step sudo pacman -S --needed --noconfirm "${OFFICIAL_PKGS[@]}"

    AUR_HELPER=""
    if command -v yay >/dev/null 2>&1; then
        AUR_HELPER="yay"
    elif command -v paru >/dev/null 2>&1; then
        AUR_HELPER="paru"
    fi

    if [[ -n "${AUR_HELPER}" ]]; then
        run_step "${AUR_HELPER}" -S --needed --noconfirm "${AUR_PKGS[@]}"
    else
        printf 'Warning: neither yay nor paru found; install AUR packages manually: %s\n' "${AUR_PKGS[*]}" >&2
    fi
fi

# 2. Stow only theme packages (never touch quickshell, hypr, systemd, zsh, starship, scripts, boot)
THEME_PACKAGES=(gtk qt matugen spotify kitty fuzzel btop fastfetch)
MANAGED_PATHS=(
    ".config/gtk-3.0/settings.ini"
    ".config/gtk-3.0/gtk.css"
    ".config/gtk-4.0/settings.ini"
    ".config/gtk-4.0/gtk.css"
    ".local/share/kxmlgui5/dolphin/dolphinui.rc"
    ".config/matugen/config.toml"
    ".config/matugen/templates"
    ".config/spotify-launcher.conf"
    ".config/spicetify/Themes/Mondlicht/color.ini"
    ".config/spicetify/Themes/Mondlicht/user.css"
    ".config/spotify-player/app.toml"
    ".config/spotify-player/theme.toml"
    ".config/kitty/kitty.conf"
    ".config/fuzzel/fuzzel.ini"
    ".config/btop/btop.conf"
    ".config/btop/themes/mondlicht.theme"
    ".config/fastfetch/config.jsonc"
)

BACKUP_DIR="${HOME}/.mondlicht-theme-backup-$(date +%Y%m%d-%H%M%S)"
backed_up=0

for rel in "${MANAGED_PATHS[@]}"; do
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
    printf '[DRY-RUN] stow -R -d %s -t %s %s\n' "${DOTFILES_DIR}" "${HOME}" "${THEME_PACKAGES[*]}"
    printf '[DRY-RUN] Write qt6ct.conf (Breeze + Mondlicht.colors), qt5ct.conf, dolphinrc, gsettings, matugen & spicetify\n'
    exit 0
fi

[[ "${backed_up}" -eq 1 ]] && printf 'Backed up conflicting theme files to %s\n' "${BACKUP_DIR}"

# Ensure matugen output parent dirs exist without modifying hyprland.lua or Quickshell files
mkdir -p \
    "${HOME}/.config/gtk-3.0" \
    "${HOME}/.config/gtk-4.0" \
    "${HOME}/.config/qt5ct/colors" \
    "${HOME}/.config/qt6ct" \
    "${HOME}/.local/share/color-schemes" \
    "${HOME}/.local/share/kxmlgui5/dolphin" \
    "${HOME}/.config/matugen" \
    "${HOME}/.config/spicetify/Themes/Mondlicht" \
    "${HOME}/.config/spotify-player" \
    "${HOME}/.config/kitty" \
    "${HOME}/.config/fuzzel" \
    "${HOME}/.config/btop/themes" \
    "${HOME}/.config/fastfetch" \
    "${HOME}/.config/brave-mondlicht-theme" \
    "${HOME}/.config/hypr" \
    "${HOME}/.config/quickshell/mondlicht"

stow -R -d "${DOTFILES_DIR}" -t "${HOME}" "${THEME_PACKAGES[@]}"

# 3. Configure Qt6/Qt5 & Dolphin minimal Obsidian Luna chrome
rm -rf "${HOME}/.config/Kvantum" "${HOME}/.config/qt6ct/colors"
for f in "${HOME}/.config/kdeglobals" "${HOME}/.config/qt6ct/qt6ct.conf" "${HOME}/.config/qt5ct/qt5ct.conf"; do
    [[ -L "${f}" ]] && rm -f "${f}"
done

cat <<EOF > "${HOME}/.config/qt6ct/qt6ct.conf"
[Appearance]
color_scheme_path=${HOME}/.local/share/color-schemes/Mondlicht.colors
custom_palette=true
icon_theme=breeze-dark
standard_dialogs=default
style=Breeze

[Fonts]
fixed="GeistMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
general="Geist,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
EOF

cat <<EOF > "${HOME}/.config/qt5ct/qt5ct.conf"
[Appearance]
color_scheme_path=${HOME}/.config/qt5ct/colors/Mondlicht.conf
custom_palette=true
icon_theme=breeze-dark
standard_dialogs=default
style=Fusion

[Fonts]
fixed="GeistMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
general="Geist,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
EOF

if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file "${HOME}/.config/dolphinrc" --group UiSettings --key ColorScheme "Mondlicht"
    kwriteconfig6 --file "${HOME}/.config/dolphinrc" --group MainWindow --key MenuBar "Disabled"
    kwriteconfig6 --file "${HOME}/.config/dolphinrc" --group MainWindow --key ToolBarsMovable "Disabled"
    kwriteconfig6 --file "${HOME}/.config/dolphinrc" --group General --key ShowFullPath "false"
    kwriteconfig6 --file "${HOME}/.config/dolphinrc" --group General --key ShowSelectionToggle "true"
    kwriteconfig6 --file "${HOME}/.config/dolphinrc" --group General --key ShowStatusBar "Small"
    kwriteconfig6 --file "${HOME}/.config/dolphinrc" --group PlacesPanel --key IconSize "16"
    kwriteconfig6 --file "${HOME}/.config/dolphinrc" --group IconsMode --key PreviewSize "64"
    kwriteconfig6 --file "${HOME}/.config/dolphinrc" --group IconsMode --key MaximumTextLines "2"
fi

# 4. Global GTK theme + Matugen decimal-RGB colors + Spicetify Mondlicht
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' || true
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || true
    gsettings set org.gnome.desktop.interface cursor-theme 'capitaine-cursors' || true
    gsettings set org.gnome.desktop.interface font-name 'Geist 10' || true
fi

if command -v matugen >/dev/null 2>&1; then
    wall=""
    if [[ -f "${HOME}/.cache/current-wallpaper" ]]; then
        cached="$(cat "${HOME}/.cache/current-wallpaper")"
        [[ -f "${cached}" && -r "${cached}" ]] && wall="${cached}"
    fi
    if [[ -n "${wall}" ]]; then
        matugen image --source-color-index 0 -m dark "${wall}"
    else
        matugen color hex "#adc6ff" --source-color-index 0 -m dark
    fi
fi

SPOTIFY_DIR=""
for candidate in \
    "${HOME}/.local/share/spotify-launcher/install/usr/share/spotify" \
    "/opt/spotify"; do
    if [[ -d "${candidate}" ]]; then
        SPOTIFY_DIR="${candidate}"
        break
    fi
done
SPOTIFY_PREFS="${HOME}/.config/spotify/prefs"

if command -v spicetify >/dev/null 2>&1 && [[ -n "${SPOTIFY_DIR}" && -f "${SPOTIFY_PREFS}" ]]; then
    spicetify config spotify_path "${SPOTIFY_DIR}"
    spicetify config prefs_path "${SPOTIFY_PREFS}"
    spicetify config current_theme Mondlicht
    spicetify config color_scheme ObsidianLuna
    spicetify config inject_css 1 replace_colors 1 overwrite_assets 0 inject_theme_js 0
    spicetify config disable_sentry 1 disable_ui_logging 1 remove_rtl_rule 1 expose_apis 1
    spicetify backup apply || true
elif command -v spicetify >/dev/null 2>&1; then
    printf 'Note: launch Spotify & log in once, then run `spicetify backup apply`.\n'
fi

pkill -SIGUSR1 kitty >/dev/null 2>&1 || true

printf '\nMondlicht themes applied (panel, Hyprland, and systemd untouched).\n'
printf 'Notes:\n'
printf '  - Load Brave theme unpacked from ~/.config/brave-mondlicht-theme if desired.\n'
printf '  - Optional Dolphin glass rule for custom Hyprland configs: match class org.kde.dolphin with blur ignore_opacity.\n'
