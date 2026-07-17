#!/usr/bin/env bash
# Build libcamera (+ IPA, tools, GStreamer plugin) for Sailfish OS aarch64.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
SFOS_SDK_RELEASE="${SFOS_SDK_RELEASE:-5.0.0.43}"
SDK_IMAGE="${SDK_IMAGE:-coderus/sailfishos-platform-sdk:${SFOS_SDK_RELEASE}}"
TARGET="${SFOS_TARGET:-SailfishOS-${SFOS_SDK_RELEASE}-aarch64}"
HOST_OUT="${LIBCAMERA_OUT:-$ROOT/out}"
JOBS="${JOBS:-$(nproc)}"
LIBCAMERA_VER="${LIBCAMERA_VER:-0.7.1}"

if [ "${LIBCAMERA_IN_SDK:-0}" != 1 ]; then
  command -v docker >/dev/null || { echo "need docker" >&2; exit 1; }
  docker pull "$SDK_IMAGE"
  mkdir -p "$HOST_OUT"
  chmod -R a+rwX "$HOST_OUT"
  exec docker run --rm --privileged \
    -e LIBCAMERA_IN_SDK=1 \
    -e JOBS="$JOBS" \
    -e SFOS_SDK_RELEASE="$SFOS_SDK_RELEASE" \
    -e SFOS_TARGET="$TARGET" \
    -e LIBCAMERA_HOST_OUT=/sailfish-pipa/pkgs/libcamera/out \
    -e LIBCAMERA_VER="$LIBCAMERA_VER" \
    -v "$REPO:/sailfish-pipa" \
    -w /sailfish-pipa \
    "$SDK_IMAGE" \
    bash /sailfish-pipa/pkgs/libcamera/build-in-sdk.sh
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

WORK="${HOME}/libcamera-work"
OUT="${WORK}/out"
DEST="${OUT}/destdir"
HOST_OUT="${LIBCAMERA_HOST_OUT:-/sailfish-pipa/pkgs/libcamera/out}"
rm -rf "$WORK"
mkdir -p "$DEST" "$OUT" "$HOST_OUT" "$WORK/src"

sb2 -t "$TARGET" true
sb2_install gcc gcc-c++ make binutils pkgconfig meson ninja git curl tar \
  xz gzip cmake python3-pip \
  openssl-devel libdrm-devel libyaml-devel libelf-devel \
  libjpeg-turbo-devel libtiff-devel \
  gstreamer1.0-devel gstreamer1.0-plugins-base-devel \
  glib2-devel libudev-devel zlib-devel || true
# Alternate / pkg-config style names on some SFOS images
sb2_install pkgconfig\(libdrm\) pkgconfig\(yaml-0.1\) pkgconfig\(libelf\) \
  pkgconfig\(libjpeg\) pkgconfig\(libtiff-4\) \
  pkgconfig\(gstreamer-1.0\) pkgconfig\(gstreamer-video-1.0\) \
  pkgconfig\(glib-2.0\) pkgconfig\(libudev\) pkgconfig\(openssl\) || true

# meson from pip if the image is too old
sb2_t bash -lc "
  set -e
  python3 -m pip install --user 'meson>=0.63' 'ninja' 'jinja2' 'ply' 'pyyaml' 2>/dev/null || \
    pip3 install --user 'meson>=0.63' 'ninja' 'jinja2' 'ply' 'pyyaml' || true
  export PATH=\"\$HOME/.local/bin:\$PATH\"
  meson --version
  python3 -c 'import jinja2,ply,yaml'
"

export PATH="${HOME}/.local/bin:${PATH}"

echo "==> fetch libcamera ${LIBCAMERA_VER}"
curl -fL --retry 3 -o "$WORK/libcamera.tar.gz" \
  "https://github.com/libcamera-org/libcamera/archive/refs/tags/v${LIBCAMERA_VER}.tar.gz"
tar -C "$WORK/src" -xzf "$WORK/libcamera.tar.gz"
SRC="$WORK/src/libcamera-${LIBCAMERA_VER}"
test -f "$SRC/meson.build"

# Pipa sensor helpers + properties (from pipa-pkgs/common/libcamera)
cp -a /sailfish-pipa/pkgs/libcamera/patches/. "$WORK/"
(
  cd "$SRC"
  patch -p1 -F3 < "$WORK/0001-ipa-libipa-Add-sensor-helper-for-OV13B10.patch"
  patch -p1 -F3 < "$WORK/0002-libcamera-add-pipa-sensor-properties.patch"
)

echo "==> meson configure + build"
sb2_t bash -lc "
  set -e
  export PATH=\"\$HOME/.local/bin:\$PATH\"
  cd $SRC
  rm -rf build
  meson setup build --prefix=/usr --libdir=lib64 \
    -Dcpp_args='-Wno-array-bounds' \
    -Ddocumentation=disabled \
    -Dpipelines=simple,uvcvideo,vimc \
    -Dipas=simple,vimc \
    -Dv4l2=enabled \
    -Dgstreamer=enabled \
    -Dcam=enabled \
    -Dlc-compliance=disabled \
    -Dqcam=disabled \
    -Dpycamera=disabled \
    -Dtest=false
  meson compile -C build -j$JOBS
  DESTDIR=$DEST meson install -C build
"

# IPA tuning for pipa sensors
install -Dm644 /sailfish-pipa/pkgs/libcamera/files/ov13b10.yaml \
  "$DEST/usr/share/libcamera/ipa/simple/ov13b10.yaml"
install -Dm644 /sailfish-pipa/pkgs/libcamera/files/hi846.yaml \
  "$DEST/usr/share/libcamera/ipa/simple/hi846.yaml"

# Sanity
test -e "$DEST/usr/lib64/libcamera.so" || test -e "$DEST/usr/lib64/libcamera.so.0"
test -x "$DEST/usr/bin/cam"
test -f "$DEST/usr/lib64/gstreamer-1.0/libgstlibcamera.so" || \
  test -f "$DEST/usr/lib/gstreamer-1.0/libgstlibcamera.so"

# Normalize gstreamer plugin path to lib64 (SFOS)
if [ -f "$DEST/usr/lib/gstreamer-1.0/libgstlibcamera.so" ] && \
   [ ! -f "$DEST/usr/lib64/gstreamer-1.0/libgstlibcamera.so" ]; then
  mkdir -p "$DEST/usr/lib64/gstreamer-1.0"
  mv "$DEST/usr/lib/gstreamer-1.0/libgstlibcamera.so" \
     "$DEST/usr/lib64/gstreamer-1.0/"
fi

rm -rf "$OUT/wrap"
mkdir -p "$OUT/wrap/destdir"
cp -a "$DEST"/. "$OUT/wrap/destdir/"
mkdir -p "$HOME/rpmbuild"/{SOURCES,SPECS,RPMS,BUILD,SRPMS}
tar -C "$OUT/wrap" -czf "$HOME/rpmbuild/SOURCES/libcamera.tar.gz" destdir
cp /sailfish-pipa/pkgs/libcamera/rpm/libcamera.spec "$HOME/rpmbuild/SPECS/"
rpmbuild -bb --target=aarch64 --define "_topdir $HOME/rpmbuild" \
  --define "__strip /bin/true" --define "debug_package %{nil}" \
  "$HOME/rpmbuild/SPECS/libcamera.spec"

find "$HOME/rpmbuild/RPMS" -name 'libcamera*.rpm' -o -name 'gstreamer1.0-plugin-libcamera*.rpm' \
  | while read -r r; do cp -v "$r" "$HOST_OUT/"; done
ls -la "$HOST_OUT"
echo "OK: libcamera RPMs"
