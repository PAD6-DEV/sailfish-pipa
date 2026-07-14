#!/usr/bin/env bash
# Turn firmware-pipa/out/xiaomi-pipa-firmware.tar.gz into firmware-pipa.rpm
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
TGZ="${1:-$REPO/firmware-pipa/out/xiaomi-pipa-firmware.tar.gz}"
OUT="${FW_RPM_OUT:-$ROOT/out}"
test -s "$TGZ" || { echo "missing $TGZ — run firmware-pipa/build-firmware-tarball.sh first" >&2; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/wrap/destdir" "$OUT" "$HOME/rpmbuild"/{SOURCES,SPECS,RPMS,BUILD,SRPMS}
tar -C "$WORK/wrap/destdir" -xzf "$TGZ"
# Only ship /usr and /lib from the tarball
tar -C "$WORK/wrap" -czf "$HOME/rpmbuild/SOURCES/firmware-pipa-tree.tar.gz" destdir
cp "$ROOT/rpm/firmware-pipa.spec" "$HOME/rpmbuild/SPECS/"
rpmbuild -bb --define "_topdir $HOME/rpmbuild" "$HOME/rpmbuild/SPECS/firmware-pipa.spec"
find "$HOME/rpmbuild/RPMS" -name 'firmware-pipa*.rpm' -exec cp -v {} "$OUT/" \;
ls -la "$OUT"
