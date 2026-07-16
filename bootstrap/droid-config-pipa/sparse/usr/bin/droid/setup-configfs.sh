#!/bin/sh

# Set up configfs as we are not using droid-boot init-script (pinetab pattern).
# pipa uses rndis on mainline dwc3 (pinetab uses ecm on Rockchip).
USB_DRIVER=rndis
USB_FUNCTIONS=$USB_DRIVER,mtp
GADGET_DIR=/sys/kernel/config/usb_gadget

write() {
  echo -n "$2" > "$1"
}

mkdir -p $GADGET_DIR/g1
write $GADGET_DIR/g1/idVendor                   "0x18D1"
write $GADGET_DIR/g1/idProduct                  "0xD001"
mkdir -p $GADGET_DIR/g1/strings/0x409
write $GADGET_DIR/g1/strings/0x409/serialnumber "$1"
write $GADGET_DIR/g1/strings/0x409/manufacturer "Xiaomi"
write $GADGET_DIR/g1/strings/0x409/product      "Pad 6"

echo $USB_FUNCTIONS | grep -q "$USB_DRIVER"  && mkdir -p $GADGET_DIR/g1/functions/$USB_DRIVER.usb0
echo $USB_FUNCTIONS | grep -q "mass_storage" && mkdir -p $GADGET_DIR/g1/functions/storage.0
echo $USB_FUNCTIONS | grep -q "mtp"          && mkdir -p $GADGET_DIR/g1/functions/ffs.mtp

mkdir -p $GADGET_DIR/g1/configs/b.1
mkdir -p $GADGET_DIR/g1/configs/b.1/strings/0x409
write $GADGET_DIR/g1/configs/b.1/strings/0x409/configuration "$USB_FUNCTIONS"

echo $USB_FUNCTIONS | grep -q "$USB_DRIVER"  && ln -sfn $GADGET_DIR/g1/functions/$USB_DRIVER.usb0 $GADGET_DIR/g1/configs/b.1
echo $USB_FUNCTIONS | grep -q "mass_storage" && ln -sfn $GADGET_DIR/g1/functions/storage.0 $GADGET_DIR/g1/configs/b.1
echo $USB_FUNCTIONS | grep -q "mtp"          && ln -sfn $GADGET_DIR/g1/functions/ffs.mtp $GADGET_DIR/g1/configs/b.1

echo "" > $GADGET_DIR/g1/UDC
echo "$(ls /sys/class/udc | grep -v dummy | head -n 1)" > $GADGET_DIR/g1/UDC

exit 0
