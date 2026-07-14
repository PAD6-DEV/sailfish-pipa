#!/bin/bash
# Mainline configfs RNDIS for pipa. Must NEVER hang boot (no full /sys walks).
set -u
mkdir -p /var/log /run/pipa-debug
LOG=/var/log/pipa-usb.log
{
echo "==== $(date -Is 2>/dev/null || date) usb-rndis-gadget ===="

# Do NOT use 18D1:D001 — that is ADB/fastboot and confuses the host PC.
USB_IDVENDOR="18D1"
USB_IDPRODUCT="4EE7"
USB_IPRODUCT="Sailfish RNDIS"
USB_ISERIAL="sfos-pipa"
USB_IMANUFACTURER="SailfishOS"
LOCAL_IP="172.16.42.1"
GADGET_DIR="/sys/kernel/config/usb_gadget"
GADGET="${GADGET_DIR}/g1"

write() { echo -n "$2" > "$1" 2>/dev/null || echo "write fail: $1=$2"; }

force_device_role() {
  local f
  for f in /sys/class/usb_role/*/role; do
    [ -e "$f" ] || continue
    echo "role $f was $(cat "$f" 2>/dev/null || true)"
    echo device > "$f" 2>/dev/null || echo peripheral > "$f" 2>/dev/null || true
  done
  # Bound paths only — never `find /sys` (hangs boot for minutes).
  for f in /sys/devices/platform/*/dwc3.*/mode \
           /sys/devices/platform/*/*/dwc3.*/mode \
           /sys/devices/platform/*.usb/dwc3.*/mode \
           /sys/devices/platform/*.usb/*.dwc3/mode; do
    [ -e "$f" ] || continue
    echo "dwc3 mode $f was $(cat "$f" 2>/dev/null || true)"
    echo device > "$f" 2>/dev/null || echo peripheral > "$f" 2>/dev/null || true
  done
}

systemctl stop usb-moded.service 2>/dev/null || true
killall -q usb_moded 2>/dev/null || true

mountpoint -q /sys/kernel/config || mount -t configfs none /sys/kernel/config || true
modprobe libcomposite 2>/dev/null || true
modprobe usb_f_rndis 2>/dev/null || true
modprobe usb_f_ecm 2>/dev/null || true

echo "UDCs: $(ls /sys/class/udc 2>/dev/null | tr '\n' ' ')"
ls -la /sys/class/usb_role/ 2>&1 || true
force_device_role

# Cleanup old gadget
if [ -d "$GADGET" ]; then
  echo "" > "$GADGET/UDC" 2>/dev/null || true
  sleep 0.2
  find "$GADGET/configs" -type l -delete 2>/dev/null || true
  rm -f "$GADGET/os_desc/c.1" 2>/dev/null || true
  rmdir "$GADGET"/configs/c.1/strings/* 2>/dev/null || true
  rmdir "$GADGET"/configs/* 2>/dev/null || true
  rmdir "$GADGET"/functions/rndis.usb0/os_desc/interface.rndis 2>/dev/null || true
  rmdir "$GADGET"/functions/ecm.usb0 2>/dev/null || true
  rmdir "$GADGET"/functions/* 2>/dev/null || true
  rmdir "$GADGET"/strings/* 2>/dev/null || true
  rmdir "$GADGET" 2>/dev/null || true
fi

mkdir -p "$GADGET" || { echo "FAIL: mkdir gadget"; exit 0; }
write "$GADGET/idVendor" "0x${USB_IDVENDOR}"
write "$GADGET/idProduct" "0x${USB_IDPRODUCT}"
write "$GADGET/bcdDevice" "0x0100"
write "$GADGET/bcdUSB" "0x0200"
mkdir -p "$GADGET/strings/0x409"
write "$GADGET/strings/0x409/serialnumber" "$USB_ISERIAL"
write "$GADGET/strings/0x409/manufacturer" "$USB_IMANUFACTURER"
write "$GADGET/strings/0x409/product" "$USB_IPRODUCT"

USE_FUNC="rndis.usb0"
if mkdir -p "$GADGET/functions/rndis.usb0" 2>/dev/null; then
  write "$GADGET/functions/rndis.usb0/dev_addr" "02:00:00:00:00:01"
  write "$GADGET/functions/rndis.usb0/host_addr" "02:00:00:00:00:02"
  mkdir -p "$GADGET/functions/rndis.usb0/os_desc/interface.rndis"
  write "$GADGET/functions/rndis.usb0/os_desc/interface.rndis/compatible_id" "RNDIS"
  write "$GADGET/functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id" "5162001"
  mkdir -p "$GADGET/os_desc"
  write "$GADGET/os_desc/use" "1"
  write "$GADGET/os_desc/b_vendor_code" "0xcd"
  write "$GADGET/os_desc/qw_sign" "MSFT100"
else
  USE_FUNC="ecm.usb0"
  mkdir -p "$GADGET/functions/ecm.usb0"
  write "$GADGET/functions/ecm.usb0/dev_addr" "02:00:00:00:00:01"
  write "$GADGET/functions/ecm.usb0/host_addr" "02:00:00:00:00:02"
fi

mkdir -p "$GADGET/configs/c.1/strings/0x409"
write "$GADGET/configs/c.1/strings/0x409/configuration" "NET"
write "$GADGET/configs/c.1/bmAttributes" "0x80"
write "$GADGET/configs/c.1/MaxPower" "250"
ln -sfn "$GADGET/functions/$USE_FUNC" "$GADGET/configs/c.1/"
if [ -d "$GADGET/os_desc" ]; then
  ln -sfn "$GADGET/configs/c.1" "$GADGET/os_desc/" 2>/dev/null || true
fi

UDC=""
for i in $(seq 1 40); do
  force_device_role
  UDC="$(ls -1 /sys/class/udc 2>/dev/null | head -n1 || true)"
  if [ -n "$UDC" ]; then
    break
  fi
  sleep 0.25
done
if [ -z "$UDC" ]; then
  echo "FAIL: no UDC after wait — leaving without blocking boot"
  exit 0
fi
echo "Binding UDC=$UDC func=$USE_FUNC"
force_device_role
write "$GADGET/UDC" "$UDC"
sleep 0.5
echo "UDC file now: [$(cat "$GADGET/UDC" 2>/dev/null || true)]"

USB_IFACE=""
for _ in $(seq 1 30); do
  for cand in usb0 rndis0 usb1 eth0; do
    if [ -d "/sys/class/net/$cand" ]; then
      USB_IFACE=$cand
      break 2
    fi
  done
  sleep 0.2
done

ip link 2>&1 | head -30 || true
if [ -z "$USB_IFACE" ]; then
  echo "WARN: no netdev yet (UDC=$UDC) — gadget still bound"
  force_device_role
  # Do not fail the unit — host may enumerate later; keep retry path via oneshot RemainAfterExit
  exit 0
fi

ip link set "$USB_IFACE" up || true
ip addr flush dev "$USB_IFACE" 2>/dev/null || true
ip addr add "${LOCAL_IP}/24" dev "$USB_IFACE" 2>/dev/null \
  || ifconfig "$USB_IFACE" "$LOCAL_IP" netmask 255.255.255.0 up || true
force_device_role

# Ensure IP stays up + sshd is reachable (never block)
/usr/libexec/pipa-usb-debug-enable.sh 2>/dev/null || true
systemctl restart sshd.service 2>/dev/null || /usr/sbin/sshd 2>/dev/null || true
# Re-assert address in case connman stole the iface
ip addr add "${LOCAL_IP}/24" dev "$USB_IFACE" 2>/dev/null || true
ip link set "$USB_IFACE" up || true

echo "RNDIS ready on $USB_IFACE ($LOCAL_IP) UDC=$UDC — ssh root@${LOCAL_IP} / defaultuser (1234)"
ip addr show "$USB_IFACE" 2>&1 || true
ss -lntp 2>/dev/null | grep ':22' || netstat -lntp 2>/dev/null | grep ':22' || true
} >>"$LOG" 2>&1
cp -f "$LOG" /run/pipa-debug/usb.log 2>/dev/null || true
# Also try boot partition if mounted (optional)
if [ -d /boot ] && touch /boot/.writetest 2>/dev/null; then
  rm -f /boot/.writetest
  mkdir -p /boot/pipa-debug
  cp -f "$LOG" /boot/pipa-debug/usb.log 2>/dev/null || true
fi
exit 0
