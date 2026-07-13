#!/usr/bin/env bash
# Build Mesa (freedreno/msm) for Sailfish OS aarch64 inside the Platform SDK.
# Uses sb2 target toolchain + sysroot (same glibc as the device) — not Ubuntu cross.
#
# On the GitHub runner this script docker-wraps itself in
#   coderus/sailfishos-platform-sdk:$SFOS_SDK_RELEASE
# Output: $MESA_OUT/mesa-freedreno-sfos-aarch64.tar.gz
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
MESA_VER="${MESA_VER:-24.1.7}"
JOBS="${JOBS:-$(nproc)}"
SFOS_SDK_RELEASE="${SFOS_SDK_RELEASE:-5.0.0.43}"
SDK_IMAGE="${SDK_IMAGE:-coderus/sailfishos-platform-sdk:${SFOS_SDK_RELEASE}}"
TARGET="${SFOS_TARGET:-SailfishOS-${SFOS_SDK_RELEASE}-aarch64}"
UA="${UA:-Mozilla/5.0 (compatible; sailfish-pipa-ci)}"
# Host-visible out dir (bind mount); defaults for local/host wrap.
HOST_OUT="${MESA_OUT:-$ROOT/out}"

# ---------- host: re-exec inside Platform SDK ----------
if [ "${MESA_IN_SDK:-0}" != 1 ]; then
  need() { command -v "$1" >/dev/null 2>&1 || { echo "missing $1" >&2; exit 1; }; }
  need docker
  echo "Pulling $SDK_IMAGE ..."
  docker pull "$SDK_IMAGE"
  mkdir -p "$HOST_OUT"
  chmod -R a+rwX "$HOST_OUT"
  exec docker run --rm --privileged \
    -e MESA_IN_SDK=1 \
    -e MESA_VER="$MESA_VER" \
    -e JOBS="$JOBS" \
    -e SFOS_SDK_RELEASE="$SFOS_SDK_RELEASE" \
    -e SFOS_TARGET="$TARGET" \
    -e MESA_HOST_OUT=/sailfish-pipa/mesa-pipa/out \
    -v "$REPO:/sailfish-pipa" \
    -w /sailfish-pipa \
    "$SDK_IMAGE" \
    bash /sailfish-pipa/mesa-pipa/build-mesa-freedreno.sh
fi

# ---------- inside Platform SDK ----------
# sb2 cannot see the /sailfish-pipa bind mount; build under $HOME (mapped into the target).
echo "Building Mesa inside SDK target $TARGET (workdir under \$HOME)"
WORK="${HOME}/mesa-pipa-work"
OUT="${WORK}/out"
DESTDIR="${OUT}/destdir"
HOST_OUT="${MESA_HOST_OUT:-/sailfish-pipa/mesa-pipa/out}"

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

echo "Available sb2 targets:"
sb2-config -l || true
sb2 -t "$TARGET" true
echo "HOME=$HOME WORK=$WORK"

echo "Installing build deps into target ..."
sb2_install \
  gcc gcc-c++ binutils make \
  pkgconfig flex bison \
  libdrm-devel zlib-devel expat-devel libffi-devel \
  wayland-devel wayland-protocols-devel \
  python3-base python3-libs python3-setuptools \
  || true
sb2_install meson ninja python3-mako 2>/dev/null || true
# wayland bits are required for EGL_WL_bind_wayland_display (lipstick apps)
sb2_install wayland-devel wayland-protocols-devel 2>/dev/null || true
# SFOS wayland-devel often omits wayland-egl-backend.pc (needed by Mesa ≥22)
sb2_t bash -lc '
set -euo pipefail
export PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
mkdir -p "$HOME/.local/lib/pkgconfig"
if ! pkg-config --exists wayland-egl-backend; then
  cat > "$HOME/.local/lib/pkgconfig/wayland-egl-backend.pc" <<EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=\${prefix}/lib64
includedir=\${prefix}/include

Name: wayland-egl-backend
Description: Backend wayland-egl interface (stub for SFOS)
Version: 3
Cflags: -I\${includedir}
EOF
  echo "Created stub wayland-egl-backend.pc"
fi
pkg-config --modversion wayland-egl-backend
pkg-config --cflags wayland-egl-backend
ls /usr/include/wayland-egl*.h 2>/dev/null || true
'
if ! sb2_t which meson >/dev/null 2>&1; then
  sb2_install python3-pip 2>/dev/null || true
  sb2_t pip3 install --user meson ninja mako || \
    sb2_t python3 -m pip install --user meson ninja mako
fi

