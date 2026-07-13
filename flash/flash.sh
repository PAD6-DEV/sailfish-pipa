#!/usr/bin/env bash
# Flash Sailfish OS pipa via fastboot (Qualcomm U-Boot + linux rootfs).
#
# Expected files in DIR:
#   u-boot-xiaomi-pipa.img[.xz]  -> boot_ab (or boot_a / boot_b)
#   sfos_rootfs.raw[.xz]        -> linux (default) or target-part.txt / ROOT_PART
#
# Legacy (LEGACY_UEFI=1 or silicium.img present without u-boot):
#   silicium.img -> boot_ab, sfos_esp.raw -> rawdump, sfos_boot.raw -> cust
set -euo pipefail
DIR="${1:-.}"

decompress() {
  local f="$1"
  if [ -f "${f}.xz" ] && [ ! -f "$f" ]; then
    xz -dkc "${f}.xz" > "$f"
  fi
  [ -f "$f" ]
}

part_size_bytes() {
  local part="$1" raw
  raw=$(fastboot getvar "partition-size:${part}" 2>&1 | sed -n "s/.*partition-size:${part}: *//p" | tr -d '\r' | head -1)
  [ -n "$raw" ] || return 1
  printf '%d' "$raw" 2>/dev/null
}

flash_part() {
  local part="$1" file="$2" mode="${3:-flash}"
  decompress "$file" || { echo "missing $file" >&2; return 1; }
  local fsize psize
  fsize=$(stat -c%s "$file")
  if psize=$(part_size_bytes "$part"); then
    echo "partition-size:${part}=${psize} file=${fsize}"
    if [ "$fsize" -gt "$psize" ]; then
      echo "ERROR: $file ($fsize bytes) is larger than $part ($psize bytes)" >&2
      return 1
    fi
  else
    echo "WARN: could not read partition-size:${part} (is device in fastboot?)"
  fi
  if [ "$mode" = "raw" ]; then
    echo "fastboot flash:raw $part $file"
    fastboot flash:raw "$part" "$file" || {
      echo "flash:raw failed; retrying with -S 64M ..."
      fastboot flash -S 64M "$part" "$file"
    }
  else
    echo "fastboot flash $part $file"
    fastboot flash "$part" "$file"
  fi
}

cd "$DIR"
[ -f sfos_rootfs.raw ] || [ -f sfos_rootfs.raw.xz ] || { echo "missing sfos_rootfs.raw" >&2; exit 1; }

HAS_UBOOT=0
if [ -f u-boot-xiaomi-pipa.img ] || [ -f u-boot-xiaomi-pipa.img.xz ]; then
  HAS_UBOOT=1
fi

if [ "$HAS_UBOOT" = 1 ] && [ "${LEGACY_UEFI:-0}" != 1 ]; then
  echo "Flashing U-Boot boot image ..."
  flash_part boot_ab u-boot-xiaomi-pipa.img || {
    flash_part boot_a u-boot-xiaomi-pipa.img
    flash_part boot_b u-boot-xiaomi-pipa.img
  }
  # Optional: clear vendor DTBO overlay that can fight mainline DTB
  if [ "${ERASE_DTBO:-1}" = 1 ]; then
    fastboot erase dtbo_a 2>/dev/null || true
    fastboot erase dtbo_b 2>/dev/null || true
    fastboot erase dtbo 2>/dev/null || true
  fi
else
  [ -f silicium.img ] || [ -f silicium.img.xz ] || {
    echo "missing u-boot-xiaomi-pipa.img and silicium.img" >&2
    exit 1
  }
  echo "LEGACY UEFI flash (silicium) ..."
  flash_part boot_ab silicium.img || flash_part boot_a silicium.img
  flash_part rawdump sfos_esp.raw
  flash_part cust sfos_boot.raw
fi

ROOT_PART=linux
if [ -n "${ROOT_PART_OVERRIDE:-}" ]; then
  ROOT_PART="$ROOT_PART_OVERRIDE"
elif [ "${MULTIBOOT:-1}" = 0 ]; then
  ROOT_PART=userdata
elif [ -f target-part.txt ]; then
  ROOT_PART=$(tr -d ' \r\n' < target-part.txt)
fi
echo "Flashing rootfs to: $ROOT_PART"
flash_part "$ROOT_PART" sfos_rootfs.raw raw

echo "Done. Reboot device."
fastboot reboot || true
