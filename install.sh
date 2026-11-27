#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
    printf 'Run install.sh as your normal user, not root (sudo will be requested only when needed).\n' >&2
    exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults populated by detect_hardware and overridable via CLI or interactive TUI
PROFILE=""
GPU=""
WITH_APPS=1
WITH_LAPTOP=""
WITH_TUNING=1
AUR_MODE=""
WITH_BOOT=0
DRY_RUN=0
AUTO_YES=0
UNINSTALL=0
BOOTLOADER="unknown"
CPU_MODEL="Unknown CPU"
RAM_TOTAL="?"
GPU_NAME="Integrated / Unknown"
APPS_SET=0
LAPTOP_SET=0
TUNING_SET=0

# Obsidian Luna terminal palette (respects non-TTY & NO_COLOR)
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RST=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[38;5;103m'
    C_BLUE=$'\033[38;5;153m'
    C_LAV=$'\033[38;5;182m'
    C_OK=$'\033[38;5;115m'
    C_WARN=$'\033[38;5;222m'
    C_CRIT=$'\033[38;5;210m'
    C_TXT=$'\033[38;5;254m'
else
    C_RST="" C_BOLD="" C_DIM="" C_BLUE="" C_LAV="" C_OK="" C_WARN="" C_CRIT="" C_TXT=""
fi

usage() {
    cat <<'EOF'
Mondlicht Arch Linux Installer (Hyprland + Quickshell + Systemd)

Usage: ./install.sh [options]

Options:
  --profile <name>    pc-standard | laptop-standard | laptop-hidpi
  --gpu <vendor>      intel | amd | nvidia | hybrid
  --with-apps         Install apps group (Brave, Antigravity, Spotify, spotify-player, Docker, CUPS, KDE Connect, fwupd)
  --no-apps           Skip optional apps group (install core desktop only)
  --with-laptop       Install laptop packages (brightnessctl, smartmontools, thermald on Intel)
  --no-laptop         Skip laptop packages
  --with-tuning       Enable debloat & performance tuning (Brave policy/VA-API, Spicetify Mondlicht, ZRAM, journald, socket activation)
  --no-tuning         Skip system tuning and app debloat tweaks
  --aur <mode>        yay | paru | bootstrap | skip
  --with-boot         Install SDDM + Dark Mondlicht GRUB theme (requires sudo)
  --dry-run           Simulate actions without modifying packages or files
  --yes               Skip interactive menu and proceed with detected/selected options
  --uninstall         Stop Mondlicht user services, unstow symlinks, and remove ~/.config/hypr/host.lua
  -h, --help          Show this help
EOF
}

validate_profile() {
    case "$1" in
        pc-standard|laptop-standard|laptop-hidpi) ;;
        *) printf 'Invalid --profile: %s\n' "$1" >&2; exit 1 ;;
    esac
}

validate_gpu() {
    case "$1" in
        intel|amd|nvidia|hybrid) ;;
        *) printf 'Invalid --gpu: %s\n' "$1" >&2; exit 1 ;;
    esac
}

validate_aur() {
    case "$1" in
        yay|paru|bootstrap|skip) ;;
        *) printf 'Invalid --aur: %s\n' "$1" >&2; exit 1 ;;
    esac
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)      PROFILE="${2:-}"; validate_profile "${PROFILE}"; shift 2 ;;
        --gpu)          GPU="${2:-}"; validate_gpu "${GPU}"; shift 2 ;;
        --with-apps)    WITH_APPS=1; APPS_SET=1; shift ;;
        --no-apps)      WITH_APPS=0; APPS_SET=1; shift ;;
        --with-laptop)  WITH_LAPTOP=1; LAPTOP_SET=1; shift ;;
        --no-laptop)    WITH_LAPTOP=0; LAPTOP_SET=1; shift ;;
        --with-tuning)  WITH_TUNING=1; TUNING_SET=1; shift ;;
        --no-tuning)    WITH_TUNING=0; TUNING_SET=1; shift ;;
        --aur)          AUR_MODE="${2:-}"; validate_aur "${AUR_MODE}"; shift 2 ;;
        --with-boot)    WITH_BOOT=1; shift ;;
        --dry-run|-n)   DRY_RUN=1; shift ;;
        --yes|-y)       AUTO_YES=1; shift ;;
        --uninstall)    UNINSTALL=1; shift ;;
        -h|--help)      usage; exit 0 ;;
        *)              printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
    esac
