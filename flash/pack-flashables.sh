#!/usr/bin/env bash
# Build pipa flash set: Qualcomm U-Boot + Sailfish rootfs on GPT "linux".
#
# Layout (default):
#   u-boot-xiaomi-pipa.img  -> boot_ab
#   sfos_rootfs.raw         -> linux   (LABEL=sfos_root, includes /boot + extlinux)
#
# Legacy UEFI (LEGACY_UEFI=1): also emit silicium/ESP/cust like the old path.
#
# Usage (as root):
#   ./pack-flashables.sh --rootfs-tbz sfe-*.tar.bz2 --outdir ./out
#   TARGET_PART=linux ./pack-flashables.sh ...
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
POCKET_SILICIUM="${POCKET_SILICIUM:-/home/ayman/Downloads/Compressed/pocketblue-xiaomi-pipa-plasma-desktop-44/images/silicium.img}"
POCKET_ESP="${POCKET_ESP:-/home/ayman/Downloads/Compressed/pocketblue-xiaomi-pipa-plasma-desktop-44/images/fedora_esp.raw}"
NEMO_EFI="${NEMO_EFI_TEMPLATE:-/home/ayman/manjaro-nemo-pipa/efi-template}"

ROOTFS_TBZ=""
KERNEL_PREBUILT="$REPO_ROOT/kernel-adaptation-pipa/prebuilt"
UBOOT_IMG="${UBOOT_IMG:-$REPO_ROOT/u-boot-pipa/out/u-boot-xiaomi-pipa.img}"
OUTDIR="$REPO_ROOT/flash/out"
ROOTFS_SIZE_MB="${ROOTFS_SIZE_MB:-0}"
ROOTFS_SIZE_MAX_MB="${ROOTFS_SIZE_MAX_MB:-0}"
TARGET_PART="${TARGET_PART:-linux}"
BOOT_SIZE_MB="${BOOT_SIZE_MB:-512}"
BOOT_LABEL="${BOOT_LABEL:-boot}"
ROOTFS_LABEL="${ROOTFS_LABEL:-sfos_root}"
ESP_LABEL="${ESP_LABEL:-SFOSPIPA}"
LEGACY_UEFI="${LEGACY_UEFI:-0}"
EXISTING_ROOTFS_RAW=""
MTDEV_SO="${MTDEV_SO:-}"
MESA_TAR="${MESA_TAR:-$REPO_ROOT/mesa-pipa/out/mesa-freedreno-sfos-aarch64.tar.gz}"
FIRMWARE_TAR="${FIRMWARE_TAR:-$REPO_ROOT/firmware-pipa/out/xiaomi-pipa-firmware.tar.gz}"

while [ $# -gt 0 ]; do
  case "$1" in
    --rootfs-tbz) ROOTFS_TBZ="$2"; shift 2 ;;
    --rootfs-raw) EXISTING_ROOTFS_RAW="$2"; shift 2 ;;
    --kernel-prebuilt) KERNEL_PREBUILT="$2"; shift 2 ;;
    --uboot-img) UBOOT_IMG="$2"; shift 2 ;;
    --outdir) OUTDIR="$2"; shift 2 ;;
    --rootfs-size-mb) ROOTFS_SIZE_MB="$2"; shift 2 ;;
    --target-part) TARGET_PART="$2"; shift 2 ;;
    --mtdev-so) MTDEV_SO="$2"; shift 2 ;;
    --mesa-tar) MESA_TAR="$2"; shift 2 ;;
    --firmware-tar) FIRMWARE_TAR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "Must run as root (loop mount / mkfs)" >&2
  exit 1
fi

[ -d "$KERNEL_PREBUILT/boot" ] || { echo "Missing kernel prebuilt at $KERNEL_PREBUILT/boot" >&2; exit 1; }
[ -f "$KERNEL_PREBUILT/boot/Image" ] || [ -f "$KERNEL_PREBUILT/boot/Image.gz" ] || {
  echo "No Image/Image.gz in $KERNEL_PREBUILT/boot" >&2
  exit 1
}
if [ -f "$KERNEL_PREBUILT/boot/Image" ] && [ "$(wc -c < "$KERNEL_PREBUILT/boot/Image")" -lt 1000000 ]; then
  echo "ERROR: kernel Image looks like placeholder (<1MB)" >&2
  exit 1
