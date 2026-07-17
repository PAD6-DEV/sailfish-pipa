#!/usr/bin/env bash
# Build libssc RPM (+ qmi-glib / qrtr-glib / protobuf-c) inside SFOS Platform SDK.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
SFOS_SDK_RELEASE="${SFOS_SDK_RELEASE:-5.0.0.43}"
SDK_IMAGE="${SDK_IMAGE:-coderus/sailfishos-platform-sdk:${SFOS_SDK_RELEASE}}"
TARGET="${SFOS_TARGET:-SailfishOS-${SFOS_SDK_RELEASE}-aarch64}"
HOST_OUT="${SSC_OUT:-$ROOT/out}"
JOBS="${JOBS:-$(nproc)}"

LIBSSC_VER="${LIBSSC_VER:-0.4.4}"
LIBQMI_VER="${LIBQMI_VER:-1.36.0}"
LIBQRTR_GLIB_VER="${LIBQRTR_GLIB_VER:-1.2.2}"
PROTOBUF_C_VER="${PROTOBUF_C_VER:-1.5.0}"

if [ "${SSC_IN_SDK:-0}" != 1 ]; then
  command -v docker >/dev/null || { echo "need docker" >&2; exit 1; }
  docker pull "$SDK_IMAGE"
  mkdir -p "$HOST_OUT"
  chmod -R a+rwX "$HOST_OUT"
  exec docker run --rm --privileged \
    -e SSC_IN_SDK=1 \
    -e JOBS="$JOBS" \
    -e SFOS_SDK_RELEASE="$SFOS_SDK_RELEASE" \
    -e SFOS_TARGET="$TARGET" \
    -e SSC_HOST_OUT=/sailfish-pipa/pkgs/libssc/out \
    -e LIBSSC_VER="$LIBSSC_VER" \
    -e LIBQMI_VER="$LIBQMI_VER" \
    -e LIBQRTR_GLIB_VER="$LIBQRTR_GLIB_VER" \
    -e PROTOBUF_C_VER="$PROTOBUF_C_VER" \
    -v "$REPO:/sailfish-pipa" \
    -w /sailfish-pipa \
    "$SDK_IMAGE" \
    bash /sailfish-pipa/pkgs/libssc/build-in-sdk.sh
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

WORK="${HOME}/libssc-work"
OUT="${WORK}/out"
DEST="${OUT}/destdir"
HOST_OUT="${SSC_HOST_OUT:-/sailfish-pipa/pkgs/libssc/out}"
rm -rf "$WORK"
mkdir -p "$DEST" "$OUT" "$HOST_OUT" "$WORK/src"

sb2 -t "$TARGET" true
sb2_install gcc gcc-c++ make binutils pkgconfig meson ninja git curl tar \
  xz gzip glib2-devel libffi-devel zlib-devel python3-pip || true

# libssc needs meson >= 1.4; SFOS image may be older — ensure via pip.
sb2_t bash -lc "
  set -e
  python3 -m pip install --user 'meson>=1.4' 'ninja' 2>/dev/null || \
    pip3 install --user 'meson>=1.4' 'ninja' || true
  export PATH=\"\$HOME/.local/bin:\$PATH\"
  meson --version
"

export PATH="${HOME}/.local/bin:${PATH}"

fetch_tgz() {
  local url="$1" out="$2"
  curl -fL --retry 3 -o "$out" "$url"
}

echo "==> fetch sources"
fetch_tgz \
  "https://github.com/protobuf-c/protobuf-c/releases/download/v${PROTOBUF_C_VER}/protobuf-c-${PROTOBUF_C_VER}.tar.gz" \
  "$WORK/protobuf-c.tar.gz"
fetch_tgz \
  "https://gitlab.freedesktop.org/mobile-broadband/libqrtr-glib/-/archive/${LIBQRTR_GLIB_VER}/libqrtr-glib-${LIBQRTR_GLIB_VER}.tar.gz" \
  "$WORK/libqrtr-glib.tar.gz"
