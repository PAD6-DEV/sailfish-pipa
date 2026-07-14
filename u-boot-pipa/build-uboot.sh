#!/usr/bin/env bash
# Build Qualcomm U-Boot for Xiaomi Pad 6 (pipa), pmOS-style.
# Maps GPT "linux" via blkmap and boots /boot/extlinux from that rootfs.
# Does NOT use bootefi/ESP (stock qcom-phone.env would require one).
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

# Stock qcom-phone.env uses `bootefi bootmgr` (needs an ESP). Sailfish stores
# Image + extlinux on the GPT "linux" rootfs instead — boot that via blkmap.
python3 - "$ENV_FILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text().splitlines()

replacements = {
    "preboot": (
        "preboot=scsi scan; "
        "part start scsi 0 linux linux_start; "
        "part size scsi 0 linux linux_size; "
        "blkmap create root; "
        "blkmap map root 0 ${linux_size} linear scsi 0 ${linux_start}"
    ),
    # Prefer extlinux on the mapped rootfs; do not require ESP / EFI bootmgr.
    "boot_sfos": (
        "boot_sfos="
        "blkmap get root dev rootdev; "
        "if bootflow scan -lb blkmap${rootdev}; then true; "
        "elif load blkmap ${rootdev} ${kernel_addr_r} /boot/Image; then "
        "load blkmap ${rootdev} ${fdt_addr_r} /boot/dtbs/qcom/sm8250-xiaomi-pipa.dtb; "
        "setenv bootargs root=LABEL=sfos_root rw rootwait "
        "console=ttyMSM0,115200n8 earlycon ignore_loglevel "
        "clk_ignore_unused pd_ignore_unused cma=128M; "
        "booti ${kernel_addr_r} - ${fdt_addr_r}; "
        "else echo \"Sailfish: no /boot on linux partition\"; false; fi"
    ),
    "bootcmd": "bootcmd=run boot_sfos; pause; run menucmd",
    "bootmenu_0": "bootmenu_0=Boot Sailfish=run boot_sfos; pause",
}

out = []
seen = set()
for line in lines:
    key = line.split("=", 1)[0] if "=" in line else None
    if key in replacements:
        out.append(replacements[key])
        seen.add(key)
    else:
        out.append(line)

# Ensure keys exist even if upstream env drops them.
for key, val in replacements.items():
    if key not in seen:
        out.append(val)

path.write_text("\n".join(out) + "\n")
print(f"Patched {path} for ESP-less Sailfish boot:")
for key in replacements:
    for line in path.read_text().splitlines():
        if line.startswith(key + "="):
            print(f"  {line[:140]}{'...' if len(line) > 140 else ''}")
            break
PY

cd "$SRC"
export CROSS_COMPILE
make qcom_defconfig qcom-phone.config
./scripts/config --enable CONFIG_BLKMAP --enable CONFIG_CMD_BLKMAP
./scripts/config --enable CONFIG_BOOTMETH_EXTLINUX
./scripts/config --enable CONFIG_CMD_BOOTI
./scripts/config --enable CONFIG_FS_EXT4
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