fi
[ -f "$UBOOT_IMG" ] || {
  echo "ERROR: missing U-Boot image: $UBOOT_IMG" >&2
  echo "  Build with: bash $REPO_ROOT/u-boot-pipa/build-uboot.sh" >&2
  exit 1
}

bytes_to_mb() { echo $(( ($1 + 1048575) / 1048576 )); }

fastboot_part_size_mb() {
  local part="$1" raw
  command -v fastboot >/dev/null 2>&1 || return 1
  raw=$(fastboot getvar "partition-size:${part}" 2>&1 | sed -n "s/.*partition-size:${part}: *//p" | tr -d '\r' | head -1)
  [ -n "$raw" ] || return 1
  local bytes
  bytes=$(printf '%d' "$raw" 2>/dev/null) || return 1
  [ "$bytes" -gt 0 ] || return 1
  bytes_to_mb "$bytes"
}

install_boot_files() {
  local dest="$1"
  mkdir -p "$dest/boot/extlinux" "$dest/boot/dtbs"
  if [ -f "$KERNEL_PREBUILT/boot/Image.gz" ]; then
    cp -f "$KERNEL_PREBUILT/boot/Image.gz" "$dest/boot/Image.gz"
  fi
  if [ -f "$KERNEL_PREBUILT/boot/Image" ]; then
    cp -f "$KERNEL_PREBUILT/boot/Image" "$dest/boot/Image"
  fi
  if [ -d "$KERNEL_PREBUILT/boot/dtbs" ]; then
    cp -a "$KERNEL_PREBUILT/boot/dtbs/." "$dest/boot/dtbs/"
  fi

  local extlinux_src="$REPO_ROOT/droid-config-pipa/sparse/boot/extlinux/extlinux.conf"
  if [ ! -f "$extlinux_src" ]; then
    extlinux_src="$REPO_ROOT/bootstrap/droid-config-pipa/sparse/boot/extlinux/extlinux.conf"
  fi
  if [ -f "$extlinux_src" ]; then
    cp -f "$extlinux_src" "$dest/boot/extlinux/extlinux.conf"
  else
    cat > "$dest/boot/extlinux/extlinux.conf" <<EOF
TIMEOUT 1
DEFAULT sailfish
LABEL sailfish
  KERNEL /boot/Image
  FDT /boot/dtbs/qcom/sm8250-xiaomi-pipa.dtb
  APPEND root=PARTLABEL=linux rw rootwait console=tty0 console=ttyMSM0,115200n8 earlycon
EOF
  fi

  # Prefer concrete DTB name present in tree
  local dtb
  dtb=$(find "$dest/boot/dtbs" -name 'sm8250-xiaomi-pipa*.dtb' | head -1 || true)
  if [ -n "$dtb" ]; then
    local rel="${dtb#"$dest"}"
    sed -i "s|FDT .*|FDT ${rel}|" "$dest/boot/extlinux/extlinux.conf"
  fi
}

