#!/usr/bin/env bash
# Stage GitHub Pages site: adaptation RPM repo + reusable prebuilts.
#
# Expects:
#   ADAPTATION_REPO  (default: repo/adaptation) with *.rpm + createrepo metadata
#   PREBUILTS_DIR    (default: out/prebuilts) with published blobs
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${ADAPTATION_REPO:-$ROOT/repo/adaptation}"
PREBUILTS="${PREBUILTS_DIR:-$ROOT/out/prebuilts}"
SITE="${PAGES_SITE:-$ROOT/site}"
PAGES_BASE="${PAGES_BASE:-https://pad6-dev.github.io/sailfish-pipa}"
GIT_SHA="${GIT_SHA:-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)}"

[ -d "$SRC" ] || { echo "missing $SRC" >&2; exit 1; }
test "$(find "$SRC" -name '*.rpm' | wc -l)" -ge 1 || {
  echo "no RPMs in $SRC" >&2
  exit 1
}

if [ ! -d "$SRC/repodata" ]; then
  if command -v createrepo_c >/dev/null; then
    createrepo_c "$SRC"
  elif command -v createrepo >/dev/null; then
    createrepo "$SRC"
  else
    echo "need createrepo_c" >&2
    exit 1
  fi
fi

need_prebuilt() {
  local f="$1"
  [ -s "$PREBUILTS/$f" ] || { echo "missing prebuilt: $PREBUILTS/$f" >&2; exit 1; }
}

need_prebuilt u-boot-xiaomi-pipa.img
need_prebuilt mesa-freedreno-sfos-aarch64.tar.gz
need_prebuilt xiaomi-pipa-firmware.tar.gz
# Kernel mirror may keep its upstream filename
KERNEL_FILE=$(find "$PREBUILTS" -maxdepth 1 -name 'linux-pipa*.pkg.tar.xz' -printf '%f\n' | head -1 || true)
[ -n "$KERNEL_FILE" ] || { echo "missing linux-pipa*.pkg.tar.xz in $PREBUILTS" >&2; exit 1; }

rm -rf "$SITE"
mkdir -p "$SITE/adaptation" "$SITE/prebuilts"
cp -a "$SRC"/. "$SITE/adaptation/"
cp -a "$PREBUILTS/u-boot-xiaomi-pipa.img" "$SITE/prebuilts/"
cp -a "$PREBUILTS/mesa-freedreno-sfos-aarch64.tar.gz" "$SITE/prebuilts/"
cp -a "$PREBUILTS/xiaomi-pipa-firmware.tar.gz" "$SITE/prebuilts/"
cp -a "$PREBUILTS/$KERNEL_FILE" "$SITE/prebuilts/"

cat > "$SITE/prebuilts/manifest.json" <<EOF
{
  "git_sha": "${GIT_SHA}",
  "pages_base": "${PAGES_BASE}",
  "uboot": "${PAGES_BASE}/prebuilts/u-boot-xiaomi-pipa.img",
  "mesa": "${PAGES_BASE}/prebuilts/mesa-freedreno-sfos-aarch64.tar.gz",
  "firmware": "${PAGES_BASE}/prebuilts/xiaomi-pipa-firmware.tar.gz",
  "kernel": "${PAGES_BASE}/prebuilts/${KERNEL_FILE}"
}
EOF

cat > "$SITE/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <title>sailfish-pipa adaptation + prebuilts</title>
</head>
<body>
  <h1>Sailfish OS pipa</h1>
  <p>Git: <code>${GIT_SHA}</code></p>
  <h2>Adaptation RPM repository</h2>
  <p><a href="adaptation/">adaptation/</a></p>
  <pre>ssu ar adaptation-xiaomi-pipa ${PAGES_BASE}/adaptation/
zypper ref adaptation-xiaomi-pipa
zypper in droid-config-pipa pipa-qcom-userspace pipa-hexagonrpc libssc firmware-pipa
# or pull the full pattern:
zypper in patterns-sailfish-device-configuration-pipa</pre>
  <h2>Reusable prebuilts</h2>
  <p>Built once by the <strong>Publish prebuilts</strong> workflow; image/pack downloads these instead of rebuilding.</p>
  <ul>
    <li><a href="prebuilts/u-boot-xiaomi-pipa.img">u-boot-xiaomi-pipa.img</a></li>
    <li><a href="prebuilts/mesa-freedreno-sfos-aarch64.tar.gz">mesa-freedreno-sfos-aarch64.tar.gz</a></li>
    <li><a href="prebuilts/xiaomi-pipa-firmware.tar.gz">xiaomi-pipa-firmware.tar.gz</a></li>
    <li><a href="prebuilts/${KERNEL_FILE}">${KERNEL_FILE}</a></li>
    <li><a href="prebuilts/manifest.json">manifest.json</a></li>
  </ul>
  <p>Enable <code>Settings → Pages → GitHub Actions</code>, run <em>Publish prebuilts</em> once, then <em>Build Sailfish pipa image</em>.</p>
</body>
</html>
EOF

echo "Pages staged at $SITE"
find "$SITE/prebuilts" -type f | sort
find "$SITE/adaptation" -maxdepth 2 -type f | head -20
