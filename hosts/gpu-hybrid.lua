-- GPU preset: Hybrid iGPU + NVIDIA dGPU (pin VA-API to Intel iGPU)
hl.env("LIBVA_DRIVER_NAME", "iHD")

-- Optional explicit Aquamarine DRM priority (check `/dev/dri/`):
-- hl.env("AQ_DRM_DEVICES", "/dev/dri/card0:/dev/dri/card1")
