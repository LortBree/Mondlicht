#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ONLY=0
[[ "${1:-}" == "--repo-only" ]] && REPO_ONLY=1

pass=0
fail=0

check() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf '[PASS] %s\n' "${label}"
        pass=$((pass + 1))
    else
        printf '[FAIL] %s\n' "${label}" >&2
        fail=$((fail + 1))
    fi
}

# 1. Shell script syntax checks
for shfile in \
    "${DOTFILES_DIR}/install.sh" \
    "${DOTFILES_DIR}/apply.sh" \
    "${DOTFILES_DIR}/test-dotfiles.sh" \
    "${DOTFILES_DIR}/boot/build-grub-assets.sh" \
    "${DOTFILES_DIR}/boot/install-boot.sh" \
    "${DOTFILES_DIR}/scripts/.local/bin/"*; do
    check "bash -n $(basename "${shfile}")" bash -n "${shfile}"
done

# 2. Config, Boot & Multi-Host sanity checks
check "fastfetch config.jsonc valid JSON" python3 -c "import json; json.load(open('${DOTFILES_DIR}/fastfetch/.config/fastfetch/config.jsonc'))"
check "matugen config.toml valid TOML" python3 -c "import tomllib; tomllib.load(open('${DOTFILES_DIR}/matugen/.config/matugen/config.toml', 'rb'))"
check "SDDM Main.qml centered passBox & no hardcoded username" bash -c "grep -q 'id: passBox' '${DOTFILES_DIR}/boot/sddm/mondlicht/Main.qml' && grep -q 'anchors.left: passBox.right' '${DOTFILES_DIR}/boot/sddm/mondlicht/Main.qml' && ! grep -q '\"bree\"' '${DOTFILES_DIR}/boot/sddm/mondlicht/Main.qml'"
check "GRUB theme.txt uses Dark Mondlicht & Geist PF2" bash -c "grep -q 'desktop-color: \"#06070B\"' '${DOTFILES_DIR}/boot/grub/mondlicht/theme.txt' && grep -q 'selected_item_color = \"#DCE4F7\"' '${DOTFILES_DIR}/boot/grub/mondlicht/theme.txt' && grep -q 'Geist Regular 26' '${DOTFILES_DIR}/boot/grub/mondlicht/theme.txt'"
check "Hyprlock matches SDDM rounding 8" bash -c "grep -q 'rounding = 8' '${DOTFILES_DIR}/hypr/.config/hypr/hyprlock.conf'"
check "QuickSettingsPanel supports optional backlight" bash -c "grep -q 'hasBacklight' '${DOTFILES_DIR}/quickshell/.config/quickshell/mondlicht/QuickSettingsPanel.qml' && grep -q 'Quickshell.Bluetooth' '${DOTFILES_DIR}/quickshell/.config/quickshell/mondlicht/QuickSettingsPanel.qml'"
check "hyprland.lua loads optional host module via pcall" bash -c "grep -q 'pcall(require, \"host\")' '${DOTFILES_DIR}/hypr/.config/hypr/hyprland.lua' && ! grep -q 'eDP-1' '${DOTFILES_DIR}/hypr/.config/hypr/hyprland.lua'"
LEAK_PATTERN='/home/''bree|"br''ee"|obsidian-''luna|Rei-''Obsidian|is''kra|ис''кра'
check "No personal path or legacy leaks" bash -c "! grep -rn -iE '${LEAK_PATTERN}' '${DOTFILES_DIR}' --exclude-dir=.git --exclude='*.png' --exclude='*.pf2'"

for hostfile in pc-standard laptop-standard laptop-hidpi gpu-intel gpu-amd gpu-nvidia gpu-hybrid; do
    check "host preset ${hostfile}.lua" test -s "${DOTFILES_DIR}/hosts/${hostfile}.lua"
done
for pkgfile in base apps laptop aur-base aur-apps; do
    check "package list ${pkgfile}.txt" test -s "${DOTFILES_DIR}/packages/${pkgfile}.txt"
done

check "install.sh --dry-run (pc-standard + nvidia)" "${DOTFILES_DIR}/install.sh" --profile pc-standard --gpu nvidia --with-apps --with-boot --dry-run --yes
check "install.sh --dry-run (laptop-hidpi + intel)" "${DOTFILES_DIR}/install.sh" --profile laptop-hidpi --gpu intel --with-apps --dry-run --yes

if [[ "${REPO_ONLY}" -eq 0 ]]; then
    for asset in background.png geist_26.pf2 geist_mono_16.pf2 select_nw.png select_n.png select_ne.png select_w.png select_c.png select_e.png select_sw.png select_s.png select_se.png; do
        check "GRUB asset ${asset}" test -s "${DOTFILES_DIR}/boot/grub/mondlicht/${asset}"
    done

    EXPECTED_LINKS=(
        ".config/hypr/hyprland.lua"
        ".config/hypr/hypridle.conf"
        ".config/hypr/hyprlock.conf"
        ".config/quickshell/mondlicht/shell.qml"
        ".config/quickshell/mondlicht/Theme.qml"
        ".config/quickshell/mondlicht/QuickSettingsPanel.qml"
        ".config/fuzzel/fuzzel.ini"
        ".config/matugen/config.toml"
        ".config/kitty/kitty.conf"
        ".config/btop/btop.conf"
        ".config/btop/themes/mondlicht.theme"
        ".zshrc"
        ".local/bin/set-wall"
    )
    for rel in "${EXPECTED_LINKS[@]}"; do
        check "symlink ~/${rel}" test -L "${HOME}/${rel}"
    done

    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        check "hyprctl no config errors" bash -c "[[ -z \"\$(hyprctl configerrors 2>/dev/null | tr -d '[:space:]')\" ]]"
        check "quickshell mondlicht running" pgrep -x qs
        check "quickshell IPC reachable" qs -c mondlicht ipc show
    fi
fi

printf '\nSummary: %d passed, %d failed\n' "${pass}" "${fail}"
[[ "${fail}" -eq 0 ]]
