#!/usr/bin/env bash
# Build plymouth-lite + default theme RPMs inside the SFOS Platform SDK.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
SFOS_SDK_RELEASE="${SFOS_SDK_RELEASE:-5.0.0.43}"
SDK_IMAGE="${SDK_IMAGE:-coderus/sailfishos-platform-sdk:${SFOS_SDK_RELEASE}}"
TARGET="${SFOS_TARGET:-SailfishOS-${SFOS_SDK_RELEASE}-aarch64}"
HOST_OUT="${PLYMOUTH_OUT:-$ROOT/out}"
PLYMOUTH_TAG="${PLYMOUTH_TAG:-0.6.0+git1}"

if [ "${PLYMOUTH_IN_SDK:-0}" != 1 ]; then
  command -v docker >/dev/null || { echo "need docker" >&2; exit 1; }
  docker pull "$SDK_IMAGE"
  mkdir -p "$HOST_OUT"
  chmod -R a+rwX "$HOST_OUT"
  exec docker run --rm --privileged \
    -e PLYMOUTH_IN_SDK=1 \
    -e SFOS_SDK_RELEASE="$SFOS_SDK_RELEASE" \
    -e SFOS_TARGET="$TARGET" \
    -e PLYMOUTH_TAG="$PLYMOUTH_TAG" \
    -e PLYMOUTH_HOST_OUT=/sailfish-pipa/pkgs/plymouth-lite/out \
    -v "$REPO:/sailfish-pipa" \
    -w /sailfish-pipa \
    "$SDK_IMAGE" \
    bash /sailfish-pipa/pkgs/plymouth-lite/build-in-sdk.sh
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

WORK="${HOME}/plymouth-lite-work"
DEST="$WORK/destdir"
HOST_OUT="${PLYMOUTH_HOST_OUT:-/sailfish-pipa/pkgs/plymouth-lite/out}"
rm -rf "$WORK"
mkdir -p "$WORK/src" "$DEST" "$HOST_OUT"

sb2 -t "$TARGET" true
sb2_install gcc make binutils pkgconfig curl tar gzip pkgconfig\(libpng\) || true

sb2_t bash -lc 'command -v gcc >/dev/null && pkg-config --exists libpng' || {
  echo "ERROR: plymouth-lite requires gcc and pkg-config(libpng)" >&2
  exit 1
}

echo "==> fetch plymouth-lite ${PLYMOUTH_TAG}"
curl -fL --retry 3 -o "$WORK/plymouth-lite.tar.gz" \
  "https://github.com/sailfishos/plymouth-lite/archive/refs/tags/${PLYMOUTH_TAG//+/%2B}.tar.gz"
tar -C "$WORK/src" -xzf "$WORK/plymouth-lite.tar.gz"
SRC="$(find "$WORK/src" -mindepth 1 -maxdepth 1 -type d -name 'plymouth-lite-*' | head -1)"
test -n "$SRC" && test -f "$SRC/Makefile"

echo "==> build plymouth-lite"
sb2_t make -C "$SRC" CC=gcc CFLAGS="-O2 -g"

install -Dm755 "$SRC/ply-image" "$DEST/usr/bin/ply-image"
install -d "$DEST/usr/share/plymouth"
for image in splash halt reboot poweroff; do
  install -Dm644 "$SRC/splash.png" "$DEST/usr/share/plymouth/${image}.png"
done

install -d "$DEST/usr/lib/systemd/system"
for action in start halt reboot poweroff; do
  install -Dm644 "$SRC/rpm/plymouth-lite-${action}.service" \
    "$DEST/usr/lib/systemd/system/plymouth-lite-${action}.service"
done

install -d \
  "$DEST/usr/lib/systemd/system/sysinit.target.wants" \
  "$DEST/usr/lib/systemd/system/halt.target.wants" \
  "$DEST/usr/lib/systemd/system/reboot.target.wants" \
  "$DEST/usr/lib/systemd/system/poweroff.target.wants"
ln -s ../plymouth-lite-start.service \
  "$DEST/usr/lib/systemd/system/sysinit.target.wants/plymouth-lite-start.service"
ln -s ../plymouth-lite-halt.service \
  "$DEST/usr/lib/systemd/system/halt.target.wants/plymouth-lite-halt.service"
ln -s ../plymouth-lite-reboot.service \
  "$DEST/usr/lib/systemd/system/reboot.target.wants/plymouth-lite-reboot.service"
ln -s ../plymouth-lite-poweroff.service \
  "$DEST/usr/lib/systemd/system/poweroff.target.wants/plymouth-lite-poweroff.service"

mkdir -p "$WORK/wrap" "$HOME/rpmbuild"/{SOURCES,SPECS,RPMS,BUILD,SRPMS}
cp -a "$DEST" "$WORK/wrap/destdir"
tar -C "$WORK/wrap" -czf "$HOME/rpmbuild/SOURCES/plymouth-lite.tar.gz" destdir
cp /sailfish-pipa/pkgs/plymouth-lite/rpm/plymouth-lite.spec "$HOME/rpmbuild/SPECS/"

rpmbuild -bb --target=aarch64 --define "_topdir $HOME/rpmbuild" \
  --define "__strip /bin/true" --define "debug_package %{nil}" \
  "$HOME/rpmbuild/SPECS/plymouth-lite.spec"

find "$HOME/rpmbuild/RPMS" -name 'plymouth-lite*.rpm' -exec cp -v {} "$HOST_OUT/" \;
test -n "$(find "$HOST_OUT" -name 'plymouth-lite-0*.rpm')"
test -n "$(find "$HOST_OUT" -name 'plymouth-lite-theme-default*.rpm')"
ls -la "$HOST_OUT"
echo "OK: plymouth-lite RPMs"
