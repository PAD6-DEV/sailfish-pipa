#!/usr/bin/env bash
# Turn mesa-pipa/out/mesa-freedreno-sfos-aarch64.tar.gz into mesa-pipa.rpm
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
TGZ="${1:-$REPO/mesa-pipa/out/mesa-freedreno-sfos-aarch64.tar.gz}"
OUT="${MESA_RPM_OUT:-$ROOT/out}"
test -s "$TGZ" || {
  echo "missing $TGZ — run mesa-pipa/build-mesa-freedreno.sh first" >&2
  exit 1
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
TOP="$WORK/rpmbuild"
mkdir -p "$WORK/wrap/destdir" "$OUT" "$TOP"/{SOURCES,SPECS,RPMS,BUILD,SRPMS}

# Tarball layout is usr/… — wrap as destdir/usr for %setup -n destdir
tar -C "$WORK/wrap/destdir" -xzf "$TGZ"
test -e "$WORK/wrap/destdir/usr/lib64/dri/msm_dri.so"
tar -C "$WORK/wrap" -czf "$TOP/SOURCES/mesa-pipa-tree.tar.gz" destdir
cp "$ROOT/rpm/mesa-pipa.spec" "$TOP/SPECS/"
rpmbuild -bb \
  --define "_topdir $TOP" \
  --define "__strip /bin/true" \
  --define "debug_package %{nil}" \
  --target aarch64-linux \
  "$TOP/SPECS/mesa-pipa.spec"
find "$TOP/RPMS" -name 'mesa-pipa*.rpm' -exec cp -v {} "$OUT/" \;
ls -la "$OUT"