fetch_tgz \
  "https://github.com/linux-mobile-broadband/libqmi/archive/refs/tags/${LIBQMI_VER}.tar.gz" \
  "$WORK/libqmi.tar.gz"
fetch_tgz \
  "https://codeberg.org/DylanVanAssche/libssc/archive/v${LIBSSC_VER}.tar.gz" \
  "$WORK/libssc.tar.gz"

tar -C "$WORK/src" -xzf "$WORK/protobuf-c.tar.gz"
tar -C "$WORK/src" -xzf "$WORK/libqrtr-glib.tar.gz"
tar -C "$WORK/src" -xzf "$WORK/libqmi.tar.gz"
tar -C "$WORK/src" -xzf "$WORK/libssc.tar.gz"

PBC_SRC="$WORK/src/protobuf-c-${PROTOBUF_C_VER}"
QRTR_SRC="$WORK/src/libqrtr-glib-${LIBQRTR_GLIB_VER}"
QMI_SRC="$WORK/src/libqmi-${LIBQMI_VER}"
# codeberg archive unpacks as libssc/ or libssc-vX.Y.Z/
SSC_SRC="$(find "$WORK/src" -maxdepth 1 -type d \( -name 'libssc' -o -name "libssc-*" \) ! -name 'libssc-work' | head -1)"
test -n "$SSC_SRC" && test -f "$SSC_SRC/meson.build"

# SFOS sysroot lacks linux/qrtr.h — stage vendored UAPI (same as pipa-qcom-userspace).
mkdir -p "$HOME/uapi-linux/linux"
cp -a /sailfish-pipa/pkgs/libssc/files/linux/qrtr.h "$HOME/uapi-linux/linux/qrtr.h"
cp -a /sailfish-pipa/pkgs/libssc/files/sfos-compat.h "$HOME/uapi-linux/sfos-compat.h"
UAPI_CFLAGS="-I$HOME/uapi-linux -include $HOME/uapi-linux/sfos-compat.h"

pc_env() {
  echo "export PKG_CONFIG_PATH=$DEST/usr/lib64/pkgconfig:$DEST/usr/lib/pkgconfig:\${PKG_CONFIG_PATH:-}"
  echo "export CFLAGS='$UAPI_CFLAGS -I$DEST/usr/include ${CFLAGS:-}'"
  echo "export CPPFLAGS=\"\$CFLAGS\""
  echo "export LDFLAGS='-L$DEST/usr/lib64 -L$DEST/usr/lib ${LDFLAGS:-}'"
  echo "export LD_LIBRARY_PATH=$DEST/usr/lib64:$DEST/usr/lib:\${LD_LIBRARY_PATH:-}"
  echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
}

fix_pc_prefix() {
  # After DESTDIR install, point pkg-config variables at the staging tree.
  local pcdir
  for pcdir in "$DEST/usr/lib64/pkgconfig" "$DEST/usr/lib/pkgconfig"; do
    [ -d "$pcdir" ] || continue
    find "$pcdir" -name '*.pc' -exec sed -i \
      -e "s|^prefix=/usr|prefix=$DEST/usr|" \
      -e "s|^prefix=\${pcfiledir}/../..|prefix=$DEST/usr|" \
      {} +
  done
}

echo "==> protobuf-c ${PROTOBUF_C_VER} (runtime only)"
sb2_t bash -lc "
  set -e
  $(pc_env)
  cd $PBC_SRC
  ./configure --prefix=/usr --libdir=/usr/lib64 --disable-protoc --disable-static
  make -j$JOBS
  make DESTDIR=$DEST install
"
fix_pc_prefix

