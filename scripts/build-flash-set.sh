#!/usr/bin/env bash
# One-shot packer for CI/local: stage kernel + pack U-Boot flash set.
# Prefer GitHub Actions (.github/workflows/build-rootfs.yml) over local runs.
set -euo pipefail

SF="$(cd "$(dirname "$0")/.." && pwd)"
PKG=${PKG:-}
TBZ=${TBZ:-}
OUT=${OUT:-$SF/flash/out}
TARGET_PART="${TARGET_PART:-linux}"
UBOOT_IMG="${UBOOT_IMG:-$SF/u-boot-pipa/out/u-boot-xiaomi-pipa.img}"

if [ "${MULTIBOOT:-1}" = 0 ]; then
  TARGET_PART=userdata
fi

if [ -z "$TBZ" ]; then
  TBZ=$(ls -1 "$SF"/image-ci/pipa/sfe-pipa-*/sfe-pipa-*.tar.bz2 2>/dev/null | head -1 || true)
fi
[ -n "$TBZ" ] && [ -f "$TBZ" ] || {
  echo "Missing rootfs tarball (set TBZ=...)" >&2
  exit 1
}
[ -f "$UBOOT_IMG" ] || {
  echo "Missing U-Boot image: $UBOOT_IMG" >&2
  echo "  bash $SF/u-boot-pipa/build-uboot.sh" >&2
  exit 1
}

if [ -n "$PKG" ] && [ -f "$PKG" ]; then
  bash "$SF/kernel-adaptation-pipa/scripts/stage-prebuilt-kernel.sh" "$PKG"
fi

[ -f "$SF/kernel-adaptation-pipa/prebuilt/boot/Image" ] || {
  echo "Missing staged kernel at kernel-adaptation-pipa/prebuilt/boot/Image" >&2
  exit 1
}

if [ "$(id -u)" -ne 0 ]; then
  echo "Re-run with sudo for loop mounts" >&2
  exit 1
fi

mkdir -p "$OUT"
bash "$SF/flash/pack-flashables.sh" \
  --rootfs-tbz "$TBZ" \
  --kernel-prebuilt "$SF/kernel-adaptation-pipa/prebuilt" \
  --uboot-img "$UBOOT_IMG" \
  --outdir "$OUT" \
  --rootfs-size-mb "${ROOTFS_SIZE_MB:-0}" \
  --target-part "$TARGET_PART"

echo
ls -lh "$OUT"
echo "Flash: bash $SF/flash/flash.sh $OUT"
