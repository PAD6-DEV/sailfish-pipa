# kernel-adaptation-pipa

Packages / stages the Xiaomi Pad 6 **mainline** kernel for Sailfish OS.

Pipa boots via **Mu-Silicium UEFI + GRUB** (ESP + `cust` boot partition).
Do **not** use Android `boot.img` here (that is for hybris ports).

## Stage real kernel from pipa-pkgs

Kernel source is [PipaDB/linux](https://github.com/PipaDB/linux) `pipa/7.1`
(packaged as Arch `linux-pipa` in pipa-pkgs). After rebuild, stage the new
`linux-pipa-7.1.0-*.pkg.tar.xz` (or whatever version CI published):

```bash
curl -fL -o /tmp/linux-pipa.pkg.tar.xz \
  https://thespider2.github.io/pipa-pkgs/repo/linux-pipa-7.1.0-4-aarch64.pkg.tar.xz
./scripts/stage-prebuilt-kernel.sh /tmp/linux-pipa.pkg.tar.xz
# or:
mkdir -p /tmp/lp && tar -C /tmp/lp -xf /tmp/linux-pipa.pkg.tar.xz
./scripts/stage-prebuilt-kernel.sh /tmp/lp
```

`7.1.0-4` includes SoftISP camera bring-up (OV13B10/HI846 @ 19.2 MHz MCLK,
CAMCC/CAMSS fixes) from pipa-pkgs.

Expect `prebuilt/boot/Image` (~40MB), `prebuilt/boot/dtbs/qcom/sm8250-xiaomi-pipa*.dtb`,
and `prebuilt/lib/modules/<kver>/`.

Then build flash images:

```bash
sudo ../flash/pack-flashables.sh \
  --rootfs-tbz /path/to/sfe-pipa-*.tar.bz2 \
  --kernel-prebuilt ./prebuilt \
  --outdir /path/to/out
```
