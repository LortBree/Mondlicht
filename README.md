# Mondlicht

Minimalist volcanic smoked-glass (`#08090E`) and moonlight (`#DCE4F7` / `#B7C4FF`) desktop environment for **Arch Linux**, built on **Hyprland `0.57+` (pure Lua)** and **Quickshell `0.3+`**, managed with **GNU Stow**, **matugen v4**, and an interactive `archinstall`-style installer.

Works out of the box across both **desktop PCs** (NVIDIA / AMD / Intel, multi-monitor, no battery/backlight) and **laptops** (standard DPI or HiDPI, GNOME-style 3-finger touchpad gestures).

## Features

- **Unified Quickshell (`qs -c mondlicht`):** auto-hiding Top Capsule (Clock + Calendar + MPRIS Media + Notes), Left Workspaces Rail, Right Status Sidebar, bottom macOS/GNOME Dash Dock, and click-through Volume/Brightness OSD pill.
- **Native Win11-Style Quick Settings:** inline pages for Wi-Fi (`nmcli`), Bluetooth (`Quickshell.Bluetooth`), Sound Output (`Pipewire`), Power Profiles (`tuned-ppd`), and automatic backlight hiding on desktops without `/sys/class/backlight/*`.
- **Keyboard & Gesture Navigation:** macOS-friendly `Super` (`Cmd`) shortcuts, `Cmd+Tab` / `Alt+Tab` live window Overview with MRU ordering, `Cmd+/` interactive shortcut & package guide modal, and 3-finger swipe navigation on laptops.
- **Dynamic Accent Pipeline (`awww` + `matugen v4`):** changing wallpaper updates Hyprland, Hyprlock, Quickshell, Fuzzel, Kitty, and GTK 3/4 accents live while anchoring dark obsidian surfaces.
- **Optional Boot & Lock Stack:** matching Qt6 SDDM theme (clock-first curtain with centered login card), Hyprlock lockscreen, and Dark Minimalist GRUB2 crescent moon theme (`--with-boot`).

## Quick Install (Arch Linux)

```bash
git clone <your-repo-url> ~/Projects/mondlicht
cd ~/Projects/mondlicht
./install.sh
```

`install.sh` launches an interactive dashboard menu where hardware is auto-detected and every choice can be toggled before installing:

1. **Machine Profile:** `pc-standard`, `laptop-standard`, or `laptop-hidpi`
2. **GPU Preset:** `intel`, `amd`, `nvidia`, or `hybrid`
3. **Apps Group:** optional daily/dev stack (`brave-bin`, `antigravity*`, `spotify-launcher`, `docker`, `dolphin`, `okular`, `cups`)
4. **Laptop Utilities:** `brightnessctl`, `smartmontools`
5. **AUR Helper:** auto-detected `yay` / `paru`, bootstrap `yay-bin`, or skip
6. **Boot Stack:** optional SDDM + Dark Mondlicht GRUB theme (`sudo`)

### Non-Interactive & Simulation Flags

```bash
# Dry-run simulation on a desktop PC with NVIDIA
./install.sh --profile pc-standard --gpu nvidia --with-apps --with-boot --dry-run --yes

# Automated install on a HiDPI Intel laptop (core packages only)
./install.sh --profile laptop-hidpi --gpu intel --no-apps --with-boot --yes

# Daily sync after pulling updates
./apply.sh

# Remove symlinks and generated host.lua cleanly
./install.sh --uninstall
```

## Multi-Host Customization (`host.lua`)

Machine-specific monitor layouts and GPU environment variables are written by `install.sh` to `~/.config/hypr/host.lua` (gitignored), while `hypr/.config/hypr/hyprland.lua` loads it via `pcall(require, "host")`. That keeps `git pull` completely conflict-free between your desktop PC and laptop.

To add dual monitors on a PC, run `hyprctl monitors all` and edit `~/.config/hypr/host.lua` following the commented examples in `hosts/pc-standard.lua`.

## Repository Layout

```text
mondlicht/
├── install.sh              # Interactive + scripted Arch installer (7 phases)
├── apply.sh                # GNU Stow symlink sync + safe conflict backup + reload
├── test-dotfiles.sh        # Repo/CLI self-checks (--repo-only) and live checks
├── packages/               # Modular native & AUR package lists
├── hosts/                  # Monitor profiles & GPU environment presets
├── boot/                   # SDDM Qt6 theme, Dark GRUB asset builder & installer
├── hypr/                   # Hyprland Lua, hypridle, hyprlock, autostart overrides
├── quickshell/             # Complete Mondlicht QML shell modules
├── matugen/                # matugen v4 config & color templates
├── fuzzel/ kitty/ btop/    # Launcher, terminal & system monitor configs
├── zsh/ starship/          # Lean Zsh + Starship prompt
├── gtk/ qt/                # GTK 3/4 + Qt5ct/Qt6ct + KDE Breeze Dark palette
├── fastfetch/              # Minimal system fetch config
└── scripts/                # set-wall, screenshot, clip-pick, night-light, power-menu
```

## Verification

Run repository-only checks before installing on a fresh system:

```bash
./test-dotfiles.sh --repo-only
```

Note: Installing AUR packages (`packages/aur-base.txt`, `packages/aur-apps.txt`) builds from AUR (`yay`/`paru`), and NVIDIA setups require matching kernel driver modules (`nvidia-open` / `nvidia-lts` / `nvidia-dkms`) with DRM KMS enabled.
