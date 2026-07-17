#!/bin/sh
# Remove broken SSU repos created by an earlier adaptation-pipa.ini that used
# keys like repo.adaptation-xiaomi-pipa.url / .name (SSU registered those
# literally as repo names with no URL).
set -eu
ADAPT_URL="${ADAPT_URL:-https://pad6-dev.github.io/sailfish-pipa/adaptation/}"

ssu rr repo.adaptation-xiaomi-pipa.name 2>/dev/null || true
ssu rr repo.adaptation-xiaomi-pipa.url 2>/dev/null || true
ssu rr 'repo.adaptation-xiaomi-pipa.name' 2>/dev/null || true
ssu rr 'repo.adaptation-xiaomi-pipa.url' 2>/dev/null || true

# Ensure the real adaptation repo exists
if ! ssu lr 2>/dev/null | grep -q 'adaptation-xiaomi-pipa'; then
  ssu ar adaptation-xiaomi-pipa "$ADAPT_URL" || true
fi
ssu ur 2>/dev/null || true
exit 0
