#!/usr/bin/env bash
# Download published adaptation RPMs into DEST so mic has qcom/hexagon/firmware
# even when bootstrap/build-rpms.sh only built the noarch trio.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$ROOT/repo/adaptation}"
PAGES_BASE="${PAGES_BASE:-https://pad6-dev.github.io/sailfish-pipa}"
BASE="${ADAPTATION_URL:-$PAGES_BASE/adaptation}"

mkdir -p "$DEST"
echo "Seeding adaptation RPMs from $BASE → $DEST"

# Parse primary.xml.gz for package hrefs
PRIMARY=$(curl -fsSL "$BASE/repodata/repomd.xml" \
  | sed -n 's|.*href="\(repodata/[^"]*primary.xml.gz\)".*|\1|p' | head -1)
[ -n "$PRIMARY" ] || { echo "WARN: no primary metadata at $BASE" >&2; exit 0; }

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
curl -fsSL "$BASE/$PRIMARY" | gzip -dc > "$TMP" || {
  echo "WARN: cannot fetch primary.xml" >&2
  exit 0
}

mapfile -t HREFS < <(sed -n 's/.*href="\([^"]*\.rpm\)".*/\1/p' "$TMP" | sort -u)
for rel in "${HREFS[@]}"; do
  base=$(basename "$rel")
  # Do not overwrite newer local bootstrap builds if already present unless forced
  if [ -f "$DEST/$base" ] && [ "${FORCE_SEED:-0}" != 1 ]; then
    echo "keep local $base"
    continue
  fi
  echo "GET $base"
  curl -fsSL -o "$DEST/$base" "$BASE/$rel" || curl -fsSL -o "$DEST/$base" "$BASE/$base" || {
    echo "WARN: failed $base" >&2
  }
done

ls -la "$DEST"
