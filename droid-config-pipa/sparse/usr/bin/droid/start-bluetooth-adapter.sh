#!/bin/sh

# first, get the bluetooth address if possible
if [ -e /persist/bluetooth/.bdaddr ] ; then
	bdaddr="$(cat < /persist/bluetooth/.bdaddr)"
else
	bdaddr=""
fi

# Load QCA Bluetooth stack (mainline sm8250 / QCA6390)
/sbin/modprobe bluetooth 2>/dev/null || true
/sbin/modprobe hci_uart 2>/dev/null || true
/sbin/modprobe btqca 2>/dev/null || true

# Reprobe serial bluetooth nodes if firmware arrived late
for d in /sys/bus/serial/devices/*/uevent; do
	[ -e "$d" ] || continue
	grep -q bluetooth "$(dirname "$d")/of_node/compatible" 2>/dev/null || continue
	echo add > "$d"
done

sleep 2

# unblock bluetooth
/usr/sbin/rfkill unblock bluetooth

timeout=15
while [ ! -e /sys/class/bluetooth/hci0 ] ; do
	sleep 1
	if [ "$timeout" -le 0 ]; then
		echo "Could not persist BT mac addr cause the hci0 interface isn't available"
		exit 0
	fi
	timeout=$((timeout - 1))
done

#check if we have persistent bdaddr already, if not, save it here for next use
if [ ! -e /persist/bluetooth/.bdaddr ] ; then
	mkdir -p /persist/bluetooth
	chmod 755 /persist/bluetooth
	bdaddr=$(/usr/bin/hcitool dev 2>/dev/null | grep hci | tail -c 18)
	[ -z "$bdaddr" ] && bdaddr=$(hciconfig 2>/dev/null | grep Address | grep -o "[[:xdigit:]:]\{11,17\}" | head -1)
	[ -n "$bdaddr" ] && echo -ne "$bdaddr" > /persist/bluetooth/.bdaddr
fi
