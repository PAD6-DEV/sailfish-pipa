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
MESON_VER="${MESON_VER:-1.7.2}"
JINJA_VER="${JINJA_VER:-3.1.6}"
MARKUPSAFE_VER="${MARKUPSAFE_VER:-2.1.5}"
PLY_VER="${PLY_VER:-3.11}"
PYYAML_VER="${PYYAML_VER:-6.0.2}"

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
    -e MESON_VER="$MESON_VER" \
    -e JINJA_VER="$JINJA_VER" \
    -e MARKUPSAFE_VER="$MARKUPSAFE_VER" \
    -e PLY_VER="$PLY_VER" \
    -e PYYAML_VER="$PYYAML_VER" \
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

# Required build deps — must succeed. Keep optional packages out of this
# transaction so a missing libevent-devel cannot roll back everything.
sb2_install gcc gcc-c++ make binutils pkgconfig ninja git curl tar \
  xz gzip cmake python3 openssl \
  openssl-devel libdrm-devel libyaml-devel libelf-devel \
  libjpeg-turbo-devel libtiff-devel \
  gstreamer1.0-devel gstreamer1.0-plugins-base-devel \
  glib2-devel libudev-devel zlib-devel

# Capability-style names (SFOS prefers these for .pc providers)
sb2_install \
  pkgconfig\(libdrm\) \
  pkgconfig\(yaml-0.1\) \
  pkgconfig\(libelf\) \
  pkgconfig\(libjpeg\) \
  pkgconfig\(libtiff-4\) \
  pkgconfig\(gstreamer-1.0\) \
  pkgconfig\(gstreamer-base-1.0\) \
  pkgconfig\(gstreamer-video-1.0\) \
  pkgconfig\(gstreamer-allocators-1.0\) \
  pkgconfig\(glib-2.0\) \
  pkgconfig\(libudev\) \
  pkgconfig\(libcrypto\) \
  pkgconfig\(openssl\)

# Optional: cam CLI only
sb2_install libevent-devel pkgconfig\(libevent_pthreads\) || true

require_pc() {
  local pc="$1"
  if ! sb2_t pkg-config --exists "$pc"; then
    echo "ERROR: missing pkg-config module: $pc" >&2
    sb2_t bash -lc "pkg-config --list-all 2>/dev/null | grep -iE 'gst|ssl|crypto|yaml|event' || true" >&2 || true
    return 1
  fi
  echo "OK pkg-config: $pc ($(sb2_t pkg-config --modversion "$pc"))"
}

require_pc libcrypto || require_pc openssl
require_pc gstreamer-1.0
require_pc gstreamer-video-1.0
require_pc glib-2.0
require_pc libudev
require_pc yaml-0.1 || true

# cam needs libevent_pthreads; SFOS often lacks it — keep libcamerify either way.
CAM_OPT=disabled
if sb2_t pkg-config --exists libevent_pthreads; then
  CAM_OPT=enabled
fi
echo "==> cam option: $CAM_OPT"

# The SFOS target has no pip and its Meson package is unavailable/too old.
# Stage architecture-independent Python build tools directly under $HOME,
# which is visible inside sb2.
PYTHON_STAGE="$WORK/python"
mkdir -p "$PYTHON_STAGE"
fetch_python_archive() {
  local url="$1" archive="$2"
  curl -fL --retry 3 -o "$WORK/$archive" "$url"
  tar -C "$WORK/src" -xzf "$WORK/$archive"
}

fetch_python_archive \
  "https://github.com/mesonbuild/meson/releases/download/${MESON_VER}/meson-${MESON_VER}.tar.gz" \
  "meson.tar.gz"
fetch_python_archive \
  "https://github.com/pallets/jinja/archive/refs/tags/${JINJA_VER}.tar.gz" \
  "jinja.tar.gz"
fetch_python_archive \
  "https://github.com/pallets/markupsafe/archive/refs/tags/${MARKUPSAFE_VER}.tar.gz" \
  "markupsafe.tar.gz"
fetch_python_archive \
  "https://github.com/dabeaz/ply/archive/refs/tags/${PLY_VER}.tar.gz" \
  "ply.tar.gz"
fetch_python_archive \
  "https://github.com/yaml/pyyaml/archive/refs/tags/${PYYAML_VER}.tar.gz" \
  "pyyaml.tar.gz"

cp -a "$WORK/src/jinja-${JINJA_VER}/src/jinja2" "$PYTHON_STAGE/"
cp -a "$WORK/src/markupsafe-${MARKUPSAFE_VER}/src/markupsafe" "$PYTHON_STAGE/"
# ply-3.x ships the package at the archive root (not src/ply).
cp -a "$WORK/src/ply-${PLY_VER}/ply" "$PYTHON_STAGE/"
cp -a "$WORK/src/pyyaml-${PYYAML_VER}/lib/yaml" "$PYTHON_STAGE/"
MESON="$WORK/src/meson-${MESON_VER}/meson.py"
test -f "$MESON"
test -d "$PYTHON_STAGE/jinja2"
test -d "$PYTHON_STAGE/markupsafe"
test -d "$PYTHON_STAGE/ply"
test -d "$PYTHON_STAGE/yaml"

sb2_t env PYTHONPATH="$PYTHON_STAGE" python3 "$MESON" --version
sb2_t env PYTHONPATH="$PYTHON_STAGE" python3 -c 'import jinja2, ply, yaml'

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

echo "==> meson configure + build (cam=$CAM_OPT)"
sb2_t bash -lc "
  set -e
  export PYTHONPATH=$PYTHON_STAGE
  cd $SRC
  rm -rf build
  python3 $MESON setup build --prefix=/usr --libdir=lib64 \
    -Dcpp_args='-Wno-array-bounds' \
    -Ddocumentation=disabled \
    -Dpipelines=simple,uvcvideo,vimc \
    -Dipas=simple,vimc \
    -Dv4l2=enabled \
    -Dgstreamer=enabled \
    -Dcam=$CAM_OPT \
    -Dlc-compliance=disabled \
    -Dqcam=disabled \
    -Dpycamera=disabled \
    -Dtest=false
  python3 $MESON compile -C build -j$JOBS
  DESTDIR=$DEST python3 $MESON install -C build
"

# IPA tuning for pipa sensors
install -Dm644 /sailfish-pipa/pkgs/libcamera/files/ov13b10.yaml \
  "$DEST/usr/share/libcamera/ipa/simple/ov13b10.yaml"
install -Dm644 /sailfish-pipa/pkgs/libcamera/files/hi846.yaml \
  "$DEST/usr/share/libcamera/ipa/simple/hi846.yaml"

# Sanity
test -e "$DEST/usr/lib64/libcamera.so" || test -e "$DEST/usr/lib64/libcamera.so.0"
test -x "$DEST/usr/bin/libcamerify"
# Keep RPM %files stable: ship a stub when libevent was unavailable.
if [ ! -x "$DEST/usr/bin/cam" ]; then
  cat > "$DEST/usr/bin/cam" <<'EOF'
#!/bin/sh
echo "cam was not built (libevent_pthreads missing on this target)" >&2
exit 1
EOF
  chmod 755 "$DEST/usr/bin/cam"
fi
if [ ! -e "$DEST/usr/bin/libcamera-bug-report" ]; then
  cat > "$DEST/usr/bin/libcamera-bug-report" <<'EOF'
#!/bin/sh
echo "libcamera-bug-report was not installed by this build" >&2
exit 1
EOF
  chmod 755 "$DEST/usr/bin/libcamera-bug-report"
fi
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