done

info_msg() { printf '  %s·%s %s\n' "${C_BLUE}" "${C_RST}" "$*"; }
ok_msg()   { printf '  %s✓%s %s\n' "${C_OK}" "${C_RST}" "$*"; }
warn_msg() { printf '  %s!%s %s\n' "${C_WARN}" "${C_RST}" "$*" >&2; }

step_header() {
    local idx="$1" total="$2" title="$3"
    printf '\n%s[%s/%s]%s %s%s%s\n' "${C_LAV}${C_BOLD}" "${idx}" "${total}" "${C_RST}" "${C_BOLD}${C_TXT}" "${title}" "${C_RST}"
}

run_cmd() {
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        printf '  %s[DRY-RUN]%s %s\n' "${C_DIM}" "${C_RST}" "$*"
    else
        "$@"
    fi
}

read_pkg_file() {
    local file="$1"
    [[ -f "${file}" ]] || return 0
    sed 's/#.*//' "${file}" | awk 'NF {print $1}'
}

detect_hardware() {
    local is_laptop=0 hidpi=0
    if compgen -G "/sys/class/power_supply/BAT*" >/dev/null 2>&1 || \
       compgen -G "/sys/class/backlight/*" >/dev/null 2>&1; then
        is_laptop=1
    fi

    if [[ "${is_laptop}" -eq 1 ]] && compgen -G "/sys/class/drm/*-eDP-*/modes" >/dev/null 2>&1; then
        local width
        width="$(awk -F'x' 'NR==1 && $1 ~ /^[0-9]+$/ {print $1; exit}' /sys/class/drm/*-eDP-*/modes 2>/dev/null || echo 0)"
        [[ "${width:-0}" -ge 2160 ]] && hidpi=1
    fi

    if [[ -z "${PROFILE}" ]]; then
        if [[ "${is_laptop}" -eq 1 ]]; then
            PROFILE="$([[ "${hidpi}" -eq 1 ]] && echo "laptop-hidpi" || echo "laptop-standard")"
        else
            PROFILE="pc-standard"
        fi
    fi

    if [[ "${LAPTOP_SET}" -eq 0 ]]; then
        WITH_LAPTOP="$([[ "${PROFILE}" == laptop-* ]] && echo 1 || echo 0)"
    fi

    if [[ -z "${GPU}" ]]; then
        local vga=""
        if command -v lspci >/dev/null 2>&1; then
            vga="$(lspci | grep -iE 'vga|3d|display' || true)"
        fi
        local has_nv=0 has_amd=0 has_intel=0
        printf '%s' "${vga}" | grep -qi 'nvidia' && has_nv=1
        printf '%s' "${vga}" | grep -qiE '(^|[^[:alnum:]])(amd|ati|radeon)([^[:alnum:]]|$)' && has_amd=1
        printf '%s' "${vga}" | grep -qi 'intel' && has_intel=1
        if [[ "${has_nv}" -eq 1 && ( "${has_intel}" -eq 1 || "${has_amd}" -eq 1 ) ]]; then
            GPU="hybrid"
        elif [[ "${has_nv}" -eq 1 ]]; then
            GPU="nvidia"
        elif [[ "${has_amd}" -eq 1 ]]; then
            GPU="amd"
        else
            GPU="intel"
        fi
        if [[ -n "${vga}" ]]; then
            GPU_NAME="$(printf '%s\n' "${vga}" | head -n1 | sed 's/.*: //' | cut -c1-48)"
        fi
    else
        GPU_NAME="Manual (${GPU})"
    fi

    CPU_MODEL="$(awk -F: '/model name/{gsub(/^[ \t]+/,"",$2); print $2; exit}' /proc/cpuinfo 2>/dev/null | cut -c1-44 || echo "Unknown CPU")"
    RAM_TOTAL="$(free -h 2>/dev/null | awk '/Mem:/{print $2}' || echo "?")"

    if [[ -z "${AUR_MODE}" ]]; then
        if command -v yay >/dev/null 2>&1; then
            AUR_MODE="yay"
        elif command -v paru >/dev/null 2>&1; then
            AUR_MODE="paru"
        else
            AUR_MODE="bootstrap"
        fi
    fi

    if [[ -f /etc/default/grub ]] && command -v grub-mkconfig >/dev/null 2>&1; then
        BOOTLOADER="grub"
    elif [[ -d /boot/loader ]]; then
        BOOTLOADER="systemd-boot"
    else
        BOOTLOADER="other"
    fi
}

