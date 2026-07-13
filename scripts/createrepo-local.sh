#!/usr/bin/env bash
# Collect built RPMs into repo/adaptation and run createrepo_c
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/repo/adaptation"
mkdir -p "$DEST"
find "$ROOT" -name '*.rpm' -not -path "$DEST/*" -exec cp -n {} "$DEST/" \; || true
if command -v createrepo_c >/dev/null; then
  createrepo_c --update "$DEST"
elif command -v createrepo >/dev/null; then
  createrepo --update "$DEST"
else
  echo "Install createrepo_c, then re-run" >&2
  exit 1
fi
echo "Repo ready at $DEST"
