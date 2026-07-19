#!/usr/bin/env bash
# Pack a real kernel-adaptation-pipa RPM from linux-pipa (.pkg.tar.xz or staged tree).
# Never ships a placeholder Image.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-${KERNEL_PKG:-https://thespider2.github.io/pipa-pkgs/repo/linux-pipa-7.1.0-4-aarch64.pkg.tar.xz}}"
OUT="${KERNEL_ADAPT_OUT:-$ROOT/out}"
STAGE="$ROOT/prebuilt"

chmod +x "$ROOT/scripts/stage-prebuilt-kernel.sh"
if [[ "$SRC" == https://* || "$SRC" == http://* ]]; then
  tmp=$(mktemp --suffix=.pkg.tar.xz)
  curl -fL --retry 3 -o "$tmp" "$SRC"
  bash "$ROOT/scripts/stage-prebuilt-kernel.sh" "$tmp"
  rm -f "$tmp"
else
  bash "$ROOT/scripts/stage-prebuilt-kernel.sh" "$SRC"
fi

test -s "$STAGE/boot/Image"
test "$(wc -c < "$STAGE/boot/Image")" -ge 1000000

mkdir -p "$OUT" "$HOME/rpmbuild"/{SOURCES,SPECS,RPMS,BUILD,SRPMS}
WRAP=$(mktemp -d)
trap 'rm -rf "$WRAP"' EXIT
mkdir -p "$WRAP/destdir/boot" "$WRAP/destdir/lib" "$WRAP/destdir/usr/share/kernel-adaptation-pipa"
cp -a "$STAGE/boot/." "$WRAP/destdir/boot/"
if [ -d "$STAGE/lib/modules" ]; then
  cp -a "$STAGE/lib/modules" "$WRAP/destdir/lib/modules"
else
  mkdir -p "$WRAP/destdir/lib/modules"
fi
if [ -d "$WRAP/destdir/boot/dtb" ] && [ ! -d "$WRAP/destdir/boot/dtbs" ]; then
  mkdir -p "$WRAP/destdir/boot/dtbs"
  cp -a "$WRAP/destdir/boot/dtb/." "$WRAP/destdir/boot/dtbs/"
fi
cat > "$WRAP/destdir/usr/share/kernel-adaptation-pipa/README" <<'EOF'
kernel-adaptation-pipa ships Image, DTBs, and modules from linux-pipa (PipaDB pipa/7.1).
EOF

tar -C "$WRAP" -czf "$HOME/rpmbuild/SOURCES/kernel-adaptation.tar.gz" destdir
cp "$ROOT/rpm/kernel-adaptation-pipa.spec" "$HOME/rpmbuild/SPECS/"

rpmbuild -bb --define "_topdir $HOME/rpmbuild" \
  --define "__strip /bin/true" --define "debug_package %{nil}" \
  "$HOME/rpmbuild/SPECS/kernel-adaptation-pipa.spec"

rm -f "$OUT"/kernel-adaptation-pipa*.rpm
find "$HOME/rpmbuild/RPMS" -name 'kernel-adaptation-pipa*.rpm' -exec cp -v {} "$OUT/" \;

tmpdir=$(mktemp -d)
rpm2cpio "$OUT"/kernel-adaptation-pipa-*.rpm | (cd "$tmpdir" && cpio -idm --quiet)
imgsz=$(wc -c < "$tmpdir/boot/Image")
test -f "$tmpdir/boot/dtbs/qcom/sm8250-xiaomi-pipa.dtb" \
  || test -f "$tmpdir/boot/dtbs/sm8250-xiaomi-pipa.dtb" \
  || find "$tmpdir/boot" -name 'sm8250-xiaomi-pipa*.dtb' | grep -q .
rm -rf "$tmpdir"
echo "Packaged /boot/Image size: $imgsz"
test "$imgsz" -ge 1000000
ls -lh "$OUT"
echo "OK: kernel-adaptation-pipa RPM"