do_uninstall() {
    local pkgs=(hypr quickshell systemd spotify fuzzel matugen kitty fastfetch zsh starship gtk qt btop scripts)
    step_header 1 2 "Stopping Mondlicht user services"
    for svc in mondlicht-quickshell mondlicht-cliphist-text mondlicht-cliphist-image mondlicht-polkit mondlicht-playerctld mondlicht-udiskie mondlicht-kwallet-pam hypridle; do
        run_cmd systemctl --user disable --now "${svc}.service" >/dev/null 2>&1 || true
    done
    step_header 2 2 "Unstowing Mondlicht symlinks"
    run_cmd stow -D -d "${REPO_DIR}" -t "${HOME}" "${pkgs[@]}"
    run_cmd rm -f "${HOME}/.config/hypr/host.lua"
    ok_msg "Done. Installed Arch packages and ~/.mondlicht-backup-* folders were kept intact."
}

if [[ "${UNINSTALL}" -eq 1 ]]; then
    do_uninstall
    exit 0
fi

detect_hardware

toggle_bool() { [[ "$1" -eq 1 ]] && echo 0 || echo 1; }

pill_bool() {
    if [[ "$1" -eq 1 ]]; then
        printf '%s● ON %s' "${C_OK}${C_BOLD}" "${C_RST}"
    else
        printf '%s○ OFF%s' "${C_DIM}" "${C_RST}"
    fi
}

show_menu() {
    [[ -t 1 ]] && clear || printf '\n'
    printf '%s╭──────────────────────────────────────────────────────────────────────╮%s\n' "${C_DIM}" "${C_RST}"
    printf '%s│%s  %s☽  Mondlicht Arch Installer%s   %sHyprland · Quickshell · Systemd%s       %s│%s\n' \
        "${C_DIM}" "${C_RST}" "${C_BOLD}${C_BLUE}" "${C_RST}" "${C_LAV}" "${C_RST}" "${C_DIM}" "${C_RST}"
    printf '%s├──────────────────────────────────────────────────────────────────────┤%s\n' "${C_DIM}" "${C_RST}"
    printf '  %sSystem%s : %s · %s RAM · Boot: %s\n' "${C_DIM}" "${C_RST}" "${CPU_MODEL}" "${RAM_TOTAL}" "${BOOTLOADER}"
    printf '  %sGPU%s    : %s\n' "${C_DIM}" "${C_RST}" "${GPU_NAME}"
    printf '  %sRepo%s   : %s\n' "${C_DIM}" "${C_RST}" "${REPO_DIR}"
    printf '%s├──────────────────────────────────────────────────────────────────────┤%s\n' "${C_DIM}" "${C_RST}"
    printf '  %s[1]%s Machine Profile   : %s%-16s%s  %s(pc | laptop | laptop-hidpi)%s\n' "${C_BLUE}" "${C_RST}" "${C_BOLD}${C_BLUE}" "${PROFILE}" "${C_RST}" "${C_DIM}" "${C_RST}"
    printf '  %s[2]%s GPU Preset        : %s%-16s%s  %s(intel | amd | nvidia | hybrid)%s\n' "${C_BLUE}" "${C_RST}" "${C_BOLD}${C_BLUE}" "${GPU}" "${C_RST}" "${C_DIM}" "${C_RST}"
    printf '  %s[3]%s Desktop & Apps    : %s   %sBrave, Antigravity, Spotify, TUI, KDE Connect%s\n' "${C_BLUE}" "${C_RST}" "$(pill_bool "${WITH_APPS}")" "${C_DIM}" "${C_RST}"
    printf '  %s[4]%s Laptop & Power    : %s   %sbrightnessctl, smartmontools%s\n' "${C_BLUE}" "${C_RST}" "$(pill_bool "${WITH_LAPTOP}")" "${C_DIM}" "${C_RST}"
    printf '  %s[5]%s Tuning & Debloat  : %s   %sBrave policy/VA-API, Spicetify, ZRAM, journald%s\n' "${C_BLUE}" "${C_RST}" "$(pill_bool "${WITH_TUNING}")" "${C_DIM}" "${C_RST}"
    printf '  %s[6]%s AUR Helper        : %s%-16s%s  %s(yay | paru | bootstrap | skip)%s\n' "${C_BLUE}" "${C_RST}" "${C_BOLD}${C_LAV}" "${AUR_MODE}" "${C_RST}" "${C_DIM}" "${C_RST}"
    printf '  %s[7]%s Boot & Lock Stack : %s   %sSDDM + Dark Mondlicht GRUB (needs sudo)%s\n' "${C_BLUE}" "${C_RST}" "$(pill_bool "${WITH_BOOT}")" "${C_DIM}" "${C_RST}"
    printf '  %s[8]%s Dry-Run Mode      : %s   %sSimulate without changing system%s\n' "${C_BLUE}" "${C_RST}" "$(pill_bool "${DRY_RUN}")" "${C_DIM}" "${C_RST}"
    printf '%s├──────────────────────────────────────────────────────────────────────┤%s\n' "${C_DIM}" "${C_RST}"
    printf '  %s[1-8]%s toggle   %s[i]%s install   %s[r]%s re-detect   %s[q]%s quit\n' \
        "${C_TXT}" "${C_DIM}" "${C_OK}${C_BOLD}" "${C_DIM}" "${C_BLUE}" "${C_DIM}" "${C_CRIT}" "${C_RST}"
    printf '%s╰──────────────────────────────────────────────────────────────────────╯%s\n' "${C_DIM}" "${C_RST}"
}

