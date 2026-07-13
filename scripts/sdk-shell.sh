#!/usr/bin/env bash
# Enter Sailfish Platform SDK Docker (dont_be_evil-ci image)
set -euo pipefail
IMG="${SFOS_SDK_IMAGE:-coderus/sailfishos-platform-sdk-base:4.6.0.13}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
docker run --rm -it --privileged \
  -v "$ROOT:/parentroot/home/ayman/sailfish-pipa" \
  -v "$ROOT:/sailfish-pipa" \
  -w /sailfish-pipa \
  "$IMG" "$@"
