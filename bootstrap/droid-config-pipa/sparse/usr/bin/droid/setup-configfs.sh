#!/bin/sh
# Prepare configfs USB gadget for usb-moded (mainline).
# Create g1 + rndis.usb0, leave UDC unbound so usb-moded can set
# idVendor/idProduct (writes fail with EINVAL while UDC is bound).

USB_FUNCTIONS=rndis
GADGET_DIR=/sys/kernel/config/usb_gadget
SERIAL="${1:-}"
# Stable MACs so host udev does not rename the interface every boot
DEV_ADDR="02:00:00:00:00:01"
HOST_ADDR="02:00:00:00:00:02"

write() {
	echo -n "$2" > "$1"
}

load_mod() {
	modprobe "$1" 2>/dev/null || true
}

if [ ! -d /sys/kernel/config ]; then
	mkdir -p /sys/kernel/config 2>/dev/null || true
fi
if ! grep -q ' /sys/kernel/config ' /proc/mounts 2>/dev/null; then
	mount -t configfs none /sys/kernel/config 2>/dev/null || true
fi

load_mod libcomposite
load_mod u_ether
load_mod usb_f_rndis

i=0
while [ ! -d "$GADGET_DIR" ] && [ "$i" -lt 20 ]; do
	load_mod libcomposite
	sleep 1
	i=$((i + 1))
done
if [ ! -d "$GADGET_DIR" ]; then
	echo "setup-configfs: $GADGET_DIR missing" >&2
	exit 1
fi

mkdir -p "$GADGET_DIR/g1" || exit 1

# Must be unbound before vendor/product writes (usb-moded also needs this)
if [ -e "$GADGET_DIR/g1/UDC" ]; then
	write "$GADGET_DIR/g1/UDC" "" || true
fi

write "$GADGET_DIR/g1/idVendor" "0x18D1"
write "$GADGET_DIR/g1/idProduct" "0x0A02"
mkdir -p "$GADGET_DIR/g1/strings/0x409"
write "$GADGET_DIR/g1/strings/0x409/serialnumber" "$SERIAL"
write "$GADGET_DIR/g1/strings/0x409/manufacturer" "Sailfish OS"
write "$GADGET_DIR/g1/strings/0x409/product" "Xiaomi Pad 6"

mkdir -p "$GADGET_DIR/g1/functions/rndis.usb0"
# Mainline usb_f_rndis uses host_addr/dev_addr (not ethaddr/wceis)
[ -e "$GADGET_DIR/g1/functions/rndis.usb0/dev_addr" ] && \
	write "$GADGET_DIR/g1/functions/rndis.usb0/dev_addr" "$DEV_ADDR" || true
[ -e "$GADGET_DIR/g1/functions/rndis.usb0/host_addr" ] && \
	write "$GADGET_DIR/g1/functions/rndis.usb0/host_addr" "$HOST_ADDR" || true

mkdir -p "$GADGET_DIR/g1/configs/b.1/strings/0x409"
write "$GADGET_DIR/g1/configs/b.1/strings/0x409/configuration" "$USB_FUNCTIONS"
ln -sfn "$GADGET_DIR/g1/functions/rndis.usb0" "$GADGET_DIR/g1/configs/b.1/"

i=0
while [ ! -e "$GADGET_DIR/g1/UDC" ] && [ "$i" -lt 10 ]; do
	sleep 1
	i=$((i + 1))
done
if [ ! -e "$GADGET_DIR/g1/UDC" ]; then
	echo "setup-configfs: UDC control missing" >&2
	exit 1
fi

# Leave unbound — usb-moded softconnects after idVendor/mode setup
write "$GADGET_DIR/g1/UDC" "" || true

exit 0