if [[ "${AUTO_YES}" -eq 0 ]]; then
    if [[ ! -t 0 ]]; then
        printf 'Non-interactive terminal detected; pass --yes to install cleanly.\n' >&2
        exit 1
    fi
    while true; do
        show_menu
        read -rp "  ${C_LAV}>${C_RST} Select option: " choice
        case "${choice}" in
            1)
                case "${PROFILE}" in
                    pc-standard)     PROFILE="laptop-standard" ;;
                    laptop-standard) PROFILE="laptop-hidpi" ;;
                    *)               PROFILE="pc-standard" ;;
                esac
                [[ "${LAPTOP_SET}" -eq 0 ]] && WITH_LAPTOP="$([[ "${PROFILE}" == laptop-* ]] && echo 1 || echo 0)"
                ;;
            2)
                case "${GPU}" in
                    intel)  GPU="amd" ;;
                    amd)    GPU="nvidia" ;;
                    nvidia) GPU="hybrid" ;;
                    *)      GPU="intel" ;;
                esac
                ;;
            3) WITH_APPS="$(toggle_bool "${WITH_APPS}")"; APPS_SET=1 ;;
            4) WITH_LAPTOP="$(toggle_bool "${WITH_LAPTOP}")"; LAPTOP_SET=1 ;;
            5) WITH_TUNING="$(toggle_bool "${WITH_TUNING}")"; TUNING_SET=1 ;;
            6)
                case "${AUR_MODE}" in
                    yay)       AUR_MODE="paru" ;;
                    paru)      AUR_MODE="bootstrap" ;;
                    bootstrap) AUR_MODE="skip" ;;
                    *)         AUR_MODE="yay" ;;
                esac
                ;;
            7) WITH_BOOT="$(toggle_bool "${WITH_BOOT}")" ;;
            8) DRY_RUN="$(toggle_bool "${DRY_RUN}")" ;;
            r|R)
                PROFILE=""; GPU=""; AUR_MODE=""; LAPTOP_SET=0
                detect_hardware
                ;;
            i|I) break ;;
            q|Q) printf '  %sAborted.%s\n' "${C_WARN}" "${C_RST}"; exit 0 ;;
            *) warn_msg "Invalid option: ${choice}"; sleep 0.6 ;;
        esac
    done
fi

# Gather packages
mapfile -t NATIVE_PKGS < <(read_pkg_file "${REPO_DIR}/packages/base.txt")
if [[ "${WITH_APPS}" -eq 1 ]]; then
    mapfile -t _app_pkgs < <(read_pkg_file "${REPO_DIR}/packages/apps.txt")
    NATIVE_PKGS+=("${_app_pkgs[@]}")
