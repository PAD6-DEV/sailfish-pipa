# Flashing Sailfish OS on Xiaomi Pad 6

Boot: **Qualcomm U-Boot** + rootfs on GPT **`linux`** (built entirely in CI).

| File | Partition |
|------|-----------|
| `u-boot-xiaomi-pipa.img` | `boot_ab` |
| `sfos_rootfs.raw` | `linux` (`LABEL=sfos_root`, Mesa freedreno + `/boot`/extlinux) |

## Build

Push / **workflow_dispatch** — download artifact `sailfish-pipa-flash`.

## Flash

```bash
bash flash/flash.sh /path/to/sailfish-pipa-flash
```

`userdata` is untouched. Optional `ERASE_DTBO=0` to skip dtbo erase.
