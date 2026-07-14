#!/usr/bin/env bash
# Build pipa-hexagonrpc RPM inside Sailfish Platform SDK (sb2 aarch64).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
SFOS_SDK_RELEASE="${SFOS_SDK_RELEASE:-5.0.0.43}"
SDK_IMAGE="${SDK_IMAGE:-coderus/sailfishos-platform-sdk:${SFOS_SDK_RELEASE}}"
TARGET="${SFOS_TARGET:-SailfishOS-${SFOS_SDK_RELEASE}-aarch64}"
HOST_OUT="${HEX_OUT:-$ROOT/out}"
JOBS="${JOBS:-$(nproc)}"
HEX_VER="${HEX_VER:-0.3.2}"

if [ "${HEX_IN_SDK:-0}" != 1 ]; then
  command -v docker >/dev/null || { echo "need docker" >&2; exit 1; }
  docker pull "$SDK_IMAGE"
  mkdir -p "$HOST_OUT"
  chmod -R a+rwX "$HOST_OUT"
  exec docker run --rm --privileged \
    -e HEX_IN_SDK=1 \
    -e JOBS="$JOBS" \
    -e SFOS_SDK_RELEASE="$SFOS_SDK_RELEASE" \
    -e SFOS_TARGET="$TARGET" \
    -e HEX_HOST_OUT=/sailfish-pipa/pkgs/pipa-hexagonrpc/out \
    -e HEX_VER="$HEX_VER" \
    -v "$REPO:/sailfish-pipa" \
    -w /sailfish-pipa \
    "$SDK_IMAGE" \
    bash /sailfish-pipa/pkgs/pipa-hexagonrpc/build-in-sdk.sh
fi

sb2_t() {
  if sb2 -t "$TARGET" -m sdk-build true 2>/dev/null; then
    sb2 -t "$TARGET" -m sdk-build "$@"
  else
    sb2 -t "$TARGET" "$@"
  fi
}

sb2_install() {
  if sb2 -t "$TARGET" -m sdk-install -R true 2>/dev/null; then
    sb2 -t "$TARGET" -m sdk-install -R zypper -n in "$@" || \
      sb2 -t "$TARGET" -m sdk-install -R zypper -n in --force-resolution "$@"
  else
    sb2 -t "$TARGET" -R zypper -n in "$@" || \
      sb2 -t "$TARGET" -R zypper -n in --force-resolution "$@"
  fi
}

WORK="${HOME}/pipa-hexagon-work"
OUT="${WORK}/out"
DEST="${OUT}/destdir"
HOST_OUT="${HEX_HOST_OUT:-/sailfish-pipa/pkgs/pipa-hexagonrpc/out}"
rm -rf "$WORK"
mkdir -p "$DEST" "$OUT" "$HOST_OUT" "$WORK/src"

sb2 -t "$TARGET" true
sb2_install gcc make binutils pkgconfig meson ninja git curl tar || true

TGZ="$WORK/hexagonrpc-${HEX_VER}.tar.gz"
curl -fL -o "$TGZ" \
  "https://github.com/linux-msm/hexagonrpc/archive/refs/tags/v${HEX_VER}.tar.gz"
tar -C "$WORK/src" -xzf "$TGZ"
SRC="$WORK/src/hexagonrpc-${HEX_VER}"

# Modern fastrpc.h for older tagged trees that may lack it / need newer ioctls
mkdir -p "$SRC/include/linux"
if [ ! -f "$SRC/include/linux/fastrpc.h" ]; then
  curl -fL -o "$SRC/include/linux/fastrpc.h" \
    "https://raw.githubusercontent.com/torvalds/linux/master/include/uapi/linux/fastrpc.h" \
    || curl -fL -o "$SRC/include/linux/fastrpc.h" \
      "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/include/uapi/linux/fastrpc.h"
fi

sb2_t bash -lc "
  set -e
  cd $SRC
  meson setup build --prefix=/usr --libdir=lib64
  meson compile -C build -j$JOBS
  DESTDIR=$DEST meson install -C build
"

install -Dm644 /sailfish-pipa/pkgs/pipa-hexagonrpc/files/hexagonrpcd-sdsp.service \
  "$DEST/usr/lib/systemd/system/hexagonrpcd-sdsp.service"
install -Dm644 /sailfish-pipa/pkgs/pipa-hexagonrpc/files/hexagonrpcd-adsp-rootpd.service \
  "$DEST/usr/lib/systemd/system/hexagonrpcd-adsp-rootpd.service"
install -Dm644 /sailfish-pipa/pkgs/pipa-hexagonrpc/files/hexagonrpcd-adsp-sensorspd.service \
  "$DEST/usr/lib/systemd/system/hexagonrpcd-adsp-sensorspd.service"
install -Dm644 /sailfish-pipa/pkgs/pipa-hexagonrpc/files/sysusers.conf \
  "$DEST/usr/lib/sysusers.d/fastrpc.conf"
install -Dm644 /sailfish-pipa/pkgs/pipa-hexagonrpc/files/10-fastrpc.rules \
  "$DEST/usr/lib/udev/rules.d/10-fastrpc.rules"

# Wrap for rpm %setup -n destdir
rm -rf "$OUT/wrap"
mkdir -p "$OUT/wrap/destdir"
cp -a "$DEST"/. "$OUT/wrap/destdir/"
mkdir -p "$HOME/rpmbuild"/{SOURCES,SPECS,RPMS,BUILD,SRPMS}
tar -C "$OUT/wrap" -czf "$HOME/rpmbuild/SOURCES/pipa-hexagonrpc.tar.gz" destdir
cp /sailfish-pipa/pkgs/pipa-hexagonrpc/rpm/pipa-hexagonrpc.spec "$HOME/rpmbuild/SPECS/"
rpmbuild -bb --target=aarch64 --define "_topdir $HOME/rpmbuild" \
  "$HOME/rpmbuild/SPECS/pipa-hexagonrpc.spec"

find "$HOME/rpmbuild/RPMS" -name 'pipa-hexagonrpc*.rpm' -exec cp -v {} "$HOST_OUT/" \;
ls -la "$HOST_OUT"
echo "OK: pipa-hexagonrpc RPM"