fi
if [[ "${WITH_LAPTOP}" -eq 1 ]]; then
    mapfile -t _lap_pkgs < <(read_pkg_file "${REPO_DIR}/packages/laptop.txt")
    NATIVE_PKGS+=("${_lap_pkgs[@]}")
    if [[ "${GPU}" == "intel" || "${GPU}" == "hybrid" ]]; then
        NATIVE_PKGS+=(thermald)
    fi
fi

case "${GPU}" in
    intel)  NATIVE_PKGS+=(vulkan-intel intel-media-driver libvpl vpl-gpu-rt) ;;
    amd)    NATIVE_PKGS+=(vulkan-radeon) ;;
    nvidia) NATIVE_PKGS+=(nvidia-utils) ;;
    hybrid) NATIVE_PKGS+=(vulkan-intel intel-media-driver nvidia-utils) ;;
esac

mapfile -t AUR_PKGS < <(read_pkg_file "${REPO_DIR}/packages/aur-base.txt")
if [[ "${WITH_APPS}" -eq 1 ]]; then
    mapfile -t _aur_apps < <(read_pkg_file "${REPO_DIR}/packages/aur-apps.txt")
    AUR_PKGS+=("${_aur_apps[@]}")
fi

step_header 1 6 "Installing official Arch packages (${#NATIVE_PKGS[@]} packages)"
run_cmd sudo pacman -S --needed --noconfirm "${NATIVE_PKGS[@]}"

step_header 2 6 "Handling AUR packages (mode: ${AUR_MODE}, ${#AUR_PKGS[@]} packages)"
if [[ "${AUR_MODE}" == "skip" ]]; then
    warn_msg "Skipping AUR packages (${AUR_PKGS[*]}). Install ttf-geist / ttf-geist-mono for Mondlicht typography."
else
    aur_bin="${AUR_MODE}"
    [[ "${aur_bin}" == "bootstrap" ]] && aur_bin="yay"
    if ! command -v "${aur_bin}" >/dev/null 2>&1; then
        info_msg "AUR helper '${aur_bin}' not found; bootstrapping ${aur_bin}-bin..."
        run_cmd sudo pacman -S --needed --noconfirm git base-devel
        if [[ "${DRY_RUN}" -eq 1 ]]; then
            printf '  %s[DRY-RUN]%s git clone https://aur.archlinux.org/%s-bin.git && makepkg -si\n' "${C_DIM}" "${C_RST}" "${aur_bin}"
        else
            TMP_AUR="$(mktemp -d)"
            trap 'rm -rf "${TMP_AUR}"' EXIT
            git clone --depth=1 "https://aur.archlinux.org/${aur_bin}-bin.git" "${TMP_AUR}/${aur_bin}-bin"
            (cd "${TMP_AUR}/${aur_bin}-bin" && makepkg -si --needed --noconfirm)
            rm -rf "${TMP_AUR}"
            trap - EXIT
        fi
    fi
    run_cmd "${aur_bin}" -S --needed --noconfirm "${AUR_PKGS[@]}"
fi

step_header 3 6 "Generating ~/.config/hypr/host.lua (${PROFILE} + gpu-${GPU})"
HOST_LUA="${HOME}/.config/hypr/host.lua"
if [[ "${DRY_RUN}" -eq 1 ]]; then
    printf '  %s[DRY-RUN]%s Combine hosts/%s.lua + hosts/gpu-%s.lua -> %s\n' "${C_DIM}" "${C_RST}" "${PROFILE}" "${GPU}" "${HOST_LUA}"
else
    mkdir -p "$(dirname "${HOST_LUA}")"
    [[ -f "${HOST_LUA}" ]] && cp -a "${HOST_LUA}" "${HOST_LUA}.bak"
    {
        printf -- '-- Generated by install.sh (%s + gpu-%s) - edit freely for this machine\n\n' "${PROFILE}" "${GPU}"
        cat "${REPO_DIR}/hosts/${PROFILE}.lua"
        printf '\n'
        cat "${REPO_DIR}/hosts/gpu-${GPU}.lua"
    } > "${HOST_LUA}"
    ok_msg "Wrote ${HOST_LUA}"
