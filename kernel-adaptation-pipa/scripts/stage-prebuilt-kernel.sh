#!/usr/bin/env bash
# Stage prebuilt kernel artifacts for kernel-adaptation-pipa / pack-flashables.
# Usage:
#   ./scripts/stage-prebuilt-kernel.sh /path/to/dir   # contains boot/ or Image
#   ./scripts/stage-prebuilt-kernel.sh /path/to/linux-pipa-*.pkg.tar.xz
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?path to kernel tree or .pkg.tar.xz}"
DEST="$ROOT/prebuilt"
rm -rf "$DEST"
mkdir -p "$DEST/boot" "$DEST/lib"

TMP=""
cleanup() { [ -n "$TMP" ] && rm -rf "$TMP"; }
trap cleanup EXIT

if [ -f "$SRC" ] && [[ "$SRC" == *.pkg.tar.xz || "$SRC" == *.tar.xz || "$SRC" == *.tar.zst ]]; then
  TMP=$(mktemp -d)
  case "$SRC" in
    *.zst) tar -C "$TMP" --zstd -xf "$SRC" ;;
    *) tar -C "$TMP" -xf "$SRC" ;;
  esac
  SRC="$TMP"
fi

if [ -f "$SRC/boot/Image" ] || [ -f "$SRC/boot/Image.gz" ]; then
  cp -a "$SRC/boot/." "$DEST/boot/"
elif [ -f "$SRC/Image" ]; then
  cp -a "$SRC/Image" "$DEST/boot/Image"
  [ -f "$SRC/Image.gz" ] && cp -a "$SRC/Image.gz" "$DEST/boot/Image.gz"
  [ -d "$SRC/dtbs" ] && cp -a "$SRC/dtbs" "$DEST/boot/dtbs"
else
  echo "No Image under $SRC" >&2
  exit 1
fi

if [ -d "$SRC/usr/lib/modules" ]; then
  cp -a "$SRC/usr/lib/modules" "$DEST/lib/modules"
elif [ -d "$SRC/lib/modules" ]; then
  cp -a "$SRC/lib/modules" "$DEST/lib/modules"
fi

if [ ! -f "$DEST/boot/Image" ] && [ -f "$DEST/boot/Image.gz" ]; then
  gunzip -c "$DEST/boot/Image.gz" > "$DEST/boot/Image"
fi

sz=$(wc -c < "$DEST/boot/Image")
if [ "$sz" -lt 1000000 ]; then
  echo "ERROR: Image is only ${sz} bytes (placeholder?)" >&2
  exit 1
fi
echo "Staged ${sz} byte Image into $DEST"
find "$DEST" -type f | head -40 || true
exit 0