inject_bringup_fixes() {
  local dest="$1"
  # Freedreno Mesa overlay (Pages prebuilt) — replaces soft/panfrost-only dri
  if [ -n "$MESA_TAR" ] && [ -f "$MESA_TAR" ]; then
    echo "Injecting Mesa freedreno from $MESA_TAR"
    tar -C "$dest" -xzf "$MESA_TAR"
    test -e "$dest/usr/lib64/dri/msm_dri.so"
  else
    echo "ERROR: Mesa freedreno tarball required ($MESA_TAR) — UI will be unusable on soft GL" >&2
    exit 1
  fi

  # Device firmware (GPU zap + Novatek touch, …)
  if [ -n "$FIRMWARE_TAR" ] && [ -f "$FIRMWARE_TAR" ]; then
    echo "Injecting pipa firmware from $FIRMWARE_TAR"
    tar -C "$dest" -xzf "$FIRMWARE_TAR"
    test -e "$dest/usr/lib/firmware/qcom/sm8250/xiaomi/pipa/a650_zap.mbn"
    test -e "$dest/usr/lib/firmware/novatek/nt36532_csot.bin" \
      -o -e "$dest/usr/lib/firmware/novatek/nt36532_tianma.bin"
    # Kernel firmware loader often searches /lib/firmware (SFOS not always usr-merged)
    mkdir -p "$dest/lib"
    if [ -d "$dest/usr/lib/firmware" ] && [ ! -e "$dest/lib/firmware" ]; then
      ln -sfn ../usr/lib/firmware "$dest/lib/firmware"
    fi
  else
    echo "ERROR: firmware tarball required ($FIRMWARE_TAR) — touch/GPU will fail" >&2
    exit 1
  fi

  # Enable MSM DRM picker before lipstick
  if [ -f "$dest/usr/lib/systemd/system/pipa-eglfs-kms.service" ]; then
    mkdir -p "$dest/etc/systemd/system/multi-user.target.wants"
    ln -sfn /usr/lib/systemd/system/pipa-eglfs-kms.service \
      "$dest/etc/systemd/system/multi-user.target.wants/pipa-eglfs-kms.service"
  fi

  # libmtdev for qt eglfs (packaged via kickstart; optional safety inject)
  local so="$MTDEV_SO"
  if [ -z "$so" ] && [ -f /tmp/sfos-rpms/extract2/usr/lib64/libmtdev.so.1.0.0 ]; then
    so=/tmp/sfos-rpms/extract2/usr/lib64/libmtdev.so.1.0.0
  fi
  if [ -n "$so" ] && [ -f "$so" ]; then
    mkdir -p "$dest/usr/lib64"
    cp -f "$so" "$dest/usr/lib64/libmtdev.so.1.0.0"
    ln -sfn libmtdev.so.1.0.0 "$dest/usr/lib64/libmtdev.so.1"
  fi

  # Ensure defaultuser password is not expired (PAM 224)
  if [ -f "$dest/etc/shadow" ]; then
    local today
    today=$(( $(date +%s) / 86400 ))
    if grep -q '^defaultuser:' "$dest/etc/shadow"; then
      awk -F: -v d="$today" 'BEGIN{OFS=FS} $1=="defaultuser"{$3=d} {print}' \
        "$dest/etc/shadow" > "$dest/etc/shadow.new"
      mv "$dest/etc/shadow.new" "$dest/etc/shadow"
      chmod 640 "$dest/etc/shadow"
    fi
  fi
}

