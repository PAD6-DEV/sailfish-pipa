#!/usr/bin/env bash
# Build sensorfw-qt5-libssc RPM inside Sailfish Platform SDK (sb2 aarch64).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
SFOS_SDK_RELEASE="${SFOS_SDK_RELEASE:-5.0.0.43}"
SDK_IMAGE="${SDK_IMAGE:-coderus/sailfishos-platform-sdk:${SFOS_SDK_RELEASE}}"
TARGET="${SFOS_TARGET:-SailfishOS-${SFOS_SDK_RELEASE}-aarch64}"
HOST_OUT="${SSC_SENSORFW_OUT:-$ROOT/out}"
JOBS="${JOBS:-$(nproc)}"

if [ "${SSC_SENSORFW_IN_SDK:-0}" != 1 ]; then
  command -v docker >/dev/null || { echo "need docker" >&2; exit 1; }
  docker pull "$SDK_IMAGE"
  mkdir -p "$HOST_OUT"
  chmod -R a+rwX "$HOST_OUT"
  exec docker run --rm --privileged \
    -e SSC_SENSORFW_IN_SDK=1 \
    -e JOBS="$JOBS" \
    -e SFOS_SDK_RELEASE="$SFOS_SDK_RELEASE" \
    -e SFOS_TARGET="$TARGET" \
    -e SSC_SENSORFW_HOST_OUT=/sailfish-pipa/pkgs/sensorfw-qt5-libssc/out \
    -v "$REPO:/sailfish-pipa" \
    -w /sailfish-pipa \
    "$SDK_IMAGE" \
    bash /sailfish-pipa/pkgs/sensorfw-qt5-libssc/build-in-sdk.sh
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

WORK="${HOME}/sensorfw-libssc-work"
OUT="${WORK}/out"
DEST="${OUT}/destdir"
HOST_OUT="${SSC_SENSORFW_HOST_OUT:-/sailfish-pipa/pkgs/sensorfw-qt5-libssc/out}"
rm -rf "$WORK"
mkdir -p "$DEST" "$OUT" "$HOST_OUT"

sb2 -t "$TARGET" true
sb2_install gcc gcc-c++ make binutils pkgconfig qt5-qtcore-devel \
  sensorfw-qt5-devel glib2-devel libffi-devel || true
# Package names vary across SFOS images
sb2_install pkgconfig\(Qt5Core\) pkgconfig\(glib-2.0\) pkgconfig\(sensord-qt5\) || true

# Install previously built libssc (+ devel) from adaptation out if present
LIBSSC_RPM="$(find /sailfish-pipa/pkgs/libssc/out -name 'libssc-0*.aarch64.rpm' ! -name '*devel*' 2>/dev/null | head -1 || true)"
LIBSSC_DEVEL="$(find /sailfish-pipa/pkgs/libssc/out -name 'libssc-devel*.rpm' 2>/dev/null | head -1 || true)"
if [ -n "$LIBSSC_RPM" ]; then
  sb2_t rpm -Uvh --force "$LIBSSC_RPM" ${LIBSSC_DEVEL:+"$LIBSSC_DEVEL"} || \
    sb2_install "$LIBSSC_RPM" ${LIBSSC_DEVEL:+"$LIBSSC_DEVEL"} || true
fi

# Ensure libssc headers/pkgconfig exist (devel RPM or stage from source tree in image)
if ! sb2_t pkg-config --exists libssc; then
  echo "libssc.pc missing — staging headers from pkgs/libssc generated build tree fallback" >&2
  # Build minimal prefix from vendored public headers snapshot if present
  if [ -d /sailfish-pipa/pkgs/libssc/include/libssc ]; then
    sb2_t bash -lc "
      mkdir -p /usr/include /usr/lib64/pkgconfig
      cp -a /sailfish-pipa/pkgs/libssc/include/libssc /usr/include/
      cp -a /sailfish-pipa/pkgs/libssc/files/libssc.pc /usr/lib64/pkgconfig/libssc.pc
      # stub .so link if only headers staged (prefer real RPM)
      test -e /usr/lib64/libssc.so || ln -sf libssc.so.2 /usr/lib64/libssc.so || true
    "
  else
    echo "ERROR: need libssc-devel RPM or pkgs/libssc/include/libssc" >&2
    exit 1
  fi
fi

SRC=/sailfish-pipa/pkgs/sensorfw-qt5-libssc/src
sb2_t bash -lc "
  set -e
  export PATH=\"\$HOME/.local/bin:\$PATH\"
  cd $SRC
  rm -rf build && mkdir build && cd build
  qmake ../sscaccelerometeradaptor.pro
  make -j$JOBS
  make INSTALL_ROOT=$DEST install
"

# Normalize plugin path (qmake installs under QT_INSTALL_LIBS)
mkdir -p "$DEST/usr/lib64/sensord-qt5"
find "$DEST" -name 'libsscaccelerometeradaptor-qt5.so' | while read -r f; do
  cp -a "$f" "$DEST/usr/lib64/sensord-qt5/"
done
test -f "$DEST/usr/lib64/sensord-qt5/libsscaccelerometeradaptor-qt5.so"

rm -rf "$OUT/wrap"
mkdir -p "$OUT/wrap/destdir"
cp -a "$DEST"/. "$OUT/wrap/destdir/"
mkdir -p "$HOME/rpmbuild"/{SOURCES,SPECS,RPMS,BUILD,SRPMS}
tar -C "$OUT/wrap" -czf "$HOME/rpmbuild/SOURCES/sensorfw-qt5-libssc.tar.gz" destdir
cp /sailfish-pipa/pkgs/sensorfw-qt5-libssc/rpm/sensorfw-qt5-libssc.spec "$HOME/rpmbuild/SPECS/"
rpmbuild -bb --target=aarch64 --define "_topdir $HOME/rpmbuild" \
  --define "__strip /bin/true" --define "debug_package %{nil}" \
  "$HOME/rpmbuild/SPECS/sensorfw-qt5-libssc.spec"

find "$HOME/rpmbuild/RPMS" -name 'sensorfw-qt5-libssc*.rpm' -exec cp -v {} "$HOST_OUT/" \;
ls -la "$HOST_OUT"
echo "OK: sensorfw-qt5-libssc RPM"
