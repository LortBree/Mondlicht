#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    printf 'Run with sudo: sudo %s [--profile pc-standard|laptop-standard|laptop-hidpi]\n' "$0" >&2
    exit 1
fi

PROFILE="pc-standard"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            PROFILE="${2:-}"
            shift 2
            ;;
        -h|--help)
            printf 'Usage: sudo %s [--profile pc-standard|laptop-standard|laptop-hidpi]\n' "$0"
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            exit 1
            ;;
    esac
done

case "${PROFILE}" in
    pc-standard|laptop-standard)
        QT_ENV="QT_SCREEN_SCALE_FACTORS=1.0,QT_FONT_DPI=96"
        GRUB_MODE="auto"
        ;;
    laptop-hidpi)
        QT_ENV="QT_SCREEN_SCALE_FACTORS=1.5,QT_FONT_DPI=144"
        GRUB_MODE="2160x1440,auto"
        ;;
    *)
        printf 'Invalid profile: %s\n' "${PROFILE}" >&2
        exit 1
        ;;
esac

BOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"
USER_HOME=""
if [[ -n "${TARGET_USER}" ]]; then
    USER_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
fi

# 1. Install SDDM Mondlicht Qt6 theme
SDDM_DEST="/usr/share/sddm/themes/mondlicht"
mkdir -p "${SDDM_DEST}" /etc/sddm.conf.d
cp -f "${BOOT_DIR}/sddm/mondlicht/metadata.desktop" \
      "${BOOT_DIR}/sddm/mondlicht/theme.conf" \
      "${BOOT_DIR}/sddm/mondlicht/Main.qml" \
      "${SDDM_DEST}/"

WALL_SRC=""
if [[ -n "${USER_HOME}" && -f "${USER_HOME}/.cache/current-wallpaper" ]]; then
    cached="$(cat "${USER_HOME}/.cache/current-wallpaper")"
    [[ -f "${cached}" ]] && WALL_SRC="${cached}"
fi
if [[ -z "${WALL_SRC}" && -n "${USER_HOME}" && -f "${USER_HOME}/Pictures/Wallpapers/mondlicht-eclipse.png" ]]; then
    WALL_SRC="${USER_HOME}/Pictures/Wallpapers/mondlicht-eclipse.png"
fi
if [[ -z "${WALL_SRC}" && -f "${BOOT_DIR}/grub/mondlicht/background.png" ]]; then
    WALL_SRC="${BOOT_DIR}/grub/mondlicht/background.png"
fi
if [[ -n "${WALL_SRC}" ]]; then
    cp -f "${WALL_SRC}" "${SDDM_DEST}/wallpaper.png"
fi
chmod -R a+rX "${SDDM_DEST}"

cat > /etc/sddm.conf.d/mondlicht.conf <<EOF
[Theme]
Current=mondlicht
CursorTheme=capitaine-cursors
CursorSize=24

[Wayland]
EnableHiDPI=true

[X11]
EnableHiDPI=true

[General]
GreeterEnvironment=${QT_ENV}
EOF

# 2. Configure optional quiet UKI / kernel printk flags cleanly
SILENT_ARGS="quiet loglevel=3 rd.udev.log_level=3 udev.log_level=3 rd.systemd.show_status=auto systemd.show_status=auto vt.global_cursor_default=0"
CMDLINE_CHANGED=0

if [[ -f /etc/kernel/cmdline ]]; then
    if [[ ! -f /etc/kernel/cmdline.mondlicht-bak ]]; then
        cp -a /etc/kernel/cmdline /etc/kernel/cmdline.mondlicht-bak
    fi

    BEFORE_CMDLINE="$(cat /etc/kernel/cmdline)"
    python3 - /etc/kernel/cmdline "${SILENT_ARGS}" <<'PY'
import sys

path, silent_args = sys.argv[1], sys.argv[2]
drop_exact = {"quiet"}
drop_prefixes = (
    "loglevel=",
    "rd.udev.log_level=",
    "udev.log_level=",
    "rd.systemd.show_status=",
    "systemd.show_status=",
    "vt.global_cursor_default=",
)

with open(path, "r", encoding="utf-8") as fh:
    tokens = fh.read().strip().split()

kept = [
    tok for tok in tokens
    if tok not in drop_exact and not tok.startswith(drop_prefixes)
]
updated = " ".join(kept + silent_args.split()) + "\n"
with open(path, "w", encoding="utf-8") as fh:
    fh.write(updated)
PY
    AFTER_CMDLINE="$(cat /etc/kernel/cmdline)"
    [[ "${BEFORE_CMDLINE}" != "${AFTER_CMDLINE}" ]] && CMDLINE_CHANGED=1
fi

mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/20-quiet-printk.conf <<'EOF'
kernel.printk = 3 3 3 3
EOF

if [[ "${CMDLINE_CHANGED}" -eq 1 ]] && command -v mkinitcpio >/dev/null 2>&1; then
    mkinitcpio -P
fi

# 3. Install Dark Mondlicht GRUB theme when GRUB is present (skip cleanly for systemd-boot)
if command -v grub-mkconfig >/dev/null 2>&1 && [[ -f /etc/default/grub ]]; then
    if [[ ! -f "${BOOT_DIR}/grub/mondlicht/background.png" ]]; then
        printf 'GRUB assets missing. Run %s/build-grub-assets.sh as your normal user first.\n' "${BOOT_DIR}" >&2
        exit 1
    fi

    GRUB_DEST="/boot/grub/themes/mondlicht"
    rm -rf "${GRUB_DEST}"
    mkdir -p "${GRUB_DEST}"
    cp -rf "${BOOT_DIR}/grub/mondlicht/." "${GRUB_DEST}/"
    chmod -R a+rX "${GRUB_DEST}"

    if [[ ! -f /etc/default/grub.mondlicht-bak ]]; then
        cp -a /etc/default/grub /etc/default/grub.mondlicht-bak
    fi

    set_grub_var() {
        local key="$1" val="$2" file="/etc/default/grub"
        if grep -qE "^#?${key}=" "${file}"; then
            sed -i -E "s|^#?${key}=.*|${key}=${val}|" "${file}"
        else
            printf '%s=%s\n' "${key}" "${val}" >> "${file}"
        fi
    }

    set_grub_var "GRUB_THEME" "\"${GRUB_DEST}/theme.txt\""
    set_grub_var "GRUB_GFXMODE" "${GRUB_MODE}"
    set_grub_var "GRUB_GFXPAYLOAD_LINUX" "keep"
    set_grub_var "GRUB_TIMEOUT" "5"
    set_grub_var "GRUB_TIMEOUT_STYLE" "menu"
    set_grub_var "GRUB_DISABLE_SUBMENU" "y"
    set_grub_var "GRUB_CMDLINE_LINUX_DEFAULT" "\"${SILENT_ARGS}\""
    sed -i -E 's|^GRUB_TERMINAL_OUTPUT=console|#GRUB_TERMINAL_OUTPUT=console|' /etc/default/grub

    grub-mkconfig -o /boot/grub/grub.cfg
    grep -q "mondlicht/theme.txt" /boot/grub/grub.cfg
    printf 'SDDM and Dark Minimalist GRUB Mondlicht configured (%s).\n' "${PROFILE}"
else
    printf '[skip] GRUB not detected (e.g. systemd-boot); SDDM Mondlicht configured (%s).\n' "${PROFILE}"
fi
