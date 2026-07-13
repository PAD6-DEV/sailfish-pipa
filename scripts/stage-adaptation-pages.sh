#!/usr/bin/env bash
# Compatibility wrapper — prefer scripts/stage-pages.sh
exec "$(cd "$(dirname "$0")" && pwd)/stage-pages.sh" "$@"
