#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
    printf 'Run install.sh as your normal user, not root (sudo will be requested only when needed).\n' >&2
    exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults populated by detect_hardware and overridable via CLI or interactive menu
PROFILE=""
GPU=""
WITH_APPS=1
WITH_LAPTOP=""
AUR_MODE=""
WITH_BOOT=0
DRY_RUN=0
AUTO_YES=0
UNINSTALL=0
BOOTLOADER="unknown"
APPS_SET=0
LAPTOP_SET=0

usage() {
    cat <<'EOF'
Mondlicht Arch Linux Installer (Hyprland + Quickshell)

Usage: ./install.sh [options]

Options:
  --profile <name>    pc-standard | laptop-standard | laptop-hidpi
  --gpu <vendor>      intel | amd | nvidia | hybrid
  --with-apps         Install daily & dev apps group (Brave, Antigravity, Spotify, Docker, CUPS)
  --no-apps           Skip optional apps group (install core desktop only)
  --with-laptop       Install laptop packages (brightnessctl, smartmontools)
  --no-laptop         Skip laptop packages
  --aur <mode>        yay | paru | bootstrap | skip
  --with-boot         Install SDDM + Dark Mondlicht GRUB theme (requires sudo)
  --dry-run           Simulate actions without modifying packages or files
  --yes               Skip interactive menu and proceed with detected/selected options
  --uninstall         Unstow Mondlicht symlinks and remove ~/.config/hypr/host.lua
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
        --aur)          AUR_MODE="${2:-}"; validate_aur "${AUR_MODE}"; shift 2 ;;
        --with-boot)    WITH_BOOT=1; shift ;;
        --dry-run|-n)   DRY_RUN=1; shift ;;
        --yes|-y)       AUTO_YES=1; shift ;;
        --uninstall)    UNINSTALL=1; shift ;;
        -h|--help)      usage; exit 0 ;;
        *)              printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
    esac
done

run_cmd() {
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        printf '[DRY-RUN] %s\n' "$*"
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
        printf '%s' "${vga}" | grep -qiE 'amd|ati|radeon' && has_amd=1
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
    fi

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
    local pkgs=(hypr quickshell fuzzel matugen kitty fastfetch zsh starship gtk qt btop scripts)
    printf 'Uninstalling Mondlicht symlinks...\n'
    run_cmd stow -D -d "${REPO_DIR}" -t "${HOME}" "${pkgs[@]}"
    run_cmd rm -f "${HOME}/.config/hypr/host.lua"
    printf 'Done. Installed Arch packages and ~/.mondlicht-backup-* folders were kept intact.\n'
}

if [[ "${UNINSTALL}" -eq 1 ]]; then
    do_uninstall
    exit 0
fi

detect_hardware

toggle_bool() { [[ "$1" -eq 1 ]] && echo 0 || echo 1; }
fmt_on() { [[ "$1" -eq 1 ]] && echo "[x] ON" || echo "[ ] OFF"; }

show_menu() {
    printf '\n============================================================\n'
    printf '  Mondlicht Installer (Arch Linux | Hyprland + Quickshell)\n'
    printf '  Repo: %s\n' "${REPO_DIR}"
    printf '============================================================\n'
    printf '  [1] Machine Profile   : %s (pc-standard | laptop-standard | laptop-hidpi)\n' "${PROFILE}"
    printf '  [2] GPU Preset        : %s (intel | amd | nvidia | hybrid)\n' "${GPU}"
    printf '  [3] Apps Group        : %s (Brave, Antigravity, Spotify, Docker, KDE, CUPS)\n' "$(fmt_on "${WITH_APPS}")"
    printf '  [4] Laptop Utilities  : %s (brightnessctl, smartmontools)\n' "$(fmt_on "${WITH_LAPTOP}")"
    printf '  [5] AUR Helper        : %s (yay | paru | skip - auto-bootstraps if missing)\n' "${AUR_MODE}"
    printf '  [6] Boot & Lock Stack : %s (SDDM + Dark GRUB [detected: %s], needs sudo)\n' "$(fmt_on "${WITH_BOOT}")" "${BOOTLOADER}"
    printf '  [7] Dry-Run Mode      : %s\n' "$(fmt_on "${DRY_RUN}")"
    printf -- '------------------------------------------------------------\n'
    printf '  [i] Install Now       [r] Re-detect Hardware       [q] Quit\n'
    printf '============================================================\n'
}

if [[ "${AUTO_YES}" -eq 0 ]]; then
    if [[ ! -t 0 ]]; then
        printf 'Non-interactive terminal detected; pass --yes to install cleanly.\n' >&2
        exit 1
    fi
    while true; do
        show_menu
        read -rp 'Select option [1-7, i, r, q]: ' choice
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
            5)
                case "${AUR_MODE}" in
                    yay)       AUR_MODE="paru" ;;
                    paru)      AUR_MODE="bootstrap" ;;
                    bootstrap) AUR_MODE="skip" ;;
                    *)         AUR_MODE="yay" ;;
                esac
                ;;
            6) WITH_BOOT="$(toggle_bool "${WITH_BOOT}")" ;;
            7) DRY_RUN="$(toggle_bool "${DRY_RUN}")" ;;
            r|R)
                PROFILE=""; GPU=""; AUR_MODE=""; LAPTOP_SET=0
                detect_hardware
                ;;
            i|I) break ;;
            q|Q) printf 'Aborted.\n'; exit 0 ;;
            *) printf 'Invalid option: %s\n' "${choice}" ;;
        esac
    done
fi

# Phase 3: Gather & install packages
mapfile -t NATIVE_PKGS < <(read_pkg_file "${REPO_DIR}/packages/base.txt")
if [[ "${WITH_APPS}" -eq 1 ]]; then
    mapfile -t _app_pkgs < <(read_pkg_file "${REPO_DIR}/packages/apps.txt")
    NATIVE_PKGS+=("${_app_pkgs[@]}")
