#!/usr/bin/env bash
# Non-interactive: pull SDK image and confirm mic exists
set -euo pipefail
IMG="${SFOS_SDK_IMAGE:-coderus/sailfishos-platform-sdk-base:4.6.0.13}"
docker pull "$IMG"
docker run --rm "$IMG" bash -lc 'command -v mic; mic --version || mic --help | head -5'
