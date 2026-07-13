#!/usr/bin/env bash
# Cross-build Mesa with gallium freedreno (msm KMD) for SFOS aarch64 (glibc 2.30).
# Intended to run in GitHub Actions — not as a local bring-up step.
#
# Output: $MESA_OUT/mesa-freedreno-sfos-aarch64.tar.gz  (usr/ tree)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${MESA_OUT:-$ROOT/out}"
WORK="${MESA_WORK:-$ROOT/work}"
SYSROOT="${SYSROOT:-$WORK/sysroot}"
DESTDIR="${DESTDIR:-$OUT/destdir}"
MESA_VER="${MESA_VER:-24.1.7}"
JOBS="${JOBS:-$(nproc)}"
UA="${UA:-Mozilla/5.0 (compatible; sailfish-pipa-ci)}"
JOLLA_OSS="https://releases.jolla.com/releases/5.0.0.77/jolla/aarch64/oss/aarch64"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing $1" >&2; exit 1; }; }
need aarch64-linux-gnu-gcc
need meson
need ninja
need curl
need python3
need tar

mkdir -p "$WORK/rpms" "$SYSROOT" "$DESTDIR" "$OUT"

fetch_rpm() {
  local name="$1"
  local url="$JOLLA_OSS/$name"
  if [ ! -s "$WORK/rpms/$name" ]; then
    echo "GET $name"
    curl -fL --retry 3 -A "$UA" -o "$WORK/rpms/$name" "$url"
  fi
  local unpack
  unpack=$(mktemp -d)
  if command -v rpm2cpio >/dev/null && command -v cpio >/dev/null; then
    rpm2cpio "$WORK/rpms/$name" | (cd "$unpack" && cpio -idm --quiet)
  else
    bsdtar -C "$unpack" -xf "$WORK/rpms/$name"
  fi
  cp -a "$unpack"/. "$SYSROOT"/
  rm -rf "$unpack"
}

# SFOS 5.0.0.77 NEVRs (from pinatab2 .packages + verified devel twins)
REQUIRED_RPMS=(
  "glibc-2.30+git12-1.10.3.jolla.aarch64.rpm"
  "glibc-devel-2.30+git12-1.10.3.jolla.aarch64.rpm"
  "glibc-headers-2.30+git12-1.10.3.jolla.aarch64.rpm"
  "libdrm-2.4.122+git1-1.7.1.jolla.aarch64.rpm"
  "libdrm-devel-2.4.122+git1-1.7.1.jolla.aarch64.rpm"
  "expat-2.6.1+git1-1.7.3.jolla.aarch64.rpm"
  "expat-devel-2.6.1+git1-1.7.3.jolla.aarch64.rpm"
  "zlib-1.3.1+git1-1.9.1.jolla.aarch64.rpm"
  "zlib-devel-1.3.1+git1-1.9.1.jolla.aarch64.rpm"
  "libffi-3.4.4+git1-1.7.2.jolla.aarch64.rpm"
  "libffi-devel-3.4.4+git1-1.7.2.jolla.aarch64.rpm"
  "libgcc-10.3.1-1.8.6.jolla.aarch64.rpm"
  "libstdc++-10.3.1-1.8.6.jolla.aarch64.rpm"
)

echo "Assembling SFOS sysroot in $SYSROOT ..."
rm -rf "$SYSROOT"
mkdir -p "$SYSROOT"
for r in "${REQUIRED_RPMS[@]}"; do
  fetch_rpm "$r"
done

mkdir -p "$SYSROOT/usr/lib/pkgconfig" "$SYSROOT/usr/lib64/pkgconfig"
if [ -d "$SYSROOT/usr/lib64/pkgconfig" ]; then
  cp -an "$SYSROOT/usr/lib64/pkgconfig/." "$SYSROOT/usr/lib/pkgconfig/" 2>/dev/null || true
fi
# Some SFOS headers live under /usr/include; ensure exists
test -d "$SYSROOT/usr/include"
test -f "$SYSROOT/usr/include/xf86drm.h" || test -f "$SYSROOT/usr/include/libdrm/xf86drm.h"

MESA_SRC="$WORK/mesa-$MESA_VER"
if [ ! -d "$MESA_SRC" ]; then
  curl -fL --retry 3 -o "$WORK/mesa-$MESA_VER.tar.xz" \
    "https://archive.mesa3d.org/mesa-${MESA_VER}.tar.xz"
  tar -C "$WORK" -xf "$WORK/mesa-$MESA_VER.tar.xz"