fi
if [[ "${WITH_LAPTOP}" -eq 1 ]]; then
    mapfile -t _lap_pkgs < <(read_pkg_file "${REPO_DIR}/packages/laptop.txt")
    NATIVE_PKGS+=("${_lap_pkgs[@]}")
fi

case "${GPU}" in
    intel)  NATIVE_PKGS+=(vulkan-intel intel-media-driver libva-intel-driver libvpl vpl-gpu-rt) ;;
    amd)    NATIVE_PKGS+=(vulkan-radeon) ;;
    nvidia) NATIVE_PKGS+=(nvidia-utils) ;;
    hybrid) NATIVE_PKGS+=(vulkan-intel intel-media-driver nvidia-utils) ;;
esac

mapfile -t AUR_PKGS < <(read_pkg_file "${REPO_DIR}/packages/aur-base.txt")
if [[ "${WITH_APPS}" -eq 1 ]]; then
    mapfile -t _aur_apps < <(read_pkg_file "${REPO_DIR}/packages/aur-apps.txt")
    AUR_PKGS+=("${_aur_apps[@]}")
fi

printf '\n[1/5] Installing official Arch packages (%d packages)...\n' "${#NATIVE_PKGS[@]}"
run_cmd sudo pacman -S --needed --noconfirm "${NATIVE_PKGS[@]}"

printf '\n[2/5] Handling AUR packages (mode: %s, %d packages)...\n' "${AUR_MODE}" "${#AUR_PKGS[@]}"
if [[ "${AUR_MODE}" == "skip" ]]; then
    printf 'Skipping AUR packages (%s). Note: ttf-geist / ttf-geist-mono are recommended for Mondlicht typography.\n' "${AUR_PKGS[*]}"
else
    aur_bin="${AUR_MODE}"
    [[ "${aur_bin}" == "bootstrap" ]] && aur_bin="yay"
    if ! command -v "${aur_bin}" >/dev/null 2>&1; then
        printf 'AUR helper "%s" not found; bootstrapping %s-bin...\n' "${aur_bin}" "${aur_bin}"
        run_cmd sudo pacman -S --needed --noconfirm git base-devel
        if [[ "${DRY_RUN}" -eq 1 ]]; then
            printf '[DRY-RUN] git clone https://aur.archlinux.org/%s-bin.git <tmp>/%s-bin && makepkg -si --needed --noconfirm\n' "${aur_bin}" "${aur_bin}"
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

# Phase 4: Generate machine-local ~/.config/hypr/host.lua
printf '\n[3/5] Writing ~/.config/hypr/host.lua (%s + gpu-%s)...\n' "${PROFILE}" "${GPU}"
HOST_LUA="${HOME}/.config/hypr/host.lua"
if [[ "${DRY_RUN}" -eq 1 ]]; then
    printf '[DRY-RUN] Combine hosts/%s.lua + hosts/gpu-%s.lua -> %s\n' "${PROFILE}" "${GPU}" "${HOST_LUA}"
else
    mkdir -p "$(dirname "${HOST_LUA}")"
    if [[ -f "${HOST_LUA}" ]]; then
        cp -a "${HOST_LUA}" "${HOST_LUA}.bak"
    fi
    {
        printf -- '-- Generated by install.sh (%s + gpu-%s) - edit freely for this machine\n\n' "${PROFILE}" "${GPU}"
        cat "${REPO_DIR}/hosts/${PROFILE}.lua"
        printf '\n'
        cat "${REPO_DIR}/hosts/gpu-${GPU}.lua"
    } > "${HOST_LUA}"
fi

# Phase 5: Safe stow + session apply
printf '\n[4/5] Applying Mondlicht dotfiles with GNU Stow...\n'
if [[ "${DRY_RUN}" -eq 1 ]]; then
    "${REPO_DIR}/apply.sh" --dry-run
else
    "${REPO_DIR}/apply.sh"
fi

# Phase 6: Enable services + shell
printf '\n[5/5] Enabling core systemd services...\n'
SERVICES=(NetworkManager bluetooth tuned tuned-ppd sddm)
[[ "${WITH_APPS}" -eq 1 ]] && SERVICES+=(docker cups)
for svc in "${SERVICES[@]}"; do
    run_cmd sudo systemctl enable "${svc}.service" || printf 'Warning: failed to enable %s.service (continuing)\n' "${svc}" >&2
done

if [[ "${DRY_RUN}" -eq 0 && "${AUTO_YES}" -eq 0 ]] && [[ "${SHELL:-}" != */zsh ]] && command -v zsh >/dev/null 2>&1; then
    read -rp 'Switch default login shell to Zsh? [y/N]: ' chsh_ans
    if [[ "${chsh_ans}" =~ ^[Yy]$ ]]; then
        chsh -s "$(command -v zsh)"
    fi
fi

# Phase 7: Optional boot stack (SDDM + GRUB)
if [[ "${WITH_BOOT}" -eq 1 ]]; then
    printf '\n[Boot] Building and installing SDDM + GRUB Mondlicht theme...\n'
    run_cmd "${REPO_DIR}/boot/build-grub-assets.sh"
    run_cmd sudo "${REPO_DIR}/boot/install-boot.sh" --profile "${PROFILE}"
fi

printf '\nMondlicht installation complete! Log out or reboot to start Hyprland via SDDM.\n'
if [[ "${GPU}" == "nvidia" || "${GPU}" == "hybrid" ]]; then
    printf 'Note (NVIDIA): ensure your kernel driver package (nvidia-open / nvidia-lts / dkms) and DRM KMS modeset=1 are installed for your kernel.\n'
fi
