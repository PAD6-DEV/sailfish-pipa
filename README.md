# Sailfish OS on Xiaomi Pad 6 (pipa)

Community port modeled on [sailfish-on-dontbeevil](https://github.com/sailfish-on-dontbeevil)
and [dont_be_evil-ci](https://gitlab.com/sailfishos-porters-ci/dont_be_evil-ci/).

**Native mainline** (mesa freedreno + eglfs), not Android hybris.
**Boot:** Qualcomm U-Boot → GPT **`linux`** rootfs (`/boot` + extlinux).

## Build (CI only)

Push to GitHub or run **Actions → Build Sailfish pipa image**.

Jobs: U-Boot · Mesa freedreno · mic rootfs · pack flash set.

Download artifact **`sailfish-pipa-flash`**, then:

```bash
bash flash/flash.sh /path/to/sailfish-pipa-flash
# u-boot-xiaomi-pipa.img -> boot_ab
# sfos_rootfs.raw       -> linux
```

See [docs/ci.md](docs/ci.md) and [flash/README.md](flash/README.md).

Default SFOS release: **5.0.0.77**.