fi

step_header 4 6 "Applying Mondlicht dotfiles with GNU Stow"
if [[ "${DRY_RUN}" -eq 1 ]]; then
    "${REPO_DIR}/apply.sh" --dry-run
else
    "${REPO_DIR}/apply.sh"
fi

step_header 5 6 "Enabling core systemd services"
SERVICES=(NetworkManager bluetooth tuned tuned-ppd sddm)
[[ "${WITH_LAPTOP}" -eq 1 && ( "${GPU}" == "intel" || "${GPU}" == "hybrid" ) ]] && SERVICES+=(thermald)
for svc in "${SERVICES[@]}"; do
    run_cmd sudo systemctl enable "${svc}.service" || warn_msg "Failed to enable ${svc}.service (continuing)"
done

if [[ "${WITH_APPS}" -eq 1 ]]; then
    if [[ "${WITH_TUNING}" -eq 1 ]]; then
        run_cmd sudo systemctl disable --now docker.service cups.service >/dev/null 2>&1 || true
        run_cmd sudo systemctl enable docker.socket cups.socket || warn_msg "Failed to enable docker/cups sockets"
    else
        run_cmd sudo systemctl enable docker.service cups.service || warn_msg "Failed to enable docker/cups services"
    fi
    run_cmd sudo systemctl enable fwupd.service || true
    if command -v ufw >/dev/null 2>&1; then
        run_cmd sudo ufw allow 1714:1764/tcp comment 'KDE Connect' >/dev/null 2>&1 || true
        run_cmd sudo ufw allow 1714:1764/udp comment 'KDE Connect' >/dev/null 2>&1 || true
    fi
fi

step_header 6 6 "Applying system tuning & app debloat (tuning=$([[ "${WITH_TUNING}" -eq 1 ]] && echo on || echo off))"
if [[ "${WITH_TUNING}" -eq 1 ]]; then
    if pacman -Q swaync >/dev/null 2>&1; then
        run_cmd sudo pacman -Rns --noconfirm swaync || true
    fi
    run_cmd sudo systemctl disable NetworkManager-wait-online.service >/dev/null 2>&1 || true
    run_cmd sudo systemctl enable --now paccache.timer systemd-oomd.service avahi-daemon.socket >/dev/null 2>&1 || true

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        printf '  %s[DRY-RUN]%s Configure systemd-resolved, ZRAM sysctl, journald cap, Brave policy & VA-API flags\n' "${C_DIM}" "${C_RST}"
    else
        sudo mkdir -p /etc/NetworkManager/conf.d /etc/sysctl.d /etc/systemd/journald.conf.d
        printf '[main]\ndns=systemd-resolved\n' | sudo tee /etc/NetworkManager/conf.d/dns-systemd-resolved.conf >/dev/null
        sudo systemctl enable --now systemd-resolved.service
        sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        sudo systemctl reload NetworkManager.service >/dev/null 2>&1 || true

        cat <<'EOF' | sudo tee /etc/sysctl.d/99-mondlicht-zram.conf >/dev/null
vm.swappiness = 150
vm.page-cluster = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
EOF
        sudo sysctl --system >/dev/null

        printf '[Journal]\nSystemMaxUse=100M\n' | sudo tee /etc/systemd/journald.conf.d/99-mondlicht-size.conf >/dev/null
        sudo systemctl restart systemd-journald
        sudo journalctl --vacuum-size=100M >/dev/null 2>&1 || true

        if [[ "${WITH_APPS}" -eq 1 ]]; then
            sudo mkdir -p /etc/brave/policies/managed
            cat <<'EOF' | sudo tee /etc/brave/policies/managed/mondlicht-debloat.json >/dev/null
{
  "BraveRewardsDisabled": true,
  "BraveWalletDisabled": true,
  "BraveVPNDisabled": true,
  "BraveAIChatEnabled": false,
  "BraveNewsDisabled": true,
  "BraveTalkDisabled": true,
  "BackgroundModeEnabled": false,
  "MetricsReportingEnabled": false,
  "PromotionsEnabled": false,
  "ShoppingListEnabled": false
}
EOF
            if [[ "${GPU}" == "nvidia" ]]; then
                printf '%s\n' '--ozone-platform-hint=auto' > "${HOME}/.config/brave-flags.conf"
            else
                cat <<'EOF' > "${HOME}/.config/brave-flags.conf"
