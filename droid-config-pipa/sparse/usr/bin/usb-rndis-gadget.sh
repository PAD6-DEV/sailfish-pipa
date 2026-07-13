#!/bin/bash
# Mainline configfs USB RNDIS for Xiaomi Pad 6 (pipa / SM8250).
# Device address: 172.16.42.1/24
set -uo pipefail

USB_IDVENDOR="18D1"
USB_IDPRODUCT="D001"
USB_IPRODUCT="Sailfish Pipa"
USB_ISERIAL="sfos-pipa"
USB_IMANUFACTURER="SailfishOS"
LOCAL_IP="172.16.42.1"
GADGET_DIR="/sys/kernel/config/usb_gadget"
GADGET="${GADGET_DIR}/g1"

write() { echo -n "$2" > "$1"; }

force_device_role() {
  local f
  for f in /sys/class/usb_role/*/role; do
    [ -e "$f" ] || continue
    echo device > "$f" 2>/dev/null || echo peripheral > "$f" 2>/dev/null || true
  done
  for f in /sys/devices/platform/*/dwc3/*/mode \
           /sys/devices/platform/*/*/dwc3/*/mode \
           /sys/devices/platform/soc@0/a600000.usb/usb_role/a600000.usb-role-switch/role \
           /sys/devices/platform/soc/a600000.usb/usb_role/a600000.usb-role-switch/role; do
    [ -e "$f" ] || continue
    echo device > "$f" 2>/dev/null || echo peripheral > "$f" 2>/dev/null || true
  done
}

wait_for_udc() {
  local i udc
  for i in $(seq 1 40); do
    udc="$(ls -1 /sys/class/udc 2>/dev/null | head -n1 || true)"
    if [ -n "$udc" ]; then
      echo "$udc"
      return 0
    fi
    [ $((i % 5)) -eq 0 ] && force_device_role
    sleep 0.25
  done
  return 1
}

cleanup_gadget() {
  if [ -d "$GADGET" ]; then
    echo "" > "$GADGET/UDC" 2>/dev/null || true
    find "$GADGET/configs" -type l -delete 2>/dev/null || true
    rmdir "$GADGET"/configs/c.1/strings/* 2>/dev/null || true
    rmdir "$GADGET"/configs/* 2>/dev/null || true
    rmdir "$GADGET"/functions/* 2>/dev/null || true
    rmdir "$GADGET"/strings/* 2>/dev/null || true
    rmdir "$GADGET" 2>/dev/null || true
  fi
}

mountpoint -q /sys/kernel/config || mount -t configfs none /sys/kernel/config
modprobe libcomposite 2>/dev/null || true
modprobe usb_f_rndis 2>/dev/null || true

force_device_role
cleanup_gadget

mkdir -p "$GADGET"
write "$GADGET/idVendor" "0x${USB_IDVENDOR}"
write "$GADGET/idProduct" "0x${USB_IDPRODUCT}"
write "$GADGET/bcdDevice" "0x0100"
write "$GADGET/bcdUSB" "0x0200"
mkdir -p "$GADGET/strings/0x409"
write "$GADGET/strings/0x409/serialnumber" "$USB_ISERIAL"
write "$GADGET/strings/0x409/manufacturer" "$USB_IMANUFACTURER"
write "$GADGET/strings/0x409/product" "$USB_IPRODUCT"

mkdir -p "$GADGET/configs/c.1/strings/0x409"
write "$GADGET/configs/c.1/strings/0x409/configuration" "RNDIS"
write "$GADGET/configs/c.1/MaxPower" "250"

mkdir -p "$GADGET/functions/rndis.usb0"
ln -s "$GADGET/functions/rndis.usb0" "$GADGET/configs/c.1/"

UDC="$(wait_for_udc)" || { echo "No UDC"; exit 1; }
write "$GADGET/UDC" "$UDC"

# Bring up interface
for iface in usb0 rndis0; do
  if ip link show "$iface" >/dev/null 2>&1; then
    ip addr flush dev "$iface" 2>/dev/null || true
    ip addr add "${LOCAL_IP}/24" dev "$iface"
    ip link set "$iface" up
    echo "RNDIS ready on $iface ($LOCAL_IP)"
    exit 0
  fi
done
echo "Gadget bound but no usb0/rndis0 yet"
exit 0