fi

CROSS="$WORK/aarch64-sfos.txt"
cat > "$CROSS" <<EOF
[binaries]
c = 'aarch64-linux-gnu-gcc'
cpp = 'aarch64-linux-gnu-g++'
ar = 'aarch64-linux-gnu-ar'
strip = 'aarch64-linux-gnu-strip'
pkg-config = 'pkg-config'

[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'

[built-in options]
c_args = ['--sysroot=${SYSROOT}', '-I${SYSROOT}/usr/include']
cpp_args = ['--sysroot=${SYSROOT}', '-I${SYSROOT}/usr/include']
c_link_args = ['--sysroot=${SYSROOT}', '-L${SYSROOT}/usr/lib64', '-L${SYSROOT}/lib64', '-Wl,-rpath-link,${SYSROOT}/usr/lib64']
cpp_link_args = ['--sysroot=${SYSROOT}', '-L${SYSROOT}/usr/lib64', '-L${SYSROOT}/lib64', '-Wl,-rpath-link,${SYSROOT}/usr/lib64']
EOF

export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib64/pkgconfig:$SYSROOT/usr/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"
export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1
export PKG_CONFIG_ALLOW_SYSTEM_LIBS=1

BUILD="$WORK/build"
rm -rf "$BUILD"
# Mesa 24+: drm/surfaceless are not -Dplatforms choices; GBM+EGL provide DRM/eglfs.
meson setup "$BUILD" "$MESA_SRC" \
  --cross-file "$CROSS" \
  --prefix=/usr \
  --libdir=lib64 \
  -Dbuildtype=release \
  -Dplatforms=[] \
  -Degl=enabled \
  -Dgbm=enabled \
  -Dglx=disabled \
  -Dgles1=enabled \
  -Dgles2=enabled \
  -Dshared-glapi=enabled \
  -Dllvm=disabled \
  -Dgallium-drivers=freedreno,swrast \
  -Dvulkan-drivers=[] \
  -Dfreedreno-kmds=msm \
  -Dglvnd=disabled \
  -Dvideo-codecs=[] \
  -Dvalgrind=disabled \
  -Dlibunwind=disabled \
  -Dlmsensors=disabled \
  -Dbuild-tests=false

meson compile -C "$BUILD" -j"$JOBS"
rm -rf "$DESTDIR"
DESTDIR="$DESTDIR" meson install -C "$BUILD"

GALLIUM=$(find "$DESTDIR/usr/lib64" -name 'libgallium*.so' | head -1 || true)
mkdir -p "$DESTDIR/usr/lib64/dri"
if [ -n "$GALLIUM" ]; then
  base=$(basename "$GALLIUM")
  ln -sfn "../$base" "$DESTDIR/usr/lib64/dri/msm_dri.so"
  ln -sfn "../$base" "$DESTDIR/usr/lib64/dri/kms_swrast_dri.so"
  ln -sfn "../$base" "$DESTDIR/usr/lib64/dri/swrast_dri.so"
fi

echo "Checking GLIBC deps (must be <= 2.30) ..."
max_ok=1
while IFS= read -r -d '' f; do
  vers=$(objdump -T "$f" 2>/dev/null | grep -oE 'GLIBC_[0-9.]+' | sort -Vu | tail -1 || true)
  echo "  $(basename "$f"): ${vers:-none}"
  case "$vers" in
    GLIBC_2.3[1-9]*|GLIBC_2.[4-9]*|GLIBC_2.[1-9][0-9]*)
      echo "ERROR: $f needs $vers (> 2.30)" >&2
      max_ok=0
      ;;
  esac
done < <(find "$DESTDIR/usr/lib64" -type f -name '*.so*' -print0)

[ "$max_ok" = 1 ] || exit 1
test -e "$DESTDIR/usr/lib64/dri/msm_dri.so"
test -e "$DESTDIR/usr/lib64/libEGL.so.1" -o -e "$DESTDIR/usr/lib64/libEGL.so.1.0.0"

TAR="$OUT/mesa-freedreno-sfos-aarch64.tar.gz"
tar -C "$DESTDIR" -czf "$TAR" usr
ls -lh "$TAR"
echo "OK: $TAR"
