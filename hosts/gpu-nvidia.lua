-- GPU preset: NVIDIA proprietary / open kernel modules
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("LIBVA_DRIVER_NAME", "nvidia")

-- Uncomment if experiencing invisible or flickering cursor on NVIDIA:
-- hl.config({ cursor = { no_hardware_cursors = true } })