--ozone-platform-hint=auto
--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,UseOzonePlatform
--enable-gpu-rasterization
--enable-zero-copy
EOF
            fi

            if [[ -f "${HOME}/.config/spotify/prefs" ]] && ! grep -q '^storage\.size=' "${HOME}/.config/spotify/prefs"; then
                printf '\nstorage.size=512\n' >> "${HOME}/.config/spotify/prefs"
            fi
            SPOTIFY_DIR="${HOME}/.local/share/spotify-launcher/install/usr/share/spotify"
            SPOTIFY_PREFS="${HOME}/.config/spotify/prefs"
            if command -v spicetify >/dev/null 2>&1 && [[ -d "${SPOTIFY_DIR}" ]]; then
                spicetify config spotify_path "${SPOTIFY_DIR}"
                spicetify config prefs_path "${SPOTIFY_PREFS}"
                spicetify config current_theme Mondlicht
                spicetify config color_scheme ObsidianLuna
                spicetify config inject_css 1 replace_colors 1 overwrite_assets 0 inject_theme_js 0
                spicetify config disable_sentry 1 disable_ui_logging 1 remove_rtl_rule 1 expose_apis 1
                spicetify backup apply || true
            fi
        fi
        ok_msg "System tuning & Brave/Spotify debloat applied"
    fi
else
    info_msg "Tuning skipped (--no-tuning)"
fi

if [[ "${DRY_RUN}" -eq 0 && "${AUTO_YES}" -eq 0 ]] && [[ "${SHELL:-}" != */zsh ]] && command -v zsh >/dev/null 2>&1; then
    read -rp "  ${C_LAV}>${C_RST} Switch default login shell to Zsh? [y/N]: " chsh_ans
    if [[ "${chsh_ans}" =~ ^[Yy]$ ]]; then
        chsh -s "$(command -v zsh)"
    fi
fi

if [[ "${WITH_BOOT}" -eq 1 ]]; then
    printf '\n%s[Boot]%s Building and installing SDDM + GRUB Mondlicht theme...\n' "${C_LAV}${C_BOLD}" "${C_RST}"
    run_cmd "${REPO_DIR}/boot/build-grub-assets.sh"
    if [[ "${WITH_TUNING}" -eq 1 && "${BOOTLOADER}" == "grub" ]] && grep -q '^GRUB_TIMEOUT=5$' /etc/default/grub 2>/dev/null; then
        run_cmd sudo sed -i 's/^GRUB_TIMEOUT=5$/GRUB_TIMEOUT=2/' /etc/default/grub
    fi
    run_cmd sudo "${REPO_DIR}/boot/install-boot.sh" --profile "${PROFILE}"
fi

printf '\n%s╭──────────────────────────────────────────────────────────────────────╮%s\n' "${C_DIM}" "${C_RST}"
printf '%s│%s  %s✓ Mondlicht installation complete%s                                    %s│%s\n' \
    "${C_DIM}" "${C_RST}" "${C_OK}${C_BOLD}" "${C_RST}" "${C_DIM}" "${C_RST}"
printf '%s├──────────────────────────────────────────────────────────────────────┤%s\n' "${C_DIM}" "${C_RST}"
printf '  %sLaunchers%s  Cmd+Space (Apps/Calc)  ·  Cmd+, (Settings)  ·  Cmd+/\n' "${C_BLUE}" "${C_RST}"
printf '  %sCapture%s    Cmd+Shift+V (Clipboard) · Cmd+Shift+4/5 (Shot/Record)\n' "${C_BLUE}" "${C_RST}"
printf '  %sNext%s       Log out or reboot to start Hyprland via SDDM\n' "${C_BLUE}" "${C_RST}"
if [[ "${GPU}" == "nvidia" || "${GPU}" == "hybrid" ]]; then
    printf '  %sNVIDIA%s     Verify kernel driver (nvidia-open/dkms) & drm_kms_helper modeset=1\n' "${C_WARN}" "${C_RST}"
fi
printf '%s╰──────────────────────────────────────────────────────────────────────╯%s\n' "${C_DIM}" "${C_RST}"
