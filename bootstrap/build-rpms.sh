#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOOT="$ROOT/bootstrap"
DEST="$ROOT/repo/adaptation"
mkdir -p "$DEST" "$HOME/rpmbuild"/{SOURCES,SPECS,RPMS,BUILD,SRPMS}

# sparse tarball
tar -C "$BOOT/droid-config-pipa" -czf "$HOME/rpmbuild/SOURCES/sparse.tar.gz" sparse
cp "$BOOT/rpm/droid-config-pipa.spec" "$HOME/rpmbuild/SPECS/"
rpmbuild -bb --define "_topdir $HOME/rpmbuild" "$HOME/rpmbuild/SPECS/droid-config-pipa.spec"

# pulseaudio-settings — device-common tables + pipa pulse overlay (not in bootstrap sparse)
PULSE_STAGING="$(mktemp -d)"
trap 'rm -rf "$PULSE_STAGING"' EXIT
DEVICE_SPARSE="$ROOT/droid-config-pipa/droid-configs-device/sparse"
PIPA_SPARSE="$ROOT/droid-config-pipa/sparse"
mkdir -p "$PULSE_STAGING/etc/sysconfig" "$PULSE_STAGING/var/lib"
cp -a "$DEVICE_SPARSE/etc/pulse" "$PULSE_STAGING/etc/"
cp -a "$DEVICE_SPARSE/var/lib/nemo-pulseaudio-parameters" "$PULSE_STAGING/var/lib/"
cp -a "$DEVICE_SPARSE/etc/sysconfig/pulseaudio" "$PULSE_STAGING/etc/sysconfig/"
cp -a "$PIPA_SPARSE/etc/pulse/." "$PULSE_STAGING/etc/pulse/"
if [ -f "$PIPA_SPARSE/etc/sysconfig/pulseaudio" ]; then
  cp -a "$PIPA_SPARSE/etc/sysconfig/pulseaudio" "$PULSE_STAGING/etc/sysconfig/"
fi
tar -C "$PULSE_STAGING" -czf "$HOME/rpmbuild/SOURCES/pulse-sparse.tar.gz" etc var
cp "$BOOT/rpm/droid-config-pipa-pulseaudio-settings.spec" "$HOME/rpmbuild/SPECS/"
rpmbuild -bb --define "_topdir $HOME/rpmbuild" "$HOME/rpmbuild/SPECS/droid-config-pipa-pulseaudio-settings.spec"
trap - EXIT
rm -rf "$PULSE_STAGING"

# kernel
echo "CI placeholder kernel" > "$HOME/rpmbuild/SOURCES/Image"
cp "$BOOT/rpm/kernel-adaptation-pipa.spec" "$HOME/rpmbuild/SPECS/"
rpmbuild -bb --define "_topdir $HOME/rpmbuild" "$HOME/rpmbuild/SPECS/kernel-adaptation-pipa.spec"

# droid-hal-version-pipa — ships /etc/hw-release (MER_HA_DEVICE=pipa)
# BuildRequires are for OBS; local/bootstrap builds use --nodeps.
VERSION_DIR="$ROOT/droid-hal-version-pipa"
VERSION_SPEC="$VERSION_DIR/rpm/droid-hal-version-pipa.spec"
# Source tarball is unused by %install but required by rpmbuild.
tar -C "$VERSION_DIR" -czf "$HOME/rpmbuild/SOURCES/droid-hal-version-pipa-0.0.1.tar.gz" \
  --transform 's,^,droid-hal-version-pipa-0.0.1/,' \
  droid-hal-version rpm README.md 2>/dev/null \
  || tar -czf "$HOME/rpmbuild/SOURCES/droid-hal-version-pipa-0.0.1.tar.gz" -T /dev/null
(
  cd "$VERSION_DIR"
  rpmbuild -bb --nodeps \
    --define "_topdir $HOME/rpmbuild" \
    --define "_sourcedir $HOME/rpmbuild/SOURCES" \
    "$VERSION_SPEC"
)

# pattern
cp "$BOOT/rpm/patterns-sailfish-device-configuration-pipa.spec" "$HOME/rpmbuild/SPECS/"
rpmbuild -bb --define "_topdir $HOME/rpmbuild" "$HOME/rpmbuild/SPECS/patterns-sailfish-device-configuration-pipa.spec"

find "$HOME/rpmbuild/RPMS" -name '*.rpm' -exec cp -v {} "$DEST/" \;

# Optional: drop in prebuilt aarch64 / firmware RPMs from pkgs/*/out
for d in \
  "$ROOT/pkgs/pipa-qcom-userspace/out" \
  "$ROOT/pkgs/pipa-hexagonrpc/out" \
  "$ROOT/pkgs/firmware-pipa/out" \
  "$ROOT/pkgs/mesa-pipa/out"
do
  if [ -d "$d" ]; then
    find "$d" -maxdepth 1 -name '*.rpm' -exec cp -v {} "$DEST/" \;
  fi
done

if command -v createrepo_c >/dev/null; then
  createrepo_c "$DEST"
elif command -v createrepo >/dev/null; then
  createrepo "$DEST"
else
  echo "WARN: no createrepo" >&2
fi
ls -la "$DEST"