mkdir -p "$OUTDIR"
WORK=$(mktemp -d)
cleanup() {
  umount "$WORK/mnt" 2>/dev/null || true
  umount "$WORK/bootmnt" 2>/dev/null || true
  umount "$WORK/espmnt" 2>/dev/null || true
  umount "$WORK/rootmnt" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT
mkdir -p "$WORK/mnt" "$WORK/bootmnt" "$WORK/espmnt" "$WORK/rootmnt" "$WORK/extract"

# ---------- 1) Rootfs tree ----------
ROOT=""
if [ -n "$EXISTING_ROOTFS_RAW" ]; then
  echo "Using existing rootfs raw: $EXISTING_ROOTFS_RAW"
  cp -f "$EXISTING_ROOTFS_RAW" "$OUTDIR/sfos_rootfs.raw"
  mount -o loop "$OUTDIR/sfos_rootfs.raw" "$WORK/rootmnt"
  if [ -d "$KERNEL_PREBUILT/lib/modules" ]; then
    mkdir -p "$WORK/rootmnt/lib/modules"
    cp -a "$KERNEL_PREBUILT/lib/modules/." "$WORK/rootmnt/lib/modules/"
    find "$WORK/rootmnt/lib/modules" -name '*.ko.zst' -print0 2>/dev/null | while IFS= read -r -d '' f; do
      zstd -d -f -q -o "${f%.zst}" "$f" && rm -f "$f"
    done
    if command -v depmod >/dev/null; then
      for kv in "$WORK/rootmnt/lib/modules"/*; do
        [ -d "$kv" ] || continue
        depmod -b "$WORK/rootmnt" "$(basename "$kv")" || true
      done
    fi
  fi
  install_boot_files "$WORK/rootmnt"
  inject_bringup_fixes "$WORK/rootmnt"
  umount "$WORK/rootmnt"
  e2fsck -fy "$OUTDIR/sfos_rootfs.raw"
elif [ -n "$ROOTFS_TBZ" ]; then
  echo "Extracting $ROOTFS_TBZ ..."
  tar -xjf "$ROOTFS_TBZ" -C "$WORK/extract"
  if [ -d "$WORK/extract/rootfs" ]; then
    ROOT="$WORK/extract/rootfs"
  elif [ -d "$WORK/extract/bin" ] && [ -d "$WORK/extract/usr" ]; then
    ROOT="$WORK/extract"
  else
    ROOT=$(find "$WORK/extract" -mindepth 1 -maxdepth 3 -type d -name bin -printf '%h\n' | head -1 || true)
  fi
  [ -n "$ROOT" ] && [ -d "$ROOT/bin" ] && [ -d "$ROOT/usr" ] || {
    echo "rootfs not found in tarball" >&2
    find "$WORK/extract" -maxdepth 3 -type d | head -40 >&2
    exit 1
  }
  echo "Using rootfs tree: $ROOT"

  if [ -d "$KERNEL_PREBUILT/lib/modules" ]; then
    mkdir -p "$ROOT/lib/modules"
    cp -a "$KERNEL_PREBUILT/lib/modules/." "$ROOT/lib/modules/"
    find "$ROOT/lib/modules" -name '*.ko.zst' -print0 2>/dev/null | while IFS= read -r -d '' f; do
      zstd -d -f -q -o "${f%.zst}" "$f" && rm -f "$f"
    done
    if command -v depmod >/dev/null; then
      for kv in "$ROOT/lib/modules"/*; do
        [ -d "$kv" ] || continue
        depmod -b "$ROOT" "$(basename "$kv")" || true
      done
    fi
  fi
  install_boot_files "$ROOT"
  inject_bringup_fixes "$ROOT"

  CONTENT_BYTES=$(du -sb "$ROOT" | awk '{print $1}')
  NEED_MB=$(( $(bytes_to_mb "$CONTENT_BYTES") * 120 / 100 + 256 ))
  [ "$NEED_MB" -lt 2048 ] && NEED_MB=2048

  MAX_MB="$ROOTFS_SIZE_MAX_MB"
  if [ "$MAX_MB" -eq 0 ]; then
    if PART_MB=$(fastboot_part_size_mb "$TARGET_PART"); then
      MAX_MB=$((PART_MB > 64 ? PART_MB - 64 : PART_MB))
      echo "fastboot ${TARGET_PART} usable ≈ ${MAX_MB}M"
    fi
  fi

  if [ "$ROOTFS_SIZE_MB" -eq 0 ]; then
    ROOTFS_SIZE_MB=$NEED_MB
    if [ "$MAX_MB" -gt 0 ] && [ "$ROOTFS_SIZE_MB" -gt "$MAX_MB" ]; then
      echo "WARN: content needs ~${NEED_MB}M but ${TARGET_PART} max is ${MAX_MB}M — using max" >&2
      ROOTFS_SIZE_MB=$MAX_MB
    fi
  fi
  if [ "$MAX_MB" -gt 0 ] && [ "$ROOTFS_SIZE_MB" -gt "$MAX_MB" ]; then
    echo "ERROR: ROOTFS_SIZE_MB=${ROOTFS_SIZE_MB} exceeds ${TARGET_PART} (~${MAX_MB}M)" >&2
    exit 1
  fi

  echo "Creating $OUTDIR/sfos_rootfs.raw (${ROOTFS_SIZE_MB}M, target=${TARGET_PART}) ..."
  rm -f "$OUTDIR/sfos_rootfs.raw"
  dd if=/dev/zero of="$OUTDIR/sfos_rootfs.raw" bs=1M count="$ROOTFS_SIZE_MB" status=progress
  mkfs.ext4 -F -L "$ROOTFS_LABEL" -m 1 "$OUTDIR/sfos_rootfs.raw"
  mount -o loop "$OUTDIR/sfos_rootfs.raw" "$WORK/rootmnt"
  if ! rsync -aHAX --info=progress2 \
      --exclude='/proc/***' --exclude='/sys/***' --exclude='/dev/***' \
      "$ROOT"/ "$WORK/rootmnt"/; then
    echo "ERROR: rsync failed" >&2
    umount "$WORK/rootmnt" || true
    exit 1
  fi
  umount "$WORK/rootmnt"

  e2fsck -fy "$OUTDIR/sfos_rootfs.raw"
  resize2fs -M "$OUTDIR/sfos_rootfs.raw"
  BLOCK_COUNT=$(dumpe2fs -h "$OUTDIR/sfos_rootfs.raw" 2>/dev/null | awk '/Block count:/{print $3}')
  BLOCK_SIZE=$(dumpe2fs -h "$OUTDIR/sfos_rootfs.raw" 2>/dev/null | awk '/Block size:/{print $3}')
  FS_BYTES=$((BLOCK_COUNT * BLOCK_SIZE))
  FINAL_BYTES=$((FS_BYTES + 64 * 1048576))
  truncate -s "$FINAL_BYTES" "$OUTDIR/sfos_rootfs.raw"
  resize2fs "$OUTDIR/sfos_rootfs.raw"
  e2fsck -fy "$OUTDIR/sfos_rootfs.raw"

  FINAL_MB=$(bytes_to_mb "$(stat -c%s "$OUTDIR/sfos_rootfs.raw")")
  echo "Final rootfs image: ${FINAL_MB}M"
  if [ "$MAX_MB" -gt 0 ] && [ "$FINAL_MB" -gt "$MAX_MB" ]; then
    echo "ERROR: final image ${FINAL_MB}M still larger than ${TARGET_PART} (~${MAX_MB}M)" >&2
    exit 1
  fi
else
  echo "Need --rootfs-tbz or --rootfs-raw" >&2
  exit 1
fi

# ---------- 2) U-Boot boot.img ----------
cp -f "$UBOOT_IMG" "$OUTDIR/u-boot-xiaomi-pipa.img"
echo "Copied $(basename "$UBOOT_IMG")"

# ---------- 3) Legacy UEFI extras (optional) ----------
if [ "$LEGACY_UEFI" = 1 ]; then
  echo "LEGACY_UEFI=1: building silicium/ESP/cust extras ..."
  BUSYBOX_AARCH64="${BUSYBOX_AARCH64:-$REPO_ROOT/flash/busybox-aarch64/busybox}"
  INITRD_OUT="$WORK/initramfs-pipa.img"
  IR="$WORK/initramfs-root"
  mkdir -p "$IR"/{bin,dev,proc,sys,newroot}
  cp -f "$BUSYBOX_AARCH64" "$IR/bin/busybox"
  chmod 755 "$IR/bin/busybox"
  (cd "$IR/bin" && for a in sh mount umount mkdir ls cat sleep switch_root blkid findfs; do ln -sf busybox "$a"; done)
  printf '%s\n' '#!/bin/sh' 'export PATH=/bin' 'exec switch_root /newroot /sbin/init' > "$IR/init"
  chmod +x "$IR/init"
  (cd "$IR" && find . | cpio -o -H newc 2>/dev/null | gzip -9 > "$INITRD_OUT")

  dd if=/dev/zero of="$OUTDIR/sfos_boot.raw" bs=1M count="$BOOT_SIZE_MB" status=none
  mkfs.ext4 -F -L "$BOOT_LABEL" "$OUTDIR/sfos_boot.raw"
  mount -o loop "$OUTDIR/sfos_boot.raw" "$WORK/bootmnt"
  cp -f "$KERNEL_PREBUILT/boot/Image" "$WORK/bootmnt/Image"
  mkdir -p "$WORK/bootmnt/dtbs/qcom" "$WORK/bootmnt/grub2"
  cp -f "$KERNEL_PREBUILT/boot/dtbs/qcom"/sm8250-xiaomi-pipa*.dtb "$WORK/bootmnt/dtbs/qcom/" 2>/dev/null || true
  cp -f "$INITRD_OUT" "$WORK/bootmnt/initramfs-pipa.img"
  echo "set default=0" > "$WORK/bootmnt/grub2/grub.cfg"
  umount "$WORK/bootmnt"

  BOOT_LABEL="$BOOT_LABEL" ESP_LABEL="$ESP_LABEL" \
    POCKET_ESP="$POCKET_ESP" NEMO_EFI_TEMPLATE="$NEMO_EFI" \
    bash "$REPO_ROOT/flash/rebuild-esp.sh" "$OUTDIR/sfos_esp.raw" || true
  [ -f "$POCKET_SILICIUM" ] && cp -f "$POCKET_SILICIUM" "$OUTDIR/silicium.img"
fi

echo "$TARGET_PART" > "$OUTDIR/target-part.txt"

echo
echo "=== Flash set ready in $OUTDIR ==="
ls -lh "$OUTDIR"
echo
echo "Flash with:"
echo "  bash $REPO_ROOT/flash/flash.sh $OUTDIR"
echo "  # u-boot -> boot_ab, rootfs -> ${TARGET_PART}"
