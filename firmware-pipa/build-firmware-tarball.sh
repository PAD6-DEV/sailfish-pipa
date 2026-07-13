#!/usr/bin/env bash
# Pack Xiaomi Pad 6 (pipa) firmware tree for SFOS rootfs inject / Pages prebuilts.
# Source: https://github.com/pipa-mainline/xiaomi-pipa-firmware (same layout as pipa-pkgs).
#
# Output: $FW_OUT/xiaomi-pipa-firmware.tar.gz  (paths under usr/…)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${FW_OUT:-$ROOT/out}"
WORK="${FW_WORK:-$ROOT/work}"
COMMIT="${FW_COMMIT:-842d35beffeda8c6d1b0e611b335543bf0e6b41e}"
UA="${UA:-Mozilla/5.0 (compatible; sailfish-pipa-ci)}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing $1" >&2; exit 1; }; }
need curl
need tar
need install

mkdir -p "$WORK" "$OUT"
SRC_TGZ="$WORK/xiaomi-pipa-firmware-${COMMIT}.tar.gz"
SRC_DIR="$WORK/xiaomi-pipa-firmware-${COMMIT}"
DEST="$WORK/destdir"

if [ ! -d "$SRC_DIR" ]; then
  echo "GET pipa-mainline/xiaomi-pipa-firmware @ ${COMMIT}"
  curl -fL --retry 3 -A "$UA" -o "$SRC_TGZ" \
    "https://github.com/pipa-mainline/xiaomi-pipa-firmware/archive/${COMMIT}.tar.gz"
  tar -C "$WORK" -xzf "$SRC_TGZ"
fi
test -d "$SRC_DIR"

rm -rf "$DEST"
mkdir -p "$DEST"

install_list() {
  local list="$1"
  local mode="$2" # basename_to_qcom | basename_to_subdir | path_as_is
  local sub="${3:-}"
  local rel dest_path
  while IFS= read -r rel || [ -n "${rel:-}" ]; do
    [ -n "$rel" ] || continue
    [[ "$rel" =~ ^# ]] && continue
    test -f "$SRC_DIR/$rel" || { echo "missing blob: $rel" >&2; exit 1; }
    case "$mode" in
      basename_to_qcom)
        dest_path="$DEST/usr/lib/firmware/qcom/sm8250/xiaomi/pipa/$(basename "$rel")"
        ;;
      basename_to_subdir)
        dest_path="$DEST/usr/lib/firmware/${sub}/$(basename "$rel")"
        ;;
      path_as_is)
        # Lists already use usr/share/... or lib/firmware/...
        if [[ "$rel" == usr/* ]]; then
          dest_path="$DEST/$rel"
        elif [[ "$rel" == lib/firmware/* ]]; then
          dest_path="$DEST/usr/$rel"
        else
          dest_path="$DEST/$rel"
        fi
        ;;
      *) echo "bad mode $mode" >&2; exit 1 ;;
    esac
    install -Dm644 "$SRC_DIR/$rel" "$dest_path"
  done < "$list"
}

# Match pipa-pkgs Arch PKGBUILD destinations
install_list "$ROOT/awinic_firmware.files" basename_to_subdir awinic
install_list "$ROOT/novatek_firmware.files" basename_to_subdir novatek
install_list "$ROOT/nuvolta_firmware.files" basename_to_subdir nuvolta
install_list "$ROOT/qcom_firmware.files" basename_to_qcom
install_list "$ROOT/dsp_firmware.files" path_as_is

# Symlinks some kernels expect next to qcom/sm8250/...
mkdir -p "$DEST/usr/lib/firmware/sm8250/xiaomi"
if [ -d "$DEST/usr/lib/firmware/qcom/sm8250/xiaomi/pipa" ]; then
  ln -sfn ../../qcom/sm8250/xiaomi/pipa \
    "$DEST/usr/lib/firmware/sm8250/xiaomi/pipa" 2>/dev/null \
    || ln -sfn /usr/lib/firmware/qcom/sm8250/xiaomi/pipa \
      "$DEST/usr/lib/firmware/sm8250/xiaomi/pipa"
fi

TGZ="$OUT/xiaomi-pipa-firmware.tar.gz"
tar -C "$DEST" -czf "$TGZ" .
echo "Wrote $TGZ ($(du -h "$TGZ" | awk '{print $1}'))"
tar -tzf "$TGZ" | grep -E 'qcom/sm8250/xiaomi/pipa/a650_zap\.mbn$' >/dev/null
echo "OK: firmware tarball contains a650_zap.mbn"
