# kernel-adaptation-pipa

Packages the Xiaomi Pad 6 mainline kernel for Sailfish OS.

Unlike PinePhone (`kernel-adaptation-pine64` which builds megi from source),
pipa uses **prebuilt** `Image` + modules + DTB from [pipa-pkgs](https://thespider2.github.io/pipa-pkgs/repo/)
or an existing Linux boot partition.

```bash
./scripts/stage-prebuilt-kernel.sh /path/to/extracted-boot
# then build RPM in Platform SDK against rpm/kernel-adaptation-pipa.spec
```

Boot on device remains **Mu-Silicium UEFI + GRUB** (not U-Boot).
