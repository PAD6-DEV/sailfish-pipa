#!/usr/bin/env bash
# Stage prebuilt kernel artifacts for kernel-adaptation-pipa RPM.
# Usage:
#   ./scripts/stage-prebuilt-kernel.sh /path/to/boot-tree
# boot-tree should contain Image and optionally dtb/ and lib/modules/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?path to directory containing Image (and optional dtb/, lib/modules/)}"
DEST="$ROOT/prebuilt"
rm -rf "$DEST"
mkdir -p "$DEST/boot"

if [ -f "$SRC/Image" ]; then
  cp -a "$SRC/Image" "$DEST/boot/Image"
elif [ -f "$SRC/boot/Image" ]; then
  cp -a "$SRC/boot/Image" "$DEST/boot/Image"
elif [ -f "$SRC/vmlinuz" ]; then
  cp -a "$SRC/vmlinuz" "$DEST/boot/Image"
else
  echo "No Image/vmlinuz under $SRC" >&2
  exit 1
fi

if [ -d "$SRC/dtb" ]; then
  cp -a "$SRC/dtb" "$DEST/boot/dtb"
elif [ -d "$SRC/boot/dtb" ]; then
  cp -a "$SRC/boot/dtb" "$DEST/boot/dtb"
fi

if [ -d "$SRC/lib/modules" ]; then
  mkdir -p "$DEST/lib"
  cp -a "$SRC/lib/modules" "$DEST/lib/modules"
elif [ -d "$SRC/modules" ]; then
  mkdir -p "$DEST/lib"
  cp -a "$SRC/modules" "$DEST/lib/modules"
fi

echo "Staged into $DEST"
find "$DEST" -type f | head -40