rm -rf "$WORK"
mkdir -p "$WORK" "$OUT" "$DESTDIR" "$HOST_OUT"
MESA_SRC="$WORK/mesa-$MESA_VER"
curl -fL --retry 3 -A "$UA" -o "$WORK/mesa-$MESA_VER.tar.xz" \
  "https://archive.mesa3d.org/mesa-${MESA_VER}.tar.xz"
tar -C "$WORK" -xf "$WORK/mesa-$MESA_VER.tar.xz"
test -d "$MESA_SRC"

python3 - "$MESA_SRC/src/freedreno/common/freedreno_common.h" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
text2 = text.replace(
    "using underlying = typename std::underlying_type_t<E>;",
    "using underlying = typename std::underlying_type<E>::type;",
)
if "#include <type_traits>" not in text2 and "#ifdef __cplusplus" in text2:
    text2 = text2.replace(
        "#ifdef __cplusplus",
        "#ifdef __cplusplus\n\n#include <type_traits>",
        1,
    )
if text2 != text:
    p.write_text(text2)
    print(f"patched {p}")
PY

BUILD="$WORK/build"
# meson compile breaks under sb2 (pathlib samefile('.') → FileNotFoundError).
# Configure with meson, then drive ninja directly from the build dir.
sb2_t bash -lc "
set -euo pipefail
export PATH=\"\$HOME/.local/bin:/usr/bin:\$PATH\"
export PKG_CONFIG_PATH=\"\$HOME/.local/lib/pkgconfig:\${PKG_CONFIG_PATH:-}\"
test -d \"$MESA_SRC\"
rm -rf \"$BUILD\"
meson setup \"$BUILD\" \"$MESA_SRC\" \
  --prefix=/usr \
  --libdir=lib64 \
  --wrap-mode=nofallback \
  -Dbuildtype=release \
  -Dplatforms=wayland \
  -Degl=enabled \
  -Dgbm=enabled \
  -Dglx=disabled \
  -Dgles1=enabled \
  -Dgles2=enabled \
  -Dshared-glapi=enabled \
  -Dllvm=disabled \
  -Dgallium-drivers=freedreno,swrast \
  -Dgallium-xa=disabled \
  -Dvulkan-drivers=[] \
  -Dfreedreno-kmds=msm \
  -Dglvnd=disabled \
  -Dvideo-codecs=[] \
  -Dvalgrind=disabled \
  -Dlibunwind=disabled \
  -Dlmsensors=disabled \
  -Dbuild-tests=false \
  -Dtools=[] \
  -Dxmlconfig=disabled
cd \"$BUILD\"
ninja -j\"$JOBS\"
rm -rf \"$DESTDIR\"
mkdir -p \"$DESTDIR\"
DESTDIR=\"$DESTDIR\" meson install --no-rebuild
"

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
  [ -n "$vers" ] || continue
  ver_num="${vers#GLIBC_}"
  highest=$(printf '%s\n%s\n' "$ver_num" "2.30" | sort -V | tail -1)
  if [ "$highest" != "2.30" ]; then
    echo "ERROR: $f needs $vers (> 2.30)" >&2
    max_ok=0
  fi
done < <(find "$DESTDIR/usr/lib64" -type f \( -name '*.so' -o -name '*.so.*' \) ! -type l -print0)

[ "$max_ok" = 1 ] || exit 1
test -e "$DESTDIR/usr/lib64/dri/msm_dri.so"
test -e "$DESTDIR/usr/lib64/libEGL.so.1" -o -e "$DESTDIR/usr/lib64/libEGL.so.1.0.0"

# Lipstick apps need this (EGL_WL_bind_wayland_display)
EGL_SO=$(find "$DESTDIR/usr/lib64" -name 'libEGL.so*' -type f | head -1)
if ! nm -D "$EGL_SO" 2>/dev/null | grep -q 'eglBindWaylandDisplayWL'; then
  echo "ERROR: libEGL missing eglBindWaylandDisplayWL — Wayland platform not linked?" >&2
  exit 1
fi
echo "OK: eglBindWaylandDisplayWL present in $(basename "$EGL_SO")"

TAR="$OUT/mesa-freedreno-sfos-aarch64.tar.gz"
tar -C "$DESTDIR" -czf "$TAR" usr
mkdir -p "$HOST_OUT"
cp -f "$TAR" "$HOST_OUT/"
chmod a+rw "$HOST_OUT/mesa-freedreno-sfos-aarch64.tar.gz" || true
ls -lh "$HOST_OUT/mesa-freedreno-sfos-aarch64.tar.gz"
echo "OK: $HOST_OUT/mesa-freedreno-sfos-aarch64.tar.gz (built via $TARGET under \$HOME)"
