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

# kernel
echo "CI placeholder kernel" > "$HOME/rpmbuild/SOURCES/Image"
cp "$BOOT/rpm/kernel-adaptation-pipa.spec" "$HOME/rpmbuild/SPECS/"
rpmbuild -bb --define "_topdir $HOME/rpmbuild" "$HOME/rpmbuild/SPECS/kernel-adaptation-pipa.spec"

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
