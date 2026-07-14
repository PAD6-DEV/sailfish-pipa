#!/bin/sh
# Pick the Qualcomm MSM DRM node for Qt EGLFS (avoid simpledrm as card0).
# Never block boot: always exit 0.
set -u

if [ ! -e /lib/firmware ] && [ -d /usr/lib/firmware ]; then
  ln -sfn /usr/lib/firmware /lib/firmware || true
fi

# Soft GPU bump (non-fatal)
for path in /sys/class/devfreq/*adreno* /sys/class/devfreq/*gpu*; do
  [ -e "$path/governor" ] || continue
  echo performance > "$path/governor" 2>/dev/null || true
done

CFG=/etc/eglfs-config.json
MSM=

for card in /sys/class/drm/card[0-9]; do
  [ -e "$card/device/driver" ] || continue
  driver=$(basename "$(readlink -f "$card/device/driver" 2>/dev/null || true)")
  case "$driver" in
    msm_drm|msm)
      MSM="/dev/dri/$(basename "$card")"
      break
      ;;
  esac
done

if [ -z "${MSM:-}" ]; then
  if [ -e /dev/dri/card1 ]; then
    MSM=/dev/dri/card1
  elif [ -e /dev/dri/card0 ]; then
    MSM=/dev/dri/card0
  else
    echo "pipa-eglfs-kms: no DRM card" >&2
    exit 0
  fi
fi

umask 022
tmp=$(mktemp 2>/dev/null || echo /run/eglfs-config.json.$$)
cat > "$tmp" <<EOF
{
    "device": "$MSM",
    "hwcursor": false
}
EOF
mv -f "$tmp" "$CFG" 2>/dev/null || cp -f "$tmp" "$CFG" || true
echo "pipa-eglfs-kms: using $MSM"
exit 0
