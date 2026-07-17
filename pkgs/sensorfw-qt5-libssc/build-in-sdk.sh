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
SRC="${WORK}/src"
LIBSSC_STAGE="${WORK}/libssc-sysroot"
HOST_OUT="${SSC_SENSORFW_HOST_OUT:-/sailfish-pipa/pkgs/sensorfw-qt5-libssc/out}"
rm -rf "$WORK"
mkdir -p "$DEST" "$OUT" "$SRC" "$LIBSSC_STAGE" "$HOST_OUT"

# /sailfish-pipa is visible to the SDK container, but not inside sb2.
# Copy every build input into $HOME before entering the target sandbox.
cp -a /sailfish-pipa/pkgs/sensorfw-qt5-libssc/src/. "$SRC/"

sb2 -t "$TARGET" true
sb2_install gcc gcc-c++ make binutils pkgconfig qt5-qtcore-devel \
  sensorfw-qt5-devel glib2-devel libffi-devel || true
# Package names vary across SFOS images
sb2_install pkgconfig\(Qt5Core\) pkgconfig\(glib-2.0\) pkgconfig\(sensord-qt5\) || true

# Stage the previously built runtime + devel RPMs in a private sysroot.
# Installing local RPMs into the sb2 target is both unnecessary and unreliable:
# sb2 cannot resolve paths under /sailfish-pipa and its /usr is read-only here.
LIBSSC_RPM="$(find /sailfish-pipa/pkgs/libssc/out -name 'libssc-0*.aarch64.rpm' ! -name '*devel*' 2>/dev/null | head -1 || true)"
LIBSSC_DEVEL="$(find /sailfish-pipa/pkgs/libssc/out -name 'libssc-devel*.rpm' 2>/dev/null | head -1 || true)"
test -n "$LIBSSC_RPM" || {
  echo "ERROR: missing pkgs/libssc/out/libssc-0*.aarch64.rpm" >&2
  exit 1
}
test -n "$LIBSSC_DEVEL" || {
  echo "ERROR: missing pkgs/libssc/out/libssc-devel*.aarch64.rpm" >&2
  exit 1
}

for rpm in "$LIBSSC_RPM" "$LIBSSC_DEVEL"; do
  (cd "$LIBSSC_STAGE" && rpm2cpio "$rpm" | cpio -idm --quiet)
done

# The packaged .pc uses prefix=/usr for the device. Rewrite only the private
# build copy so pkg-config resolves headers and libraries in our staging tree.
LIBSSC_PC="$LIBSSC_STAGE/usr/lib64/pkgconfig/libssc.pc"
test -f "$LIBSSC_PC"
sed -i "s|^prefix=/usr$|prefix=$LIBSSC_STAGE/usr|" "$LIBSSC_PC"
test -f "$LIBSSC_STAGE/usr/include/libssc/libssc.h"
test -e "$LIBSSC_STAGE/usr/lib64/libssc.so"

sb2_t bash -lc "
  set -e
  export PATH=\"\$HOME/.local/bin:\$PATH\"
  export PKG_CONFIG_PATH=$LIBSSC_STAGE/usr/lib64/pkgconfig:\${PKG_CONFIG_PATH:-}
  export LD_LIBRARY_PATH=$LIBSSC_STAGE/usr/lib64:\${LD_LIBRARY_PATH:-}
  export LIBRARY_PATH=$LIBSSC_STAGE/usr/lib64:\${LIBRARY_PATH:-}
  cd $SRC
  for pro in sscaccelerometeradaptor.pro sscalsadaptor.pro; do
    name=\${pro%.pro}
    rm -rf build-\$name && mkdir build-\$name && cd build-\$name
    qmake ../\$pro
    make -j$JOBS
    make INSTALL_ROOT=$DEST install
    cd ..
  done
"

# Normalize plugin path (qmake installs under QT_INSTALL_LIBS)
mkdir -p "$DEST/usr/lib64/sensord-qt5"
find "$DEST" -name 'libssc*adaptor-qt5.so' | while read -r f; do
  target="$DEST/usr/lib64/sensord-qt5/$(basename "$f")"
  if [ "$f" != "$target" ]; then
    cp -a "$f" "$target"
  fi
done
test -f "$DEST/usr/lib64/sensord-qt5/libsscaccelerometeradaptor-qt5.so"
test -f "$DEST/usr/lib64/sensord-qt5/libsscalsadaptor-qt5.so"

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
