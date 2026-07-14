#!/usr/bin/env bash
# Build pipa-qcom-userspace RPM inside Sailfish Platform SDK (sb2 aarch64).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
SFOS_SDK_RELEASE="${SFOS_SDK_RELEASE:-5.0.0.43}"
SDK_IMAGE="${SDK_IMAGE:-coderus/sailfishos-platform-sdk:${SFOS_SDK_RELEASE}}"
TARGET="${SFOS_TARGET:-SailfishOS-${SFOS_SDK_RELEASE}-aarch64}"
HOST_OUT="${QCOM_OUT:-$ROOT/out}"
JOBS="${JOBS:-$(nproc)}"
QRTR_REF="${QRTR_REF:-v1.1}"
PD_MAPPER_REF="${PD_MAPPER_REF:-master}"
TQFTP_REF="${TQFTP_REF:-master}"
RMTFS_REF="${RMTFS_REF:-master}"

if [ "${QCOM_IN_SDK:-0}" != 1 ]; then
  command -v docker >/dev/null || { echo "need docker" >&2; exit 1; }
  docker pull "$SDK_IMAGE"
  mkdir -p "$HOST_OUT"
  chmod -R a+rwX "$HOST_OUT"
  exec docker run --rm --privileged \
    -e QCOM_IN_SDK=1 \
    -e JOBS="$JOBS" \
    -e SFOS_SDK_RELEASE="$SFOS_SDK_RELEASE" \
    -e SFOS_TARGET="$TARGET" \
    -e QCOM_HOST_OUT=/sailfish-pipa/pkgs/pipa-qcom-userspace/out \
    -e QRTR_REF="$QRTR_REF" \
    -e PD_MAPPER_REF="$PD_MAPPER_REF" \
    -e TQFTP_REF="$TQFTP_REF" \
    -e RMTFS_REF="$RMTFS_REF" \
    -v "$REPO:/sailfish-pipa" \
    -w /sailfish-pipa \
    "$SDK_IMAGE" \
    bash /sailfish-pipa/pkgs/pipa-qcom-userspace/build-in-sdk.sh
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

WORK="${HOME}/pipa-qcom-work"
OUT="${WORK}/out"
DEST="${OUT}/destdir"
HOST_OUT="${QCOM_HOST_OUT:-/sailfish-pipa/pkgs/pipa-qcom-userspace/out}"
rm -rf "$WORK"
mkdir -p "$DEST" "$OUT" "$HOST_OUT"

sb2 -t "$TARGET" true
sb2_install gcc make binutils pkgconfig meson ninja git xz-devel systemd-devel \
  kernel-headers || true

# SFOS sysroot often lacks linux/qrtr.h — stage vendored UAPI into sb2-visible HOME.
mkdir -p "$HOME/uapi-linux/linux"
cp -a /sailfish-pipa/pkgs/pipa-qcom-userspace/files/linux/qrtr.h \
  "$HOME/uapi-linux/linux/qrtr.h"
cp -a /sailfish-pipa/pkgs/pipa-qcom-userspace/files/sfos-compat.h \
  "$HOME/uapi-linux/sfos-compat.h"

fetch() {
  local name="$1" url="$2" ref="$3"
  local dir="$WORK/$name"
  if [ ! -d "$dir/.git" ]; then
    git clone --depth 1 --branch "$ref" "$url" "$dir" 2>/dev/null \
      || { git clone "$url" "$dir"; git -C "$dir" checkout "$ref"; }
  fi
}

fetch qrtr https://github.com/linux-msm/qrtr.git "$QRTR_REF" || fetch qrtr https://github.com/linux-msm/qrtr.git master
fetch pd-mapper https://github.com/linux-msm/pd-mapper.git "$PD_MAPPER_REF"
fetch tqftpserv https://github.com/linux-msm/tqftpserv.git "$TQFTP_REF"
fetch rmtfs https://github.com/linux-msm/rmtfs.git "$RMTFS_REF"

# qrtr (meson) — inject UAPI include if sysroot lacks linux/qrtr.h
sb2_t bash -lc "
  set -e
  cd $WORK/qrtr
  export CFLAGS='-I$HOME/uapi-linux -include $HOME/uapi-linux/sfos-compat.h'
  export CPPFLAGS=\"\$CFLAGS\"
  meson setup build --prefix=/usr --libdir=lib64 -Dc_args=\"\$CFLAGS\"
  meson compile -C build -j$JOBS
  DESTDIR=$DEST meson install -C build
"