echo "==> libqrtr-glib ${LIBQRTR_GLIB_VER}"
# SFOS headers lack linux/qrtr.h; skip the configure-time assert and compile with vendored UAPI.
sed -i "/assert(cc.has_header('linux\\/qrtr.h')/d" "$QRTR_SRC/meson.build"
sb2_t bash -lc "
  set -e
  $(pc_env)
  cd $QRTR_SRC
  rm -rf build
  meson setup build --prefix=/usr --libdir=lib64 \
    -Dintrospection=false -Dgtk_doc=false \
    -Dc_args=\"\$CFLAGS\"
  meson compile -C build -j$JOBS
  DESTDIR=$DEST meson install -C build
"
fix_pc_prefix

echo "==> libqmi ${LIBQMI_VER}"
sb2_t bash -lc "
  set -e
  $(pc_env)
  cd $QMI_SRC
  meson setup build --prefix=/usr --libdir=lib64 \
    -Dqrtr=true \
    -Dmbim_qmux=false \
    -Drmnet=false \
    -Dfirmware_update=false \
    -Dintrospection=false \
    -Dman=false \
    -Dbash_completion=false \
    -Dudev=false \
    -Dmm_runtime_check=false \
    -Dcollection=full \
    -Dgtk_doc=false \
    -Dc_args=\"\$CFLAGS\"
  meson compile -C build -j$JOBS
  DESTDIR=$DEST meson install -C build
"
fix_pc_prefix

echo "==> libssc ${LIBSSC_VER}"
# Pregenerated protobuf-c + skip mocking/tests (need python/qrtr mock server).
cp -a /sailfish-pipa/pkgs/libssc/generated/*.pb-c.c \
      /sailfish-pipa/pkgs/libssc/generated/*.pb-c.h \
      "$SSC_SRC/data/"
cp -a /sailfish-pipa/pkgs/libssc/files/data.meson.build "$SSC_SRC/data/meson.build"
# Drop protoc lookups and test/mocking subdirs; relax meson if needed.
sed -i \
  -e "/protocc_tool/d" \
  -e "/protoc_tool/d" \
  -e "/subdir('mocking')/d" \
  -e "/subdir('tests')/d" \
  -e "s/meson_version: '>= 1.4.0'/meson_version: '>= 0.60.0'/" \
  "$SSC_SRC/meson.build"

sb2_t bash -lc "
  set -e
  $(pc_env)
  cd $SSC_SRC
  meson setup build --prefix=/usr --libdir=lib64 -Dc_args=\"\$CFLAGS\"
  meson compile -C build -j$JOBS
  DESTDIR=$DEST meson install -C build
"

# Simplified pkg-config for SFOS (bundled qmi/qrtr; avoid missing .pc Requires)
install -Dm644 /sailfish-pipa/pkgs/libssc/files/libssc.pc \
  "$DEST/usr/share/libssc/libssc.pc"
install -Dm644 /sailfish-pipa/pkgs/libssc/files/libssc.pc \
  "$DEST/usr/lib64/pkgconfig/libssc.pc"

# Package RPM
rm -rf "$OUT/wrap"
mkdir -p "$OUT/wrap/destdir"
cp -a "$DEST"/. "$OUT/wrap/destdir/"
mkdir -p "$HOME/rpmbuild"/{SOURCES,SPECS,RPMS,BUILD,SRPMS}
tar -C "$OUT/wrap" -czf "$HOME/rpmbuild/SOURCES/libssc.tar.gz" destdir
cp /sailfish-pipa/pkgs/libssc/rpm/libssc.spec "$HOME/rpmbuild/SPECS/"
rpmbuild -bb --target=aarch64 --define "_topdir $HOME/rpmbuild" \
  --define "__strip /bin/true" --define "debug_package %{nil}" \
  "$HOME/rpmbuild/SPECS/libssc.spec"

find "$HOME/rpmbuild/RPMS" -name 'libssc*.rpm' -exec cp -v {} "$HOST_OUT/" \;
ls -la "$HOST_OUT"
echo "OK: libssc RPM"
