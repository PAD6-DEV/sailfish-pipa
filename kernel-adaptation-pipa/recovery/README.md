# Display blank after U-Boot (even with plain `.ko`)

## Real cause

`CONFIG_DRM_MSM=y` (built-in) probes **before** userspace.
`CONFIG_DRM_PANEL_NOVATEK_NT36532=m` and `CONFIG_BACKLIGHT_KTZ8866=m` load only from
`modules-load.d` — often **after** DRM has already given up → black panel.

Decompressing `.ko.zst` → `.ko` is necessary but **not sufficient**.

The port previously worked on **`7.1.3-pipa`** (that package is gone from
pipa-pkgs; only `7.1.0-1` remains).

## Proper fix

Rebuild `linux-pipa` with panel + backlight built-in (already patched in
`pipa-pkgs`):

- `CONFIG_DRM_PANEL_NOVATEK_NT36532=y`
- `CONFIG_BACKLIGHT_KTZ8866=y`
- no `CONFIG_MODULE_COMPRESS`

Then republish and repack `kernel-adaptation-pipa`.

## Temporary (if USB SSH works)

```bash
modprobe panel-novatek-nt36532
modprobe ktz8866
echo 1024 > /sys/class/backlight/*/brightness
ls /sys/class/drm
# uname -r must match /lib/modules/$(uname -r)
```

If DRM already failed, modular load may not recover — you need the rebuilt Image.
