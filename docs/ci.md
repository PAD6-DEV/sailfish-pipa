# CI build

Repo: https://github.com/PAD6-DEV/sailfish-pipa

All image artifacts are produced by GitHub Actions — **no local mic/U-Boot/Mesa builds required**.

Workflow: [`.github/workflows/build-rootfs.yml`](../.github/workflows/build-rootfs.yml)

| Job | Output |
|-----|--------|
| `build-uboot` | `u-boot-xiaomi-pipa.img` (blkmap GPT **linux** + extlinux; no ESP) |
| `build-mesa` | `mesa-freedreno-sfos-aarch64.tar.gz` (msm/freedreno for glibc 2.30) |
| `build-rootfs` | mic `sfe-pipa-*.tar.bz2` (full UI via pinetab2-style patterns) |
| `pack-flash-set` | injects Mesa + kernel into rootfs, packs flash set |

Final artifact **`sailfish-pipa-flash`**:

- `u-boot-xiaomi-pipa.img` → `boot_ab`
- `sfos_rootfs.raw` → `linux`

```bash
bash flash/flash.sh /path/to/sailfish-pipa-flash
```

Triggers: push to `main`/`master` (paths above) or **Actions → workflow_dispatch**.

## Adaptation RPM GitHub Pages

Published feed (enable Pages → GitHub Actions in repo Settings if needed):

`https://pad6-dev.github.io/sailfish-pipa/adaptation/`

Workflow: `.github/workflows/publish-adaptation-pages.yml`

Kickstart and on-device SSU use that URL. Image mic CI still overlays a local `file://` copy for the same run so packages are available before Pages catches up.
