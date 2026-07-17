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

extract_archive() {
  local archive="$1"
  TMP=$(mktemp -d)
  tar -C "$TMP" -xf "$archive"
  SRC="$TMP"
}

if [ -f "$SRC" ]; then
  case "$SRC" in
    *.pkg.tar.xz|*.tar.xz|*.tar.zst|*.tar.gz|*.tgz)
      extract_archive "$SRC"
      ;;
    *)
      # Downloads may lack a suffix (mktemp); detect compressed tar by content.
      if xz -t "$SRC" 2>/dev/null || gzip -t "$SRC" 2>/dev/null; then
        extract_archive "$SRC"
      fi
      ;;
  esac
fi

if [ -d "$SRC/boot" ]; then
  cp -a "$SRC/boot/." "$DEST/boot/"
elif [ -f "$SRC/Image" ] || [ -f "$SRC/Image.gz" ]; then
  [ -f "$SRC/Image" ] && cp -a "$SRC/Image" "$DEST/boot/Image"
  [ -f "$SRC/Image.gz" ] && cp -a "$SRC/Image.gz" "$DEST/boot/Image.gz"
  [ -d "$SRC/dtbs" ] && cp -a "$SRC/dtbs" "$DEST/boot/dtbs"
else
  echo "No boot/ or Image under $SRC" >&2
  find "$SRC" -maxdepth 3 -type f 2>/dev/null | head -40 >&2 || true
  exit 1
fi

# Normalize Arch linux-pipa names to /boot/Image
if [ ! -f "$DEST/boot/Image" ]; then
  if [ -f "$DEST/boot/Image.gz" ]; then
    gunzip -c "$DEST/boot/Image.gz" > "$DEST/boot/Image"
  elif compgen -G "$DEST/boot/vmlinuz-*.uncompressed" >/dev/null; then
    cp -a "$(compgen -G "$DEST/boot/vmlinuz-*.uncompressed" | head -1)" "$DEST/boot/Image"
  elif compgen -G "$DEST/boot/vmlinuz-*" >/dev/null; then
    vmlinuz="$(compgen -G "$DEST/boot/vmlinuz-*" | grep -v '\.uncompressed$' | head -1)"
    if gzip -t "$vmlinuz" 2>/dev/null; then
      gunzip -c "$vmlinuz" > "$DEST/boot/Image"
    else
      cp -a "$vmlinuz" "$DEST/boot/Image"
    fi
  fi
fi

if [ -d "$SRC/usr/lib/modules" ]; then
  cp -a "$SRC/usr/lib/modules" "$DEST/lib/modules"
elif [ -d "$SRC/lib/modules" ]; then
  cp -a "$SRC/lib/modules" "$DEST/lib/modules"
fi

# Sailfish kmod does not load CONFIG_MODULE_COMPRESS_ZSTD (.ko.zst).
# Decompress in place so panel/DRM modules can load without an initramfs.
if [ -d "$DEST/lib/modules" ]; then
  if command -v zstd >/dev/null 2>&1; then
    find "$DEST/lib/modules" -type f -name '*.ko.zst' -print0 \
      | while IFS= read -r -d '' f; do
          zstd -d -f -q -o "${f%.zst}" "$f" && rm -f "$f"
        done
  else
    echo "WARN: zstd not installed; leaving .ko.zst modules (panel may not load)" >&2
  fi
fi

if [ ! -f "$DEST/boot/Image" ]; then
  echo "ERROR: could not locate kernel Image under $DEST/boot" >&2
  ls -la "$DEST/boot" >&2 || true
  exit 1
fi

sz=$(wc -c < "$DEST/boot/Image")
if [ "$sz" -lt 1000000 ]; then
  echo "ERROR: Image is only ${sz} bytes (placeholder?)" >&2
  exit 1
fi
echo "Staged ${sz} byte Image into $DEST"
find "$DEST" -type f | head -40 || true
exit 0
