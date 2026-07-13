#!/usr/bin/env bash
# Flash Sailfish OS pipa images via fastboot.
# Expected files in DIR (default: ./out or Downloads):
#   silicium.img[.xz]  -> boot_ab
#   sfos_esp.raw[.xz]  -> rawdump   (optional; ESP)
#   sfos_boot.raw[.xz] -> cust
#   sfos_rootfs.raw[.xz] -> userdata (or linux if MULTIBOOT=1)
set -euo pipefail
DIR="${1:-.}"
decompress() {
  local f="$1"
  if [ -f "${f}.xz" ]; then
    xz -dkc "${f}.xz" > "$f"
  fi
  [ -f "$f" ]
}

flash_part() {
  local part="$1" file="$2"
  decompress "$file" || { echo "missing $file"; return 1; }
  echo "fastboot flash $part $file"
  fastboot flash "$part" "$file"
}

cd "$DIR"
flash_part boot_ab silicium.img || flash_part boot_a silicium.img
[ -f sfos_esp.raw ] || [ -f sfos_esp.raw.xz ] && flash_part rawdump sfos_esp.raw || true
flash_part cust sfos_boot.raw
if [ "${MULTIBOOT:-0}" = 1 ]; then
  flash_part linux sfos_rootfs.raw
else
  flash_part userdata sfos_rootfs.raw
fi
echo "Done. Reboot device."
fastboot reboot || true
