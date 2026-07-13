#!/usr/bin/env bash
# Post-flash bring-up checks over USB RNDIS SSH
set -euo pipefail
HOST="${1:-172.16.42.1}"
USER="${2:-root}"
export SSHPASS="${SSHPASS:-}"
SSH=(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5)
if [ -n "${SSHPASS}" ]; then
  SSH=(sshpass -e "${SSH[@]}" )
fi
"${SSH[@]}" "${USER}@${HOST}" 'bash -s' <<'REMOTE'
set -e
echo "== host =="; uname -a; cat /etc/os-release | head -5
echo "== display =="; busctl call com.nokia.mce /com/nokia/mce/request com.nokia.mce.request get_display_status 2>/dev/null || true
echo "== lipstick =="; systemctl --user -M nemo@ is-active lipstick 2>/dev/null || ps aux | grep -E '[l]ipstick' || true
echo "== backlight =="; cat /sys/class/backlight/*/brightness 2>/dev/null || true
echo "== wifi =="; connmanctl technologies 2>/dev/null | head -20 || true
echo "== rndis =="; ip -br addr | grep -E 'usb|rndis' || true
REMOTE
