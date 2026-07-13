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
OUT="${MESA_OUT:-$ROOT/out}"
WORK="${MESA_WORK:-$ROOT/work}"
DESTDIR="${DESTDIR:-$OUT/destdir}"
MESA_VER="${MESA_VER:-24.1.7}"
JOBS="${JOBS:-$(nproc)}"
SFOS_SDK_RELEASE="${SFOS_SDK_RELEASE:-5.0.0.43}"
SDK_IMAGE="${SDK_IMAGE:-coderus/sailfishos-platform-sdk:${SFOS_SDK_RELEASE}}"
TARGET="${SFOS_TARGET:-SailfishOS-${SFOS_SDK_RELEASE}-aarch64}"
UA="${UA:-Mozilla/5.0 (compatible; sailfish-pipa-ci)}"

# ---------- host: re-exec inside Platform SDK ----------
if [ "${MESA_IN_SDK:-0}" != 1 ]; then
  need() { command -v "$1" >/dev/null 2>&1 || { echo "missing $1" >&2; exit 1; }; }
  need docker
  echo "Pulling $SDK_IMAGE ..."
  docker pull "$SDK_IMAGE"
  # SDK container user (mersdk) must be able to write into the bind mount.
  mkdir -p "$OUT/destdir" "$WORK"
  chmod -R a+rwX "$OUT" "$WORK"
  exec docker run --rm --privileged \
    -e MESA_IN_SDK=1 \
    -e MESA_VER="$MESA_VER" \
    -e JOBS="$JOBS" \
    -e SFOS_SDK_RELEASE="$SFOS_SDK_RELEASE" \
    -e SFOS_TARGET="$TARGET" \
    -e MESA_OUT=/sailfish-pipa/mesa-pipa/out \
    -e MESA_WORK=/sailfish-pipa/mesa-pipa/work \
    -e DESTDIR=/sailfish-pipa/mesa-pipa/out/destdir \
    -v "$REPO:/sailfish-pipa" \
    -w /sailfish-pipa \
    "$SDK_IMAGE" \
    bash /sailfish-pipa/mesa-pipa/build-mesa-freedreno.sh
fi

# ---------- inside Platform SDK ----------
echo "Building Mesa inside SDK target $TARGET"

sb2_t() {
  # Prefer sdk-build (compilers) or fall back to default mode
  if sb2 -t "$TARGET" -m sdk-build true 2>/dev/null; then
    sb2 -t "$TARGET" -m sdk-build "$@"
  else
    sb2 -t "$TARGET" "$@"
  fi
}

sb2_install() {
  # Install packages into the aarch64 target root
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

echo "Installing build deps into target ..."
sb2_install \
  gcc gcc-c++ binutils make \
  pkgconfig flex bison \
  libdrm-devel zlib-devel expat-devel libffi-devel \
  python3-base python3-libs python3-setuptools \
  || true
# meson/ninja/mako — try packages, else pip
sb2_install meson ninja python3-mako 2>/dev/null || true
if ! sb2_t which meson >/dev/null 2>&1; then
  sb2_install python3-pip 2>/dev/null || true
  sb2_t pip3 install --user meson ninja mako || \
    sb2_t python3 -m pip install --user meson ninja mako
  export PATH="$(sb2_t bash -lc 'echo $HOME/.local/bin'):$PATH"
fi

mkdir -p "$WORK" "$OUT" "$DESTDIR"
MESA_SRC="$WORK/mesa-$MESA_VER"
if [ ! -d "$MESA_SRC" ]; then
  curl -fL --retry 3 -A "$UA" -o "$WORK/mesa-$MESA_VER.tar.xz" \
    "https://archive.mesa3d.org/mesa-${MESA_VER}.tar.xz"
  tar -C "$WORK" -xf "$WORK/mesa-$MESA_VER.tar.xz"
fi

# Portable C++11 form + type_traits (harmless if already present)
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
rm -rf "$BUILD"

# Host meson configures; use sb2 compilers as cross when meson runs in sdk-build.
# Prefer a native configuration *inside* sb2 so headers/libs are the SFOS root.
sb2_t bash -lc "
set -euo pipefail
export PATH=\"\$HOME/.local/bin:/usr/bin:\$PATH\"
cd \"$MESA_SRC\"
rm -rf \"$BUILD\"
meson setup \"$BUILD\" \"$MESA_SRC\" \
  --prefix=/usr \
  --libdir=lib64 \
  --wrap-mode=nofallback \
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
meson compile -C \"$BUILD\" -j\"$JOBS\"
rm -rf \"$DESTDIR\"
DESTDIR=\"$DESTDIR\" meson install -C \"$BUILD\"
"

GALLIUM=$(find "$DESTDIR/usr/lib64" -name 'libgallium*.so' | head -1 || true)
mkdir -p "$DESTDIR/usr/lib64/dri"
if [ -n "$GALLIUM" ]; then
  base=$(basename "$GALLIUM")
  ln -sfn "../$base" "$DESTDIR/usr/lib64/dri/msm_dri.so"
  ln -sfn "../$base" "$DESTDIR/usr/lib64/dri/kms_swrast_dri.so"
  ln -sfn "../$base" "$DESTDIR/usr/lib64/dri/swrast_dri.so"
fi

# Require symbols ≤ GLIBC_2.30 (SFOS 5.0)
echo "Checking GLIBC deps (must be <= 2.30) ..."
max_ok=1
while IFS= read -r -d '' f; do
  vers=$(objdump -T "$f" 2>/dev/null | grep -oE 'GLIBC_[0-9.]+' | sort -Vu | tail -1 || true)
  echo "  $(basename "$f"): ${vers:-none}"
  [ -n "$vers" ] || continue
  ver_num="${vers#GLIBC_}"
  # sort -V: if the highest of (ver_num, 2.30) is not 2.30, then ver > 2.30
  highest=$(printf '%s\n%s\n' "$ver_num" "2.30" | sort -V | tail -1)
  if [ "$highest" != "2.30" ]; then
    echo "ERROR: $f needs $vers (> 2.30)" >&2
    max_ok=0
  fi
done < <(find "$DESTDIR/usr/lib64" -type f \( -name '*.so' -o -name '*.so.*' \) ! -type l -print0)

[ "$max_ok" = 1 ] || exit 1
test -e "$DESTDIR/usr/lib64/dri/msm_dri.so"
test -e "$DESTDIR/usr/lib64/libEGL.so.1" -o -e "$DESTDIR/usr/lib64/libEGL.so.1.0.0"

TAR="$OUT/mesa-freedreno-sfos-aarch64.tar.gz"
tar -C "$DESTDIR" -czf "$TAR" usr
ls -lh "$TAR"
echo "OK: $TAR (built via $TARGET)"
