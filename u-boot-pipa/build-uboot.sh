#!/usr/bin/env bash
# Build Qualcomm U-Boot for Xiaomi Pad 6 (pipa), pmOS-style.
# Maps the GPT "linux" partition via blkmap (multiboot-safe; userdata untouched).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="${UBOOT_SRC:-$ROOT/src}"
OUT="${UBOOT_OUT:-$ROOT/out}"
JOBS="${JOBS:-$(nproc)}"
DTB_NAME="qcom/sm8250-xiaomi-pipa"

if command -v aarch64-none-elf-gcc >/dev/null 2>&1; then
  CROSS_COMPILE="${CROSS_COMPILE:-aarch64-none-elf-}"
elif command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
  CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
else
  echo "ERROR: need aarch64-none-elf-gcc or aarch64-linux-gnu-gcc" >&2
  exit 1
fi

command -v python3 >/dev/null 2>&1 || {
  echo "ERROR: python3 required for mkbootimg.py" >&2
  exit 1
}

mkdir -p "$OUT"

if [ ! -d "$SRC/.git" ]; then
  echo "Cloning U-Boot into $SRC ..."
  git clone --depth=1 https://source.denx.de/u-boot/u-boot.git "$SRC"
fi

ENV_FILE="$SRC/board/qualcomm/qcom-phone.env"
[ -f "$ENV_FILE" ] || {
  echo "ERROR: missing $ENV_FILE (U-Boot tree too old or incomplete)" >&2
  exit 1
}

# Map GPT partition "linux" as blkmap root (Sailfish rootfs + /boot).
PREBOOT='preboot=scsi scan; part start scsi 0 linux linux_start; part size scsi 0 linux linux_size; blkmap create root; blkmap map root 0 0x${linux_size} linear scsi 0 0x${linux_start}'
if grep -q '^preboot=' "$ENV_FILE"; then
  sed -i "s|^preboot=.*$|${PREBOOT}|" "$ENV_FILE"
else
  printf '%s\n' "$PREBOOT" >> "$ENV_FILE"
fi
echo "Patched preboot for linux partition:"
grep '^preboot=' "$ENV_FILE"

cd "$SRC"
export CROSS_COMPILE
make qcom_defconfig qcom-phone.config
./scripts/config --enable CONFIG_BLKMAP --enable CONFIG_CMD_BLKMAP
./scripts/config --set-str CONFIG_DEFAULT_DEVICE_TREE "$DTB_NAME"
# Host tool mkeficapsule needs gnutls; we don't need EFI capsules for pipa boot.img
./scripts/config --disable CONFIG_TOOLS_MKFICAPSULE 2>/dev/null || true
./scripts/config --disable CONFIG_TOOLS_LIBCRYPTO 2>/dev/null || true
# Refresh autoconf after scripts/config
make olddefconfig

echo "Building U-Boot (CROSS_COMPILE=$CROSS_COMPILE) ..."
make -j"$JOBS"

[ -f u-boot-nodtb.bin ] || { echo "ERROR: u-boot-nodtb.bin missing" >&2; exit 1; }
DTB_FILE="u-boot.dtb"
if [ ! -f "$DTB_FILE" ]; then
  # Some trees emit arch/arm/dts/...
  DTB_FILE=$(find . -name 'sm8250-xiaomi-pipa.dtb' | head -1 || true)
fi
[ -n "$DTB_FILE" ] && [ -f "$DTB_FILE" ] || {
  echo "ERROR: sm8250-xiaomi-pipa.dtb not produced — is DTB enabled in tree?" >&2
  find . -name '*pipa*.dtb' 2>/dev/null | head >&2 || true
  exit 1
}

gzip -f -k u-boot-nodtb.bin
PAYLOAD="$OUT/u-boot-xiaomi-pipa.bin"
IMG="$OUT/u-boot-xiaomi-pipa.img"
cat u-boot-nodtb.bin.gz "$DTB_FILE" > "$PAYLOAD"

MKBOOTIMG="$ROOT/mkbootimg.py"
if [ -x "$MKBOOTIMG" ] || [ -f "$MKBOOTIMG" ]; then
  python3 "$MKBOOTIMG" --kernel "$PAYLOAD" -o "$IMG"
elif command -v mkbootimg >/dev/null 2>&1; then
  mkbootimg --kernel "$PAYLOAD" -o "$IMG"
else
  echo "ERROR: no mkbootimg (expected $MKBOOTIMG)" >&2
  exit 1
fi

ls -lh "$PAYLOAD" "$IMG"
echo "OK: $IMG"
echo "$IMG"
