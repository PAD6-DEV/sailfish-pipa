#!/usr/bin/env bash
# Stage GitHub Pages site with adaptation RPM repository.
# Expects repo/adaptation/*.rpm (+ createrepo metadata).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${ADAPTATION_REPO:-$ROOT/repo/adaptation}"
SITE="${PAGES_SITE:-$ROOT/site}"

[ -d "$SRC" ] || { echo "missing $SRC" >&2; exit 1; }
test "$(find "$SRC" -name '*.rpm' | wc -l)" -ge 1 || {
  echo "no RPMs in $SRC" >&2
  exit 1
}

if [ ! -d "$SRC/repodata" ]; then
  if command -v createrepo_c >/dev/null; then
    createrepo_c "$SRC"
  elif command -v createrepo >/dev/null; then
    createrepo "$SRC"
  else
    echo "need createrepo_c" >&2
    exit 1
  fi
fi

rm -rf "$SITE"
mkdir -p "$SITE/adaptation"
cp -a "$SRC"/. "$SITE/adaptation/"

cat > "$SITE/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <title>sailfish-pipa adaptation</title>
</head>
<body>
  <h1>Sailfish OS pipa adaptation</h1>
  <p>RPM repository: <a href="adaptation/">adaptation/</a></p>
  <pre>ssu ar adaptation-xiaomi-pipa https://pad6-dev.github.io/sailfish-pipa/adaptation/
zypper ref adaptation-xiaomi-pipa</pre>
</body>
</html>
EOF

echo "Pages staged at $SITE"
find "$SITE/adaptation" -maxdepth 2 -type f | head -20
