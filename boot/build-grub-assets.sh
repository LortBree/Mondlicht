#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/grub/mondlicht"
mkdir -p "${OUT_DIR}"

UI_FONT="/usr/share/fonts/TTF/Geist-Regular.ttf"
[[ -f "${UI_FONT}" ]] || UI_FONT="/usr/share/fonts/TTF/DejaVuSans.ttf"

HEADER_FONT="/usr/share/fonts/TTF/Geist-Light.ttf"
[[ -f "${HEADER_FONT}" ]] || HEADER_FONT="${UI_FONT}"

MONO_FONT="/usr/share/fonts/TTF/GeistMono-Regular.ttf"
[[ -f "${MONO_FONT}" ]] || MONO_FONT="/usr/share/fonts/TTF/DejaVuSansMono.ttf"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# 1. Dark Mondlicht background (2160x1440) - subtle moonlight core fading into volcanic obsidian #06070B
magick -size 2160x1440 radial-gradient:"#101524-#06070B" "${TMP_DIR}/bg_base.png"

# Minimalist crescent moon emblem with soft lunar-blue glow
magick -size 84x84 xc:none \
    -fill "rgba(220,228,247,0.95)" \
    -draw "circle 42,42 42,16" \
    \( -size 84x84 xc:none -fill white -draw "circle 53,35 53,11" \) \
    -compose DstOut -composite \
    "${TMP_DIR}/crescent_core.png"

magick "${TMP_DIR}/crescent_core.png" \
    -fill "#B7C4FF" -colorize 100% \
    -blur 0x8 -channel A -evaluate multiply 0.42 +channel \
    "${TMP_DIR}/crescent_glow.png"

magick "${TMP_DIR}/crescent_glow.png" "${TMP_DIR}/crescent_core.png" \
    -compose Over -composite "${TMP_DIR}/crescent.png"

magick "${TMP_DIR}/bg_base.png" \
    "${TMP_DIR}/crescent.png" -gravity north -geometry +0+204 -compose Over -composite \
    -gravity north -font "${HEADER_FONT}" -pointsize 42 -kerning 4 \
    -fill "rgba(220,228,247,0.94)" -annotate +0+312 "Mondlicht" \
    -depth 8 "PNG32:${OUT_DIR}/background.png"

# 2. Frosted dark obsidian 240x60 highlight card + left lunar accent pill, sliced into 12/36/12 9-patch PNGs
magick -size 240x60 xc:none \
    -fill "rgba(22,27,44,0.88)" \
    -stroke "rgba(220,228,247,0.16)" -strokewidth 1.5 \
    -draw "roundrectangle 1,1 238,58 10,10" \
    -fill "rgba(183,196,255,0.95)" -stroke none \
    -draw "roundrectangle 9,14 12,45 1.5,1.5" \
    -depth 8 "PNG32:${TMP_DIR}/select_full.png"

slice_tile() {
    local name="$1" geom="$2"
    magick "${TMP_DIR}/select_full.png" -crop "${geom}" +repage -depth 8 "PNG32:${OUT_DIR}/select_${name}.png"
}

slice_tile nw "24x12+0+0"
slice_tile n  "192x12+24+0"
slice_tile ne "24x12+216+0"
slice_tile w  "24x36+0+12"
slice_tile c  "192x36+24+12"
slice_tile e  "24x36+216+12"
slice_tile sw "24x12+0+48"
slice_tile s  "192x12+24+48"
slice_tile se "24x12+216+48"

# 3. HiDPI PF2 bitmap fonts (exact embedded font names verified via -v)
grub-mkfont -v -n "Geist" -s 26 -r 0x20-0x7e -o "${OUT_DIR}/geist_26.pf2" "${UI_FONT}"
grub-mkfont -v -n "Geist Mono" -s 16 -r 0x20-0x7e -o "${OUT_DIR}/geist_mono_16.pf2" "${MONO_FONT}"

printf 'Built Dark Mondlicht GRUB assets in %s\n' "${OUT_DIR}"
