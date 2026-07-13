# Flashing Sailfish OS on Xiaomi Pad 6

Partition map (same as Ultramarine/Nemo pipa):

| Image | Partition |
|-------|-----------|
| `silicium.img` | `boot_ab` |
| `sfos_esp.raw` | `rawdump` |
| `sfos_boot.raw` | `cust` |
| `sfos_rootfs.raw` | `userdata` or `linux` |

```bash
./pack-rootfs.sh ../image-ci/pipa/sfe-pipa-*/sfe-pipa-*.tar.bz2 ./out
# copy silicium.img + ESP into out/
./flash.sh ./out
```

USB SSH after boot: `172.16.42.1` (RNDIS), user `nemo` / developer mode.
