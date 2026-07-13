#!/usr/bin/env bash
# Pack mic sfe-*.tar.bz2 into pipa flashable raw images.
# Usage: ./pack-rootfs.sh /path/to/sfe-pipa-*.tar.bz2 [outdir]
set -euo pipefail
TBZ="${1:?sfe-pipa tarball}"
OUT="${2:-$(pwd)/out}"
mkdir -p "$OUT"
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo "Extracting $TBZ ..."
tar -xjf "$TBZ" -C "$WORKDIR"
# mic fs pack-to creates a directory tree or a single rootfs dir
ROOT=""
if [ -d "$WORKDIR/rootfs" ]; then
  ROOT="$WORKDIR/rootfs"
else
  # find largest directory that looks like a rootfs
  ROOT=$(find "$WORKDIR" -maxdepth 2 -type d -name 'bin' -printf '%h\n' | head -1)
fi
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "Could not find rootfs in tarball"; ls -la "$WORKDIR"; exit 1; }

SIZE_MB=${ROOTFS_SIZE_MB:-12288}
IMG="$OUT/sfos_rootfs.raw"
echo "Creating $IMG (${SIZE_MB}M) ..."
dd if=/dev/zero of="$IMG" bs=1M count="$SIZE_MB" status=progress
mkfs.ext4 -F -L sfos_root "$IMG"
MNT="$WORKDIR/mnt"
mkdir -p "$MNT"
sudo mount -o loop "$IMG" "$MNT"
sudo rsync -aHAX --info=progress2 "$ROOT"/ "$MNT"/
sudo umount "$MNT"

# boot partition raw from /boot inside rootfs if present
if [ -d "$ROOT/boot" ] && [ -f "$ROOT/boot/Image" ] || [ -f "$ROOT/boot/Image.placeholder" ]; then
  BOOT_MB=${BOOT_SIZE_MB:-256}
  BOOTIMG="$OUT/sfos_boot.raw"
  dd if=/dev/zero of="$BOOTIMG" bs=1M count="$BOOT_MB" status=none
  mkfs.ext4 -F -L sfos_boot "$BOOTIMG"
  sudo mount -o loop "$BOOTIMG" "$MNT"
  sudo rsync -a "$ROOT/boot"/ "$MNT"/
  sudo umount "$MNT"
  echo "Wrote $BOOTIMG"
fi

# ESP placeholder — reuse silicium/ESP from ultramarine/nemo flash set separately
echo "Wrote $IMG"
ls -lh "$OUT"
