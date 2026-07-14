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

# Adreno A650 SQE/GMU from linux-firmware (required for MSM DRM GLES; zap alone is not enough)
mkdir -p "$DEST/usr/lib/firmware/qcom"
for blob in a650_sqe.fw a650_gmu.bin; do
  if [ ! -f "$WORK/linux-fw-$blob" ]; then
    echo "GET linux-firmware qcom/$blob"
    curl -fL --retry 3 -A "$UA" -o "$WORK/linux-fw-$blob" \
      "https://gitlab.com/kernel-firmware/linux-firmware/-/raw/main/qcom/$blob"
  fi
  install -Dm644 "$WORK/linux-fw-$blob" "$DEST/usr/lib/firmware/qcom/$blob"
done

# ath11k QCA6390 (WiFi) + QCA Bluetooth from linux-firmware
mkdir -p "$DEST/usr/lib/firmware/ath11k/QCA6390/hw2.0" "$DEST/usr/lib/firmware/qca"
for blob in \
  ath11k/QCA6390/hw2.0/amss.bin \
  ath11k/QCA6390/hw2.0/board-2.bin \
  ath11k/QCA6390/hw2.0/m3.bin \
  qca/htbtfw20.tlv \
  qca/htnv20.bin
do
  base=$(basename "$blob")
  cache="$WORK/linux-fw-$(echo "$blob" | tr / -)"
  if [ ! -f "$cache" ]; then
    echo "GET linux-firmware $blob"
    curl -fL --retry 3 -A "$UA" -o "$cache" \
      "https://gitlab.com/kernel-firmware/linux-firmware/-/raw/main/$blob"
  fi
  install -Dm644 "$cache" "$DEST/usr/lib/firmware/$blob"
done

# Symlinks some kernels expect next to qcom/sm8250/...
mkdir -p "$DEST/usr/lib/firmware/sm8250/xiaomi"
if [ -d "$DEST/usr/lib/firmware/qcom/sm8250/xiaomi/pipa" ]; then
  ln -sfn ../../qcom/sm8250/xiaomi/pipa \
    "$DEST/usr/lib/firmware/sm8250/xiaomi/pipa" 2>/dev/null \
    || ln -sfn /usr/lib/firmware/qcom/sm8250/xiaomi/pipa \
      "$DEST/usr/lib/firmware/sm8250/xiaomi/pipa"
fi

# Also expose under /lib/firmware for the kernel loader when not usr-merged.
mkdir -p "$DEST/lib"
ln -sfn ../usr/lib/firmware "$DEST/lib/firmware"

TGZ="$OUT/xiaomi-pipa-firmware.tar.gz"
tar -C "$DEST" -czf "$TGZ" .
echo "Wrote $TGZ ($(du -h "$TGZ" | awk '{print $1}'))"
tar -tzf "$TGZ" | grep -E 'qcom/sm8250/xiaomi/pipa/a650_zap\.mbn$' >/dev/null
tar -tzf "$TGZ" | grep -E 'novatek/nt36532_' >/dev/null
tar -tzf "$TGZ" | grep -E 'ath11k/QCA6390/hw2.0/amss\.bin$' >/dev/null
tar -tzf "$TGZ" | grep -E 'qca/htbtfw20\.tlv$' >/dev/null
echo "OK: firmware tarball contains a650_zap.mbn + novatek + ath11k + qca BT"
