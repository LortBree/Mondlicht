-- Host preset: Desktop PC (standard DPI)
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- Example dual-monitor layout (uncomment and match outputs from `hyprctl monitors all`):
-- hl.monitor({ output = "DP-1",     mode = "2560x1440@144", position = "0x0",    scale = 1 })
-- hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60",  position = "2560x0", scale = 1 })
