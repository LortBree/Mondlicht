# Mondlicht

Minimalist volcanic smoked-glass (`#08090E`) and moonlight (`#DCE4F7` / `#B7C4FF`) desktop environment for **Arch Linux**, built on **Hyprland `0.57+` (pure Lua)** and **Quickshell `0.3+`**, managed with **GNU Stow**, **matugen v4**, and an interactive `archinstall`-style installer.

Designed to work cleanly on both **desktop PCs** (NVIDIA / AMD / Intel, multi-monitor, no battery/backlight) and **laptops** (standard DPI or HiDPI, GNOME-style 3-finger touchpad gestures).

## Features

- **Unified Quickshell (`qs -c mondlicht`):** auto-hiding Top Capsule (Clock, Calendar, MPRIS Media, Quick Notes), Left Workspaces Rail, Right Status Sidebar, bottom macOS/GNOME Dash Dock, and click-through Volume/Brightness OSD pill.
- **Native Win11-Style Quick Settings:** inline pages for Wi-Fi (`nmcli`), Bluetooth (`Quickshell.Bluetooth`), Sound Output (`Pipewire`), Power Profiles (`tuned-ppd`), and automatic backlight hiding on desktops without `/sys/class/backlight/*`.
- **Keyboard & Gesture Navigation:** macOS-friendly `Super` (`Cmd`) shortcuts, `Super+Tab` / `Alt+Tab` live window Overview with MRU ordering, `Super+/` shortcut & package guide modal, and 3-finger swipe navigation on laptops.
- **Dynamic Accent Pipeline (`awww` + `matugen v4`):** changing wallpaper updates Hyprland, Hyprlock, Quickshell, Fuzzel, Kitty, and GTK 3/4 accents live while anchoring dark obsidian surfaces.
- **Optional Boot & Lock Stack:** matching Qt6 SDDM theme (clock-first curtain with centered login card), Hyprlock lockscreen, and Dark Minimalist GRUB2 crescent moon theme (`--with-boot`).

## Prerequisites

- Fresh or existing **Arch Linux** installation with `git` and `sudo` access (`yay` or `paru` is optional; `install.sh` can bootstrap `yay-bin` automatically).

## Quick Install

```bash
git clone https://github.com/LortBree/Mondlicht.git ~/Mondlicht
cd ~/Mondlicht
./install.sh
```

Running `./install.sh` opens an `archinstall`-style interactive dashboard that auto-detects your hardware and lets you toggle options `[1]` through `[7]` before installing:

1. **Machine Profile:** `pc-standard`, `laptop-standard`, or `laptop-hidpi`
2. **GPU Preset:** `intel`, `amd`, `nvidia`, or `hybrid`
3. **Apps Group:** optional daily & dev stack (`brave-bin`, `antigravity*`, `spotify-launcher`, `docker`, `dolphin`, `okular`, `cups`)
4. **Laptop Utilities:** `brightnessctl` and `smartmontools`
5. **AUR Helper:** auto-detected `yay` / `paru`, bootstrap `yay-bin`, or `skip`
6. **Boot & Lock Stack:** optional SDDM + Dark Mondlicht GRUB theme (`sudo`; automatically skips GRUB on `systemd-boot` hosts)
7. **Dry-Run Mode:** preview every package, conflict backup, and generated config without changing the system

### Scripted / Non-Interactive Install

```bash
# Preview what a desktop PC (NVIDIA) install will do without modifying anything
./install.sh --profile pc-standard --gpu nvidia --with-apps --with-boot --dry-run --yes

# Automated install on a desktop PC (NVIDIA + daily apps + SDDM/GRUB)
./install.sh --profile pc-standard --gpu nvidia --with-apps --with-boot --yes

# Automated install on a HiDPI Intel laptop (core desktop packages only)
./install.sh --profile laptop-hidpi --gpu intel --no-apps --with-boot --yes

# Uninstall Mondlicht symlinks and generated ~/.config/hypr/host.lua
./install.sh --uninstall
```

## Package Groups

| File | Contents | Toggle |
|---|---|---|
| `packages/base.txt` | Hyprland, Quickshell, Fuzzel, Kitty, Zsh, Starship, PipeWire, NetworkManager, BlueZ, Tuned, SDDM, GTK/Qt themes, Noto fonts | Always installed |
| `packages/aur-base.txt` | `ttf-geist`, `ttf-geist-mono` | AUR (`--aur skip` to skip) |
| `packages/apps.txt` | `dolphin`, `ark`, `okular`, `imv`, `mpv`, `spotify-launcher`, `docker`, `docker-buildx`, `docker-compose`, `cups` | `--with-apps` / `--no-apps` |
| `packages/aur-apps.txt` | `brave-bin`, `antigravity`, `antigravity-cli`, `antigravity-ide` | Follows Apps Group + AUR |
| `packages/laptop.txt` | `brightnessctl`, `smartmontools` | `--with-laptop` / `--no-laptop` |

GPU drivers are added automatically by preset (`vulkan-intel`, `intel-media-driver`, `libva-intel-driver`, `libvpl`, `vpl-gpu-rt` for Intel; `vulkan-radeon` for AMD; `nvidia-utils` for NVIDIA). For NVIDIA systems, ensure the matching kernel module (`nvidia-open`, `nvidia-lts`, or `nvidia-dkms`) and DRM KMS (`nvidia_drm.modeset=1`) are configured for your kernel.

## Multi-Host Overrides & Updates

Machine-specific monitor layouts and GPU environment variables are written by `install.sh` to `~/.config/hypr/host.lua` (gitignored), while `hypr/.config/hypr/hyprland.lua` loads it via `pcall(require, "host")`. Your desktop PC and laptop can stay on the same branch without merge conflicts.

To configure dual monitors on a PC, run `hyprctl monitors all` and edit `~/.config/hypr/host.lua` following the commented example in `hosts/pc-standard.lua`.

After pulling updates from GitHub:

```bash
cd ~/Mondlicht && git pull && ./apply.sh
```

`apply.sh` safely backs up any conflicting non-symlink files into `~/.mondlicht-backup-<timestamp>/` before running GNU Stow.

## Essential Keybindings

| Shortcut | Action |
|---|---|
| `Super + Space` | Toggle App Launcher |
| `Super + R` | Open Fuzzel dmenu |
| `Super + Return` | Open Kitty terminal |
| `Super + E` | Open Dolphin file manager |
| `Super + Q` | Close active window |
| `Super + Tab` / `Alt + Tab` | Cycle live window Overview |
| `Super + A` | Toggle Quick Settings (Wi-Fi, BT, Audio, Power) |
| `Super + T` | Toggle Clock / Calendar / Media / Notes drawer |
| `Super + N` | Toggle Notification Center |
| `Super + Shift + W` | Toggle Wallpaper Picker (`awww` + `matugen`) |
| `Super + /` | Open Shortcuts & Package Guide modal |
| `Super + S` / `Super + Shift + S` | Toggle Scratchpad / stash or restore window |
| `Super + Shift + 4` / `3` | Region / full screenshot (`grim` + `slurp` + `satty`) |
| `Super + L` | Lock screen (`hyprlock`) |
| `Super + Escape` | Toggle Power Menu |

## Repository Layout

```text
Mondlicht/
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

Run repository-only checks before installing on a target machine:

```bash
./test-dotfiles.sh --repo-only
```