# pd-mapper (make; needs libqrtr from DEST or target — copy into target HOME)
export LD_LIBRARY_PATH="${DEST}/usr/lib64:${DEST}/usr/lib:${LD_LIBRARY_PATH:-}"
sb2_t bash -lc "
  set -e
  export PKG_CONFIG_PATH=$DEST/usr/lib64/pkgconfig:$DEST/usr/lib/pkgconfig
  export CFLAGS='-I$DEST/usr/include -I$HOME/uapi-linux -include $HOME/uapi-linux/sfos-compat.h'
  export LDFLAGS='-L$DEST/usr/lib64 -L$DEST/usr/lib'
  cd $WORK/pd-mapper
  make prefix=/usr -j$JOBS
  make DESTDIR=$DEST prefix=/usr install
"

# tqftpserv
sb2_t bash -lc "
  set -e
  export PKG_CONFIG_PATH=$DEST/usr/lib64/pkgconfig:$DEST/usr/lib/pkgconfig
  export CFLAGS='-I$DEST/usr/include -I$HOME/uapi-linux -include $HOME/uapi-linux/sfos-compat.h'
  export LDFLAGS='-L$DEST/usr/lib64 -L$DEST/usr/lib'
  cd $WORK/tqftpserv
  export CPPFLAGS=\"\$CFLAGS\"
  meson setup build --prefix=/usr --libdir=lib64 -Dc_args=\"\$CFLAGS\"
  meson compile -C build -j$JOBS
  DESTDIR=$DEST meson install -C build
"

# rmtfs
sb2_t bash -lc "
  set -e
  export PKG_CONFIG_PATH=$DEST/usr/lib64/pkgconfig:$DEST/usr/lib/pkgconfig
  export CFLAGS='-I$DEST/usr/include -I$HOME/uapi-linux -include $HOME/uapi-linux/sfos-compat.h'
  export LDFLAGS='-L$DEST/usr/lib64 -L$DEST/usr/lib'
  cd $WORK/rmtfs
  touch qmi_rmtfs.c qmi_rmtfs.h
  make prefix=/usr -j$JOBS
  make DESTDIR=$DEST prefix=/usr install
"

# Upstream may have already installed units; only write if missing
mkdir -p "$DEST/usr/lib/systemd/system"
for unit in pd-mapper tqftpserv rmtfs; do
  if [ ! -f "$DEST/usr/lib/systemd/system/${unit}.service" ]; then
    case "$unit" in
      pd-mapper)
        cat > "$DEST/usr/lib/systemd/system/pd-mapper.service" <<'U'
[Unit]
Description=Qualcomm PD mapper
After=network.target
[Service]
ExecStart=/usr/bin/pd-mapper
Restart=on-failure
[Install]
WantedBy=multi-user.target
U
        ;;
      tqftpserv)
        cat > "$DEST/usr/lib/systemd/system/tqftpserv.service" <<'U'
[Unit]
Description=Qualcomm TFTP server
After=pd-mapper.service
Wants=pd-mapper.service
[Service]
ExecStart=/usr/bin/tqftpserv
Restart=on-failure
[Install]
WantedBy=multi-user.target
U
        ;;
      rmtfs)
        cat > "$DEST/usr/lib/systemd/system/rmtfs.service" <<'U'
[Unit]
Description=Qualcomm Remote Filesystem Service
After=pd-mapper.service
[Service]
ExecStart=/usr/bin/rmtfs -r -P -s
Restart=on-failure
[Install]
WantedBy=multi-user.target
U
        ;;
    esac
  fi
done

# Package RPM: arch aarch64 binaries
TGZ="$OUT/pipa-qcom-userspace.tar.gz"
tar -C "$DEST" -czf "$TGZ" .
mkdir -p "$HOME/rpmbuild"/{SOURCES,SPECS,RPMS,BUILD,SRPMS}
cp "$TGZ" "$HOME/rpmbuild/SOURCES/"
cp /sailfish-pipa/pkgs/pipa-qcom-userspace/rpm/pipa-qcom-userspace.spec "$HOME/rpmbuild/SPECS/"
# Fix prep: tar extracts as destdir contents — pack so top dir is destdir
rm -rf "$OUT/destdir-wrap"
mkdir -p "$OUT/destdir-wrap/destdir"
cp -a "$DEST"/. "$OUT/destdir-wrap/destdir/"
tar -C "$OUT/destdir-wrap" -czf "$HOME/rpmbuild/SOURCES/pipa-qcom-userspace.tar.gz" destdir

rpmbuild -bb --target=aarch64 --define "_topdir $HOME/rpmbuild" \
  "$HOME/rpmbuild/SPECS/pipa-qcom-userspace.spec"

find "$HOME/rpmbuild/RPMS" -name 'pipa-qcom-userspace*.rpm' -exec cp -v {} "$HOST_OUT/" \;
cp -a "$TGZ" "$HOST_OUT/" || true
ls -la "$HOST_OUT"
echo "OK: pipa-qcom-userspace RPM"
