#!/bin/bash
# Mainline configfs RNDIS for pipa. Logs to /var/log and /boot/pipa-debug.
set -uo pipefail
mkdir -p /boot/pipa-debug /var/log
LOG=/var/log/pipa-usb.log
BOOTLOG=/boot/pipa-debug/usb.log
exec > >(tee -a "$LOG" "$BOOTLOG") 2>&1
echo "==== $(date -Is) usb-rndis-gadget ===="

USB_IDVENDOR="18D1"
USB_IDPRODUCT="D001"
USB_IPRODUCT="Sailfish Pipa"
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
    echo "role $f was $(cat "$f" 2>/dev/null)"
    echo device > "$f" 2>/dev/null || echo peripheral > "$f" 2>/dev/null || true
    echo "role $f now $(cat "$f" 2>/dev/null)"
  done
  find /sys -name mode -path '*/dwc3/*' 2>/dev/null | while read -r f; do
    echo "dwc3 mode $f was $(cat "$f" 2>/dev/null)"
    echo device > "$f" 2>/dev/null || echo peripheral > "$f" 2>/dev/null || true
  done
}

systemctl stop usb-moded.service 2>/dev/null || true
killall -q usb_moded 2>/dev/null || true

mountpoint -q /sys/kernel/config || mount -t configfs none /sys/kernel/config
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
  rmdir "$GADGET"/functions/* 2>/dev/null || true
  rmdir "$GADGET"/strings/* 2>/dev/null || true
  rmdir "$GADGET" 2>/dev/null || true
fi

mkdir -p "$GADGET"
write "$GADGET/idVendor" "0x${USB_IDVENDOR}"
write "$GADGET/idProduct" "0x${USB_IDPRODUCT}"
write "$GADGET/bcdDevice" "0x0100"
write "$GADGET/bcdUSB" "0x0200"
# Windows RNDIS needs 1 config + OS descriptors
mkdir -p "$GADGET/strings/0x409"
write "$GADGET/strings/0x409/serialnumber" "$USB_ISERIAL"
write "$GADGET/strings/0x409/manufacturer" "$USB_IMANUFACTURER"
write "$GADGET/strings/0x409/product" "$USB_IPRODUCT"

mkdir -p "$GADGET/functions/rndis.usb0"
write "$GADGET/functions/rndis.usb0/dev_addr" "02:00:00:00:00:01"
write "$GADGET/functions/rndis.usb0/host_addr" "02:00:00:00:00:02"
# OS descriptors for Windows
mkdir -p "$GADGET/functions/rndis.usb0/os_desc/interface.rndis"
write "$GADGET/functions/rndis.usb0/os_desc/interface.rndis/compatible_id" "RNDIS"
write "$GADGET/functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id" "5162001"
mkdir -p "$GADGET/os_desc"
write "$GADGET/os_desc/use" "1"
write "$GADGET/os_desc/b_vendor_code" "0xcd"
write "$GADGET/os_desc/qw_sign" "MSFT100"

mkdir -p "$GADGET/configs/c.1/strings/0x409"
write "$GADGET/configs/c.1/strings/0x409/configuration" "RNDIS"
write "$GADGET/configs/c.1/bmAttributes" "0x80"
write "$GADGET/configs/c.1/MaxPower" "250"
ln -sfn "$GADGET/functions/rndis.usb0" "$GADGET/configs/c.1/"
ln -sfn "$GADGET/configs/c.1" "$GADGET/os_desc/"

UDC=""
for i in $(seq 1 80); do
  force_device_role
  UDC="$(ls -1 /sys/class/udc 2>/dev/null | head -n1 || true)"
  if [ -n "$UDC" ]; then
    break
  fi
  sleep 0.25
done
if [ -z "$UDC" ]; then
  echo "FAIL: no UDC after wait"
  exit 1
fi
echo "Binding UDC=$UDC"
force_device_role
write "$GADGET/UDC" "$UDC"
sleep 0.5
echo "UDC file now: [$(cat "$GADGET/UDC" 2>/dev/null)]"

USB_IFACE=""
for _ in $(seq 1 40); do
  for cand in usb0 rndis0 usb1; do
    if [ -d "/sys/class/net/$cand" ]; then
      USB_IFACE=$cand
      break 2
    fi
  done
  sleep 0.25
done

ip link 2>&1 | head -30 || true
if [ -z "$USB_IFACE" ]; then
  echo "FAIL: no RNDIS netdev (UDC=$UDC)"
  # still leave gadget bound — host may enumerate later
  force_device_role
  exit 1
fi

ip link set "$USB_IFACE" up
ip addr flush dev "$USB_IFACE" 2>/dev/null || true
ip addr add "${LOCAL_IP}/24" dev "$USB_IFACE" 2>/dev/null \
  || ifconfig "$USB_IFACE" "$LOCAL_IP" netmask 255.255.255.0 up
force_device_role
echo "RNDIS ready on $USB_IFACE ($LOCAL_IP) UDC=$UDC"
ip addr show "$USB_IFACE" 2>&1 || true
exit 0
